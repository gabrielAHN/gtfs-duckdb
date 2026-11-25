-- Statement section (core workstream), run by PRAGMA gtfs_validate after validate_schema.sql.
-- Placeholders, replaced before parsing: {{DATE}} (a DATE expression), {{DIRECTORY}} (a quoted string literal).
INSERT INTO gtfs_validation_state VALUES ({{DATE}}, {{DIRECTORY}}, now());
