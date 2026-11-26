-- Statement section (core workstream), run once per validated file that exists, in the order
-- stops, pathways, routes, trips, stop_times, shapes, calendar, calendar_dates.
-- Placeholders, replaced before parsing, each in double braces (never inside a comment, see validate_begin.sql):
-- TABLE (bare name, e.g. stop_times), FILE (quoted literal, e.g. 'stop_times.txt'), PATH (quoted literal path) and
-- REQUIRED (true/false: GtfsTableDescriptor.isRequired()).
-- Port of CsvFileLoader.load (macros in validate_core.sql): read the file once, split it into lines, parse its
-- records, check the header, then rows, values and entities, and record its TableStatus and notices.
-- Each step after the split works on one row per line or record, so DuckDB runs it on every thread. The big working
-- tables are emptied as soon as they are used, with CREATE OR REPLACE (DuckDB v1.4 keeps a DELETE's memory). One that a
-- later file refills names its columns (as in validate_schema.sql): DuckDB v2.0 runs the whole PRAGMA in one
-- transaction, and there an INSERT ... SELECT from a table into a table replaced AS SELECT in the same transaction
-- loses its rows when it spans several row groups and preserve_insertion_order is on (its default).
DELETE FROM gtfs_vc_text;
DELETE FROM gtfs_vc_header;
DELETE FROM gtfs_vc_state;
DELETE FROM gtfs_vc_pos;
DELETE FROM gtfs_vc_notices;
-- Decoded text (CsvFile: UTF-8 with U+FFFD for malformed bytes) split on LF. BOMInputStream strips one UTF-8 BOM and
-- univocity a second one. A CASE, not coalesce: DuckDB v2.0 evaluates coalesce's slow fallback for valid text too.
-- TRY in both places: DuckDB computes a repeated subexpression once, before the CASE, so a bare decode would throw.
INSERT INTO gtfs_vc_lines
SELECT unnest(range(1, len(l) + 1)), unnest(l)
FROM (SELECT string_split(CASE WHEN TRY(decode(content)) IS NOT NULL THEN TRY(decode(content))
                               ELSE gtfs_vc_decode_invalid(content) END, chr(10)) AS l
      FROM read_blob({{PATH}}));
UPDATE gtfs_vc_lines SET line = regexp_replace(line, '^\x{FEFF}\x{FEFF}?', '')
WHERE line_no = 1 AND starts_with(line, chr(65279));
INSERT INTO gtfs_vc_records SELECT * FROM gtfs_vc_line_records();
INSERT INTO gtfs_vc_text SELECT {{FILE}}, NULL, gtfs_vc_invalid_line_ending_row(),
  EXISTS (SELECT 1 FROM gtfs_vc_records WHERE kind = 'open');
-- The whole text, only for a quoted value spanning lines or a record the parser fails on (rare). The condition sits
-- inside the subquery: DuckDB computes an uncorrelated subquery even when the UPDATE matches no row.
UPDATE gtfs_vc_text SET text = (
  SELECT string_agg(l.line, chr(10) ORDER BY l.line_no) FROM gtfs_vc_lines l
  WHERE gtfs_vc_text.multiline
    OR EXISTS (SELECT 1 FROM gtfs_vc_records r WHERE r.kind = 'row' AND (r.max_len > 4096 OR len(r.fields) > 512)));
CREATE OR REPLACE TEMP TABLE gtfs_vc_lines (line_no BIGINT, line VARCHAR);
DELETE FROM gtfs_vc_records WHERE (SELECT multiline FROM gtfs_vc_text);
INSERT INTO gtfs_vc_records SELECT * FROM gtfs_vc_parse_records();
CREATE OR REPLACE TEMP TABLE gtfs_vc_fail AS SELECT * FROM gtfs_vc_failure();
UPDATE gtfs_vc_text SET text = NULL WHERE text IS NOT NULL;
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
-- Each schema column's position in the header (its first column of that name).
INSERT INTO gtfs_vc_pos
SELECT list(h.column_index + 1 ORDER BY s.col_ord)
FROM gtfs_vc_schema() s
LEFT JOIN (SELECT column_name, min(column_index) AS column_index FROM gtfs_vc_header GROUP BY column_name) h
  USING (column_name)
WHERE s.filename = {{FILE}};
INSERT INTO gtfs_vc_wide_{{TABLE}} SELECT * FROM gtfs_vc_wide_build_{{TABLE}}();
INSERT INTO gtfs_vc_notices SELECT * FROM gtfs_vc_row_length_notices({{FILE}});
CREATE OR REPLACE TEMP TABLE gtfs_vc_records (
  rec_no BIGINT, csv_row_number BIGINT, kind VARCHAR, fields VARCHAR[], max_len BIGINT, plain BOOLEAN);
INSERT INTO gtfs_vc_notices SELECT * FROM gtfs_vc_cell_notices_{{TABLE}}();
INSERT INTO gtfs_v_{{TABLE}} SELECT * FROM gtfs_vc_entities_{{TABLE}}();
-- Its last use in this PRAGMA (validate_schema.sql replaces it, naming its columns, before the next one fills it).
CREATE OR REPLACE TEMP TABLE gtfs_vc_wide_{{TABLE}} AS SELECT * FROM gtfs_vc_wide_{{TABLE}} LIMIT 0;
INSERT INTO gtfs_validation_generic_notices SELECT code, notice FROM gtfs_vc_notices;
INSERT INTO gtfs_validation_columns
SELECT {{FILE}}, column_name, column_index FROM gtfs_vc_header;
INSERT INTO gtfs_validation_files
SELECT {{FILE}}, gtfs_vc_status(), {{REQUIRED}}, gtfs_vc_status() = 'PARSABLE_HEADERS_AND_ROWS',
  (SELECT count(*) FROM gtfs_v_{{TABLE}});
INSERT INTO gtfs_validation_generic_notices
SELECT 'empty_file', gtfs_validation_notice(json_object('filename', {{FILE}})) WHERE gtfs_vc_status() = 'EMPTY_FILE'
UNION ALL
SELECT 'empty_required_file', gtfs_validation_notice(json_object('filename', {{FILE}}))
WHERE {{REQUIRED}} AND gtfs_vc_status() = 'PARSABLE_HEADERS_AND_ROWS' AND NOT EXISTS (SELECT 1 FROM gtfs_v_{{TABLE}})
UNION ALL
SELECT 'invalid_line_ending', gtfs_validation_notice(json_object('filename', {{FILE}}, 'rowNumber', invalid_line_ending_row))
FROM gtfs_vc_text WHERE invalid_line_ending_row IS NOT NULL;
