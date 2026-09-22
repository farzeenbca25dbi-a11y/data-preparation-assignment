-- ============================================================================
-- 07_win_definition.sql
-- Goal: create a clear, consistent definition of the winning team.
--
-- Investigation:
--   SELECT result, COUNT(*) FROM matches_working GROUP BY result;
--   -- win: 1187, tie: 16, no result: 9
--
--   SELECT * FROM matches_working WHERE result = 'no result';
--   -- these 9 abandoned matches still have match_winner POPULATED in the
--   -- raw data, even though win_by_runs/win_by_wickets/player_of_match are
--   -- (correctly) NULL. An abandoned match has no winner - this is an
--   -- inconsistency in the raw data, not a real result, so match_winner is
--   -- cleared to NULL for these 9 rows.
--
--   SELECT * FROM matches_working WHERE result = 'tie';
--   -- these 16 rows DO have a real match_winner (IPL ties are broken by a
--   -- Super Over) and a real player_of_match, confirming the match was
--   -- actually completed and decided. match_winner is left as-is here.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Fix the 'no result' inconsistency - an abandoned match cannot
-- have a winner.
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET match_winner    = NULL,
    match_winner_id = NULL
WHERE result = 'no result';

-- ----------------------------------------------------------------------------
-- STEP 2: Add a simple boolean-style column, team1_won, so downstream
-- analysis doesn't need to repeat the "match_winner = team1" comparison
-- (and doesn't need to know to special-case NULL for no-result matches).
--   1    -> team1 won the match
--   0    -> team2 won the match
--   NULL -> no result / match_winner unknown
-- ----------------------------------------------------------------------------
ALTER TABLE matches_working ADD COLUMN team1_won INTEGER;

UPDATE matches_working
SET team1_won = CASE
    WHEN match_winner IS NULL       THEN NULL
    WHEN match_winner = team1       THEN 1
    WHEN match_winner = team2       THEN 0
    ELSE NULL   -- defensive: match_winner set but matches neither team1 nor team2
END;

-- ----------------------------------------------------------------------------
-- STEP 3: Verify.
-- ----------------------------------------------------------------------------

-- 3a. Every 'no result' row should now have a NULL match_winner and a NULL
-- team1_won.
SELECT result, COUNT(*) AS n, SUM(CASE WHEN match_winner IS NULL THEN 1 ELSE 0 END) AS null_winner
FROM matches_working
GROUP BY result;

-- 3b. Every 'win'/'tie' row should have team1_won resolved to 0 or 1
-- (no unexplained NULLs).
SELECT team1_won, COUNT(*) AS n
FROM matches_working
GROUP BY team1_won;

-- 3c. Defensive check: any row where match_winner is set but doesn't equal
-- team1 or team2 (should be 0 rows - would indicate a data-entry error).
SELECT match_id, team1, team2, match_winner
FROM matches_working
WHERE match_winner IS NOT NULL
  AND match_winner NOT IN (team1, team2);
