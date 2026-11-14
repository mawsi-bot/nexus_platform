package auth_test

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"nexus/backend-go/internal/core"
)

type captureSMS struct {
	to    []string
	codes []string
	fail  bool
}

func (c *captureSMS) Send(_ context.Context, to, body string) error {
	if c.fail {
		return errors.New("provider down")
	}
	c.to = append(c.to, to)
	// The body is "Nexus verification code: <code>".
	c.codes = append(c.codes, strings.TrimPrefix(body, "Nexus verification code: "))
	return nil
}

func TestSMSVerificationMarksPhoneVerified(t *testing.T) {
	s, _, _ := setup(t)
	ctx := context.Background()
	phone := &captureSMS{}
	s.SMS = phone

	pair, err := s.Register(ctx, "+959123456789", device, "owner@example.com")
	if err != nil {
		t.Fatal(err)
	}
	hdr, _, e := s.Authenticate(ctx, pair.JWT)
	if e != nil {
		t.Fatal(e)
	}
	if err = s.StartPhoneVerification(ctx, hdr.ID); err != nil {
		t.Fatal(err)
	}
	if len(phone.codes) != 1 || phone.to[0] != "+959123456789" {
		t.Fatalf("sms not delivered: %+v", phone)
	}
	if err = s.ConfirmPhone(ctx, phone.codes[0]); err != nil {
		t.Fatal(err)
	}
	u, e := s.Store.ByID(ctx, hdr.ID)
	if e != nil || !u.PhoneVerified {
		t.Fatal("phone not marked verified", u, e)
	}
	// A code is single use.
	if err = s.ConfirmPhone(ctx, phone.codes[0]); !errors.Is(err, core.ErrUnauthorized) {
		t.Fatal("code reused", err)
	}
}

func TestSMSVerificationRejectsWrongCodeAndRateLimits(t *testing.T) {
	s, _, _ := setup(t)
	ctx := context.Background()
	phone := &captureSMS{}
	s.SMS = phone
	pair, e := s.Register(ctx, "+959123456789", device, "owner@example.com")
	if e != nil {
		t.Fatal(e)
	}
	hdr, _, _ := s.Authenticate(ctx, pair.JWT)

	if e = s.StartPhoneVerification(ctx, hdr.ID); e != nil {
		t.Fatal(e)
	}
	wrong := strings.Repeat("a", 22) + "." + strings.Repeat("b", 43)
	if e = s.ConfirmPhone(ctx, wrong); !errors.Is(e, core.ErrUnauthorized) {
		t.Fatal("wrong code accepted", e)
	}
	// One message per minute per account.
	if e = s.StartPhoneVerification(ctx, hdr.ID); !errors.Is(e, core.ErrLimited) {
		t.Fatal("second send not limited", e)
	}
	if u, _ := s.Store.ByID(ctx, hdr.ID); u.PhoneVerified {
		t.Fatal("wrong code verified the number")
	}
}

func TestSMSVerificationUnconfiguredAndProviderFailure(t *testing.T) {
	s, _, _ := setup(t)
	ctx := context.Background()
	pair, _ := s.Register(ctx, "+959123456789", device, "owner@example.com")
	hdr, _, _ := s.Authenticate(ctx, pair.JWT)

	if e := s.StartPhoneVerification(ctx, hdr.ID); !errors.Is(e, core.ErrUnavailable) {
		t.Fatal("unconfigured sender accepted", e)
	}
	s.SMS = &captureSMS{fail: true}
	if e := s.StartPhoneVerification(ctx, hdr.ID); !errors.Is(e, core.ErrUnavailable) {
		t.Fatal("provider failure swallowed", e)
	}
	// The failed provider call still consumed the minute budget, so the very next
	// send is refused rather than hammering the provider (fail-closed by design).
	if e := s.StartPhoneVerification(ctx, hdr.ID); !errors.Is(e, core.ErrLimited) {
		t.Fatal("limit not enforced after provider failure", e)
	}
	_ = time.Now
}
