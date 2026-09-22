-- ============================================================================
-- 06_season_year.sql
-- Goal: create a consistent, numeric season_year field.
--
-- Investigation:
--   SELECT DISTINCT season FROM matches_working ORDER BY season;
--
-- `season` is already one value per IPL year (2008, 2009, ... 2026) EXCEPT
-- for IPL 2020, which was played in the UAE across the 2020-2021 calendar
-- years and is genuinely labelled '2020/21' in the source data (Cricsheet).
-- This is a real, correct label - not an error - but it is text, not a
-- number, so it can't be sorted/filtered/grouped numerically alongside the
-- other seasons. We derive a clean integer season_year (the season's
-- starting year) while leaving the original `season` column untouched, so
-- both the human-readable label and a machine-usable year are available.
--
-- We also independently verify season_year against the calendar year of
-- match_date, to make sure no match's season label disagrees with when it
-- was actually played.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Add the new column.
-- ----------------------------------------------------------------------------
ALTER TABLE matches_working ADD COLUMN season_year INTEGER;

-- ----------------------------------------------------------------------------
-- STEP 2: Populate it from the first 4 characters of `season`
-- (handles both a plain year like '2019' and the '2020/21' edge case, both
-- of which start with a 4-digit year).
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET season_year = CAST(SUBSTR(TRIM(season), 1, 4) AS INTEGER);

-- ----------------------------------------------------------------------------
-- STEP 3: Verify.
-- ----------------------------------------------------------------------------

-- 3a. season_year should always be a sensible 4-digit IPL year.
SELECT MIN(season_year) AS earliest_season, MAX(season_year) AS latest_season
FROM matches_working;

-- 3b. One row per season_year, with the original label alongside it.
SELECT season AS original_season_label, season_year, COUNT(*) AS matches
FROM matches_working
GROUP BY season, season_year
ORDER BY season_year;

-- 3c. Cross-check against the calendar year the match was actually played
-- on. A mismatch would mean a match_date/season data-entry error.
SELECT match_id, season, season_year, match_date
FROM matches_working
WHERE season_year != CAST(STRFTIME('%Y', match_date) AS INTEGER)
  AND season != '2020/21';   -- the 2020/21 season spans two calendar years by design
-- Expect: 0 rows (no unexplained mismatches).
