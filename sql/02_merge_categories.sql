-- ============================================================================
-- 02_merge_categories.sql
-- Goal: standardize inconsistent category values - specifically team names,
--       which appear in FOUR columns: team1, team2, toss_winner, match_winner.
--
-- Investigation (run before writing the fix):
--   SELECT DISTINCT team1 FROM matches_working
--   UNION SELECT DISTINCT team2 FROM matches_working
--   ORDER BY 1;
--
-- Result: this particular CSV export already stores full, consistently
-- cased franchise names (e.g. "Mumbai Indians", never "MI" or
-- "mumbai indians"). There are 14 distinct, clean team names and zero
-- case/abbreviation variants.
--
-- Even so, the assignment requires a standardization step, and real IPL
-- data (e.g. a fresh Kaggle/Cricsheet pull, or manually entered data) very
-- commonly DOES contain short codes and mixed case. So this file builds a
-- reusable lookup table and a CASE-based normalizer that will correctly
-- collapse those variants if/when they appear, and we prove on THIS data
-- that it is a safe no-op (row counts / distinct values do not change).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Lookup table of known short codes / alternate spellings -> the
-- single canonical franchise name we standardize on.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS team_alias_map;
CREATE TABLE team_alias_map (
    alias           TEXT PRIMARY KEY,   -- stored UPPER(TRIM(...)) for matching
    canonical_name  TEXT NOT NULL
);

INSERT INTO team_alias_map (alias, canonical_name) VALUES
    ('MI',                              'Mumbai Indians'),
    ('MUMBAI INDIANS',                  'Mumbai Indians'),
    ('CSK',                             'Chennai Super Kings'),
    ('CHENNAI SUPER KINGS',             'Chennai Super Kings'),
    ('RCB',                             'Royal Challengers Bangalore'),
    ('ROYAL CHALLENGERS BANGALORE',     'Royal Challengers Bangalore'),
    ('ROYAL CHALLENGERS BENGALURU',     'Royal Challengers Bangalore'),
    ('KKR',                             'Kolkata Knight Riders'),
    ('KOLKATA KNIGHT RIDERS',           'Kolkata Knight Riders'),
    ('SRH',                             'Sunrisers Hyderabad'),
    ('SUNRISERS HYDERABAD',             'Sunrisers Hyderabad'),
    ('DC',                              'Delhi Capitals'),
    ('DELHI CAPITALS',                  'Delhi Capitals'),
    ('DELHI DAREDEVILS',                'Delhi Capitals'),   -- franchise renamed 2019
    ('PBKS',                            'Punjab Kings'),
    ('PUNJAB KINGS',                    'Punjab Kings'),
    ('KINGS XI PUNJAB',                 'Punjab Kings'),      -- franchise renamed 2021
    ('RR',                              'Rajasthan Royals'),
    ('RAJASTHAN ROYALS',                'Rajasthan Royals'),
    ('GT',                              'Gujarat Titans'),
    ('GUJARAT TITANS',                  'Gujarat Titans'),
    ('GL',                              'Gujarat Lions'),
    ('GUJARAT LIONS',                   'Gujarat Lions'),
    ('LSG',                             'Lucknow Super Giants'),
    ('LUCKNOW SUPER GIANTS',            'Lucknow Super Giants'),
    ('PWI',                             'Pune Warriors'),
    ('PUNE WARRIORS',                   'Pune Warriors'),
    ('PUNE WARRIORS INDIA',             'Pune Warriors'),
    ('RPS',                             'Rising Pune Supergiant'),
    ('RISING PUNE SUPERGIANT',          'Rising Pune Supergiant'),
    ('RISING PUNE SUPERGIANTS',         'Rising Pune Supergiant'),
    ('KTK',                             'Kochi Tuskers Kerala'),
    ('KOCHI TUSKERS KERALA',            'Kochi Tuskers Kerala');

-- ----------------------------------------------------------------------------
-- STEP 2: Apply the mapping to every column that stores a team name.
-- Any value not found in the lookup is left unchanged (COALESCE fallback),
-- so we never null-out a legitimate name we didn't anticipate.
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET team1 = COALESCE(
    (SELECT canonical_name FROM team_alias_map WHERE alias = UPPER(TRIM(team1))),
    TRIM(team1)
);

UPDATE matches_working
SET team2 = COALESCE(
    (SELECT canonical_name FROM team_alias_map WHERE alias = UPPER(TRIM(team2))),
    TRIM(team2)
);

UPDATE matches_working
SET toss_winner = COALESCE(
    (SELECT canonical_name FROM team_alias_map WHERE alias = UPPER(TRIM(toss_winner))),
    TRIM(toss_winner)
);

UPDATE matches_working
SET match_winner = COALESCE(
    (SELECT canonical_name FROM team_alias_map WHERE alias = UPPER(TRIM(match_winner))),
    TRIM(match_winner)
);

-- ----------------------------------------------------------------------------
-- STEP 3: Verify - list the distinct team names left after standardization.
-- Expect exactly 14 clean franchise names, same as before the update, which
-- confirms this dataset had no dirty team values to begin with.
-- ----------------------------------------------------------------------------
SELECT name, COUNT(*) AS appearances
FROM (
    SELECT team1 AS name FROM matches_working
    UNION ALL SELECT team2 FROM matches_working
)
GROUP BY name
ORDER BY name;

-- Any team value that still doesn't match a known canonical name would show
-- up here (should return zero rows):
SELECT DISTINCT team1 AS unmapped_team_name
FROM matches_working
WHERE team1 NOT IN (SELECT DISTINCT canonical_name FROM team_alias_map)
UNION
SELECT DISTINCT team2
FROM matches_working
WHERE team2 NOT IN (SELECT DISTINCT canonical_name FROM team_alias_map);
