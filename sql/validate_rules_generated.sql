-- Validation rules the Java validator generates from schema annotations (generated workstream): primary keys,
-- foreign keys, start/end ranges, lat/lon points and mixed-case fields over the validated files.
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*; the entry point
-- gtfs_validate_rules_generated() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.
CREATE OR REPLACE MACRO gtfs_validate_rules_generated() AS TABLE
SELECT NULL::VARCHAR AS code, NULL::JSON AS notice WHERE false;
