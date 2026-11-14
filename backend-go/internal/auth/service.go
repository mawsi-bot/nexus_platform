package auth

import (
	"context"
	"errors"
	"net/mail"
	"nexus/backend-go/internal/core"
	"regexp"
	"strings"
	"time"
)

type Service struct {
	Store     core.AuthStore
	Mail      core.EmailSender
	SMS       core.PhoneSender
	Tokens    Tokens
	LookupKey []byte
	Now       func() time.Time
}
type Pair struct {
	JWT     string `json:"jwt"`
	Refresh string `json:"refresh"`
}

var phoneRE = regexp.MustCompile(`^\+[1-9][0-9]{7,14}$`)
var deviceRE = regexp.MustCompile(`^[A-Za-z0-9_-]{16,128}$`)

func ValidPhone(p string) bool  { return phoneRE.MatchString(p) }
func ValidDevice(d string) bool { return deviceRE.MatchString(d) }
func NormalizeEmail(e string) (string, error) {
	e = strings.ToLower(strings.TrimSpace(e))
	a, err := mail.ParseAddress(e)
	if err != nil || a.Address != e || len(e) > 254 || !strings.Contains(e, ".") {
		return "", core.ErrInvalid
	}
	return e, nil
}
func (s *Service) Register(ctx context.Context, p, d, e string) (Pair, error) {
	e, err := NormalizeEmail(e)
	if err != nil || !ValidPhone(p) || !ValidDevice(d) {
		return Pair{}, core.ErrInvalid
	}
	// Device-first signup: the installation that creates the account owns it at
	// once, so registration returns a session instead of a mail round-trip.
	// The address on file is the recovery channel only and stays unverified
	// until a recovery code is redeemed (Confirm marks it verified).
	u := core.User{ID: Random(18), Phone: p, Email: e, DeviceHash: Lookup(s.LookupKey, "device:"+d)}
	if err = s.Store.Register(ctx, u); err != nil {
		return Pair{}, err
	}
	return s.grant(ctx, core.Grant{Mode: "device", PhoneHash: Lookup(s.LookupKey, "phone:"+p), DeviceHash: u.DeviceHash})
}
func (s *Service) grant(ctx context.Context, g core.Grant) (Pair, error) {
	refresh := Random(32)
	g.Session = core.Session{ID: Random(18), Hash: Digest(refresh), Expires: s.Now().Add(30 * 24 * time.Hour)}
	g.Now = s.Now()
	u, err := s.Store.Grant(ctx, g)
	if err != nil {
		return Pair{}, err
	}
	// Rotation keeps its existing session ID; stores return it through g's mode-independent lookup below.
	sid := g.Session.ID
	if g.Mode == "refresh" {
		sid = g.Selector
	}
	return Pair{s.Tokens.Sign(u.ID, sid), refresh}, nil
}
func (s *Service) DeviceLogin(ctx context.Context, p, d string) (Pair, error) {
	if !ValidPhone(p) || !ValidDevice(d) {
		return Pair{}, core.ErrInvalid
	}
	return s.grant(ctx, core.Grant{Mode: "device", PhoneHash: Lookup(s.LookupKey, "phone:"+p), DeviceHash: Lookup(s.LookupKey, "device:"+d)})
}
func (s *Service) EmailVerify(ctx context.Context, p, e string) error {
	e, err := NormalizeEmail(e)
	if err != nil || !ValidPhone(p) {
		return core.ErrInvalid
	}
	// Reserve the same persistent limiter even for unknown/mismatched identities.
	if err = s.Store.Limit(ctx, "email:"+Lookup(s.LookupKey, p), 1, time.Minute, s.Now()); err != nil {
		return err
	}
	u, err := s.Store.ByPhone(ctx, Lookup(s.LookupKey, "phone:"+p))
	if errors.Is(err, core.ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	if !strings.EqualFold(u.Email, e) {
		return nil
	}
	selector := Random(16)
	code := selector + "." + Random(32)
	c := core.Challenge{Selector: Digest(selector), Hash: Digest(code), UserID: u.ID, Expires: s.Now().Add(10 * time.Minute)}
	if err = s.Store.IssueChallenge(ctx, c, s.Now()); err != nil {
		return err
	}
	if err = s.Mail.Send(ctx, u.Email, code); err != nil {
		cancelCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
		defer cancel()
		_ = s.Store.CancelChallenge(cancelCtx, c.Selector)
		return errors.New("email delivery unavailable")
	}
	return nil
}

// StartPhoneVerification sends a one-time code to the account's own number.
// It is deliberately limited to one message per minute per account.
func (s *Service) StartPhoneVerification(ctx context.Context, uid string) error {
	if s.SMS == nil {
		return core.ErrUnavailable
	}
	if err := s.Store.Limit(ctx, "sms:"+uid, 1, time.Minute, s.Now()); err != nil {
		return err
	}
	u, err := s.Store.ByID(ctx, uid)
	if err != nil {
		return err
	}
	selector := Random(16)
	code := selector + "." + Random(32)
	c := core.Challenge{Selector: Digest(selector), Hash: Digest(code), UserID: uid, Expires: s.Now().Add(5 * time.Minute)}
	if err = s.Store.IssueChallenge(ctx, c, s.Now()); err != nil {
		return err
	}
	if err = s.SMS.Send(ctx, u.Phone, "Nexus verification code: "+code); err != nil {
		cancelCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
		defer cancel()
		_ = s.Store.CancelChallenge(cancelCtx, c.Selector)
		return core.ErrUnavailable
	}
	return nil
}

// ConfirmPhone redeems the SMS code. It does not touch the device binding:
// verifying a number must never move a session to another installation.
func (s *Service) ConfirmPhone(ctx context.Context, otp string) error {
	parts := strings.Split(otp, ".")
	if len(parts) != 2 || len(parts[0]) != 22 || len(parts[1]) != 43 {
		return core.ErrUnauthorized
	}
	return s.Store.ConfirmPhone(ctx, Digest(parts[0]), Digest(otp), s.Now())
}

func (s *Service) Confirm(ctx context.Context, otp, d string) (Pair, error) {
	if !ValidDevice(d) {
		return Pair{}, core.ErrInvalid
	}
	parts := strings.Split(otp, ".")
	if len(parts) != 2 || len(parts[0]) != 22 || len(parts[1]) != 43 {
		return Pair{}, core.ErrUnauthorized
	}
	return s.grant(ctx, core.Grant{Mode: "otp", Selector: Digest(parts[0]), CodeHash: Digest(otp), DeviceHash: Lookup(s.LookupKey, "device:"+d)})
}
func (s *Service) Refresh(ctx context.Context, token string) (Pair, error) {
	// Refresh capability is session-id.random-secret so lookup never scans all sessions.
	parts := strings.Split(token, ".")
	if len(parts) != 2 || len(parts[0]) != 24 || len(parts[1]) != 43 {
		return Pair{}, core.ErrUnauthorized
	}
	return s.grant(ctx, core.Grant{Mode: "refresh", Selector: parts[0], RefreshHash: Digest(parts[1])})
}

// ExternalRefresh adds the nonsecret selector without changing the hashed secret.
func ExternalRefresh(p Pair, t Tokens) Pair {
	c, e := t.Verify(p.JWT)
	if e == nil {
		p.Refresh = c.Session + "." + p.Refresh
	}
	return p
}
func (s *Service) Authenticate(ctx context.Context, raw string) (core.User, string, error) {
	c, e := s.Tokens.Verify(raw)
	if e != nil {
		return core.User{}, "", core.ErrUnauthorized
	}
	ok, e := s.Store.Active(ctx, c.Subject, c.Session, s.Now())
	if e != nil {
		return core.User{}, "", e
	}
	if !ok {
		return core.User{}, "", core.ErrUnauthorized
	}
	return core.User{ID: c.Subject}, c.Session, nil
}
