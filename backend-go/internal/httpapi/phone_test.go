package httpapi

import (
	"testing"
)

// A deployment without Twilio must answer 503, never a silent success.
func TestPhoneVerificationUnavailableWithoutProvider(t *testing.T) {
	a, m := fixture()
	h := a.Handler()
	_, p := login(t, a, m)
	if w := request(h, "POST", "/api/v1/users/me/phone/verification", "", p.JWT); w.Code != 503 {
		t.Fatalf("unconfigured = %d %s", w.Code, w.Body)
	}
}

func TestPhoneVerificationSendsAndConfirms(t *testing.T) {
	a, m := fixture()
	sms := &fakeSMS{}
	a.Auth.SMS = sms
	h := a.Handler()
	_, p := login(t, a, m)
	if w := request(h, "POST", "/api/v1/users/me/phone/verification", "", p.JWT); w.Code != 202 {
		t.Fatalf("send = %d %s", w.Code, w.Body)
	}
	if sms.sent != 1 {
		t.Fatalf("sms sent = %d", sms.sent)
	}
	// The endpoint requires the exact 66-character capability shape.
	if w := request(h, "POST", "/api/v1/users/me/phone/confirm", `{"otp":"short"}`, p.JWT); w.Code != 401 {
		t.Fatalf("bad otp = %d %s", w.Code, w.Body)
	}
}
