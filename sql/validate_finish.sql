-- Statement section (core workstream), run after every file: collects every notice. The last statement's result is
-- what PRAGMA gtfs_validate returns.
-- Each rule macro of each group (gtfs_validate_rules_<group>(), in that macro's order) runs in its own statement.
-- Run as one UNION ALL, DuckDB v1.4 kept the working state of every rule at once and ran out of memory on the New
-- York City Subway feed at memory_limit = '2GB'. test_validation.py checks that this list matches the group macros.
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_validation_generic_notices;
-- gtfs_validate_rules_stops()
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_location_type();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_name();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_required_location();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_access();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_exit_gate();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_pathway_mode_fields();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_pathway_loop();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_parent_distance();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_parent_station();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_station_distance();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_stop_times();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_url();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_dangling_node();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_endpoint_type();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_pathway_access();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stops_reachable();
-- gtfs_validate_rules_stop_times()
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_pickup_drop_off_window();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_pickup_drop_off_type();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_geography_id();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_shape_dist_presence();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_increasing_distance();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_record();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_timepoint();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_trip_edge();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_arrival_departure();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_same_time();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_block_order();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_trip_usage();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_duplicate_trips();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_continuous_pickup_drop_off();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_trip_shape_id();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_bikes_allowance();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_block_route_type();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_trip_headsign();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_stoptimes_travel_speed();
-- gtfs_validate_rules_routes_calendar()
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_route_entities();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_duplicate_route_name();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_service_spread();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_expired_calendar();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_calendar_presence();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_trip_service_fk();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_routescal_block_overlaps();
-- gtfs_validate_rules_shapes()
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_missing_file();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_stop_matching_notices();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_increasing_distance();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_single_point();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_unused();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_trip_distance();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_shapes_trip_dist_no_shape_dist();
-- gtfs_validate_rules_generated()
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_generated_duplicate_key();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_generated_foreign_key();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_generated_end_range();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_generated_lat_lon();
INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM gtfs_vr_generated_mixed_case();
INSERT INTO gtfs_validation_notices
SELECT n.code, r.severity,
  coalesce(n.notice->>'$.filename', n.notice->>'$.childFilename'),
  TRY_CAST(coalesce(n.notice->>'$.csvRowNumber', n.notice->>'$.childCsvRowNumber', n.notice->>'$.csvRowNumber1') AS BIGINT),
  n.notice
FROM gtfs_vc_rule_notices n
LEFT JOIN gtfs_validation_rules() r USING (code);
-- Empty the working tables: the rules' notices, and the loader's tables, which still hold the last loaded file.
DELETE FROM gtfs_vc_rule_notices;
DELETE FROM gtfs_vc_text;
DELETE FROM gtfs_vc_records;
DELETE FROM gtfs_vc_header;
DELETE FROM gtfs_vc_state;
DELETE FROM gtfs_vc_rows;
DELETE FROM gtfs_vc_cells;
DELETE FROM gtfs_vc_notices;
SELECT * FROM gtfs_validation_summary();
