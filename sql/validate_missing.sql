-- Statement section (core workstream), run once per validated file that does not exist. Same placeholders as
-- validate_load.sql. A missing optional file is parsed successfully; a missing required file is not.
INSERT INTO gtfs_validation_files VALUES ({{FILE}}, 'MISSING_FILE', {{REQUIRED}}, NOT {{REQUIRED}}, 0);
