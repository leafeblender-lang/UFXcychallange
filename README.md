# Golf Rival Data Engineering Challenge

## Overview

This project is a solution for the Nordeus Data Engineering Challenge 2026.

The goal is to process raw game event data and transform it into a clean analytical model that can be queried through a REST API.

The input data consists of JSONL files with events such as:

- user registrations
- session pings
- match start events
- match finish events

The solution loads the raw data into SQLite, cleans invalid and duplicate events, reconstructs matches, creates helper tables and views, and exposes the results through Flask API endpoints.

---

## Tech Stack

- Python
- SQLite
- SQL
- Flask

## Environment

Tested with:

- Python 3.10.6
- Flask 3.1.3
- Werkzeug 3.1.8
- SQLite 3.37.2
- pip 26.0.1

## Installation

Install Flask:

```bash
pip install flask
```

---

## Project Structure

```text
.
├── data/
│   ├── events.jsonl
│   └── maps.jsonl
├── golf.db
├── load_raw.py
├── clean.py
├── create_helpT_and_views.py
├── clean_data.sql
├── help_tables.sql
├── views.sql
├── app.py
└── README.md
```

### File Descriptions

- `load_raw.py`  
  Loads raw JSONL files into SQLite tables.

- `clean_data.sql`  
  Handles data cleaning, duplicate removal, and invalid event filtering.

- `clean.py`  
  Executes `clean_data.sql`.

- `help_tables.sql`  
  Builds helper tables witch wil be used in views

- `views.sql`  
  Creates views used by the API.

- `create_helpT_and_views.py`  
  Executes `help_tables.sql` and `views.sql`.

- `app.py`  
  Flask application exposing REST API routes.

---

## How to Run

### 1. Load raw data

```bash
python load_raw.py
```

### 2. Clean data

```bash
python clean.py
```

### 3. Create helper tables and views

```bash
python create_helpT_and_views.py
```

### 4. Start the API

```bash
python app.py
```

After starting app.py, the API will usually be available at:

```text
http://127.0.0.1:5000
```

---

## API Endpoints

## GET `/user-stats`

Returns player statistics.

### Optional query parameters

- `countries` — list of country codes(separated with comma)
- `oss` — list of operating systems,iOS or Android(separated with comma)

### Examples

```text
/user-stats
/user-stats?countries=USA
/user-stats?countries=SRB,USA
/user-stats?oss=Android
/user-stats?oss=iOS
/user-stats?countries=SRB&oss=iOS
```

### Response fields

- `username`
- `country`
- `fav_map`
- `fav_map_win_ratio`
- `total_playtime`
- `total_win_ratio`
- `avg_matches_per_session`
- `registration_date`

---

## GET `/map-stats/<map_name>`

Returns daily statistics for a selected map.

### Optional query parameters

- `date_from` — lower date boundary in `YYYY-MM-DD` format
- `date_to` — upper date boundary in `YYYY-MM-DD` format

### Examples

```text
/map-stats/Cobblestone
/map-stats/Lake
/map-stats/Inferno
/map-stats/Cobblestone?date_from=2026-04-01
/map-stats/Cobblestone?date_from=2026-04-03&date_to=2026-04-06
```

### Response fields

- `date`
- `avg_playtime`
- `best_player_username`
- `match_cnt`

---


## GET `/chart`
A line chart showing match count over the last 7 days, with a separate line for each map, is available at:
```text
http://127.0.0.1:5000/chart
```

## Data Processing Approach

### 1. Raw Data Loading

Raw JSONL files are loaded into SQLite tables:

- `raw_events`
- `raw_maps`

This step is handled by `load_raw.py`.

---

### 2. Data Cleaning

The cleaning process removes or handles:

- duplicate events
- events with missing required fields
- unsupported event types
- invalid users
- invalid match events (incomplete matches that dont have complete pair)
- impossible self matches
- Matches without both start and end were not handled during the cleaning process (this has been resolved in `help_tables.sql`)

Duplicate events are handled by keeping the earliest timestamp for each event id.

---

### 3. Session Track

Sessions are track from `session_ping` events.

A new session starts when the gap between two consecutive pings for the same user is greater than 120 seconds.

Sessions are tracked without field `state`.

---

### 4. Match Reconstruction

Match events are reconstructed from `match_start` and `match_finish` events.

The process includes:

- normalizing player pairs lexicographically
- reconstructing missing map information where possible
- reconstructing missing outcomes where possible
- removing duplicated match start and finish events
- pairing match starts and finishes
- creating final match tables

A user_matches table is also created so that each match can be analyzed from both players' perspectives.

---

## Metrics

### User Stats

For each user, the API calculates:

- total playtime
- total win ratio
- favorite map
- favorite map win ratio
- average matches per session
- registration date

When OS filters are used, statistics are calculated using the session OS.

---

### Map Stats

For each map and date, the API calculates:

- average match duration
- number of matches
- best player username

The best player is calculated using cumulative win ratio on that map up to and including the given date.

---

## Notes

This solution focuses on:

- clear SQL-based transformations
- persistent analytical tables/views
- practical handling of imperfect event data
- simple and documented REST API usage

---

