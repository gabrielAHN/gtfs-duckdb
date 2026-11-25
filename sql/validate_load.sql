-- Statement section (core workstream), run once per validated file that exists, in the order
-- stops, pathways, routes, trips, stop_times, shapes, calendar, calendar_dates.
-- Placeholders, replaced before parsing: {{TABLE}} (bare name, e.g. stop_times), {{FILE}} (quoted literal, e.g. 'stop_times.txt'),
-- {{PATH}} (quoted literal path), {{REQUIRED}} (true/false: GtfsTableDescriptor.isRequired()).
-- GTFS_VALIDATION_STUB: while this marker is present the dev harness (test/validation/harness.py) fills gtfs_v_{{TABLE}}
-- itself with a naive reference loader. The core workstream removes the marker when this section loads the file.
INSERT INTO gtfs_validation_files VALUES ({{FILE}}, 'PARSABLE_HEADERS_AND_ROWS', {{REQUIRED}}, true, NULL);
