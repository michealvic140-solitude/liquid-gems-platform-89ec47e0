ALTER TYPE bet_status ADD VALUE IF NOT EXISTS 'refunded';
ALTER TYPE bet_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TYPE bet_status ADD VALUE IF NOT EXISTS 'open';
ALTER TYPE match_status ADD VALUE IF NOT EXISTS 'scheduled';