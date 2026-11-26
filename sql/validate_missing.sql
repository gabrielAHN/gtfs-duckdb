-- Statement section (core workstream), run once per validated file that does not exist. Same placeholders as
-- validate_load.sql. A missing optional file is parsed successfully, a missing required file is not.
INSERT INTO gtfs_validation_files VALUES ({{FILE}}, 'MISSING_FILE', {{REQUIRED}}, NOT {{REQUIRED}}, 0);
-- TableLoader.loadMissingFile (required files) and MissingStopsFileValidator (stops.txt, locations.geojson is
-- treated as absent since the port does not read it).
INSERT INTO gtfs_validation_generic_notices
SELECT 'missing_required_file', gtfs_validation_notice(json_object('filename', {{FILE}}))
WHERE {{REQUIRED}} OR {{FILE}} = 'stops.txt';
