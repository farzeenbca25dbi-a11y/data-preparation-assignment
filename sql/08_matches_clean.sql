-- ============================================================================
-- 08_matches_clean.sql
-- Goal: assemble the FINAL clean dataset from matches_working, after all of
--       01-07 have been run in order, and materialize it as `matches_clean`.
--
-- The final table:
--   * has no duplicate rows (04_dedupe_venues.sql)
--   * has standardized team names in team1/team2/toss_winner/match_winner
--     (02_merge_categories.sql)
--   * has standardized venue names (03_venue_names.sql)
--   * has no missing city where it was recoverable from the venue
--     (05_city_fallback.sql)
--   * has a clean numeric season_year column (06_season_year.sql)
--   * has a corrected, unambiguous match_winner + team1_won flag
--     (07_win_definition.sql)
--   * documents remaining, legitimate NULLs (win_by_runs, win_by_wickets,
--     match_number, player_of_match) rather than hiding or fabricating them
--     (01_nulls_and_blanks.sql)
-- ============================================================================

DROP TABLE IF EXISTS matches_clean;

CREATE TABLE matches_clean AS
SELECT
    match_id,
    season_year,
    season                              AS season_label,     -- original label kept (e.g. '2020/21')
    match_date,
    match_number,
    event_name,
    city,
    venue,
    team1,
    team2,
    toss_winner,
    toss_decision,
    match_winner,
    team1_won,
    result,
    win_by_runs,
    win_by_wickets,
    player_of_match,
    balls_per_over,
    overs,
    format,
    match_type,
    gender,
    team_type,
    team1_id,
    team2_id,
    toss_winner_id,
    match_winner_id,
    player_of_match_id
FROM matches_working
ORDER BY match_date, match_id;

-- ----------------------------------------------------------------------------
-- FINAL VERIFICATION
-- ----------------------------------------------------------------------------

-- Row count: should equal the raw row count (1212) since no real duplicates
-- were found/removed.
SELECT COUNT(*) AS final_row_count FROM matches_clean;

-- No duplicate match_id.
SELECT match_id, COUNT(*) FROM matches_clean GROUP BY match_id HAVING COUNT(*) > 1;

-- city is only NULL where it was genuinely unrecoverable (expect 0 here).
SELECT COUNT(*) AS remaining_null_city FROM matches_clean WHERE city IS NULL;

-- match_winner is NULL only for 'no result' matches.
SELECT result, COUNT(*) AS n, SUM(CASE WHEN match_winner IS NULL THEN 1 ELSE 0 END) AS null_winner
FROM matches_clean
GROUP BY result;

-- Distinct, standardized team / venue counts.
SELECT COUNT(DISTINCT name) AS distinct_teams
FROM (SELECT team1 AS name FROM matches_clean UNION SELECT team2 FROM matches_clean);

SELECT COUNT(DISTINCT venue) AS distinct_venues FROM matches_clean;

-- Quick look at the final shape of the table.
SELECT * FROM matches_clean LIMIT 5;

-- ----------------------------------------------------------------------------
-- EXPORTING output/matches_clean.csv
--
-- SQLite's SQL dialect has no built-in "export to CSV" statement - that is a
-- client feature, not SQL. Use whichever client you ran these files with:
--
--   * sqlite3 CLI:
--       sqlite3 ipl.db
--       .headers on
--       .mode csv
--       .once output/matches_clean.csv
--       SELECT * FROM matches_clean;
--
--   * SQLime: run this file, then use SQLime's "Export" / download button
--     on the matches_clean result grid.
--
--   * DB Browser for SQLite: File > Export > Table as CSV file...,
--     choose matches_clean.
-- ----------------------------------------------------------------------------
