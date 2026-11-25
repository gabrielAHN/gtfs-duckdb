-- Validation rules the Java validator generates from schema annotations (generated workstream): primary keys,
-- foreign keys, start/end ranges, lat/lon points and mixed-case fields over the validated files.
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*, the entry point
-- gtfs_validate_rules_generated() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.

-- Whether the table container of a file was built (TableStatus PARSABLE_HEADERS_AND_ROWS): only then does its
-- setupIndices() run and report duplicate_key.
CREATE OR REPLACE MACRO gtfs_vr_generated_indexed(p_file) AS (
  coalesce((SELECT bool_and(f.status = 'PARSABLE_HEADERS_AND_ROWS') FROM gtfs_validation_files f
            WHERE f.filename = p_file), false)
);

-- duplicate_key (TableContainerIndexGenerator.setupIndices, ColumnarEntityList.finish). Every entity whose primary
-- key equals the key of an earlier entity is reported against the FIRST entity holding that key (file order).
-- Single-column keys report the new entity's key value and skip entities without one. Composite keys report
-- CompositeKey.getDefinedKeys/getDefinedValues of the first entity: the defined key names and values joined by ','.
CREATE OR REPLACE MACRO gtfs_vr_generated_duplicate_key() AS TABLE
WITH single_keys AS (
  SELECT 'stops.txt' AS file, 'stop_id' AS field, stop_id AS key, csv_row_number FROM gtfs_v_stops
  UNION ALL SELECT 'pathways.txt', 'pathway_id', pathway_id, csv_row_number FROM gtfs_v_pathways
  UNION ALL SELECT 'routes.txt', 'route_id', route_id, csv_row_number FROM gtfs_v_routes
  UNION ALL SELECT 'trips.txt', 'trip_id', trip_id, csv_row_number FROM gtfs_v_trips
  UNION ALL SELECT 'calendar.txt', 'service_id', service_id, csv_row_number FROM gtfs_v_calendar
),
single_dups AS (
  SELECT file, field, key, csv_row_number,
         first_value(csv_row_number) OVER (PARTITION BY file, key ORDER BY csv_row_number) AS first_row
  FROM single_keys
  WHERE key IS NOT NULL
),
-- Composite keys: the entity's key values (Java getters: coalesced to the default) and whether each is defined.
composite_keys AS (
  SELECT 'stop_times.txt' AS file, 'trip_id' AS name1, 'stop_sequence' AS name2,
         coalesce(trip_id, '') AS k1, coalesce(stop_sequence, 0)::VARCHAR AS k2,
         trip_id IS NOT NULL AS has1, stop_sequence IS NOT NULL AS has2, to_json(stop_sequence) AS json2,
         csv_row_number
  FROM gtfs_v_stop_times
  UNION ALL
  SELECT 'shapes.txt', 'shape_id', 'shape_pt_sequence',
         coalesce(shape_id, ''), coalesce(shape_pt_sequence, 0)::VARCHAR,
         shape_id IS NOT NULL, shape_pt_sequence IS NOT NULL, to_json(shape_pt_sequence), csv_row_number
  FROM gtfs_v_shapes
  UNION ALL
  SELECT 'calendar_dates.txt', 'service_id', 'date',
         coalesce(service_id, ''), gtfs_validation_date_text(coalesce(date, DATE '1970-01-01')),
         service_id IS NOT NULL, date IS NOT NULL, to_json(gtfs_validation_date_text(date)), csv_row_number
  FROM gtfs_v_calendar_dates
),
composite_dups AS (
  SELECT file, csv_row_number,
         first_value(csv_row_number) OVER w AS first_row,
         first_value(struct_pack(name1 := name1, name2 := name2, k1 := k1, k2 := k2, has1 := has1, has2 := has2,
                                 json2 := json2)) OVER w AS first_key
  FROM composite_keys
  WINDOW w AS (PARTITION BY file, k1, k2 ORDER BY csv_row_number)
)
SELECT 'duplicate_key' AS code,
       gtfs_validation_notice(json_object('filename', file, 'oldCsvRowNumber', first_row,
         'newCsvRowNumber', csv_row_number, 'fieldName1', field, 'fieldValue1', key)) AS notice
FROM single_dups
WHERE csv_row_number <> first_row AND gtfs_vr_generated_indexed(file)
UNION ALL
SELECT 'duplicate_key',
       gtfs_validation_notice(json_object('filename', file, 'oldCsvRowNumber', first_row,
         'newCsvRowNumber', csv_row_number,
         'fieldName1', concat_ws(',', CASE WHEN first_key.has1 THEN first_key.name1 END,
                                      CASE WHEN first_key.has2 THEN first_key.name2 END),
         -- values.stream().reduce(a + "," + b).orElse(null): the joined text when both are defined, else the
         -- single defined value itself (an Integer stays a number), else null.
         'fieldValue1', CASE WHEN first_key.has1 AND first_key.has2
                               THEN to_json(first_key.k1 || ',' || first_key.k2)
                             WHEN first_key.has1 THEN to_json(first_key.k1)
                             WHEN first_key.has2 THEN first_key.json2 END))
FROM composite_dups
WHERE csv_row_number <> first_row AND gtfs_vr_generated_indexed(file);

-- foreign_key_violation (ForeignKeyValidatorGenerator): one FileValidator per @ForeignKey whose parent and child are
-- validated files. It injects the parent and child containers (both must be parsed), and shouldCallValidate() is
-- childContainer.hasColumn(child column). Every child entity with a value absent from the parent's key is reported.
-- trips.service_id has no @ForeignKey (routescal ports GtfsTripServiceIdForeignKeyValidator).
CREATE OR REPLACE MACRO gtfs_vr_generated_fk_notice(p_child_file, p_child_field, p_parent_file, p_parent_field,
                                                    p_value, p_row) AS (
  gtfs_validation_notice(json_object('childFilename', p_child_file, 'childFieldName', p_child_field,
    'parentFilename', p_parent_file, 'parentFieldName', p_parent_field, 'fieldValue', p_value,
    'csvRowNumber', p_row))
);

CREATE OR REPLACE MACRO gtfs_vr_generated_foreign_key() AS TABLE
-- stops.parent_station -> stops.stop_id
SELECT 'foreign_key_violation' AS code,
       gtfs_vr_generated_fk_notice('stops.txt', 'parent_station', 'stops.txt', 'stop_id', c.parent_station,
                                   c.csv_row_number) AS notice
FROM gtfs_v_stops c
WHERE c.parent_station IS NOT NULL
  AND gtfs_validation_parsed(['stops.txt']) AND gtfs_validation_has_column('stops.txt', 'parent_station')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_stops p WHERE p.stop_id = c.parent_station)
UNION ALL
-- pathways.from_stop_id -> stops.stop_id
SELECT 'foreign_key_violation',
       gtfs_vr_generated_fk_notice('pathways.txt', 'from_stop_id', 'stops.txt', 'stop_id', c.from_stop_id,
                                   c.csv_row_number)
FROM gtfs_v_pathways c
WHERE c.from_stop_id IS NOT NULL
  AND gtfs_validation_parsed(['stops.txt', 'pathways.txt'])
  AND gtfs_validation_has_column('pathways.txt', 'from_stop_id')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_stops p WHERE p.stop_id = c.from_stop_id)
UNION ALL
-- pathways.to_stop_id -> stops.stop_id
SELECT 'foreign_key_violation',
       gtfs_vr_generated_fk_notice('pathways.txt', 'to_stop_id', 'stops.txt', 'stop_id', c.to_stop_id,
                                   c.csv_row_number)
FROM gtfs_v_pathways c
WHERE c.to_stop_id IS NOT NULL
  AND gtfs_validation_parsed(['stops.txt', 'pathways.txt'])
  AND gtfs_validation_has_column('pathways.txt', 'to_stop_id')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_stops p WHERE p.stop_id = c.to_stop_id)
UNION ALL
-- trips.route_id -> routes.route_id
SELECT 'foreign_key_violation',
       gtfs_vr_generated_fk_notice('trips.txt', 'route_id', 'routes.txt', 'route_id', c.route_id, c.csv_row_number)
FROM gtfs_v_trips c
WHERE c.route_id IS NOT NULL
  AND gtfs_validation_parsed(['routes.txt', 'trips.txt'])
  AND gtfs_validation_has_column('trips.txt', 'route_id')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_routes p WHERE p.route_id = c.route_id)
UNION ALL
-- trips.shape_id -> shapes.shape_id (an @Index of shapes.txt)
SELECT 'foreign_key_violation',
       gtfs_vr_generated_fk_notice('trips.txt', 'shape_id', 'shapes.txt', 'shape_id', c.shape_id, c.csv_row_number)
FROM gtfs_v_trips c
WHERE c.shape_id IS NOT NULL
  AND gtfs_validation_parsed(['shapes.txt', 'trips.txt'])
  AND gtfs_validation_has_column('trips.txt', 'shape_id')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_shapes p WHERE p.shape_id = c.shape_id)
UNION ALL
-- stop_times.trip_id -> trips.trip_id
SELECT 'foreign_key_violation',
       gtfs_vr_generated_fk_notice('stop_times.txt', 'trip_id', 'trips.txt', 'trip_id', c.trip_id, c.csv_row_number)
FROM gtfs_v_stop_times c
WHERE c.trip_id IS NOT NULL
  AND gtfs_validation_parsed(['trips.txt', 'stop_times.txt'])
  AND gtfs_validation_has_column('stop_times.txt', 'trip_id')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_trips p WHERE p.trip_id = c.trip_id)
UNION ALL
-- stop_times.stop_id -> stops.stop_id
SELECT 'foreign_key_violation',
       gtfs_vr_generated_fk_notice('stop_times.txt', 'stop_id', 'stops.txt', 'stop_id', c.stop_id, c.csv_row_number)
FROM gtfs_v_stop_times c
WHERE c.stop_id IS NOT NULL
  AND gtfs_validation_parsed(['stops.txt', 'stop_times.txt'])
  AND gtfs_validation_has_column('stop_times.txt', 'stop_id')
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_stops p WHERE p.stop_id = c.stop_id);

-- start_and_end_range_out_of_order / start_and_end_range_equal (EndRangeValidatorGenerator, SingleEntityValidator).
-- The two @EndRange of the validated files both allow equality (stop_times arrival_time -> departure_time,
-- calendar start_date -> end_date), so start_and_end_range_equal is never generated for them.
-- entityId is the single-column primary key (calendar.service_id). stop_times has a composite key, hence none.
CREATE OR REPLACE MACRO gtfs_vr_generated_end_range() AS TABLE
SELECT 'start_and_end_range_out_of_order' AS code,
       gtfs_validation_notice(json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number,
         'startFieldName', 'arrival_time', 'startValue', gtfs_validation_time_text(arrival_time),
         'endFieldName', 'departure_time', 'endValue', gtfs_validation_time_text(departure_time))) AS notice
FROM gtfs_v_stop_times
WHERE arrival_time IS NOT NULL AND departure_time IS NOT NULL AND arrival_time > departure_time
UNION ALL
SELECT 'start_and_end_range_out_of_order',
       gtfs_validation_notice(json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number,
         'entityId', coalesce(service_id, ''),
         'startFieldName', 'start_date', 'startValue', gtfs_validation_date_text(start_date),
         'endFieldName', 'end_date', 'endValue', gtfs_validation_date_text(end_date)))
FROM gtfs_v_calendar
WHERE start_date IS NOT NULL AND end_date IS NOT NULL AND start_date > end_date;

-- point_near_origin / point_near_pole (LatLonValidatorGenerator, SingleEntityValidator. S2Earth.isNearOrigin:
-- |lat| <= 1 and |lon| <= 1, S2Earth.isNearPole: |lat| >= 89). Only when both coordinates are present.
-- entityId is the single-column primary key (stops.stop_id). shapes has a composite key, hence none.
CREATE OR REPLACE MACRO gtfs_vr_generated_lat_lon() AS TABLE
WITH points AS (
  SELECT 'stops.txt' AS file, csv_row_number, coalesce(stop_id, '') AS entity_id,
         'stop_lat' AS lat_name, stop_lat AS lat, 'stop_lon' AS lon_name, stop_lon AS lon
  FROM gtfs_v_stops
  UNION ALL
  SELECT 'shapes.txt', csv_row_number, NULL, 'shape_pt_lat', shape_pt_lat, 'shape_pt_lon', shape_pt_lon
  FROM gtfs_v_shapes
),
flagged AS (
  SELECT *, CASE WHEN abs(lat) <= 1.0 AND abs(lon) <= 1.0 THEN 'point_near_origin'
                 WHEN abs(lat) >= 89.0 THEN 'point_near_pole' END AS code
  FROM points
  WHERE lat IS NOT NULL AND lon IS NOT NULL
)
SELECT code,
       gtfs_validation_notice(json_object('filename', file, 'csvRowNumber', csv_row_number, 'entityId', entity_id,
         'latFieldName', lat_name, 'latFieldValue', lat, 'lonFieldName', lon_name, 'lonFieldValue', lon)) AS notice
FROM flagged
WHERE code IS NOT NULL;

-- Java String.length() of a text: UTF-16 code units (a code point above U+FFFF counts twice).
CREATE OR REPLACE MACRO gtfs_vr_generated_utf16_length(p_text) AS (
  length(p_text) + length(regexp_replace(p_text, '[^\x{10000}-\x{10FFFF}]', '', 'g'))
);

-- mixed_case_recommended_field (MixedCaseValidatorGenerator, SingleEntityValidator), for each present value:
--   tokens = value.split("[^\\p{L}]+"): the runs of letters, preceded by an empty token when the value starts
--   with a non-letter and has a letter (String.split keeps a leading empty token and drops trailing ones).
--   One token: reported when longer than 1 (UTF-16 units) and all lowercase (^\p{Ll}+$). The token digit test
--   (.*\d+.*) can never match a run of letters.
--   Otherwise: tokens of length 1 are skipped (the empty token counts), reported when at least 2 tokens count
--   and none of them has both an uppercase and a lowercase letter.
-- shouldCallValidate(header) is true when any mixed-case column of the file is in the header. A value can only be
-- present when its column is, so that gate never removes a notice.
CREATE OR REPLACE MACRO gtfs_vr_generated_mixed_case() AS TABLE
WITH vals AS (
  SELECT 'stops.txt' AS file, 'stop_name' AS field, stop_name AS value, csv_row_number FROM gtfs_v_stops
  UNION ALL SELECT 'pathways.txt', 'signposted_as', signposted_as, csv_row_number FROM gtfs_v_pathways
  UNION ALL SELECT 'pathways.txt', 'reversed_signposted_as', reversed_signposted_as, csv_row_number
            FROM gtfs_v_pathways
  UNION ALL SELECT 'routes.txt', 'route_short_name', route_short_name, csv_row_number FROM gtfs_v_routes
  UNION ALL SELECT 'routes.txt', 'route_long_name', route_long_name, csv_row_number FROM gtfs_v_routes
  UNION ALL SELECT 'routes.txt', 'route_desc', route_desc, csv_row_number FROM gtfs_v_routes
  UNION ALL SELECT 'trips.txt', 'trip_headsign', trip_headsign, csv_row_number FROM gtfs_v_trips
  UNION ALL SELECT 'trips.txt', 'trip_short_name', trip_short_name, csv_row_number FROM gtfs_v_trips
),
-- Distinct values first: a feed repeats the same headsigns and names on many rows.
tokens AS (
  SELECT value,
         regexp_extract_all(value, '\p{L}+') AS runs,
         regexp_matches(value, '^[^\p{L}]') AND regexp_matches(value, '\p{L}') AS lead
  FROM (SELECT DISTINCT value FROM vals WHERE value IS NOT NULL)
),
counted AS (
  SELECT value, runs, lead,
         len(runs) + CASE WHEN lead THEN 1 ELSE 0 END AS token_count,
         list_filter(runs, lambda r: length(r) + length(regexp_replace(r, '[^\x{10000}-\x{10FFFF}]', '', 'g')) <> 1)
           AS long_runs
  FROM tokens
),
flagged AS (
  SELECT value
  FROM counted
  WHERE CASE
          WHEN token_count = 1 THEN
            gtfs_vr_generated_utf16_length(runs[1]) > 1 AND regexp_full_match(runs[1], '\p{Ll}+')
          ELSE
            len(long_runs) + CASE WHEN lead THEN 1 ELSE 0 END >= 2
            AND len(list_filter(long_runs, lambda r: regexp_matches(r, '\p{Lu}') AND regexp_matches(r, '\p{Ll}'))) = 0
        END
)
SELECT 'mixed_case_recommended_field' AS code,
       gtfs_validation_notice(json_object('filename', v.file, 'fieldName', v.field, 'fieldValue', v.value,
         'csvRowNumber', v.csv_row_number)) AS notice
FROM vals v
JOIN flagged k ON k.value = v.value;

CREATE OR REPLACE MACRO gtfs_validate_rules_generated() AS TABLE
SELECT code, notice FROM gtfs_vr_generated_duplicate_key()
UNION ALL SELECT code, notice FROM gtfs_vr_generated_foreign_key()
UNION ALL SELECT code, notice FROM gtfs_vr_generated_end_range()
UNION ALL SELECT code, notice FROM gtfs_vr_generated_lat_lon()
UNION ALL SELECT code, notice FROM gtfs_vr_generated_mixed_case();
