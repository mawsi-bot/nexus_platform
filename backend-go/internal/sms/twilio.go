// Package sms sends one-time codes by SMS. It speaks the Twilio Messages REST
// API directly over HTTPS so the binary carries no third-party SDK.
package sms

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// ErrNotConfigured is returned when credentials or a sender id are missing.
var ErrNotConfigured = errors.New("sms: not configured")

// Sender delivers one message.
type Sender interface {
	Send(ctx context.Context, to, body string) error
}

// Twilio is a Messages API client.
type Twilio struct {
	AccountSID, AuthToken, From string
	// Endpoint is overridable for tests; empty means the public API.
	Endpoint string
	Client   *http.Client
}

// New builds a Twilio sender. It returns nil when any credential is absent, so
// callers can treat "no SMS configured" as a normal state rather than an error.
func New(accountSID, authToken, from string) *Twilio {
	if accountSID == "" || authToken == "" || from == "" {
		return nil
	}
	return &Twilio{
		AccountSID: accountSID,
		AuthToken:  authToken,
		From:       from,
		Client:     &http.Client{Timeout: 8 * time.Second},
	}
}

// FromEnv reads the three values the deployment provides.
//
//	TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, SMS_FROM
func FromEnv() *Twilio {
	return New(
		strings.TrimSpace(os.Getenv("TWILIO_ACCOUNT_SID")),
		strings.TrimSpace(os.Getenv("TWILIO_AUTH_TOKEN")),
		strings.TrimSpace(os.Getenv("SMS_FROM")),
	)
}

func (t *Twilio) endpoint() string {
	if t.Endpoint != "" {
		return t.Endpoint
	}
	return "https://api.twilio.com/2010-04-01/Accounts/" + url.PathEscape(t.AccountSID) + "/Messages.json"
}

// Send posts the message. The provider's response body is not echoed to the
// caller: it can contain the destination number.
func (t *Twilio) Send(ctx context.Context, to, body string) error {
	if t == nil || t.AccountSID == "" || t.AuthToken == "" || t.From == "" {
		return ErrNotConfigured
	}
	form := url.Values{"To": {to}, "From": {t.From}, "Body": {body}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.endpoint(), strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.SetBasicAuth(t.AccountSID, t.AuthToken)
	resp, err := t.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("sms: provider returned %d", resp.StatusCode)
	}
	return nil
}
