package core

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

var (
	ErrUnauthorized = errors.New("unauthorized")
	ErrConflict     = errors.New("conflict")
	ErrLimited      = errors.New("rate_limited")
	ErrInvalid      = errors.New("invalid_input")
	ErrNotFound     = errors.New("not_found")
	ErrForbidden    = errors.New("forbidden")
	// ErrUnavailable marks a capability this deployment has not configured.
	ErrUnavailable = errors.New("unavailable")
)

type requestIDKey struct{}

func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey{}, id)
}
func RequestID(ctx context.Context) string { id, _ := ctx.Value(requestIDKey{}).(string); return id }

type User struct {
	ID         string          `json:"id"`
	Phone      string          `json:"phone_number,omitempty"`
	Email      string          `json:"email,omitempty"`
	DeviceHash string          `json:"-"`
	Verified   bool            `json:"email_verified"`
	Name       string          `json:"name"`
	Bio        string          `json:"bio"`
	Metadata   json.RawMessage `json:"metadata,omitempty"`
	// Privacy module (§2.4).
	PhoneVerified bool   `json:"phone_verified"`
	Private       bool   `json:"private_account"`
	Comments      string `json:"comment_policy,omitempty"`
}
type Challenge struct {
	Selector, Hash, UserID string
	Expires                time.Time
	Attempts               int
	Used                   bool
}
type Session struct {
	ID, UserID, Hash string
	Expires          time.Time
	Revoked          bool
}
type Grant struct {
	Mode, PhoneHash, DeviceHash, Selector, CodeHash, RefreshHash string
	Session                                                      Session
	Now                                                          time.Time
}

// AuthStore operations that mutate identity and sessions MUST be atomic.
// SQLStore is the production implementation; MemoryStore is a race-safe test double.
type AuthStore interface {
	Register(context.Context, User) error
	ByPhone(context.Context, string) (User, error)
	ByID(context.Context, string) (User, error)
	ConfirmPhone(context.Context, string, string, time.Time) error
	IssueChallenge(context.Context, Challenge, time.Time) error
	CancelChallenge(context.Context, string) error
	Grant(context.Context, Grant) (User, error)
	Active(context.Context, string, string, time.Time) (bool, error)
	Revoke(context.Context, string, string) error
	Limit(context.Context, string, int, time.Duration, time.Time) error
}

type EmailSender interface {
	Send(context.Context, string, string) error
}

// PhoneSender delivers a short message (SMS) to an E.164 number.
type PhoneSender interface {
	Send(context.Context, string, string) error
}

type Item struct {
	ID         int64            `json:"id"`
	Kind       string           `json:"kind"`
	AuthorID   string           `json:"author_id,omitempty"`
	ParentID   int64            `json:"parent_id,omitempty"`
	Name       string           `json:"name,omitempty"`
	Body       string           `json:"body,omitempty"`
	Visibility string           `json:"visibility,omitempty"`
	Price      int64            `json:"price_minor,omitempty"`
	Currency   string           `json:"currency,omitempty"`
	PlaceName  string           `json:"place_name,omitempty"`
	MediaURL   string           `json:"media_url,omitempty"`
	Media      []string         `json:"media,omitempty"`
	Reactions  *ReactionSummary `json:"reactions,omitempty"`
	Lat        *float64         `json:"lat,omitempty"`
	Lng        *float64         `json:"lng,omitempty"`
	CreatedAt  time.Time        `json:"created_at"`
	Metadata   json.RawMessage  `json:"metadata,omitempty"`
}
type Query struct {
	Kind, UserID, Search string
	ParentID, Before     int64
	Limit                int
}
type ProfilePatch struct {
	Name *string `json:"name,omitempty"`
	Bio  *string `json:"bio,omitempty"`
}
type Activity struct {
	ID        int64     `json:"id"`
	ActorID   string    `json:"actor_id,omitempty"`
	TargetID  string    `json:"target_id,omitempty"`
	ItemID    int64     `json:"item_id,omitempty"`
	Kind      string    `json:"kind"`
	Body      string    `json:"body,omitempty"`
	Quantity  int       `json:"quantity,omitempty"`
	Read      bool      `json:"read"`
	CreatedAt time.Time `json:"created_at"`
}
type ActivityStore interface {
	Activities(context.Context, string, string, int64, int) ([]Activity, error)
	FollowUser(context.Context, string, string, bool) error
	Share(context.Context, string, int64) (Activity, error)
	Cart(context.Context, string, int64, int) error
	ReadNotification(context.Context, string, int64) error
}
type SocialStore interface {
	// Privacy persists the account privacy module (§2.4).
	Privacy(ctx context.Context, uid string, private *bool, policy *string) error
	Profile(context.Context, string, *ProfilePatch) (User, error)
	List(context.Context, Query) ([]Item, error)
	Get(context.Context, string, string, int64) (Item, error)
	Create(context.Context, string, Item, []string) (Item, error)
	Membership(context.Context, string, string, int64, bool) error
	Relation(context.Context, string, string, int64, bool) error
	DeleteUser(context.Context, string) error
}

// Emotion is one of the three community reactions (§3 v1.3.0).
var emotions = map[string]bool{"love": true, "hug": true, "strong": true}

// ValidEmotion reports whether e is a supported reaction.
func ValidEmotion(e string) bool { return emotions[e] }

// ReactionSummary is the per-emotion tally for one post.
type ReactionSummary struct {
	Counts map[string]int `json:"counts"`
	Total  int            `json:"total"`
	Mine   string         `json:"mine,omitempty"`
}

// Reactor is one row of the who-reacted sheet.
type Reactor struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Emotion  string `json:"emotion"`
	Verified bool   `json:"verified"`
}

// EngageStore is the reaction/report surface of a social store.
type EngageStore interface {
	React(ctx context.Context, uid string, id int64, emotion string) (ReactionSummary, error)
	Reactions(ctx context.Context, uid string, id int64) (ReactionSummary, error)
	Reactors(ctx context.Context, id int64, emotion string, limit int) ([]Reactor, error)
	Flag(ctx context.Context, uid string, id int64, kind string) error
}

// ValidReportReason guards the free-text report reason.
func ValidReportReason(r string) bool { return len(r) <= 300 }
