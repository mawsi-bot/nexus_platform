-- Reactions by emotion (§1 v1.3.0), reports and hides.
ALTER TABLE relations DROP CONSTRAINT IF EXISTS relations_kind_check;
ALTER TABLE relations ADD CONSTRAINT relations_kind_check
  CHECK(kind IN ('like','save','follow','report','hide'));
ALTER TABLE relations ADD COLUMN emotion text NOT NULL DEFAULT ''
  CHECK(emotion IN ('','love','hug','strong'));

-- One reaction per person per post: 'like' with an emotion, or none.
CREATE UNIQUE INDEX relations_reaction_idx ON relations(item_id,user_id)
  WHERE kind = 'like';
