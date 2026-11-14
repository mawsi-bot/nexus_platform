DROP INDEX IF EXISTS relations_reaction_idx;
ALTER TABLE relations DROP COLUMN IF EXISTS emotion;
ALTER TABLE relations DROP CONSTRAINT IF EXISTS relations_kind_check;
ALTER TABLE relations ADD CONSTRAINT relations_kind_check CHECK(kind IN ('like','save','follow'));
-- Rows created by the newer kinds cannot survive the older constraint.
DELETE FROM relations WHERE kind IN ('report','hide');
