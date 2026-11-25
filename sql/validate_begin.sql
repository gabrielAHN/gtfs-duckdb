-- Statement section (core workstream), run by PRAGMA gtfs_validate after validate_schema.sql.
-- Placeholders, replaced before parsing: DATE (a DATE expression) and DIRECTORY (a quoted string literal), each in
-- double braces. Never write a placeholder in a comment: comments are replaced too, and a directory name with a
-- newline would end the comment and run as SQL (test_validation.py checks the section files).
INSERT INTO gtfs_validation_state VALUES ({{DATE}}, {{DIRECTORY}}, now());
