# IPL Matches — Data Preparation Assignment

SQL-based data cleaning of an IPL (Indian Premier League) cricket matches
dataset, with every cleaning step kept in its own numbered `.sql` file so
the full pipeline is transparent, reviewable, and reproducible.

## Dataset used

**Source:** "IPL Dataset 2008 to 2026" (Kaggle, author *Abhishek Marathe*),
compiled from [Cricsheet](https://cricsheet.org) and enriched with
ESPN Cricinfo / IPL official stats. Licence: CC BY-SA 4.0.

**File cleaned:** `data/raw/matches.csv` — one row per IPL match.

| | |
|---|---|
| Rows | 1,212 matches |
| Seasons | 2008 – 2026 (19 seasons) |
| Columns | 28 (match info, teams, toss, result, venue, player of the match, plus numeric ID columns for joins to a `teams`/`players` table) |

The raw file is left **completely unchanged** in `data/raw/`. All cleaning
happens on a working copy (`matches_working`) built inside the SQL scripts.

## How to run the SQL files

The scripts are plain, portable SQL (SQLite dialect) — no dialect-specific
extensions beyond `ALTER TABLE ... ADD COLUMN` and `CREATE TABLE ... AS
SELECT`, both supported by SQLite/SQLime.

1. Load `data/raw/matches.csv` into a table called **`matches`**.
   - **SQLime** (recommended, no install — [sqlime.org](https://sqlime.org)):
     open a new database and import the CSV; SQLime creates a table named
     after the file (`matches`) automatically.
   - **sqlite3 CLI:**
     ```bash
     sqlite3 ipl.db
     .mode csv
     .import data/raw/matches.csv matches
     ```
2. Run the 8 files in `sql/` **in numeric order** — each one builds on the
   previous file's result (they all operate on a table called
   `matches_working`):
   ```
   01_nulls_and_blanks.sql
   02_merge_categories.sql
   03_venue_names.sql
   04_dedupe_venues.sql
   05_city_fallback.sql
   06_season_year.sql
   07_win_definition.sql
   08_matches_clean.sql
   ```
   Each file contains its own investigation queries, the fix, and
   verification queries at the end — running a file prints the "before"
   audit and "after" verification numbers referenced below.
3. File `08` materializes the final result as table **`matches_clean`**.
   Export it to `output/matches_clean.csv` using your client's export/CSV
   feature (exact commands for the sqlite3 CLI / SQLime / DB Browser are in
   the comment block at the bottom of `08_matches_clean.sql`).

The whole pipeline was also run and verified end-to-end with Python's
`sqlite3` + `pandas` while building this repo, to confirm every script
executes without errors and produces the row/column counts documented
below.

## Cleaning steps performed

| File | What it does |
|---|---|
| `01_nulls_and_blanks.sql` | Audits every column for NULLs and blank strings; documents which NULLs are real gaps vs. structurally-expected (see below); trims stray whitespace from text columns. |
| `02_merge_categories.sql` | Standardizes team names across `team1`, `team2`, `toss_winner`, `match_winner` via a reusable alias lookup table (e.g. `MI` → `Mumbai Indians`, `Delhi Daredevils` → `Delhi Capitals`). |
| `03_venue_names.sql` | Cleans whitespace/typos and merges venue-name variants — both simple ones (`Wankhede Stadium` vs `Wankhede Stadium, Mumbai`) and real historical stadium renames (`Feroz Shah Kotla` → `Arun Jaitley Stadium, Delhi`). Distinct venues drop from **59 → 36**. |
| `04_dedupe_venues.sql` | Checks for duplicate rows by primary key (`match_id`) and by business key (same date + same two teams + standardized venue). None found in this dataset — the script is a documented no-op, kept for reproducibility if a future CSV refresh introduces dupes. |
| `05_city_fallback.sql` | Fills the 51 rows with a missing `city` using a venue→city lookup built from the data itself (all 51 are Dubai/Sharjah neutral-venue matches). `city` is NULL in 0 rows afterward. |
| `06_season_year.sql` | Adds a clean integer `season_year` column derived from the `season` label (handles the real `2020/21` UAE-season label), and cross-checks it against `match_date`. |
| `07_win_definition.sql` | Fixes 9 rows where `result = 'no result'` (abandoned matches) still had a `match_winner` set — cleared to NULL. Adds a `team1_won` (1 / 0 / NULL) flag for easy analysis. |
| `08_matches_clean.sql` | Assembles the final `matches_clean` table with a clear column order, runs final verification checks, and documents how to export to CSV. |

## Important data-quality issues found

- **Missing `city` (51 rows)** — not random: every one is a Dubai/Sharjah
  neutral-venue match. Fixed via venue-based fallback in file `05`.
- **Inconsistent venue names (59 raw spellings for 36 real venues)** — a mix
  of trailing whitespace, a punctuation typo (`M.Chinnaswamy Stadium`),
  `venue` vs `venue, City` duplicates, and genuine historical stadium
  renames (Feroz Shah Kotla → Arun Jaitley Stadium, Sardar Patel Stadium →
  Narendra Modi Stadium, Subrata Roy Sahara Stadium → Maharashtra Cricket
  Association Stadium, Sheikh Zayed Stadium = Zayed Cricket Stadium). Fixed
  in file `03`.
- **`match_winner` populated for abandoned ('no result') matches (9 rows)**
  — internally inconsistent, since an abandoned match has no winner and
  these rows correctly have NULL `player_of_match`/`win_by_*`. Fixed in
  file `07`.
- **`win_by_runs` / `win_by_wickets` NULLs (666 / 571 rows)** — **expected,
  not missing.** A match is won by runs (batting first) or by wickets
  (chasing), never both, so the two columns are mutually exclusive by
  design. Left as NULL rather than coalesced to 0 (see `01`).
- **`match_number` NULLs (70 rows)** — not derivable from any other column
  and not required by downstream analysis; left as NULL rather than
  invented.
- **Team names were already clean** in this particular CSV export (14
  consistent full names, no abbreviations/case variants found) — `02`
  still builds and applies a standardization lookup so the pipeline is
  robust against messier data in future loads, and proves on this data
  that the step is a safe no-op.
- **Zero duplicate rows** were found in this dataset, checked by both
  `match_id` and by a date+teams+venue business key (`04`).

## Final outcome

`output/matches_clean.csv` — **1,212 rows × 29 columns**:

- 0 missing `city` values (was 51)
- 36 standardized venue names (was 59 raw spellings)
- 14 standardized team names, used consistently across `team1`, `team2`,
  `toss_winner`, `match_winner`
- 0 duplicate rows
- Clean integer `season_year` (2008–2026) alongside the original `season`
  label
- Consistent, corrected `match_winner` + a derived `team1_won` flag
  (1 / 0 / NULL) for easy win/loss analysis
- Remaining NULLs (`win_by_runs`, `win_by_wickets`, `match_number`,
  `player_of_match`, `match_winner` for no-result games) are all
  documented, legitimate absences of data rather than errors

The dataset is ready for further analysis (e.g. team win rates, toss impact,
venue-level scoring trends, season-over-season comparisons).

## Repository structure

```
data-preparation-assignment/
├── README.md
├── data/
│   └── raw/
│       └── matches.csv          # untouched raw dataset
├── sql/
│   ├── 01_nulls_and_blanks.sql
│   ├── 02_merge_categories.sql
│   ├── 03_venue_names.sql
│   ├── 04_dedupe_venues.sql
│   ├── 05_city_fallback.sql
│   ├── 06_season_year.sql
│   ├── 07_win_definition.sql
│   └── 08_matches_clean.sql
├── notebooks/
│   └── data_exploration.ipynb   # EDA + runs the SQL pipeline end-to-end
└── output/
    └── matches_clean.csv        # final cleaned dataset
```
