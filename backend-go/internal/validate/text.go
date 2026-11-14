// Package validate holds the input rules shared by every write endpoint (§4.1).
package validate

import (
	"net/url"
	"regexp"
	"strings"
	"unicode/utf8"
)

// Limits are enforced in the database too; these give a clear 400 first.
const (
	MaxPost    = 5000
	MaxComment = 1000
	MaxMessage = 2000
	MaxName    = 120
	MaxLinks   = 2
)

// Profanity is a deliberately small, English-only baseline. It is not a
// moderation strategy — it stops casual abuse and nothing more.
var profanity = []string{
	"fuck", "shit", "bitch", "cunt", "asshole", "nigger", "faggot", "rape",
}

var linkRE = regexp.MustCompile(`(?i)\b(?:https?://|www\.)\S+`)

// Text normalises and validates user-authored content.
//
// It returns the cleaned text. A blocked word is replaced with the same number
// of asterisks so the sentence still reads.
func Text(raw string, limit int) (string, error) {
	s := strings.TrimSpace(raw)
	if s == "" {
		return "", Err("text is required")
	}
	if utf8.RuneCountInString(s) > limit {
		return "", Err("text is too long")
	}
	if strings.Count(s, "\x00") > 0 {
		return "", Err("text contains invalid characters")
	}
	// Link spam: more than a couple of URLs in one message is a bot pattern.
	if len(linkRE.FindAllString(s, MaxLinks+1)) > MaxLinks {
		return "", Err("too many links")
	}
	lower := strings.ToLower(s)
	for _, word := range profanity {
		if idx := strings.Index(lower, word); idx >= 0 {
			masked := strings.Repeat("*", len(word))
			var b strings.Builder
			for {
				i := strings.Index(lower, word)
				if i < 0 {
					b.WriteString(s)
					break
				}
				b.WriteString(s[:i])
				b.WriteString(masked)
				s, lower = s[i+len(word):], lower[i+len(word):]
			}
			s = b.String()
		}
	}
	return s, nil
}

// SafeURL accepts only http(s) links that carry a host.
func SafeURL(raw string) (string, bool) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return "", false
	}
	return u.String(), true
}

// Error is a validation failure that maps to 400 invalid_input.
type Error string

func (e Error) Error() string { return string(e) }

// Err builds a validation error.
func Err(msg string) error { return Error(msg) }
