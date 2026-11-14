package httpapi

import (
	"errors"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"

	"nexus/backend-go/internal/core"
	"nexus/backend-go/internal/media"
)

// uploadMedia accepts one multipart file (§1.1). The content type is decided by
// magic bytes inside media.Store, never by the client header.
func (a *API) uploadMedia(w http.ResponseWriter, r *http.Request) {
	if a.Media == nil {
		a.write(w, 501, map[string]string{"error": "media_not_configured", "request_id": core.RequestID(r.Context())})
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, media.Limit+1<<20)
	file, header, err := r.FormFile("file")
	if err != nil {
		a.fail(w, core.ErrInvalid)
		return
	}
	defer file.Close()
	if header.Size > media.Limit {
		a.write(w, 413, map[string]string{"error": "media_too_large", "request_id": core.RequestID(r.Context())})
		return
	}
	rec, err := a.Media.Save(r.Context(), who(r).UID, file)
	switch {
	case errors.Is(err, media.ErrTooLarge):
		a.write(w, 413, map[string]string{"error": "media_too_large"})
		return
	case errors.Is(err, media.ErrUnsupported):
		a.write(w, 415, map[string]string{"error": "unsupported_media_type"})
		return
	case err != nil:
		a.fail(w, err)
		return
	}
	a.write(w, 201, map[string]any{
		"id":           rec.ID,
		"kind":         rec.Kind,
		"content_type": rec.ContentType,
		"bytes":        rec.Bytes,
		"url":          "/api/v1/media/" + rec.ID,
	})
}

// serveMedia streams an upload. Ids are 128-bit random, so the URL is the
// capability; responses are immutable and cacheable.
func (a *API) serveMedia(w http.ResponseWriter, r *http.Request) {
	if a.Media == nil {
		http.NotFound(w, r)
		return
	}
	rec, f, err := a.Media.Open(r.Context(), strings.TrimSpace(r.PathValue("id")))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	w.Header().Set("Content-Type", rec.ContentType)
	w.Header().Set("Content-Length", strconv.FormatInt(rec.Bytes, 10))
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	if _, err = io.Copy(w, f); err != nil && !errors.Is(err, os.ErrClosed) {
		a.Logger.Warn("media stream", "id", rec.ID, "err", err)
	}
}
