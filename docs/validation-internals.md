# Validation internals

`PRAGMA gtfs_validate` ports the [MobilityData GTFS validator](https://github.com/MobilityData/gtfs-validator)
(pinned at commit `f9f4b9e`, the code behind the `8.0.2-SNAPSHOT` CLI jar) to DuckDB SQL. This file is the contract for
everyone changing `sql/validate_*.sql`: the pipeline, the tables, the notice format and how parity is tested.
User-facing usage is in [validation.md](validation.md).

## Scope

Only the 8 files `PRAGMA gtfs_import` reads are validated: `stops.txt`, `pathways.txt`, `routes.txt`, `trips.txt`,
`stop_times.txt`, `shapes.txt`, `calendar.txt`, `calendar_dates.txt`. The registry
`SELECT * FROM gtfs_validation_rules()` lists the 111 notice codes that can come from rules over these files (one row
per code: severity, owner groups, notice fields and their JSON types, summary).

Not ported, because they read other files: everything about `agency.txt`, `feed_info.txt`, `frequencies.txt`,
`transfers.txt`, `levels.txt`, `translations.txt`, `attributions.txt`, fares, GTFS-Flex (`locations.geojson`,
`location_groups.txt`, `booking_rules.txt`) and `licenses.txt`; foreign keys into those files; and
`RouteAgencyIdValidator` (`routes.agency_id` required or recommended depending on the agency count). The port behaves
as if those files were valid and `frequencies.txt` were absent.

## Sections and ownership

| File | Kind | Owner | Content |
|---|---|---|---|
| `sql/validate_schema.sql` | statements | manager (generated block) + core (below `CORE-TABLES`) | creates every table any validation macro reads |
| `sql/validate_registry.sql` | macros | manager (generated) | `gtfs_validation_rules()`, `gtfs_validation_enum_name()` |
| `sql/validate_common.sql` | macros | manager | shared helpers listed below |
| `sql/validate_core.sql` | macros | core | loader helpers: CSV, header, row and field checks; `gtfs_validation_summary()` |
| `sql/validate_begin.sql` | statements | core | records the validation date and directory |
| `sql/validate_load.sql` | statements | core | loads one existing file into `gtfs_v_<table>` and records its notices |
| `sql/validate_missing.sql` | statements | core | records one missing file |
| `sql/validate_finish.sql` | statements | core | runs every rule macro of every group, one statement each, into `gtfs_validation_notices`; its last statement is the PRAGMA's result |
| `sql/validate_rules_stops.sql` | macros | stops | `gtfs_validate_rules_stops()` |
| `sql/validate_rules_stop_times.sql` | macros | stoptimes | `gtfs_validate_rules_stop_times()` |
| `sql/validate_rules_routes_calendar.sql` | macros | routescal | `gtfs_validate_rules_routes_calendar()` |
| `sql/validate_rules_shapes.sql` | macros | shapes | `gtfs_validate_rules_shapes()` |
| `sql/validate_rules_generated.sql` | macros | generated | `gtfs_validate_rules_generated()`: the validators Java generates from schema annotations (primary and foreign keys, start/end ranges, lat/lon points, mixed case) |

A *macro* section holds only `CREATE OR REPLACE MACRO` statements; the extension registers them as functions at
`LOAD`. A *statement* section holds no macros; `PRAGMA gtfs_validate` executes it.

`PRAGMA gtfs_validate(directory[, date])` executes, in order:

1. `validate_schema.sql`;
2. `validate_begin.sql` with `{{DATE}}` (a DATE expression: `DATE '2026-11-24'`, or `current_date` when the date is
   omitted or NULL) and `{{DIRECTORY}}` (a quoted string literal);
3. for each file in the order stops, pathways, routes, trips, stop_times, shapes, calendar, calendar_dates:
   `validate_load.sql` if `<directory>/<file>` exists, else `validate_missing.sql`, with `{{TABLE}}` (bare name, e.g.
   `stop_times`), `{{FILE}}` (`'stop_times.txt'`), `{{PATH}}` (quoted path) and `{{REQUIRED}}` (`true` for routes,
   trips and stop_times: `GtfsTableDescriptor.isRequired()`);
4. `validate_finish.sql`.

Placeholders are replaced as plain text before parsing, so a placeholder must never appear in a comment: a newline in
a directory name would end the comment and run the rest of the name as SQL (`test_validation.py` checks every section).
`{{DIRECTORY}}` and `{{PATH}}` are replaced last, so the text of a path is never scanned for placeholders. The PRAGMA
raises an error when the directory is NULL, when its path has `*`, `?` or `[` (`read_blob` would read it as a glob
pattern: `feed[1]/stops.txt` matches `feed1/stops.txt`, and DuckDB has no escape for these characters), or when it
finds no file and the directory does not exist.

`test/validation/harness.py` emulates exactly this with a
stock DuckDB CLI (it creates the macros with `CREATE OR REPLACE MACRO`), so the SQL can be developed and tested without
building the extension. A DuckDB session binds a macro's tables when the macro is created, which is why every table a
macro reads must be created by `validate_schema.sql` (the harness runs it before creating the macros).

DuckDB v2.0 runs all the statements a PRAGMA expands into in one transaction; v1.4 commits each statement. The harness
emulates both: on v2.0 it wraps the statements, and the queries a test runs after them, in `BEGIN TRANSACTION` ...
`COMMIT`. Inside that transaction:

- The optimizer has no statistics for the tables the PRAGMA wrote, so a rule's join order can differ from the one an
  `EXPLAIN` after the PRAGMA shows. The plan tests (`harness.plan`, `harness.operator_rows`) run inside it.
- Nothing written is freed before the end: a `DELETE`, `DROP`, `TRUNCATE` or `CREATE OR REPLACE` keeps the old rows'
  memory until the commit, so the PRAGMA's peak memory is everything the loader wrote.

## Tables

All are TEMP tables, recreated empty by `validate_schema.sql` on every run.

- `gtfs_validation_state(validation_date DATE, directory VARCHAR, started_at TIMESTAMP)`: one row.
- `gtfs_validation_files(filename, status, required, parsed, row_count)`: one row per validated file.
  `status` is the Java `TableStatus`: `PARSABLE_HEADERS_AND_ROWS`, `MISSING_FILE`, `EMPTY_FILE`, `INVALID_HEADERS` or
  `UNPARSABLE_ROWS`. `parsed` is `GtfsEntityContainer.isParsedSuccessfully()`: true for `PARSABLE_HEADERS_AND_ROWS`, and
  for `MISSING_FILE` when the file is not required.
- `gtfs_validation_columns(filename, column_name, column_index)`: the header of each loaded file, as `CsvHeader` holds it.
- `gtfs_validation_generic_notices(code, notice)`: notices from the core group.
- `gtfs_validation_notices(code, severity, filename, csv_row_number, notice)`: the result, filled by `validate_finish.sql`.
- `gtfs_vc_*`: the loader's working tables (the lines, records, header, wide rows and notices of the file being
  loaded, see below). `validate_load.sql` replaces the large ones with empty tables as soon as it has used them;
  `validate_finish.sql` empties the rest.
- `gtfs_v_<table>` for the 8 files: the entities. Columns: `csv_row_number BIGINT` and every field of the Java schema
  (`test/validation/typed_schema.json`, generated from `Gtfs*Schema.java`).

### Loading a file

`validate_load.sql` ports `CsvFileLoader.load`. Every step after the first works on one row per line or per record,
so DuckDB spreads it over all threads; a step over the whole text in one row would run on one thread.

1. `gtfs_vc_lines`: the file decoded as Java decodes it (U+FFFD for malformed UTF-8, BOMs stripped) and split on LF.
2. `gtfs_vc_records` from `gtfs_vc_line_records()`: one record per line. A line without a quote splits on commas; a
   line with one goes through the same tokenizer as the whole-text parser. A line where a quoted value runs past its
   end is marked `open`, and then the whole file is parsed by `gtfs_vc_parse_records()` instead (one token stream
   over the text, single-threaded; rare in real feeds). A record is `plain` when its line has only characters from
   `!` to `~`: none of its values needs trimming or can have a character notice, so those checks skip it.
3. The header, its notices and `gtfs_vc_pos` (each schema column's position in the header).
4. `gtfs_vc_wide_<table>` from `gtfs_vc_wide_build_<table>()`: one row per data row of the header's length, with the raw
   value `r_<column>` of every schema column (NULL when the header lacks it) and, for typed columns, the value Java
   parses, `p_<column>`.
5. Row-length notices, then `gtfs_vc_cell_notices_<table>()` (RowParser and DefaultFieldValidator checks, one column
   at a time) and the entities, `gtfs_vc_entities_<table>()`.

The three per-table macros and the `gtfs_vc_wide_<table>` tables are generated from `gtfs_vc_schema()` by
`python3 test/validation/gen_loader.py` (between the `LOADER-GENERATED` lines); after changing the schema, rerun it.
`test_validation.py` fails when the blocks are out of date, and checks that forcing the whole-text parser on every
fixture changes no notice, file status or entity.

DuckDB details the loader depends on:

- `coalesce(TRY(decode(x)), fallback(x))` evaluates the slow fallback for valid text on DuckDB v2.0; a `CASE` does
  not. Write `TRY(decode(x))` in both the condition and the branch: DuckDB computes a repeated subexpression once,
  before the `CASE`, so a bare `decode(x)` in the branch throws on invalid UTF-8.
- An `UPDATE ... SET c = (uncorrelated subquery) WHERE false` still computes the subquery; put the condition inside it.
- On DuckDB v1.4 a `DELETE` keeps the table's memory; `CREATE OR REPLACE TEMP TABLE t (columns)` frees it, and macros
  that read `t` still work afterwards.
- Never refill a table that was replaced `AS SELECT` in the same transaction: on DuckDB v2.0.0, an `INSERT ... SELECT`
  from a table into it loses all its rows when they are more than a row group (122,880 rows; 100,000 load, 130,000 do
  not) and `preserve_insertion_order` is on, its default; the loss survives the commit. Inserting from `range()`,
  replacing the table by naming its columns, or `preserve_insertion_order = false` avoids it; v1.4.3 is not affected.
  `validate_load.sql` therefore replaces
  `gtfs_vc_lines` and `gtfs_vc_records`, which the next file refills, by naming their columns; it replaces
  `gtfs_vc_wide_<table>` `AS SELECT` only after its last use in the PRAGMA. `test_validation.py` loads two files over
  a row group each with the default settings.

### Entity rows

`gtfs_v_<table>` holds exactly the rows the Java loader turns into entities: rows with the header's length and no
ERROR notice of their own. A row with an ERROR (invalid integer, missing required field, ...) is not an entity; its
notices are still reported. Values are what the Java entity stores:

| Kind (`kind` in typed_schema.json) | SQL type | Value |
|---|---|---|
| text, id, url, timezone | VARCHAR | the parsed text |
| integer, enum | INTEGER | the number as written; an enum value outside the enum stays (Java `UNRECOGNIZED`) |
| float, latitude, longitude | DOUBLE | |
| date | DATE | |
| time | INTEGER | seconds since midnight; may exceed 86400 |
| color | INTEGER | `0xRRGGBB` |

An empty field is NULL. Java `entity.hasX()` is `x IS NOT NULL`. Java `entity.x()` is `coalesce(x, <default>)`, where
the default is the field's `default` in typed_schema.json (`@DefaultValue`), else 0 for numbers and enums, `''` for
text, ids and URLs, `DATE '1970-01-01'` for dates, `0` for times and colors and `'UTC'` for timezones.
`gtfs_validation_enum_name(java_type, value)` gives the Java constant name of an enum value, `'UNRECOGNIZED'` outside the
enum.

### When a Java validator runs (gating)

Reproduce the Java conditions exactly; parity depends on them.

- A `SingleEntityValidator` runs on every entity as the file loads, so it runs on every `gtfs_v_<table>` row whatever
  the file's final status (it injects no tables, only context such as the country code or the date). It is skipped
  when its `shouldCallValidate(header)` is false.
- A `FileValidator` (single- or multi-file) runs only when every table its constructor injects is parsed:
  `gtfs_validation_parsed(['stops.txt', 'stop_times.txt'])`. Injecting `GtfsFeedContainer` means every file. Files
  outside the 8 count as parsed. It is also skipped when `shouldCallValidate()` is false.
- Column presence (`ColumnInspector.hasColumn`, `table.hasColumn(...)`): `gtfs_validation_has_column('trips.txt', 'shape_id')`.
- A file that is missing (optional), empty, has invalid headers or failed CSV parsing at the header has no entities.
- A file with `UNPARSABLE_ROWS` still has its good rows in `gtfs_v_<table>` (single-entity validators ran on them), but
  Java hands every file validator an empty container for it. Nothing is lost: every file validator that reads it is
  skipped by the rule above.
- `duplicate_key` comes from building the table container (`ColumnarEntityList`), so only files with status
  `PARSABLE_HEADERS_AND_ROWS` can have it.
- Notices from a `SingleEntityValidator`, including ERRORs, never change a file's status. Only a row's own parse
  notices (`RowParser`, `DefaultFieldValidator`) decide whether the row becomes an entity.

## Notices

Each rule group's entry macro returns `(code VARCHAR, notice JSON)`, one row per notice. `notice` is the object Gson
writes for the Java notice:

- keys: exactly the notice's fields, `notice_fields` in the registry (the jar's notice schema). Gson leaves out null
  fields: build every notice with `gtfs_validation_notice(json_object(...))`, which drops null values.
- types (`notice_field_types`): `integer` from an INTEGER/BIGINT; `number` from a DOUBLE, even when integral (Java writes
  `5.0`); `string`; `boolean`; `enum` as the Java constant name (`gtfs_validation_enum_name`); a lat/lng pair
  (`S2LatLng`) as `[lat, lng]` of DOUBLEs.
- `GtfsTime` fields: `gtfs_validation_time_text(seconds)` (`'25:01:01'`); `GtfsDate`: `gtfs_validation_date_text(d)`
  (`'20260105'`); `GtfsColor`: `gtfs_validation_color_text(rgb)` (`'#00FF00'`).
- row numbers come from `csv_row_number`.
- distances: `gtfs_validation_distance_m(lat1, lon1, lat2, lon2)` is `S2Earth.getDistanceMeters` (sphere of radius
  6,371,010 m). Divide by 1000 for kilometers as the Java code does.

The severity is not part of the notice: `validate_finish.sql` takes it from the registry.

## Shared helpers (`validate_common.sql`, `validate_registry.sql`)

`gtfs_validation_notice(fields)`, `gtfs_validation_distance_m(lat1, lon1, lat2, lon2)`,
`gtfs_validation_time_text(seconds)`, `gtfs_validation_date_text(d)`, `gtfs_validation_color_text(rgb)`,
`gtfs_validation_parsed(files)`, `gtfs_validation_has_column(file, column)`, `gtfs_validation_date()`,
`gtfs_validation_enum_name(java_type, value)`, `gtfs_validation_rules()`.

## Writing a rule group

- Entry point: `gtfs_validate_rules_<group>()`, a table macro returning `(code, notice)`: the `UNION ALL` of the
  group's rule macros. Name helper macros `gtfs_vr_<group>_<name>`. Add no new tables: derive everything from the
  `gtfs_v_*` tables, `gtfs_validation_files`, `gtfs_validation_columns` and `gtfs_validation_state`.
- List a new rule macro in the entry point and, in the same order, under the group's comment in
  `validate_finish.sql`, which runs each rule macro in its own statement: run as one `UNION ALL`, DuckDB v1.4 kept
  the state of every rule at once and ran out of memory on the New York City Subway feed at `memory_limit='2GB'`.
  `test_validation.py` checks that the two lists match. Write each statement on one line,
  `INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM <rule macro>();`, and keep the group comments and
  statements together, with no other line between them, not even a blank one: the check reads the list up to its first
  other line and reports any later line naming a rule macro or a group, so a statement commented out or moved is never
  counted as run.
- Name macro parameters so they never equal a column of a table the body reads (`p_trip_id`, not `trip_id`): DuckDB
  reports a conflicting column name or silently binds the column.
- Port the Java classes your group owns, rule for rule, including thresholds, comparison operators, ordering, which
  row a notice reports and the gating above. Read the Java source; do not reconstruct a rule from its documentation.
- Must run on DuckDB 2.0.0 and 1.4.3 (the browser build still uses DuckDB-WASM 1.4), with core functions only: no
  spatial, httpfs or other extension, no `INSTALL`/`LOAD`.
- Must scale to a large feed: the NYC subway feed (562,944 stop_times, 5 MB of shapes) must validate in well under a
  minute. Avoid unbounded self-joins: partition by trip, shape or a coordinate grid.
- Join on plain columns. An equality whose sides span three relations, such as `l2.cx = l1.cx + o.dx` over a cross
  join with `o`, is not a join key: DuckDB joins on the other conditions and filters, so a grid lookup became a
  comparison of every stop with every other one. Compute the key in a CTE first. `harness.plan()` returns the
  physical plan of a query after a validation; `PlanTest` uses it to check that the stop distance rules hash-join on
  their grid cells.

## URLs with non-ASCII hosts (IDN)

`gtfs_vc_url_ok` ports commons-validator 1.6 `UrlValidator.isValid`, which converts the authority with
`java.net.IDN.toASCII` before the ASCII checks. The `gtfs_vc_idn_*` macros in `validate_core.sql` emulate it (RFC 3491
nameprep, RFC 3492 Punycode) and run only for authorities with a code point above U+007F. The nameprep data comes from
the oracle's own JDK 17 (its internal `StringPrep` and `UCharacter`, read by reflection), never from a Unicode data
file: the code points whose map plus NFKC differs from their NFC (the rest is left to DuckDB's `nfc_normalize()`), the
refused code points (unassigned in Unicode 3.2 or mapped to a prohibited one) and the bidi classes R/AL and L. It sits
between `-- BEGIN GENERATED` and `-- END GENERATED`; regenerate it, and the corpus, from the repository root with

    java --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/jdk.internal.icu.text=ALL-UNNAMED --add-exports java.base/jdk.internal.icu.lang=ALL-UNNAMED -cp <gtfs-validator cli jar> test/validation/idn/GenIdn.java sql/validate_core.sql test/validation/idn/corpus.tsv

(Java 17; the output is the same bytes on every run). CI's Format Check runs clang-format on `GenIdn.java` too (DuckDB's
`scripts/format.py`, run by `make format-check`, covers `.java` files under `test/`); formatting it does not change its
output. `test/validation/idn/corpus.tsv` holds hosts with Java's `IDN.toASCII` result (or `ERROR`) and URLs with
`UrlValidator`'s answer; `test/test_idn.py` checks the SQL against it on every DuckDB binary, without Java. Keep the
lambdas shallow: DuckDB 2.0 binds a lambda body more than once, so the steps are chained through macro arguments instead
of nested lambdas.

## Testing

- Fixtures: `test/validation/feeds/<name>/`. A fixture holds only the files it changes; `harness.materialize` copies
  `feeds/base` first, removes the names listed in an optional `_remove` file, and a `_standalone` file skips the base.
  `expected.json` is the oracle's output, never hand-written: `python3 test/validation/harness.py expect <name>` (needs
  the jar and Java 17; see the harness docstring). Name fixtures by group: `core-`, `generated-`, `stops-`,
  `stoptimes-`, `routescal-`, `shapes-`. The oracle exports at most 1000 notices per code; keep fixtures small.
- `python3 -m unittest discover -s test -p 'test_validation.py' -v` runs every fixture on DuckDB 2.0.0 and 1.4.3 and
  compares our notices with expected.json (decimals with a relative tolerance of 1e-6, coordinate pairs such as a
  shape match location with 1e-9; a zero must have the same sign, since report.json prints `-0.0`, and NaN matches
  NaN). `GTFS_VALIDATION_SCOPE=stops`
  (groups: core, generated, stops, stoptimes, routescal, shapes) limits the comparison to codes the stops group owns;
  codes shared with another group must then only produce no extra notice. CI runs the same tests against the built
  extension (`GTFS_EXTENSION`).
- `python3 test/validation/harness.py diff <feed dir or zip>` compares a whole feed with the oracle, code by code.
- `python3 test/validation/gen_loader.py --check` fails when the generated loader blocks are out of date.
- A notice whose file field names alternatives (`calendar.txt or calendar_dates.txt`) is in scope when every
  alternative is one of the 8 files.
