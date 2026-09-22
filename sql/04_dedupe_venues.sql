-- ============================================================================
-- 04_dedupe_venues.sql
-- Goal: identify and remove duplicate match records. Run AFTER venue names
--       have been standardized (03_venue_names.sql) so that two rows which
--       are really the same match but were logged with slightly different
--       venue spellings ('Wankhede Stadium' vs 'Wankhede Stadium, Mumbai')
--       are recognized as duplicates instead of being missed.
--
-- How duplicates are identified:
--   1. Exact primary-key duplicates: two rows sharing the same match_id.
--   2. Business-key duplicates: two rows describing the same real-world
--      fixture - same match_date, same two teams (regardless of which is
--      team1/team2), and same (now-standardized) venue. This catches a
--      match that was accidentally re-entered under a new match_id.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Check for primary-key duplicates on match_id.
-- ----------------------------------------------------------------------------
SELECT match_id, COUNT(*) AS n
FROM matches_working
GROUP BY match_id
HAVING COUNT(*) > 1;
-- Result on this dataset: 0 rows -> no match_id is duplicated.

-- ----------------------------------------------------------------------------
-- STEP 2: Check for business-key duplicates (same fixture, different
-- match_id). We build a "matchup key" that is order-independent for the two
-- teams (MIN/MAX) so 'Team A vs Team B' and 'Team B vs Team A' on the same
-- date/venue are still recognized as the same fixture.
-- ----------------------------------------------------------------------------
SELECT
    match_date,
    venue,
    MIN(team1, team2) AS team_a,
    MAX(team1, team2) AS team_b,
    COUNT(*)          AS n,
    GROUP_CONCAT(match_id) AS match_ids
FROM matches_working
GROUP BY match_date, venue, team_a, team_b
HAVING COUNT(*) > 1;
-- Result on this dataset: 0 rows -> no business-key duplicates either.

-- ----------------------------------------------------------------------------
-- STEP 3: Defensive DELETE.
-- No duplicates were found in steps 1-2 on this data load, so this DELETE is
-- a no-op today. It is kept in the pipeline (rather than removed) so that if
-- a future refresh of the raw CSV does introduce duplicate fixtures, running
-- this file will still catch and remove them - keeping the lowest match_id
-- of each duplicate group and discarding the rest.
-- ----------------------------------------------------------------------------
DELETE FROM matches_working
WHERE match_id NOT IN (
    SELECT MIN(match_id)
    FROM matches_working
    GROUP BY match_date, venue, MIN(team1, team2), MAX(team1, team2)
);

-- ----------------------------------------------------------------------------
-- STEP 4: Verify - row count should be unchanged (1212) since there were no
-- real duplicates to remove, and the business-key check should be empty.
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS row_count_after_dedupe FROM matches_working;

SELECT match_date, venue, MIN(team1, team2) AS team_a, MAX(team1, team2) AS team_b, COUNT(*) AS n
FROM matches_working
GROUP BY match_date, venue, team_a, team_b
HAVING COUNT(*) > 1;
-- Expect: 0 rows.
