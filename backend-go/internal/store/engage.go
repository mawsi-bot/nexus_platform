package store

import (
	"context"
	"nexus/backend-go/internal/core"
)

// React records one emotion for a post, replacing any previous reaction. An
// empty emotion removes the reaction. Counting lives in Postgres so the summary
// stays correct across clients.
func (p *Postgres) React(ctx context.Context, uid string, id int64, emotion string) (core.ReactionSummary, error) {
	var summary core.ReactionSummary
	if emotion != "" && !core.ValidEmotion(emotion) {
		return summary, core.ErrInvalid
	}
	tx, e := p.DB.BeginTx(ctx, nil)
	if e != nil {
		return summary, e
	}
	defer tx.Rollback()
	var actual string
	if e = tx.QueryRowContext(ctx, `SELECT i.kind FROM items i WHERE i.id=$2 AND `+visible+` FOR SHARE`, uid, id).Scan(&actual); e != nil {
		return summary, mapErr(e)
	}
	if actual != "post" {
		return summary, core.ErrInvalid
	}
	if emotion == "" {
		_, e = tx.ExecContext(ctx, `DELETE FROM relations WHERE item_id=$1 AND user_id=$2 AND kind='like'`, id, uid)
	} else {
		_, e = tx.ExecContext(ctx, `INSERT INTO relations(item_id,user_id,kind,emotion) VALUES($1,$2,'like',$3)
			ON CONFLICT (item_id,user_id) WHERE kind='like' DO UPDATE SET emotion=EXCLUDED.emotion`, id, uid, emotion)
	}
	if e != nil {
		return summary, e
	}
	if e = tx.Commit(); e != nil {
		return summary, e
	}
	return p.Reactions(ctx, uid, id)
}

// Reactions returns the per-emotion counts plus the caller's own reaction.
func (p *Postgres) Reactions(ctx context.Context, uid string, id int64) (core.ReactionSummary, error) {
	var s core.ReactionSummary
	rows, e := p.DB.QueryContext(ctx, `SELECT emotion, count(*) FROM relations WHERE item_id=$1 AND kind='like' AND emotion<>'' GROUP BY emotion`, id)
	if e != nil {
		return s, e
	}
	defer rows.Close()
	s.Counts = map[string]int{}
	for rows.Next() {
		var emotion string
		var n int
		if e = rows.Scan(&emotion, &n); e != nil {
			return s, e
		}
		s.Counts[emotion] = n
		s.Total += n
	}
	if e = rows.Err(); e != nil {
		return s, e
	}
	_ = p.DB.QueryRowContext(ctx, `SELECT emotion FROM relations WHERE item_id=$1 AND user_id=$2 AND kind='like'`, id, uid).Scan(&s.Mine)
	return s, e
}

// Reactors lists who reacted, newest first, for the "who reacted" sheet.
func (p *Postgres) Reactors(ctx context.Context, id int64, emotion string, limit int) ([]core.Reactor, error) {
	if limit <= 0 || limit > 50 {
		limit = 30
	}
	q := `SELECT u.id, u.name, r.emotion, u.email_verified FROM relations r
		JOIN users u ON u.id = r.user_id
		WHERE r.item_id=$1 AND r.kind='like' AND r.emotion<>''`
	args := []any{id}
	if emotion != "" {
		q += ` AND r.emotion=$2`
		args = append(args, emotion)
	}
	q += ` ORDER BY u.name LIMIT ` + itoa(limit)
	rows, e := p.DB.QueryContext(ctx, q, args...)
	if e != nil {
		return nil, e
	}
	defer rows.Close()
	out := []core.Reactor{}
	for rows.Next() {
		var r core.Reactor
		if e = rows.Scan(&r.ID, &r.Name, &r.Emotion, &r.Verified); e != nil {
			return nil, e
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// Flag records a report or a hide for the caller without touching the post.
func (p *Postgres) Flag(ctx context.Context, uid string, id int64, kind string) error {
	if kind != "report" && kind != "hide" {
		return core.ErrInvalid
	}
	var actual string
	if e := p.DB.QueryRowContext(ctx, `SELECT i.kind FROM items i WHERE i.id=$2 AND `+visible+` FOR SHARE`, uid, id).Scan(&actual); e != nil {
		return mapErr(e)
	}
	_, e := p.DB.ExecContext(ctx, `INSERT INTO relations(item_id,user_id,kind) VALUES($1,$2,$3) ON CONFLICT DO NOTHING`, id, uid, kind)
	return e
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [8]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
