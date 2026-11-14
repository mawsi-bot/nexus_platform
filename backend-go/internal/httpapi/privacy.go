package httpapi

import (
	"net/http"

	"nexus/backend-go/internal/core"
)

// privacyInput is the §2.4 settings payload.
type privacyInput struct {
	PrivateAccount *bool   `json:"private_account"`
	CommentPolicy  *string `json:"comment_policy"`
}

// updatePrivacy persists the account privacy module. Values are constrained by
// a database CHECK, so an unknown policy is rejected rather than stored.
func (a *API) updatePrivacy(w http.ResponseWriter, r *http.Request) {
	var in privacyInput
	if err := decode(w, r, &in); err != nil {
		a.fail(w, err)
		return
	}
	if in.CommentPolicy != nil {
		switch *in.CommentPolicy {
		case "everyone", "friends", "nobody":
		default:
			a.fail(w, core.ErrInvalid)
			return
		}
	}
	if err := a.Social.Privacy(r.Context(), who(r).UID, in.PrivateAccount, in.CommentPolicy); err != nil {
		a.fail(w, err)
		return
	}
	u, err := a.Social.Profile(r.Context(), who(r).UID, nil)
	if err != nil {
		a.fail(w, err)
		return
	}
	a.write(w, 200, u)
}
