package store_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"nexus/backend-go/internal/auth"
	"nexus/backend-go/internal/core"
)

func TestReactReplacesAndSummarises(t *testing.T) {
	p := database(t)
	ctx := context.Background()
	now := time.Now().UTC()
	s := &auth.Service{Store: p, Mail: &mailCapture{}, LookupKey: p.LookupKey, Now: func() time.Time { return now }, Tokens: auth.Tokens{Key: []byte("jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj"), Now: func() time.Time { return now }}}
	pair, e := s.Register(ctx, "+959123450001", "device-react-0000000001", "react@example.com")
	if e != nil {
		t.Fatal(e)
	}
	user, _, e := s.Authenticate(ctx, pair.JWT)
	if e != nil {
		t.Fatal(e)
	}
	uid := user.ID
	post, e := p.Create(ctx, uid, core.Item{Kind: "post", Body: "hello"}, nil)
	if e != nil {
		t.Fatal(e)
	}

	// Invalid emotion is refused, not silently stored.
	if _, e = p.React(ctx, uid, post.ID, "angry"); !errors.Is(e, core.ErrInvalid) {
		t.Fatal("bad emotion accepted", e)
	}
	for _, emotion := range []string{"love", "hug", "strong"} {
		summary, err := p.React(ctx, uid, post.ID, emotion)
		if err != nil {
			t.Fatal(err)
		}
		// Switching emotion must move the count, never accumulate.
		if summary.Total != 1 || summary.Counts[emotion] != 1 || summary.Mine != emotion {
			t.Fatalf("after %s: %+v", emotion, summary)
		}
	}
	list, e := p.Reactors(ctx, post.ID, "strong", 10)
	if e != nil || len(list) != 1 || list[0].Emotion != "strong" {
		t.Fatalf("reactors: %v %v", list, e)
	}
	summary, e := p.React(ctx, uid, post.ID, "")
	if e != nil || summary.Total != 0 || summary.Mine != "" {
		t.Fatalf("clear: %+v %v", summary, e)
	}
}

func TestFlagRejectsUnknownKind(t *testing.T) {
	p := database(t)
	if e := p.Flag(context.Background(), "nobody", 1, "spam"); !errors.Is(e, core.ErrInvalid) {
		t.Fatal("unknown flag kind accepted", e)
	}
}
