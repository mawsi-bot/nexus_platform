package sms

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSendPostsFormWithBasicAuth(t *testing.T) {
	var gotForm, gotUser string
	var gotPassOK bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			t.Fatal(err)
		}
		gotForm = r.PostForm.Encode()
		gotUser, _, gotPassOK = r.BasicAuth()
		_, _ = io.Copy(io.Discard, r.Body)
		w.WriteHeader(201)
	}))
	defer srv.Close()

	s := &Twilio{AccountSID: "AC123", AuthToken: "tok", From: "+15550000", Endpoint: srv.URL, Client: srv.Client()}
	if err := s.Send(context.Background(), "+959123456789", "Your code is 123456"); err != nil {
		t.Fatal(err)
	}
	if gotUser != "AC123" || !gotPassOK {
		t.Fatalf("basic auth = %q %v", gotUser, gotPassOK)
	}
	for _, want := range []string{"To=%2B959123456789", "From=%2B15550000", "Body=Your+code+is+123456"} {
		if !contains(gotForm, want) {
			t.Fatalf("form %q missing %q", gotForm, want)
		}
	}
}

func TestSendFailureIsAnError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
	}))
	defer srv.Close()
	s := &Twilio{AccountSID: "AC", AuthToken: "t", From: "+1", Endpoint: srv.URL, Client: srv.Client()}
	if err := s.Send(context.Background(), "+959123456789", "x"); err == nil {
		t.Fatal("401 accepted")
	}
}

func TestUnconfiguredSenderIsNil(t *testing.T) {
	if New("", "token", "+1") != nil || New("AC", "", "+1") != nil || New("AC", "t", "") != nil {
		t.Fatal("partial configuration built a sender")
	}
	var s *Twilio
	if err := s.Send(context.Background(), "+1", "x"); err == nil {
		t.Fatal("nil sender accepted a message")
	}
}

func contains(h, n string) bool {
	for i := 0; i+len(n) <= len(h); i++ {
		if h[i:i+len(n)] == n {
			return true
		}
	}
	return false
}
