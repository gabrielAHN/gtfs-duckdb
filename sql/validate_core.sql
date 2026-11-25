-- Core validation macros (core workstream). Macro section: only CREATE OR REPLACE MACRO statements, which the
-- extension registers as functions at LOAD. Tables they reference must be created in validate_schema.sql.

-- One row per notice code: severity, code and how many notices the last PRAGMA gtfs_validate produced.
CREATE OR REPLACE MACRO gtfs_validation_summary() AS TABLE
SELECT severity, code, count(*) AS total_notices
FROM gtfs_validation_notices
GROUP BY severity, code
ORDER BY CASE severity WHEN 'ERROR' THEN 0 WHEN 'WARNING' THEN 1 ELSE 2 END, code;
