package httpapi

import "regexp"

// mediaRefRE matches the opaque ids minted by POST /api/v1/media. Posts may
// only reference media this API created, never an arbitrary external URL.
var mediaRefRE = regexp.MustCompile(`^/api/v1/media/[0-9a-f]{32}$`)
