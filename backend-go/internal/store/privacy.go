package store

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"nexus/backend-go/internal/auth"
	"nexus/backend-go/internal/core"
)

// Privacy writes only the fields supplied, so a partial PATCH never clears the
// other setting.
func (p *Postgres) Privacy(ctx context.Context, uid string, private *bool, policy *string) error {
	if private != nil {
		if _, e := p.DB.ExecContext(ctx, `UPDATE users SET private_account=$1 WHERE id=$2`, *private, uid); e != nil {
			return e
		}
	}
	if policy != nil {
		if _, e := p.DB.ExecContext(ctx, `UPDATE users SET comment_policy=$1 WHERE id=$2`, *policy, uid); e != nil {
			return e
		}
	}
	return nil
}

// ByID loads the account behind a session subject.
func (p *Postgres) ByID(ctx context.Context, id string) (core.User, error) {
	var u core.User
	var ph, em []byte
	e := p.DB.QueryRowContext(ctx, `SELECT id,phone_cipher,email_cipher,device_hash,email_verified,phone_verified,name,bio,private_account,comment_policy FROM users WHERE id=$1`, id).
		Scan(&u.ID, &ph, &em, &u.DeviceHash, &u.Verified, &u.PhoneVerified, &u.Name, &u.Bio, &u.Private, &u.Comments)
	if e != nil {
		return u, mapErr(e)
	}
	if u.Phone, e = auth.Open(p.EncryptionKey, ph); e != nil {
		return u, e
	}
	u.Email, e = auth.Open(p.EncryptionKey, em)
	return u, e
}

// ConfirmPhone redeems an SMS challenge and marks the number verified.
func (p *Postgres) ConfirmPhone(ctx context.Context, selector, codeHash string, now time.Time) error {
	tx, e := p.DB.BeginTx(ctx, nil)
	if e != nil {
		return e
	}
	defer tx.Rollback()
	var uid, hash string
	var expires time.Time
	var attempts int
	var used bool
	e = tx.QueryRowContext(ctx, `SELECT user_id,code_hash,expires_at,attempts,used FROM challenges WHERE selector=$1 FOR UPDATE`, selector).
		Scan(&uid, &hash, &expires, &attempts, &used)
	if errors.Is(e, sql.ErrNoRows) {
		return core.ErrUnauthorized
	}
	if e != nil {
		return e
	}
	if used || !now.Before(expires) || attempts >= 5 || !equal(hash, codeHash) {
		if !equal(hash, codeHash) {
			if _, e = tx.ExecContext(ctx, `UPDATE challenges SET attempts=attempts+1 WHERE selector=$1`, selector); e != nil {
				return e
			}
			if e = tx.Commit(); e != nil {
				return e
			}
		}
		return core.ErrUnauthorized
	}
	if _, e = tx.ExecContext(ctx, `UPDATE challenges SET used=true WHERE selector=$1`, selector); e != nil {
		return e
	}
	if _, e = tx.ExecContext(ctx, `UPDATE users SET phone_verified=true WHERE id=$1`, uid); e != nil {
		return e
	}
	return tx.Commit()
}
