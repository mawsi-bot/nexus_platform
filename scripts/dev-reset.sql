-- Local development only: wipe every table so a registration can be retried.
-- TRUNCATE ... CASCADE clears dependants; RESTART IDENTITY resets sequences.
TRUNCATE TABLE
    sessions, challenges, rate_limits, notifications, shares,
    memberships, relations, user_follows, cart_entries, items, users
RESTART IDENTITY CASCADE;
