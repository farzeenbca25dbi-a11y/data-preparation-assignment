-- ============================================================================
-- 01_nulls_and_blanks.sql
-- Goal: audit NULL / blank values in the raw IPL matches table and decide,
--       column by column, whether they represent real missing data or an
--       expected/legitimate absence of a value.
--
-- ASSUMPTION: the raw file data/raw/matches.csv has already been imported
-- into a table called `matches` (this is what SQLime does automatically
-- when you load a CSV; on a local SQLite CLI you can do:
--   sqlite3 ipl.db
--   .mode csv
--   .import data/raw/matches.csv matches
-- ============================================================================

-- Never touch the raw table directly. All cleaning happens on a working copy
-- so `matches` (the raw import) always stays reproducible from the CSV.
DROP TABLE IF EXISTS matches_working;
CREATE TABLE matches_working AS
SELECT * FROM matches;

-- ----------------------------------------------------------------------------
-- STEP 1: Find columns containing NULLs
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*)                                            AS total_rows,
    SUM(CASE WHEN city               IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN match_number       IS NULL THEN 1 ELSE 0 END) AS null_match_number,
    SUM(CASE WHEN win_by_runs        IS NULL THEN 1 ELSE 0 END) AS null_win_by_runs,
    SUM(CASE WHEN win_by_wickets     IS NULL THEN 1 ELSE 0 END) AS null_win_by_wickets,
    SUM(CASE WHEN player_of_match    IS NULL THEN 1 ELSE 0 END) AS null_player_of_match,
    SUM(CASE WHEN player_of_match_id IS NULL THEN 1 ELSE 0 END) AS null_player_of_match_id
FROM matches_working;

-- ----------------------------------------------------------------------------
-- STEP 2: Find blank / whitespace-only values in every text column
-- (none were found in this dataset, but we check defensively so the script
-- still catches the problem if a future refresh of the CSV introduces one)
-- ----------------------------------------------------------------------------
SELECT
    SUM(CASE WHEN TRIM(city)            = '' THEN 1 ELSE 0 END) AS blank_city,
    SUM(CASE WHEN TRIM(venue)           = '' THEN 1 ELSE 0 END) AS blank_venue,
    SUM(CASE WHEN TRIM(team1)           = '' THEN 1 ELSE 0 END) AS blank_team1,
    SUM(CASE WHEN TRIM(team2)           = '' THEN 1 ELSE 0 END) AS blank_team2,
    SUM(CASE WHEN TRIM(toss_winner)     = '' THEN 1 ELSE 0 END) AS blank_toss_winner,
    SUM(CASE WHEN TRIM(match_winner)    = '' THEN 1 ELSE 0 END) AS blank_match_winner,
    SUM(CASE WHEN TRIM(result)          = '' THEN 1 ELSE 0 END) AS blank_result,
    SUM(CASE WHEN TRIM(player_of_match) = '' THEN 1 ELSE 0 END) AS blank_player_of_match
FROM matches_working;

-- ----------------------------------------------------------------------------
-- STEP 3: Decisions on how to handle each NULL column
--
-- * city (51 NULLs): NOT random missing data. Every one of these rows is a
--   match played at Dubai International Cricket Stadium or Sharjah Cricket
--   Stadium (neutral/overseas venues used during IPL 2014 & 2020/21).
--   -> Fixed later in 05_city_fallback.sql using the venue -> city mapping.
--
-- * match_number (70 NULLs): the numeric "match N of the season" label is
--   not derivable from any other column and is not required by any
--   downstream task in this assignment. We leave it NULL rather than
--   inventing a fake sequence number.
--
-- * win_by_runs / win_by_wickets (666 / 571 NULLs): EXPECTED, not missing.
--   A T20 match is won either by a batting-first team (win_by_runs is set,
--   win_by_wickets is NULL) or by a chasing team (win_by_wickets is set,
--   win_by_runs is NULL) - the two columns are mutually exclusive by design.
--   Ties / no-results also legitimately leave both NULL. We leave these as
--   NULL rather than coalescing to 0, because 0 would wrongly imply "won by
--   zero runs/wickets" instead of "not applicable".
--
-- * player_of_match / player_of_match_id (9 NULLs): these 9 rows are exactly
--   the matches with result = 'no result' (abandoned, no play possible), so
--   there genuinely is no player of the match. Left as NULL - this is
--   handled/explained again in 07_win_definition.sql.
-- ----------------------------------------------------------------------------

-- Confirm the player_of_match NULLs line up 1:1 with 'no result' matches
SELECT result, COUNT(*) AS n
FROM matches_working
WHERE player_of_match IS NULL
GROUP BY result;

-- ----------------------------------------------------------------------------
-- STEP 4: Defensive text cleanup
-- Trim stray leading/trailing whitespace on every free-text column so later
-- string comparisons (venue/team standardisation) are not thrown off by it.
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET city            = TRIM(city),
    venue            = TRIM(venue),
    team1            = TRIM(team1),
    team2            = TRIM(team2),
    toss_winner      = TRIM(toss_winner),
    match_winner     = TRIM(match_winner),
    result           = TRIM(result),
    player_of_match  = TRIM(player_of_match);

-- Sanity check: row count is unchanged (no rows were dropped in this file)
SELECT COUNT(*) AS row_count_after_step_01 FROM matches_working;
