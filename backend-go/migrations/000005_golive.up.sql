-- v1.1.0 go-live schema.
-- (1) Media attachments. Files themselves live outside the database; this table
--     records ownership, kind and a stable public id.
CREATE TABLE media (
 id text PRIMARY KEY,
 user_id text NOT NULL REFERENCES users ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN ('image','video')),
 content_type text NOT NULL,
 bytes bigint NOT NULL CHECK(bytes > 0 AND bytes <= 26214400),
 width integer NOT NULL DEFAULT 0,
 height integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX media_user_idx ON media(user_id, created_at DESC);

-- (2) Reactions: a post keeps a per-emotion counter set, and a user's own
--     reaction replaces any previous one (Facebook-style single reaction).
ALTER TABLE items ADD COLUMN reaction text NOT NULL DEFAULT '';
ALTER TABLE items ADD COLUMN reactions jsonb NOT NULL DEFAULT '{}'::jsonb
 CHECK(jsonb_typeof(reactions)='object');

-- (3) Geo for Radar / Nearby. PostGIS is not available on this deployment, so
--     the earthdistance + cube pair gives the same ST_DWithin semantics with a
--     GiST index over ll_to_earth(lat,lng).
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
ALTER TABLE items ADD COLUMN lat double precision;
ALTER TABLE items ADD COLUMN lng double precision;
CREATE INDEX items_geo_idx ON items USING gist (ll_to_earth(lat, lng))
 WHERE lat IS NOT NULL AND lng IS NOT NULL;

-- (4) Privacy module (§2.4) and per-account comment policy.
ALTER TABLE users ADD COLUMN private_account boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN comment_policy text NOT NULL DEFAULT 'everyone'
 CHECK(comment_policy IN ('everyone','friends','nobody'));

-- (5) Offline queue needs an idempotency key so a retried post is not inserted twice.
ALTER TABLE items ADD COLUMN client_key text NOT NULL DEFAULT '';
CREATE UNIQUE INDEX items_client_key_idx ON items(author_id, client_key)
 WHERE client_key <> '';

-- (6) Message bodies are stored encrypted (AES-GCM) for at-rest protection (§4.5).
ALTER TABLE items ADD COLUMN body_cipher bytea;
