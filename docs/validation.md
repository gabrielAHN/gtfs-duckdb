# Validating a feed

`PRAGMA gtfs_validate` checks a GTFS feed with the rules of the
[MobilityData GTFS validator](https://github.com/MobilityData/gtfs-validator), ported to DuckDB SQL. For the files
`gtfs_import` reads, it reports the notices the official validator reports: the same codes, severities and fields.

```sql
LOAD gtfs;
PRAGMA gtfs_validate('feed');                -- the GTFS files in the folder feed/, validated as of today
PRAGMA gtfs_validate('feed', '2026-11-24');  -- as of another date (rules about expired or future service)
```

The PRAGMA returns one row per notice code, errors first:

| severity | code | total_notices |
|---|---|---|
| ERROR | foreign_key_violation | 2 |
| WARNING | stops_too_close | 1 |
| INFO | unused_station | 3 |

`ERROR` notices make a feed invalid; `WARNING` and `INFO` notices are recommendations. No rows means no notice.

Every notice is in the `gtfs_validation_notices` table of the session. `notice` is the JSON object the official
validator writes to `report.json`, with the same field names:

```sql
SELECT code, filename, csv_row_number, notice
FROM gtfs_validation_notices
WHERE severity = 'ERROR'
ORDER BY code, filename, csv_row_number;

SELECT notice->>'stopId' AS stop_id, notice->>'tripId' AS trip_id, (notice->>'geoDistanceToShape')::DOUBLE AS meters
FROM gtfs_validation_notices
WHERE code = 'stop_too_far_from_shape';
```

The table keeps every notice. The official `report.json` keeps at most 1,000 sample notices per code, and its
`totalNotices` counts the rest.

`gtfs_validation_rules()` lists every rule: its code, severity, notice fields and a summary.

```sql
SELECT code, severity, summary FROM gtfs_validation_rules() ORDER BY code;
```

`gtfs_validate` does not import the feed and does not change the dataset or pending edits. It keeps its results in
temporary tables named `gtfs_validation_*` and `gtfs_v_*`, which the next validation replaces, and works in temporary
tables named `gtfs_vc_*`, which it empties when it finishes. Do not use these names for your own tables. Pass `''` to
read the files in the working directory. A directory that does not exist, a file path or NULL is an error, and so is
a directory whose path has `*`, `?` or `[`: DuckDB reads such a path as a file pattern, which can match another
directory's files. Rename it, or validate it through a link.

The rules need DuckDB's `json` extension. Most DuckDB builds include it, and others load it automatically on first
use. If automatic loading is turned off, run `LOAD json;` first.

From the command line, [GTFS Tools](https://github.com/gabrielAHN/gtfs-tools) runs it on a zip, a folder or a URL:
`gtfs-tools validate feed.zip`.

## Memory

Each file is read whole, so the memory a validation needs grows with the largest file, usually `stop_times.txt`.
Measured with DuckDB v2.0.0 on a Mac (peak resident memory of the DuckDB process):

| stop_times.txt | memory_limit | Peak memory | Time |
|---|---|---|---|
| 42 MB (New York City Subway) | default | 2.9 GiB | 3.5 s |
| 42 MB | `'2GB'` | 2.3 GiB | 3.6 s |
| 42 MB | `'1GB'` | 1.6 GiB | 4.4 s |
| 150 MB (the same feed, 4 times over) | `'2GB'` | 3.0 GiB | 11 s |

`SET memory_limit` lowers the peak by spilling to disk, at some cost in time. With `memory_limit='512MB'` the New
York feed fails with an out-of-memory error. The peak can exceed the limit, and grows with the file: about 7 times the
extra size between the two files above. At that rate a 1 GB `stop_times.txt`, as some national feeds have, would need
about 9 GiB (an estimate, not measured).

## What is validated

The 8 files `gtfs_import` reads: `stops.txt`, `pathways.txt`, `routes.txt`, `trips.txt`, `stop_times.txt`,
`shapes.txt`, `calendar.txt` and `calendar_dates.txt`:

- reading the files: CSV syntax, encoding, line endings, headers, required and recommended columns and fields,
  field types and ranges, colors, dates, times, URLs and time zones;
- primary keys, and references between these files (a trip's route, a stop time's trip and stop, a stop's parent
  station, a pathway's ends, a trip's shape and service);
- the validator's rules over stops and stations, pathways, trips and stop times, routes, services and shapes, such as
  stops too close to each other, unusable or unused trips, fast travel between stops, expired calendars and stops too
  far from their trip's shape.

URLs are checked as the official validator checks them, internationalized domain names such as `https://例え.jp/`
included: the host is converted to punycode as Java 17 does first. As in the official validator, a field that fails
its check (an `invalid_url`, for example) is an error that makes its whole file unparsable, and the rules that need
that file are then skipped.

## Not validated

Other files and the rules that need them: `agency.txt`, `feed_info.txt`, `frequencies.txt`, `transfers.txt`,
`levels.txt`, `translations.txt`, `attributions.txt`, `licenses.txt`, fares (v1 and v2) and GTFS-Flex
(`locations.geojson`, `location_groups.txt`, `booking_rules.txt`). References into those files (a route's
`agency_id`, a stop's `level_id`) are not checked, and rules that read them run as if those files were valid and
`frequencies.txt` absent. A feed the official validator flags only for these files passes here.

## Known differences

The rules follow the official validator's Java code, but a few cases can still come out differently:

- Rules that also read a file this port does not. The official validator skips `stops_too_close` for stops on
  different levels (`levels.txt`), and counts a stop used through `location_group_stops.txt` as used. It does not ask
  for `shapes.txt` when demand-responsive trips serve only location groups (`location_groups.txt`). This port
  reports all three.
- Text compared without case, such as a stop's name and description or a trip's headsign, follows Java's
  `equalsIgnoreCase` one letter at a time through DuckDB's `upper()` and `lower()`. Whether a route's long name starts
  with its short name lowercases the whole names, where Java applies context rules such as the Greek final sigma, so a
  name built for it can come out differently. Unicode letter classes come from DuckDB's regular expressions, whose
  Unicode version can differ from Java 17's for recently added letters.
- The official validator asks for `shapes.txt` (`missing_recommended_file`) only when every file of the feed parses,
  `agency.txt` and the other files this port does not read included. This port checks only the files it reads, so a
  feed with a missing or broken `agency.txt` still gets the notice.
- File names must be lowercase, such as `stops.txt`, as for `gtfs_import`. The official validator also reads
  `Stops.txt`. On a case-insensitive file system, such as macOS's default one, DuckDB finds it too.
- In the message of `csv_parsing_failed`, the CSV parser the official validator uses (univocity) drops NUL characters
  from some quoted values, and for a row of more than 512 columns it can add a note about line separators left over
  from an earlier value. This port keeps the NUL characters and leaves that note out.
- When trips follow the same stops and times, `fast_travel_between_consecutive_stops` reports the first trip in Java's
  hash map order. This port reproduces that order, except when a single hash bucket holds 8 or more trips.
- Java's check for overlapping trips in a block treats services whose first common date is 1 January 1970 as never
  overlapping. This port reports those trips.
- Distances add up in a different order, and DuckDB's `sin`, `cos` and `atan2` can differ from Java's in the last
  bit. A distance or speed within about 10⁻¹² of a limit can fall on the other side of it, and a match location in a
  shape notice (`match`, `match1`, `match2`) can differ in its last digit.

## How it is tested

Each rule has small feeds whose expected notices are the official validator's own output (the 8.0.2-SNAPSHOT CLI,
commit `f9f4b9e`), compared notice by notice, field by field, on DuckDB v2.0.0 and v1.4.3. Decimal fields such as
distances and speeds must match to 6 significant digits, and coordinates to 9. A whole real feed, the New York City Subway, is compared
the same way. See [validation-internals.md](validation-internals.md#testing).
