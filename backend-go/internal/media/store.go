// Package media stores user uploads on disk and records them in Postgres (§1.1).
package media

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Errors map onto the API's standard error kinds.
var (
	ErrUnsupported = errors.New("unsupported media type")
	ErrTooLarge    = errors.New("media is too large")
	ErrNotFound    = errors.New("media not found")
)

// Limit is the largest accepted upload (25 MiB, matching the media table check).
const Limit = 25 << 20

type record struct {
	ID, UserID, Kind, ContentType string
	Bytes                         int64
}

// Record is the persisted metadata for one upload.
type Record = record

// Store writes uploads under Dir and keeps metadata in the database.
type Store struct {
	Dir  string
	Exec func(ctx context.Context, query string, args ...any) error
	// QueryFn scans exactly one row into dest.
	QueryFn func(ctx context.Context, query string, args []any, dest ...any) error
}

// sniff identifies images and videos from their magic bytes: the client's
// Content-Type header is never trusted.
func sniff(head []byte) (kind, contentType, ext string) {
	switch {
	case len(head) > 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF:
		return "image", "image/jpeg", ".jpg"
	case len(head) > 8 && strings.HasPrefix(string(head), "\x89PNG\r\n\x1a\n"):
		return "image", "image/png", ".png"
	case len(head) > 12 && string(head[0:4]) == "RIFF" && string(head[8:12]) == "WEBP":
		return "image", "image/webp", ".webp"
	case len(head) > 12 && string(head[4:8]) == "ftyp":
		return "video", "video/mp4", ".mp4"
	}
	return "", "", ""
}

// Save consumes r, validates it, writes it to disk and records ownership.
// The caller must have authenticated the user.
func (s *Store) Save(ctx context.Context, userID string, r io.Reader) (Record, error) {
	if err := os.MkdirAll(s.Dir, 0o750); err != nil {
		return Record{}, err
	}
	head := make([]byte, 16)
	n, err := io.ReadFull(r, head)
	if err != nil && !errors.Is(err, io.ErrUnexpectedEOF) && !errors.Is(err, io.EOF) {
		return Record{}, err
	}
	kind, ctype, ext := sniff(head[:n])
	if kind == "" {
		return Record{}, ErrUnsupported
	}
	id := newID()
	tmp, err := os.CreateTemp(s.Dir, ".upload-*")
	if err != nil {
		return Record{}, err
	}
	defer os.Remove(tmp.Name())
	written, err := io.Copy(tmp, io.LimitReader(io.MultiReader(strings.NewReader(string(head[:n])), r), Limit+1))
	closeErr := tmp.Close()
	if err != nil {
		return Record{}, err
	}
	if closeErr != nil {
		return Record{}, closeErr
	}
	if written > Limit {
		return Record{}, ErrTooLarge
	}
	final := filepath.Join(s.Dir, id+ext)
	if err = os.Rename(tmp.Name(), final); err != nil {
		return Record{}, err
	}
	if err = s.Exec(ctx, `INSERT INTO media(id,user_id,kind,content_type,bytes) VALUES($1,$2,$3,$4,$5)`, id, userID, kind, ctype, written); err != nil {
		os.Remove(final)
		return Record{}, err
	}
	return Record{ID: id, UserID: userID, Kind: kind, ContentType: ctype, Bytes: written}, nil
}

// Open resolves a stored object for serving. Ownership is not checked: media
// URLs are unguessable and the API only ever exposes them inside authorised
// payloads.
func (s *Store) Open(ctx context.Context, id string) (Record, *os.File, error) {
	var rec Record
	err := s.Query(ctx, `SELECT id,user_id,kind,content_type,bytes FROM media WHERE id=$1`, []any{id},
		&rec.ID, &rec.UserID, &rec.Kind, &rec.ContentType, &rec.Bytes)
	if err != nil {
		return rec, nil, ErrNotFound
	}
	for _, ext := range []string{".jpg", ".png", ".webp", ".mp4"} {
		f, err := os.Open(filepath.Join(s.Dir, id+ext))
		if err == nil {
			return rec, f, nil
		}
	}
	return rec, nil, ErrNotFound
}

// Query scans one row; injected so the package does not depend on database/sql.
func (s *Store) Query(ctx context.Context, q string, args []any, dest ...any) error {
	if s.QueryFn == nil {
		return ErrNotFound
	}
	return s.QueryFn(ctx, q, args, dest...)
}

func newID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// ContentTypeOf is shared with tests.
func ContentTypeOf(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	head := make([]byte, 16)
	n, _ := f.Read(head)
	_, ct, _ := sniff(head[:n])
	return ct
}

var _ = http.DetectContentType
