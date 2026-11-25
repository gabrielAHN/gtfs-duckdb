-- Statement section (core workstream), run after every file: collects every notice. The last statement's result is
-- what PRAGMA gtfs_validate returns.
INSERT INTO gtfs_validation_notices
SELECT n.code, r.severity,
  coalesce(n.notice->>'$.filename', n.notice->>'$.childFilename'),
  TRY_CAST(coalesce(n.notice->>'$.csvRowNumber', n.notice->>'$.childCsvRowNumber', n.notice->>'$.csvRowNumber1') AS BIGINT),
  n.notice
FROM (
  SELECT code, notice FROM gtfs_validation_generic_notices
  UNION ALL SELECT code, notice FROM gtfs_validate_rules_stops()
  UNION ALL SELECT code, notice FROM gtfs_validate_rules_stop_times()
  UNION ALL SELECT code, notice FROM gtfs_validate_rules_routes_calendar()
  UNION ALL SELECT code, notice FROM gtfs_validate_rules_shapes()
  UNION ALL SELECT code, notice FROM gtfs_validate_rules_generated()
) n
LEFT JOIN gtfs_validation_rules() r USING (code);
-- Empty the loader's working tables, which still hold the last loaded file.
DELETE FROM gtfs_vc_text;
DELETE FROM gtfs_vc_records;
DELETE FROM gtfs_vc_header;
DELETE FROM gtfs_vc_state;
DELETE FROM gtfs_vc_rows;
DELETE FROM gtfs_vc_cells;
DELETE FROM gtfs_vc_notices;
SELECT * FROM gtfs_validation_summary();
