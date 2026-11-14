package email

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestFileSinkWritesVerificationMail(t *testing.T) {
	p := filepath.Join(t.TempDir(), "mail.log")
	s, err := NewFileSink(p)
	if err != nil {
		t.Fatalf("sink: %v", err)
	}
	if err := s.Send(context.Background(), "a@b.co", "sel.code"); err != nil {
		t.Fatalf("send: %v", err)
	}
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(string(b), "to=a@b.co") || !strings.Contains(string(b), "code=sel.code") {
		t.Fatalf("unexpected sink content: %s", b)
	}
	info, err := os.Stat(p)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("sink permissions must be 0600, got %v (%v)", info.Mode().Perm(), err)
	}
}

func TestFileSinkRejectsRelativePath(t *testing.T) {
	if _, err := NewFileSink("mail.log"); err == nil {
		t.Fatal("relative sink path accepted")
	}
}

func TestFileSinkCreatesMissingParentDirectory(t *testing.T) {
	// Windows users point the sink at C:\nexus\emails.log; that directory
	// often does not exist yet, which used to fail the whole startup.
	p := filepath.Join(t.TempDir(), "nexus", "mail", "emails.log")
	s, err := NewFileSink(p)
	if err != nil {
		t.Fatalf("sink with missing parent dir: %v", err)
	}
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(string(b), "sink ready") {
		t.Fatalf("expected a ready line at construction, got %q", b)
	}
	if err := s.Send(context.Background(), "x@y.co", "cap"); err != nil {
		t.Fatalf("send after boot: %v", err)
	}
	info, err := os.Stat(p)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("perm must stay 0600, got %v (%v)", info.Mode().Perm(), err)
	}
}
