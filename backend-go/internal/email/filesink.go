package email

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"nexus/backend-go/internal/core"
)

// FileSink writes verification mail to a local file instead of a provider.
// It exists only for local end-to-end rehearsal; main refuses to build it
// unless NEXUS_ENV=development, so production cannot silently drop mail.
type FileSink struct {
	Path string
}

// NewFileSink validates the path, creates the parent directory when missing
// (Windows: C:\nexus usually does not exist yet), and writes a "sink ready"
// line immediately so an operator can tell wiring from delivery at a glance.
func NewFileSink(path string) (*FileSink, error) {
	if path == "" || !filepath.IsAbs(path) {
		return nil, fmt.Errorf("email sink path must be absolute, got %q", path)
	}
	if dir := filepath.Dir(path); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return nil, fmt.Errorf("email sink directory %s: %w", dir, err)
		}
	}
	h, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, fmt.Errorf("email sink open %s: %w", path, err)
	}
	defer h.Close()
	if _, err = fmt.Fprintf(h, "# nexus email sink ready path=%s\n", path); err != nil {
		return nil, fmt.Errorf("email sink write %s: %w", path, err)
	}
	return &FileSink{Path: path}, nil
}

func (f *FileSink) Send(ctx context.Context, to, code string) error {
	h, err := os.OpenFile(f.Path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return fmt.Errorf("email sink unavailable (%s): %w", f.Path, err)
	}
	defer h.Close()
	if _, err = fmt.Fprintf(h, "to=%s code=%s request_id=%s\n", to, code, core.RequestID(ctx)); err != nil {
		return fmt.Errorf("email sink write failed (%s): %w", f.Path, err)
	}
	return nil
}
