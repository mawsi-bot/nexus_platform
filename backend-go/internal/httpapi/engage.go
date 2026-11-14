package httpapi

import (
	"errors"
	"net/http"
	"strconv"

	"nexus/backend-go/internal/core"
)

// react handles PUT/DELETE /api/v1/items/{id}/reaction?emotion=love|hug|strong.
func (a *API) react(w http.ResponseWriter, r *http.Request) {
	store, ok := a.Social.(core.EngageStore)
	if !ok {
		a.fail(w, core.ErrUnavailable)
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		a.fail(w, core.ErrInvalid)
		return
	}
	emotion := ""
	if r.Method == http.MethodPut {
		emotion = r.URL.Query().Get("emotion")
		if !core.ValidEmotion(emotion) {
			a.fail(w, core.ErrInvalid)
			return
		}
	}
	summary, err := store.React(r.Context(), who(r).UID, id, emotion)
	if err != nil {
		a.fail(w, err)
		return
	}
	a.write(w, 200, summary)
}

// reactionSummary handles GET /api/v1/items/{id}/reactions.
func (a *API) reactionSummary(w http.ResponseWriter, r *http.Request) {
	store, ok := a.Social.(core.EngageStore)
	if !ok {
		a.fail(w, core.ErrUnavailable)
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		a.fail(w, core.ErrInvalid)
		return
	}
	if r.URL.Query().Get("who") != "" {
		list, err := store.Reactors(r.Context(), id, r.URL.Query().Get("emotion"), 30)
		if err != nil {
			a.fail(w, err)
			return
		}
		a.write(w, 200, map[string]any{"items": list})
		return
	}
	summary, err := store.Reactions(r.Context(), who(r).UID, id)
	if err != nil {
		a.fail(w, err)
		return
	}
	a.write(w, 200, summary)
}

// flag handles PUT /api/v1/items/{id}/report and /hide.
func (a *API) flag(kind string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		store, ok := a.Social.(core.EngageStore)
		if !ok {
			a.fail(w, core.ErrUnavailable)
			return
		}
		id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
		if err != nil {
			a.fail(w, core.ErrInvalid)
			return
		}
		if err = store.Flag(r.Context(), who(r).UID, id, kind); err != nil {
			a.fail(w, err)
			return
		}
		a.write(w, 204, nil)
	}
}

var _ = errors.Is
