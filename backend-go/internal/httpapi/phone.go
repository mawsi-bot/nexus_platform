package httpapi

import (
	"net/http"

	"nexus/backend-go/internal/core"
)

// startPhoneVerification sends the SMS code (503 when Twilio is not configured).
func (a *API) startPhoneVerification(w http.ResponseWriter, r *http.Request) {
	if err := a.Auth.StartPhoneVerification(r.Context(), who(r).UID); err != nil {
		a.fail(w, err)
		return
	}
	a.write(w, 202, map[string]string{"action": "CHECK_SMS"})
}

// confirmPhone redeems the SMS code and flags the number as verified.
func (a *API) confirmPhone(w http.ResponseWriter, r *http.Request) {
	var in struct {
		OTP string `json:"otp"`
	}
	if err := decode(w, r, &in); err != nil || in.OTP == "" {
		a.fail(w, core.ErrInvalid)
		return
	}
	if err := a.Auth.ConfirmPhone(r.Context(), in.OTP); err != nil {
		a.fail(w, err)
		return
	}
	a.write(w, 200, map[string]any{"phone_verified": true})
}
