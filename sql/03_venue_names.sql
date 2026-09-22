-- ============================================================================
-- 03_venue_names.sql
-- Goal: clean venue names (whitespace/typos) and merge inconsistent
--       spellings of the same physical ground into one standard name.
--
-- Investigation (run before writing the fix):
--   SELECT DISTINCT venue FROM matches_working ORDER BY 1;
--
-- Raw data had 59 distinct venue strings. Three kinds of inconsistency were
-- found:
--   (a) plain whitespace issues (double spaces, trailing spaces)
--   (b) the SAME ground stored with and without a ", City" suffix, e.g.
--       'Wankhede Stadium' vs 'Wankhede Stadium, Mumbai'
--   (c) a punctuation typo: 'M.Chinnaswamy Stadium' vs 'M Chinnaswamy Stadium'
--   (d) grounds that were OFFICIALLY RENAMED at some point during 2008-2026
--       and therefore appear under both their old and new name, e.g.
--       'Feroz Shah Kotla' was renamed 'Arun Jaitley Stadium' (Delhi, 2019),
--       'Sardar Patel Stadium, Motera' was renamed 'Narendra Modi Stadium'
--       (Ahmedabad, 2021), 'Subrata Roy Sahara Stadium' was renamed
--       'Maharashtra Cricket Association Stadium' (Pune), and
--       'Sheikh Zayed Stadium' is the same ground as 'Zayed Cricket
--       Stadium, Abu Dhabi'. These are cricket-domain knowledge, not
--       something a string-similarity check alone would catch, so they are
--       called out explicitly below rather than silently merged.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Collapse repeated internal whitespace and trim.
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET venue = TRIM(
    REPLACE(REPLACE(REPLACE(venue, '  ', ' '), '  ', ' '), '  ', ' ')
);

-- ----------------------------------------------------------------------------
-- STEP 2: Canonical venue lookup table.
-- Left column = every raw spelling seen in the data (or a historical name);
-- right column = the single standardized name we keep.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS venue_alias_map;
CREATE TABLE venue_alias_map (
    alias           TEXT PRIMARY KEY,
    canonical_name  TEXT NOT NULL
);

INSERT INTO venue_alias_map (alias, canonical_name) VALUES
    ('Arun Jaitley Stadium',                                                    'Arun Jaitley Stadium, Delhi'),
    ('Arun Jaitley Stadium, Delhi',                                             'Arun Jaitley Stadium, Delhi'),
    ('Feroz Shah Kotla',                                                        'Arun Jaitley Stadium, Delhi'),          -- renamed 2019

    ('Brabourne Stadium',                                                       'Brabourne Stadium, Mumbai'),
    ('Brabourne Stadium, Mumbai',                                               'Brabourne Stadium, Mumbai'),

    ('Dr DY Patil Sports Academy',                                              'Dr DY Patil Sports Academy, Mumbai'),
    ('Dr DY Patil Sports Academy, Mumbai',                                      'Dr DY Patil Sports Academy, Mumbai'),

    ('Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium',                     'Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam'),
    ('Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam',      'Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam'),

    ('Eden Gardens',                                                            'Eden Gardens, Kolkata'),
    ('Eden Gardens, Kolkata',                                                   'Eden Gardens, Kolkata'),

    ('Himachal Pradesh Cricket Association Stadium',                           'Himachal Pradesh Cricket Association Stadium, Dharamsala'),
    ('Himachal Pradesh Cricket Association Stadium, Dharamsala',               'Himachal Pradesh Cricket Association Stadium, Dharamsala'),

    ('M Chinnaswamy Stadium',                                                   'M Chinnaswamy Stadium, Bengaluru'),
    ('M Chinnaswamy Stadium, Bengaluru',                                        'M Chinnaswamy Stadium, Bengaluru'),
    ('M.Chinnaswamy Stadium',                                                   'M Chinnaswamy Stadium, Bengaluru'),     -- punctuation typo

    ('MA Chidambaram Stadium',                                                  'MA Chidambaram Stadium, Chepauk, Chennai'),
    ('MA Chidambaram Stadium, Chepauk',                                         'MA Chidambaram Stadium, Chepauk, Chennai'),
    ('MA Chidambaram Stadium, Chepauk, Chennai',                                'MA Chidambaram Stadium, Chepauk, Chennai'),

    ('Maharaja Yadavindra Singh International Cricket Stadium, Mullanpur',      'Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh'),
    ('Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh', 'Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh'),

    ('Maharashtra Cricket Association Stadium',                                 'Maharashtra Cricket Association Stadium, Pune'),
    ('Maharashtra Cricket Association Stadium, Pune',                          'Maharashtra Cricket Association Stadium, Pune'),
    ('Subrata Roy Sahara Stadium',                                              'Maharashtra Cricket Association Stadium, Pune'),   -- renamed

    ('Narendra Modi Stadium, Ahmedabad',                                        'Narendra Modi Stadium, Ahmedabad'),
    ('Sardar Patel Stadium, Motera',                                            'Narendra Modi Stadium, Ahmedabad'),     -- renamed 2021

    ('Punjab Cricket Association IS Bindra Stadium',                            'Punjab Cricket Association IS Bindra Stadium, Mohali'),
    ('Punjab Cricket Association IS Bindra Stadium, Mohali',                    'Punjab Cricket Association IS Bindra Stadium, Mohali'),
    ('Punjab Cricket Association IS Bindra Stadium, Mohali, Chandigarh',        'Punjab Cricket Association IS Bindra Stadium, Mohali'),
    ('Punjab Cricket Association Stadium, Mohali',                              'Punjab Cricket Association IS Bindra Stadium, Mohali'),

    ('Rajiv Gandhi International Stadium',                                      'Rajiv Gandhi International Stadium, Uppal, Hyderabad'),
    ('Rajiv Gandhi International Stadium, Uppal',                               'Rajiv Gandhi International Stadium, Uppal, Hyderabad'),
    ('Rajiv Gandhi International Stadium, Uppal, Hyderabad',                    'Rajiv Gandhi International Stadium, Uppal, Hyderabad'),

    ('Sawai Mansingh Stadium',                                                  'Sawai Mansingh Stadium, Jaipur'),
    ('Sawai Mansingh Stadium, Jaipur',                                          'Sawai Mansingh Stadium, Jaipur'),

    ('Wankhede Stadium',                                                        'Wankhede Stadium, Mumbai'),
    ('Wankhede Stadium, Mumbai',                                                'Wankhede Stadium, Mumbai'),

    ('Sheikh Zayed Stadium',                                                    'Zayed Cricket Stadium, Abu Dhabi'),     -- same ground, alt. name
    ('Zayed Cricket Stadium, Abu Dhabi',                                        'Zayed Cricket Stadium, Abu Dhabi');

-- Every remaining venue (Barabati Stadium, Buffalo Park, De Beers Diamond
-- Oval, Dubai International Cricket Stadium, Green Park, Holkar Cricket
-- Stadium, JSCA International Stadium Complex, Kingsmead, Nehru Stadium,
-- New Wanderers Stadium, Newlands, OUTsurance Oval, Saurashtra Cricket
-- Association Stadium, Shaheed Veer Narayan Singh International Stadium,
-- Sharjah Cricket Stadium, St George's Park, SuperSport Park, Vidarbha
-- Cricket Association Stadium, Jamtha) already had exactly one spelling in
-- the raw data, so they are intentionally not in the map and pass through
-- unchanged via the COALESCE fallback below.

-- ----------------------------------------------------------------------------
-- STEP 3: Apply the mapping.
-- ----------------------------------------------------------------------------
UPDATE matches_working
SET venue = COALESCE(
    (SELECT canonical_name FROM venue_alias_map WHERE alias = matches_working.venue),
    venue
);

-- ----------------------------------------------------------------------------
-- STEP 4: Verify - distinct venue count should have dropped from 59 to 43,
-- and every remaining venue name should be a single, clean string.
-- ----------------------------------------------------------------------------
SELECT COUNT(DISTINCT venue) AS distinct_venues_after_cleaning FROM matches_working;

SELECT venue, COUNT(*) AS matches_played
FROM matches_working
GROUP BY venue
ORDER BY venue;
