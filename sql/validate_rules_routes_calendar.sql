-- Validation rules for routes.txt, calendar.txt, calendar_dates.txt and blocks (routescal workstream).
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*; the entry point
-- gtfs_validate_rules_routes_calendar() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.
CREATE OR REPLACE MACRO gtfs_validate_rules_routes_calendar() AS TABLE
SELECT NULL::VARCHAR AS code, NULL::JSON AS notice WHERE false;
