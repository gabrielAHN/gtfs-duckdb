-- Shared helpers for every validation rule group. Manager-owned: workers never edit this file.
-- Macro section: only CREATE OR REPLACE MACRO statements (registered as gtfs extension functions).

-- Distance in meters between two WGS84 points, as MobilityData's S2Earth.getDistanceMeters(S2LatLng, S2LatLng):
-- S2LatLng.getDistance (haversine) on a sphere of radius 6,371,010 m.
CREATE OR REPLACE MACRO gtfs_validation_distance_m(lat1, lon1, lat2, lon2) AS (
  2 * asin(sqrt(least(1.0,
      pow(sin(0.5 * (radians(lat2) - radians(lat1))), 2)
    + pow(sin(0.5 * (radians(lon2) - radians(lon1))), 2) * cos(radians(lat1)) * cos(radians(lat2))
  ))) * 6371010.0
);

-- A notice object as Gson writes it: the notice's fields without the null ones. Build notices as
-- gtfs_validation_notice(json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, ...)).
CREATE OR REPLACE MACRO gtfs_validation_notice(fields) AS (json_merge_patch('{}', fields));

-- GtfsTime.toHHMMSS(): seconds since midnight -> 'HH:MM:SS' (hours can exceed 24).
CREATE OR REPLACE MACRO gtfs_validation_time_text(seconds) AS (
  CASE WHEN seconds IS NULL THEN NULL
       ELSE printf('%02d:%02d:%02d', seconds // 3600, (seconds % 3600) // 60, seconds % 60) END
);

-- GtfsDate.toYYYYMMDD()
CREATE OR REPLACE MACRO gtfs_validation_date_text(d) AS (strftime(d, '%Y%m%d'));

-- GtfsColor.toHtmlColor(): 0xRRGGBB integer -> '#RRGGBB'
CREATE OR REPLACE MACRO gtfs_validation_color_text(rgb) AS (
  CASE WHEN rgb IS NULL THEN NULL ELSE '#' || upper(lpad(to_hex(rgb), 6, '0')) END
);

-- GtfsEntityContainer.isParsedSuccessfully() for every listed file: status PARSABLE_HEADERS_AND_ROWS, or MISSING_FILE
-- for an optional file. Files outside the 8 validated files count as parsed (they are not read).
-- Multi-file and single-file validators run only when this is TRUE for all of their dependencies.
CREATE OR REPLACE MACRO gtfs_validation_parsed(dependency_files) AS (
  coalesce((SELECT bool_and(f.parsed) FROM gtfs_validation_files f WHERE list_contains(dependency_files, f.filename)), true)
);

-- Whether a validated file's header has the column (ColumnInspector.hasColumn in the Java validators). Header cells are
-- matched as the Java loader stores them (CsvHeader: trimmed, case-sensitive).
CREATE OR REPLACE MACRO gtfs_validation_has_column(header_file, header_column) AS (
  EXISTS (SELECT 1 FROM gtfs_validation_columns c WHERE c.filename = header_file AND c.column_name = header_column)
);

-- The validation date: PRAGMA gtfs_validate's second argument, default current_date.
CREATE OR REPLACE MACRO gtfs_validation_date() AS ((SELECT s.validation_date FROM gtfs_validation_state s));
