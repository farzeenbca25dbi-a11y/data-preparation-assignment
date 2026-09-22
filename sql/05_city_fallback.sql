-- ============================================================================
-- 05_city_fallback.sql
-- Goal: fill missing `city` values using the (now standardized) `venue`
--       column, whenever the venue itself is enough to determine the city.
--
-- Investigation:
--   SELECT venue, COUNT(*) FROM matches_working WHERE city IS NULL
--   GROUP BY venue;
--
-- All 51 rows with a NULL city are matches played at either
-- 'Dubai International Cricket Stadium' or 'Sharjah Cricket Stadium'.
-- Both venues also appear, in OTHER rows, with city correctly populated
-- ('Dubai' and 'Sharjah' respectively) - so we can build a reliable
-- venue -> city lookup straight from the data itself instead of hardcoding
-- guesses.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Build a venue -> city lookup from rows where city IS already known.
-- (MIN() here just picks the single consistent city value per venue - every
-- venue in this dataset maps to exactly one city.)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS venue_city_lookup;
CREATE TABLE venue_city_lookup AS
SELECT venue, MIN(city) AS city
FROM matches_working
WHERE city IS NOT NULL
GROUP BY venue;

-- Sanity check: confirm each venue maps to exactly one distinct city
-- (returns 0 rows if the assumption above holds).
SELECT venue, COUNT(DISTINCT city) AS distinct_cities
FROM matches_working
WHERE city IS NOT NULL
GROUP BY venue
HAVING COUNT(DISTINCT city) > 1;

-- ----------------------------------------------------------------------------
-- STEP 2: Fill NULL city values using the lookup.
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET city = (
    SELECT city FROM venue_city_lookup
    WHERE venue_city_lookup.venue = matches_working.venue
)
WHERE city IS NULL;

-- ----------------------------------------------------------------------------
-- STEP 3: Verify - how many rows still have a missing city, and which
-- venues (if any) could not be resolved this way.
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS remaining_null_city FROM matches_working WHERE city IS NULL;

SELECT venue, COUNT(*) AS unresolved_rows
FROM matches_working
WHERE city IS NULL
GROUP BY venue;
-- Expect: 0 remaining_null_city, 0 unresolved venues.
