package httpapi

import (
	"encoding/json"
	"testing"

	"nexus/backend-go/internal/auth"
)

// Product directive: registration IS the device binding. No mail round-trip
// stands between signup and a usable session.
func TestRegisterReturnsSessionAndBindsDevice(t *testing.T) {
	a, _ := fixture()
	h := a.Handler()
	const body = `{"phone_number":"+959123456789","device_id":"device-012345678901","email":"owner@example.com"}`

	w := request(h, "POST", "/api/v1/auth/register", body, "")
	if w.Code != 200 {
		t.Fatalf("register = %d, want 200: %s", w.Code, w.Body)
	}
	var p auth.Pair
	if err := json.Unmarshal(w.Body.Bytes(), &p); err != nil || p.JWT == "" || p.Refresh == "" {
		t.Fatalf("register returned no session: %s", w.Body)
	}
	if me := request(h, "GET", "/api/v1/users/me", "", p.JWT); me.Code != 200 {
		t.Fatalf("register token rejected: %d %s", me.Code, me.Body)
	}
	// The same installation returns later with no verification step at all.
	if again := request(h, "POST", "/api/v1/auth/device-login", `{"phone_number":"+959123456789","device_id":"device-012345678901"}`, ""); again.Code != 200 {
		t.Fatalf("device-login = %d, want 200: %s", again.Code, again.Body)
	}
	// A different installation is routed to email recovery.
	other := request(h, "POST", "/api/v1/auth/device-login", `{"phone_number":"+959123456789","device_id":"device-999999999999"}`, "")
	if other.Code != 202 || other.Body.String() != "{\"action\":\"REQUIRE_EMAIL_VERIFICATION\"}\n" {
		t.Fatalf("mismatched device = %d %s", other.Code, other.Body)
	}
	// A second account on the same number is still refused.
	if dup := request(h, "POST", "/api/v1/auth/register", `{"phone_number":"+959123456789","device_id":"device-888888888888","email":"other@example.com"}`, ""); dup.Code != 409 {
		t.Fatalf("duplicate register = %d %s", dup.Code, dup.Body)
	}
}

// One installation, one account: the device binding is the primary credential.
func TestDeviceCannotOwnTwoAccounts(t *testing.T) {
	a, _ := fixture()
	h := a.Handler()
	first := request(h, "POST", "/api/v1/auth/register", `{"phone_number":"+959123456789","device_id":"device-012345678901","email":"owner@example.com"}`, "")
	if first.Code != 200 {
		t.Fatalf("first register = %d %s", first.Code, first.Body)
	}
	second := request(h, "POST", "/api/v1/auth/register", `{"phone_number":"+959123456700","device_id":"device-012345678901","email":"second@example.com"}`, "")
	if second.Code != 409 {
		t.Fatalf("same device second account = %d, want 409: %s", second.Code, second.Body)
	}
	// A different phone and a different device is a genuinely separate account.
	other := request(h, "POST", "/api/v1/auth/register", `{"phone_number":"+959123456700","device_id":"device-777777777777","email":"second@example.com"}`, "")
	if other.Code != 200 {
		t.Fatalf("separate register = %d %s", other.Code, other.Body)
	}
}
