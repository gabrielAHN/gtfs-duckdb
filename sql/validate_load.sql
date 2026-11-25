-- Statement section (core workstream), run once per validated file that exists, in the order
-- stops, pathways, routes, trips, stop_times, shapes, calendar, calendar_dates.
-- Placeholders, replaced before parsing: {{TABLE}} (bare name, e.g. stop_times), {{FILE}} (quoted literal, e.g. 'stop_times.txt'),
-- {{PATH}} (quoted literal path), {{REQUIRED}} (true/false: GtfsTableDescriptor.isRequired()).
-- Port of CsvFileLoader.load (macros in validate_core.sql): read the file once, parse its records, check the header,
-- then rows, cells and entities, and record its TableStatus and notices.
DELETE FROM gtfs_vc_text;
DELETE FROM gtfs_vc_records;
DELETE FROM gtfs_vc_header;
DELETE FROM gtfs_vc_state;
DELETE FROM gtfs_vc_rows;
DELETE FROM gtfs_vc_cells;
DELETE FROM gtfs_vc_notices;
INSERT INTO gtfs_vc_text SELECT {{FILE}}, TRY(decode(content)), NULL, content FROM read_blob({{PATH}});
UPDATE gtfs_vc_text SET text = gtfs_vc_decode_invalid(content) WHERE text IS NULL;
-- BOMInputStream strips one UTF-8 BOM and univocity a second one.
UPDATE gtfs_vc_text SET text = regexp_replace(text, '^\x{FEFF}\x{FEFF}?', ''),
  invalid_line_ending_row = gtfs_vc_invalid_line_ending_row(text), content = NULL;
INSERT INTO gtfs_vc_records SELECT * FROM gtfs_vc_parse_records();
CREATE OR REPLACE TEMP TABLE gtfs_vc_fail AS SELECT * FROM gtfs_vc_failure();
INSERT INTO gtfs_validation_generic_notices SELECT 'csv_parsing_failed', notice FROM gtfs_vc_fail;
-- A header the parser failed on: INVALID_HEADERS, no header notices.
INSERT INTO gtfs_vc_header
SELECT unnest(names), unnest(range(0, len(names)))::INTEGER FROM gtfs_vc_header_record()
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_fail WHERE at_header);
INSERT INTO gtfs_vc_state
SELECT EXISTS (SELECT 1 FROM gtfs_vc_header_record()), (SELECT count(*) FROM gtfs_vc_header), NULL,
  (SELECT rec_no FROM gtfs_vc_fail);
INSERT INTO gtfs_validation_generic_notices SELECT code, notice FROM gtfs_vc_header_notices({{FILE}});
UPDATE gtfs_vc_state SET header_ok = has_header AND NOT EXISTS (SELECT 1 FROM gtfs_vc_fail WHERE at_header)
  AND NOT EXISTS (SELECT 1 FROM gtfs_vc_header_notices({{FILE}}) n WHERE n.code <> 'unknown_column');
INSERT INTO gtfs_vc_rows SELECT * FROM gtfs_vc_data_rows();
INSERT INTO gtfs_vc_cells SELECT * FROM gtfs_vc_build_cells({{FILE}});
INSERT INTO gtfs_vc_notices SELECT * FROM gtfs_vc_row_length_notices({{FILE}});
INSERT INTO gtfs_vc_notices SELECT * FROM gtfs_vc_cell_notices({{FILE}});
UPDATE gtfs_vc_rows SET entity = length_ok AND csv_row_number NOT IN (
  SELECT csv_row_number FROM gtfs_vc_notices WHERE err);
INSERT INTO gtfs_v_{{TABLE}} SELECT * FROM gtfs_vc_entities_{{TABLE}}();
INSERT INTO gtfs_validation_generic_notices SELECT code, notice FROM gtfs_vc_notices;
INSERT INTO gtfs_validation_columns
SELECT {{FILE}}, column_name, column_index FROM gtfs_vc_header;
INSERT INTO gtfs_validation_files
SELECT {{FILE}}, gtfs_vc_status(), {{REQUIRED}}, gtfs_vc_status() = 'PARSABLE_HEADERS_AND_ROWS',
  (SELECT count(*) FROM gtfs_vc_rows WHERE entity);
INSERT INTO gtfs_validation_generic_notices
SELECT 'empty_file', gtfs_validation_notice(json_object('filename', {{FILE}})) WHERE gtfs_vc_status() = 'EMPTY_FILE'
UNION ALL
SELECT 'empty_required_file', gtfs_validation_notice(json_object('filename', {{FILE}}))
WHERE {{REQUIRED}} AND gtfs_vc_status() = 'PARSABLE_HEADERS_AND_ROWS' AND NOT EXISTS (SELECT 1 FROM gtfs_vc_rows WHERE entity)
UNION ALL
SELECT 'invalid_line_ending', gtfs_validation_notice(json_object('filename', {{FILE}}, 'rowNumber', invalid_line_ending_row))
FROM gtfs_vc_text WHERE invalid_line_ending_row IS NOT NULL;
