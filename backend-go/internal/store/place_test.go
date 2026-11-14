package store

import (
	"testing"

	"nexus/backend-go/internal/core"
)

func f(v float64) *float64 { return &v }

func TestValidatePlace(t *testing.T) {
	cases := []struct {
		name string
		item core.Item
		ok   bool
	}{
		{"no place", core.Item{Kind: "post"}, true},
		{"valid place", core.Item{Kind: "post", PlaceName: "Bahan, Yangon", Lat: f(16.8), Lng: f(96.15)}, true},
		{"place without coords", core.Item{Kind: "post", PlaceName: "Bahan"}, true},
		{"lat without lng", core.Item{Kind: "post", Lat: f(16.8)}, false},
		{"lng without lat", core.Item{Kind: "post", Lng: f(96.1)}, false},
		{"lat out of range", core.Item{Kind: "post", Lat: f(91), Lng: f(96)}, false},
		{"lng out of range", core.Item{Kind: "post", Lat: f(16), Lng: f(-181)}, false},
		{"place on a comment", core.Item{Kind: "comment", PlaceName: "Bahan", ParentID: 1}, false},
		{"place name too long", core.Item{Kind: "post", PlaceName: string(make([]byte, 121))}, false},
	}
	for _, c := range cases {
		err := validatePlace(c.item)
		if (err == nil) != c.ok {
			t.Fatalf("%s: ok=%v err=%v", c.name, c.ok, err)
		}
	}
}
