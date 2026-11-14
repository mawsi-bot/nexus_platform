package httpapi

import (
	"net/http"

	"nexus/backend-go/internal/core"
	"nexus/backend-go/internal/validate"
)

// guardBody applies §4.1 to every user-authored write before it reaches the
// store: length limits, profanity masking and link-spam rejection.
func guardBody(w http.ResponseWriter, kind string, body *string) bool {
	limit := validate.MaxPost
	switch kind {
	case "comment":
		limit = validate.MaxComment
	case "message":
		limit = validate.MaxMessage
	}
	clean, err := validate.Text(*body, limit)
	if err != nil {
		http.Error(w, `{"error":"invalid_input"}`, http.StatusBadRequest)
		return false
	}
	*body = clean
	return true
}

var _ = core.ErrInvalid
