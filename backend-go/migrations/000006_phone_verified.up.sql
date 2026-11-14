-- SMS verification of the phone number (owner directive 2026-11-13).
ALTER TABLE users ADD COLUMN phone_verified boolean NOT NULL DEFAULT false;
