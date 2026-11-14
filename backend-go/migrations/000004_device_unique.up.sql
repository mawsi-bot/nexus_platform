-- One installation, one account: the device binding is the primary credential,
-- so a device_hash may appear on at most one user. Partial index because older
-- rows may still carry an empty hash (registration before device binding).
--
-- Uniqueness of the contact identifiers is already enforced by
-- users.phone_hash UNIQUE and users.email_hash UNIQUE (indexes 000001). The
-- plaintext contact values live in phone_cipher / email_cipher and are never
-- stored in the clear, so no plaintext UNIQUE column is added here.
CREATE UNIQUE INDEX users_device_hash_unique_idx ON users(device_hash) WHERE device_hash <> '';
