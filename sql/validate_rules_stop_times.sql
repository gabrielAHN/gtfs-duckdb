-- Validation rules for stop_times.txt and trips.txt (stoptimes workstream).
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*; the entry point
-- gtfs_validate_rules_stop_times() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.
--
-- Ports, rule for rule, these MobilityData validators (gtfs-validator f9f4b9e, main/.../validator/):
--   StopTimeIncreasingDistanceValidator, DuplicateTripsValidator, StopTimeTravelSpeedValidator,
--   PickupDropOffWindowValidator, ContinuousPickupDropOffValidator, PickupDropOffTypeValidator,
--   StopTimesGeographyIdPresenceValidator, StopTimesShapeDistTraveledPresenceValidator,
--   InconsistentRouteTypeForBlockIdValidator, BikesAllowanceValidator, StopTimesRecordValidator,
--   TimepointTimeValidator, MissingTripEdgeValidator, StopTimeArrivalAndDepartureTimeValidator,
--   TooManyConsecutiveStopTimesWithSameTimeValidator, TripHeadsignValidator, StopTimesTripBlockOrderValidator,
--   TripUsabilityValidator, TripUsageValidator, TripShapeIdConditionalValidator.

-- ---------------------------------------------------------------------------------------------------- shared helpers

-- GtfsStopTimeTableContainer.byTripId(): the stop times of each trip sorted by stop_sequence, then by file row
-- (ColumnarEntityList.sortBySequence). idx is the 0-based position in that list, trip_size its length.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_ordered() AS TABLE
SELECT st.*,
  (row_number() OVER (PARTITION BY st.trip_id ORDER BY coalesce(st.stop_sequence, 0), st.csv_row_number) - 1)::INTEGER
    AS idx,
  count(*) OVER (PARTITION BY st.trip_id) AS trip_size
FROM gtfs_v_stop_times st;

-- GtfsTripTableContainer.byTripId() / GtfsRouteTableContainer.byRouteId() / GtfsStopTableContainer.byStopId(): the
-- first entity with the key wins (later duplicates are reported as duplicate_key and left out of the map).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_trip_by_id() AS TABLE
SELECT * FROM gtfs_v_trips t WHERE t.trip_id IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY t.trip_id ORDER BY t.csv_row_number) = 1;

CREATE OR REPLACE MACRO gtfs_vr_stoptimes_route_by_id() AS TABLE
SELECT * FROM gtfs_v_routes r WHERE r.route_id IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY r.route_id ORDER BY r.csv_row_number) = 1;

-- StopUtil.getOptionalStopOrParentLatLng: the stop's coordinates, else its parent's, else its grandparent's (3 lookups
-- at most). lat/lon are NULL when no location in the chain has both coordinates (Java: Optional.empty()).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_stop_latlng() AS TABLE
WITH s AS (
  SELECT x.stop_id, x.stop_name, x.parent_station, x.stop_lat, x.stop_lon,
    x.stop_lat IS NOT NULL AND x.stop_lon IS NOT NULL AS has_latlon
  FROM gtfs_v_stops x WHERE x.stop_id IS NOT NULL
  QUALIFY row_number() OVER (PARTITION BY x.stop_id ORDER BY x.csv_row_number) = 1
)
SELECT s.stop_id, s.stop_name,
  CASE WHEN s.has_latlon THEN s.stop_lat WHEN p.has_latlon THEN p.stop_lat WHEN g.has_latlon THEN g.stop_lat END AS lat,
  CASE WHEN s.has_latlon THEN s.stop_lon WHEN p.has_latlon THEN p.stop_lon WHEN g.has_latlon THEN g.stop_lon END AS lon
FROM s
LEFT JOIN s p ON NOT s.has_latlon AND p.stop_id = s.parent_station
LEFT JOIN s g ON NOT p.has_latlon AND g.stop_id = p.parent_station;

-- Java String.hashCode() of a text, as an unsigned 32-bit value (UTF-16 code units, surrogate pairs included).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_java_string_hash(p_text) AS (
  CASE WHEN p_text IS NULL OR p_text = '' THEN 0::BIGINT ELSE
  list_reduce(
    list_prepend(0::BIGINT, list_transform(string_split(p_text, ''), lambda ch: unicode(ch)::BIGINT)),
    lambda h, cp: CASE WHEN cp > 65535
      THEN (h * 961 + (55296 + ((cp - 65536) >> 10)) * 31 + (56320 + ((cp - 65536) & 1023))) % 4294967296
      ELSE (h * 31 + cp) % 4294967296 END)
  END
);

-- Bucket of a String key in a java.util.HashMap of p_capacity buckets: (h ^ (h >>> 16)) & (capacity - 1).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_java_bucket(p_text, p_capacity) AS (
  xor(gtfs_vr_stoptimes_java_string_hash(p_text), gtfs_vr_stoptimes_java_string_hash(p_text) >> 16) & (p_capacity - 1)
);

-- GtfsTime arithmetic of StopTimeTravelSpeedValidator.getTimeBetweenStops(arrivalTime, departureTime).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_seconds_between(p_arrival, p_departure) AS (
  CASE WHEN p_arrival - p_departure <= 0 THEN 60
       WHEN p_arrival % 60 = 0 AND p_departure % 60 = 0 THEN p_arrival - p_departure + 60
       ELSE p_arrival - p_departure END
);

-- StopTimeTravelSpeedValidator.getMaxVehicleSpeedKph(routeType)
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_max_speed_kph(p_route_type) AS (
  CASE p_route_type
    WHEN 0 THEN 100.0 WHEN 2 THEN 500.0
    WHEN 1 THEN 150.0 WHEN 12 THEN 150.0 WHEN 3 THEN 150.0 WHEN 11 THEN 150.0
    WHEN 4 THEN 80.0 WHEN 5 THEN 30.0 WHEN 6 THEN 50.0 WHEN 7 THEN 50.0
    ELSE 200.0 END
);

-- GtfsContinuousPickupDropOff ALLOWED (0), MUST_PHONE (2) or ON_REQUEST_TO_DRIVER (3).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_is_continuous(p_value) AS (coalesce(p_value IN (0, 2, 3), false));

-- ---------------------------------------------------------------------------------------- single-entity validators

-- PickupDropOffWindowValidator: forbidden_arrival_or_departure_time, missing_pickup_or_drop_off_window,
-- invalid_pickup_drop_off_window.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_pickup_drop_off_window() AS TABLE
WITH st AS (
  SELECT * FROM gtfs_v_stop_times x
  WHERE (gtfs_validation_has_column('stop_times.txt', 'start_pickup_drop_off_window')
         OR gtfs_validation_has_column('stop_times.txt', 'end_pickup_drop_off_window'))
    AND (x.start_pickup_drop_off_window IS NOT NULL OR x.end_pickup_drop_off_window IS NOT NULL)
)
SELECT 'forbidden_arrival_or_departure_time' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number,
  'arrivalTime', gtfs_validation_time_text(arrival_time),
  'departureTime', gtfs_validation_time_text(departure_time),
  'startPickupDropOffWindow', gtfs_validation_time_text(start_pickup_drop_off_window),
  'endPickupDropOffWindow', gtfs_validation_time_text(end_pickup_drop_off_window))) AS notice
FROM st WHERE arrival_time IS NOT NULL OR departure_time IS NOT NULL
UNION ALL
SELECT 'missing_pickup_or_drop_off_window', gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number,
  'startPickupDropOffWindow', gtfs_validation_time_text(start_pickup_drop_off_window),
  'endPickupDropOffWindow', gtfs_validation_time_text(end_pickup_drop_off_window)))
FROM st WHERE start_pickup_drop_off_window IS NULL OR end_pickup_drop_off_window IS NULL
UNION ALL
SELECT 'invalid_pickup_drop_off_window', gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number,
  'startPickupDropOffWindow', gtfs_validation_time_text(start_pickup_drop_off_window),
  'endPickupDropOffWindow', gtfs_validation_time_text(end_pickup_drop_off_window)))
FROM st WHERE start_pickup_drop_off_window >= end_pickup_drop_off_window;

-- PickupDropOffTypeValidator: forbidden_pickup_type, forbidden_drop_off_type. The notice uses the getters, so an
-- absent window is written as 00:00:00.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_pickup_drop_off_type() AS TABLE
WITH st AS (
  SELECT * FROM gtfs_v_stop_times x
  WHERE (gtfs_validation_has_column('stop_times.txt', 'start_pickup_drop_off_window')
         OR gtfs_validation_has_column('stop_times.txt', 'end_pickup_drop_off_window'))
    AND (x.start_pickup_drop_off_window IS NOT NULL OR x.end_pickup_drop_off_window IS NOT NULL)
)
SELECT 'forbidden_pickup_type' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number,
  'startPickupDropOffWindow', gtfs_validation_time_text(coalesce(start_pickup_drop_off_window, 0)),
  'endPickupDropOffWindow', gtfs_validation_time_text(coalesce(end_pickup_drop_off_window, 0)))) AS notice
FROM st WHERE coalesce(pickup_type, 0) IN (0, 3)
UNION ALL
SELECT 'forbidden_drop_off_type', gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number,
  'startPickupDropOffWindow', gtfs_validation_time_text(coalesce(start_pickup_drop_off_window, 0)),
  'endPickupDropOffWindow', gtfs_validation_time_text(coalesce(end_pickup_drop_off_window, 0))))
FROM st WHERE coalesce(drop_off_type, 0) = 0;

-- StopTimesGeographyIdPresenceValidator: missing_required_field (stop_id), forbidden_geography_id.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_geography_id() AS TABLE
WITH st AS (
  SELECT x.*, (x.stop_id IS NOT NULL)::INTEGER + (x.location_group_id IS NOT NULL)::INTEGER
              + (x.location_id IS NOT NULL)::INTEGER AS presence
  FROM gtfs_v_stop_times x
  WHERE gtfs_validation_has_column('stop_times.txt', 'stop_id')
     OR gtfs_validation_has_column('stop_times.txt', 'location_group_id')
     OR gtfs_validation_has_column('stop_times.txt', 'location_id')
)
SELECT 'missing_required_field' AS code, gtfs_validation_notice(json_object(
  'filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id')) AS notice
FROM st WHERE presence = 0
UNION ALL
SELECT 'forbidden_geography_id', gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number, 'stopId', stop_id, 'locationGroupId', location_group_id,
  'locationId', location_id))
FROM st WHERE presence > 1;

-- StopTimesShapeDistTraveledPresenceValidator: forbidden_shape_dist_traveled. Getters: absent ids are ''.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_shape_dist_presence() AS TABLE
SELECT 'forbidden_shape_dist_traveled' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', x.csv_row_number, 'tripId', coalesce(x.trip_id, ''),
  'locationGroupId', coalesce(x.location_group_id, ''), 'locationId', coalesce(x.location_id, ''),
  'shapeDistTraveled', x.shape_dist_traveled)) AS notice
FROM gtfs_v_stop_times x
WHERE gtfs_validation_has_column('stop_times.txt', 'shape_dist_traveled')
  AND (gtfs_validation_has_column('stop_times.txt', 'location_id')
       OR gtfs_validation_has_column('stop_times.txt', 'location_group_id'))
  AND x.stop_id IS NULL
  AND (x.location_group_id IS NOT NULL OR x.location_id IS NOT NULL)
  AND x.shape_dist_traveled IS NOT NULL;

-- ---------------------------------------------------------------------------- file validators over stop_times.txt

-- StopTimeIncreasingDistanceValidator: decreasing_or_equal_stop_time_distance. Stop times without stop_id are skipped;
-- the previous stop time is the previous one with a stop_id, whether or not it has shape_dist_traveled.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_increasing_distance() AS TABLE
SELECT 'decreasing_or_equal_stop_time_distance' AS code, gtfs_validation_notice(json_object(
  'tripId', trip_id, 'stopId', stop_id, 'csvRowNumber', csv_row_number,
  'shapeDistTraveled', shape_dist_traveled, 'stopSequence', stop_sequence,
  'prevCsvRowNumber', prev_row, 'prevShapeDistTraveled', prev_dist, 'prevStopSequence', prev_sequence)) AS notice
FROM (
  SELECT o.*,
    lag(o.csv_row_number) OVER w AS prev_row,
    lag(o.shape_dist_traveled) OVER w AS prev_dist,
    lag(o.stop_sequence) OVER w AS prev_sequence
  FROM gtfs_vr_stoptimes_ordered() o
  WHERE o.stop_id IS NOT NULL
    AND gtfs_validation_parsed(['stop_times.txt'])
    AND gtfs_validation_has_column('stop_times.txt', 'stop_id')
    AND gtfs_validation_has_column('stop_times.txt', 'shape_dist_traveled')
  WINDOW w AS (PARTITION BY o.trip_id ORDER BY o.idx)
)
WHERE prev_dist >= shape_dist_traveled;

-- StopTimesRecordValidator: missing_stop_times_record. Getters: absent ids are ''.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_record() AS TABLE
SELECT 'missing_stop_times_record' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', o.csv_row_number, 'tripId', coalesce(o.trip_id, ''),
  'locationGroupId', coalesce(o.location_group_id, ''), 'locationId', coalesce(o.location_id, ''))) AS notice
FROM gtfs_vr_stoptimes_ordered() o
WHERE gtfs_validation_parsed(['stop_times.txt'])
  AND gtfs_validation_has_column('stop_times.txt', 'start_pickup_drop_off_window')
  AND gtfs_validation_has_column('stop_times.txt', 'end_pickup_drop_off_window')
  AND gtfs_validation_has_column('stop_times.txt', 'pickup_type')
  AND gtfs_validation_has_column('stop_times.txt', 'drop_off_type')
  AND o.start_pickup_drop_off_window IS NOT NULL AND o.end_pickup_drop_off_window IS NOT NULL
  AND o.pickup_type = 2 AND o.drop_off_type = 2
  AND o.trip_size = 1;

-- TimepointTimeValidator: missing_timepoint_value, stop_time_timepoint_without_times.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_timepoint() AS TABLE
WITH st AS (
  SELECT * FROM gtfs_v_stop_times x
  WHERE gtfs_validation_parsed(['stop_times.txt']) AND gtfs_validation_has_column('stop_times.txt', 'timepoint')
)
SELECT 'missing_timepoint_value' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number, 'tripId', trip_id, 'stopSequence', stop_sequence)) AS notice
FROM st WHERE (arrival_time IS NOT NULL OR departure_time IS NOT NULL) AND timepoint IS NULL
UNION ALL
SELECT 'stop_time_timepoint_without_times', gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number, 'tripId', trip_id, 'stopSequence', stop_sequence, 'specifiedField', f.field))
FROM st, (VALUES ('arrival_time'), ('departure_time')) f(field)
WHERE timepoint = 1
  AND ((f.field = 'arrival_time' AND arrival_time IS NULL) OR (f.field = 'departure_time' AND departure_time IS NULL));

-- MissingTripEdgeValidator: missing_trip_edge on the first and on the last stop time of each trip (both when the trip
-- has a single stop time).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_trip_edge() AS TABLE
WITH edge AS (
  SELECT o.* FROM gtfs_vr_stoptimes_ordered() o WHERE o.idx = 0
  UNION ALL
  SELECT o.* FROM gtfs_vr_stoptimes_ordered() o WHERE o.idx = o.trip_size - 1
)
SELECT 'missing_trip_edge' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', e.csv_row_number, 'stopSequence', e.stop_sequence, 'tripId', e.trip_id,
  'specifiedField', f.field)) AS notice
FROM edge e, (VALUES ('arrival_time'), ('departure_time')) f(field)
WHERE gtfs_validation_parsed(['stop_times.txt'])
  AND e.start_pickup_drop_off_window IS NULL AND e.end_pickup_drop_off_window IS NULL
  AND ((f.field = 'arrival_time' AND e.arrival_time IS NULL)
       OR (f.field = 'departure_time' AND e.departure_time IS NULL));

-- StopTimeArrivalAndDepartureTimeValidator: stop_time_with_only_arrival_or_departure_time,
-- stop_time_with_arrival_before_previous_departure_time (against the last earlier stop time with a departure).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_arrival_departure() AS TABLE
WITH st AS (
  SELECT o.*,
    last_value(o.departure_time IGNORE NULLS) OVER w AS prev_departure,
    last_value(CASE WHEN o.departure_time IS NOT NULL THEN o.csv_row_number END IGNORE NULLS) OVER w AS prev_row
  FROM gtfs_vr_stoptimes_ordered() o
  WHERE gtfs_validation_parsed(['stop_times.txt'])
  WINDOW w AS (PARTITION BY o.trip_id ORDER BY o.idx ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
)
SELECT 'stop_time_with_only_arrival_or_departure_time' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number, 'tripId', trip_id, 'stopSequence', stop_sequence,
  'specifiedField', CASE WHEN arrival_time IS NOT NULL THEN 'arrival_time' ELSE 'departure_time' END)) AS notice
FROM st WHERE (arrival_time IS NULL) <> (departure_time IS NULL)
UNION ALL
SELECT 'stop_time_with_arrival_before_previous_departure_time', gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number, 'prevCsvRowNumber', prev_row, 'tripId', trip_id,
  'arrivalTime', gtfs_validation_time_text(arrival_time),
  'departureTime', gtfs_validation_time_text(prev_departure)))
FROM st WHERE arrival_time < prev_departure;

-- TooManyConsecutiveStopTimesWithSameTimeValidator: too_many_consecutive_stop_times_with_same_time.
-- A fully timed stop time either continues the current run (its arrival equals the previous fully timed departure and
-- its own departure) or starts a new run. Stop times without both times only count when a later fully timed stop time
-- continues the run. A run is reported when it counts more than 5 stop times.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_same_time() AS TABLE
WITH full_prev AS (
  SELECT o.trip_id, o.idx, o.arrival_time, o.departure_time,
    lag(o.departure_time) OVER (PARTITION BY o.trip_id ORDER BY o.idx) AS prev_departure
  FROM gtfs_vr_stoptimes_ordered() o
  WHERE gtfs_validation_parsed(['stop_times.txt']) AND o.arrival_time IS NOT NULL AND o.departure_time IS NOT NULL
),
runs AS (
  SELECT f.*,
    sum((NOT coalesce(f.prev_departure = f.arrival_time AND f.arrival_time = f.departure_time, false))::INTEGER)
      OVER (PARTITION BY f.trip_id ORDER BY f.idx) AS run
  FROM full_prev f
)
SELECT 'too_many_consecutive_stop_times_with_same_time' AS code, gtfs_validation_notice(json_object(
  'tripId', trip_id, 'entityCount', entity_count, 'time', gtfs_validation_time_text(run_time))) AS notice
FROM (
  SELECT trip_id, run,
    (max(idx) - min(idx) + 1)::INTEGER AS entity_count,
    arg_min(departure_time, idx) AS run_time
  FROM runs GROUP BY trip_id, run
)
WHERE entity_count > 5;

-- StopTimesTripBlockOrderValidator: unsorted_stop_times. Uses the file order of the entities.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_block_order() AS TABLE
SELECT 'unsorted_stop_times' AS code, gtfs_validation_notice(json_object(
  'tripId', trip_id, 'startCsvRowNumber', min_row, 'endCsvRowNumber', max_row)) AS notice
FROM (
  SELECT trip_id, count(*) AS row_count, min(csv_row_number) AS min_row, max(csv_row_number) AS max_row,
    coalesce(bool_or(coalesce(stop_sequence, 0) <= prev_sequence), false) AS unsorted
  FROM (
    SELECT x.trip_id, x.csv_row_number, x.stop_sequence,
      lag(coalesce(x.stop_sequence, 0)) OVER (PARTITION BY x.trip_id ORDER BY x.csv_row_number) AS prev_sequence
    FROM gtfs_v_stop_times x
    WHERE gtfs_validation_parsed(['stop_times.txt']) AND x.trip_id IS NOT NULL
  )
  GROUP BY trip_id
)
WHERE max_row - min_row + 1 > row_count OR unsorted;

-- ----------------------------------------------------------------------- file validators over trips.txt and more

-- TripUsabilityValidator (unusable_trip) and TripUsageValidator (unused_trip, once per trip_id).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_trip_usage() AS TABLE
WITH t AS (
  SELECT x.trip_id, x.csv_row_number,
    row_number() OVER (PARTITION BY x.trip_id ORDER BY x.csv_row_number) AS occurrence,
    coalesce(c.stop_time_count, 0) AS stop_time_count
  FROM gtfs_v_trips x
  LEFT JOIN (SELECT s.trip_id, count(*) AS stop_time_count FROM gtfs_v_stop_times s GROUP BY s.trip_id) c
    ON c.trip_id = x.trip_id
  WHERE gtfs_validation_parsed(['trips.txt', 'stop_times.txt'])
)
SELECT 'unusable_trip' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', csv_row_number, 'tripId', trip_id)) AS notice
FROM t WHERE stop_time_count <= 1
UNION ALL
SELECT 'unused_trip', gtfs_validation_notice(json_object('tripId', trip_id, 'csvRowNumber', csv_row_number))
FROM t WHERE stop_time_count = 0 AND occurrence = 1;

-- DuplicateTripsValidator: duplicate_trips. Trips (file order) whose stop times all have a stop_id are compared on
-- service_id and the ordered (stop_id, arrival, departure) list, an absent time counting as -1. Each trip is reported
-- against the first trip of its class.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_duplicate_trips() AS TABLE
WITH st AS (
  SELECT o.trip_id,
    list(struct_pack(s := o.stop_id, a := coalesce(o.arrival_time, -1), d := coalesce(o.departure_time, -1))
         ORDER BY o.idx) AS stop_key,
    bool_and(o.stop_id IS NOT NULL) AS all_stops,
    arg_min(o.csv_row_number, o.idx) AS first_row
  FROM gtfs_vr_stoptimes_ordered() o
  WHERE gtfs_validation_parsed(['trips.txt', 'stop_times.txt'])
  GROUP BY o.trip_id
),
t AS (
  SELECT x.trip_id, x.csv_row_number, st.first_row,
    first_value(x.trip_id) OVER w AS first_trip_id,
    first_value(st.first_row) OVER w AS first_trip_row,
    row_number() OVER w AS rank_in_class
  FROM gtfs_v_trips x JOIN st ON st.trip_id = x.trip_id
  WHERE st.all_stops
  WINDOW w AS (PARTITION BY x.service_id, st.stop_key ORDER BY x.csv_row_number)
)
SELECT 'duplicate_trips' AS code, gtfs_validation_notice(json_object(
  'tripId1', first_trip_id, 'tripId2', trip_id,
  'csvRowNumberTripId1FirstStopTime', first_trip_row, 'csvRowNumberTripId2FirstStopTime', first_row)) AS notice
FROM t WHERE rank_in_class > 1;

-- ContinuousPickupDropOffValidator: forbidden_continuous_pickup_drop_off. Note the Java operator precedence in
-- shouldCallValidate: continuous_pickup || (continuous_drop_off && (start window || end window)).
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_continuous_pickup_drop_off() AS TABLE
SELECT 'forbidden_continuous_pickup_drop_off' AS code, gtfs_validation_notice(json_object(
  'routeCsvRowNumber', r.csv_row_number, 'tripId', t.trip_id, 'stopTimeCsvRowNumber', s.csv_row_number,
  'startPickupDropOffWindow', gtfs_validation_time_text(coalesce(s.start_pickup_drop_off_window, 0)),
  'endPickupDropOffWindow', gtfs_validation_time_text(coalesce(s.end_pickup_drop_off_window, 0)))) AS notice
FROM gtfs_v_routes r
JOIN gtfs_v_trips t ON t.route_id = r.route_id
JOIN gtfs_v_stop_times s ON s.trip_id = t.trip_id
WHERE gtfs_validation_parsed(['routes.txt', 'trips.txt', 'stop_times.txt'])
  AND (gtfs_validation_has_column('routes.txt', 'continuous_pickup')
       OR (gtfs_validation_has_column('routes.txt', 'continuous_drop_off')
           AND (gtfs_validation_has_column('stop_times.txt', 'start_pickup_drop_off_window')
                OR gtfs_validation_has_column('stop_times.txt', 'end_pickup_drop_off_window'))))
  AND (gtfs_vr_stoptimes_is_continuous(coalesce(r.continuous_pickup, 1))
       OR gtfs_vr_stoptimes_is_continuous(coalesce(r.continuous_drop_off, 1)))
  AND (s.start_pickup_drop_off_window IS NOT NULL OR s.end_pickup_drop_off_window IS NOT NULL);

-- TripShapeIdConditionalValidator: missing_required_field (trips.txt shape_id) for a trip without shape_id whose
-- stop times (or route, when the trip has none) have continuous pickup or drop-off.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_trip_shape_id() AS TABLE
WITH t AS (
  SELECT x.trip_id, x.csv_row_number,
    CASE WHEN r.route_id IS NULL THEN 1 ELSE coalesce(r.continuous_pickup, 1) END AS route_pickup,
    CASE WHEN r.route_id IS NULL THEN 1 ELSE coalesce(r.continuous_drop_off, 1) END AS route_drop_off
  FROM gtfs_v_trips x
  LEFT JOIN gtfs_vr_stoptimes_route_by_id() r ON r.route_id = x.route_id
  WHERE x.shape_id IS NULL
    AND gtfs_validation_parsed(['routes.txt', 'trips.txt', 'stop_times.txt'])
    AND (gtfs_validation_has_column('routes.txt', 'continuous_pickup')
         OR gtfs_validation_has_column('routes.txt', 'continuous_drop_off')
         OR gtfs_validation_has_column('stop_times.txt', 'continuous_pickup')
         OR gtfs_validation_has_column('stop_times.txt', 'continuous_drop_off'))
),
behavior AS (
  SELECT t.trip_id, t.csv_row_number,
    CASE WHEN count(s.csv_row_number) = 0
      THEN gtfs_vr_stoptimes_is_continuous(any_value(t.route_pickup))
           OR gtfs_vr_stoptimes_is_continuous(any_value(t.route_drop_off))
      ELSE bool_or(gtfs_vr_stoptimes_is_continuous(coalesce(s.continuous_pickup, t.route_pickup))
                   OR gtfs_vr_stoptimes_is_continuous(coalesce(s.continuous_drop_off, t.route_drop_off)))
    END AS continuous
  FROM t LEFT JOIN gtfs_v_stop_times s ON s.trip_id = t.trip_id
  GROUP BY t.trip_id, t.csv_row_number
)
SELECT 'missing_required_field' AS code, gtfs_validation_notice(json_object(
  'filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id')) AS notice
FROM behavior WHERE continuous;

-- BikesAllowanceValidator: missing_bike_allowance for every trip of every ferry route (route_type 4) whose
-- bikes_allowed is absent, 0 or unrecognized.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_bikes_allowance() AS TABLE
SELECT 'missing_bike_allowance' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', t.csv_row_number, 'routeId', t.route_id, 'tripId', t.trip_id)) AS notice
FROM gtfs_v_routes r JOIN gtfs_v_trips t ON t.route_id = r.route_id
WHERE gtfs_validation_parsed(['trips.txt', 'routes.txt'])
  AND r.route_type = 4
  AND coalesce(t.bikes_allowed, 0) NOT IN (1, 2);

-- InconsistentRouteTypeForBlockIdValidator: inconsistent_route_type_for_block_id. Route types (enum names, distinct,
-- in trip file order) of the trips' routes that exist; route ids distinct in trip file order.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_block_route_type() AS TABLE
WITH t AS (
  SELECT x.block_id, x.csv_row_number, coalesce(x.route_id, '') AS route_id,
    CASE WHEN r.route_id IS NOT NULL
      THEN coalesce(gtfs_validation_enum_name('GtfsRouteType', coalesce(r.route_type, 0)), 'UNRECOGNIZED') END
      AS route_type_name
  FROM gtfs_v_trips x
  LEFT JOIN gtfs_vr_stoptimes_route_by_id() r ON r.route_id = x.route_id
  WHERE gtfs_validation_parsed(['trips.txt', 'routes.txt'])
    AND gtfs_validation_has_column('trips.txt', 'block_id')
    AND x.block_id IS NOT NULL AND x.block_id <> ''
),
types AS (
  SELECT block_id, count(*) AS type_count,
    string_agg(route_type_name, ', ' ORDER BY first_row) AS route_types
  FROM (SELECT block_id, route_type_name, min(csv_row_number) AS first_row FROM t
        WHERE route_type_name IS NOT NULL GROUP BY block_id, route_type_name)
  GROUP BY block_id
),
ids AS (
  SELECT block_id, string_agg(route_id, ', ' ORDER BY first_row) AS route_ids
  FROM (SELECT block_id, route_id, min(csv_row_number) AS first_row FROM t GROUP BY block_id, route_id)
  GROUP BY block_id
)
SELECT 'inconsistent_route_type_for_block_id' AS code, gtfs_validation_notice(json_object(
  'blockId', types.block_id, 'routeIds', ids.route_ids, 'routeTypes', types.route_types)) AS notice
FROM types JOIN ids USING (block_id)
WHERE types.type_count > 1;

-- TripHeadsignValidator: trip_headsign_matches_intermediate_stop. Every stop time but the last one whose stop name
-- equals the headsign ignoring case; circular trips (first stop_id = last stop_id) are skipped.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_trip_headsign() AS TABLE
WITH o AS (
  SELECT o.*,
    first_value(o.stop_id) OVER w AS first_stop_id,
    last_value(o.stop_id) OVER w AS last_stop_id
  FROM gtfs_vr_stoptimes_ordered() o
  WHERE gtfs_validation_parsed(['trips.txt', 'stop_times.txt', 'stops.txt'])
  WINDOW w AS (PARTITION BY o.trip_id ORDER BY o.idx ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
s AS (
  SELECT x.stop_id, x.stop_name FROM gtfs_v_stops x WHERE x.stop_id IS NOT NULL
  QUALIFY row_number() OVER (PARTITION BY x.stop_id ORDER BY x.csv_row_number) = 1
)
SELECT 'trip_headsign_matches_intermediate_stop' AS code, gtfs_validation_notice(json_object(
  'csvRowNumber', t.csv_row_number, 'tripId', t.trip_id, 'tripHeadsign', t.trip_headsign,
  'stopId1', coalesce(o.stop_id, ''), 'stopSequence', o.stop_sequence, 'stopId2', coalesce(o.last_stop_id, ''))) AS notice
FROM gtfs_v_trips t
JOIN o ON o.trip_id = t.trip_id
JOIN s ON s.stop_id = o.stop_id
WHERE t.trip_headsign IS NOT NULL
  AND o.trip_size >= 2
  AND o.idx < o.trip_size - 1
  AND o.first_stop_id IS DISTINCT FROM o.last_stop_id
  AND s.stop_name IS NOT NULL
  AND gtfs_validation_equals_ignore_case(s.stop_name, t.trip_headsign);

-- StopTimeTravelSpeedValidator: fast_travel_between_consecutive_stops, fast_travel_between_far_stops.
-- Trips are grouped by (route_id, ordered stop_id/arrival/departure list, absent times as 0). Each group is validated
-- on its first trip in the iteration order of byTripIdAsMap(): a java.util.HashMap over the stop_times trip_id
-- dictionary (Maps.newHashMapWithExpectedSize(12): 16 buckets, doubled while size > 0.75 * buckets; insertion = first
-- file appearance; a bucket iterates in insertion order). Consecutive notices
-- carry that first trip's stop times for every trip of the group; far-stop notices carry each trip's own stop times.
CREATE OR REPLACE MACRO gtfs_vr_stoptimes_travel_speed() AS TABLE
WITH st AS MATERIALIZED (
  SELECT o.trip_id, o.idx, o.csv_row_number, o.stop_sequence, o.stop_id, o.arrival_time, o.departure_time
  FROM gtfs_vr_stoptimes_ordered() o
  WHERE gtfs_validation_parsed(['routes.txt', 'trips.txt', 'stop_times.txt', 'stops.txt'])
),
dict AS (
  SELECT st.trip_id, min(st.csv_row_number) AS first_row,
    list(struct_pack(s := coalesce(st.stop_id, ''), a := coalesce(st.arrival_time, 0),
                     d := coalesce(st.departure_time, 0)) ORDER BY st.idx) AS stop_key
  FROM st GROUP BY st.trip_id
),
capacity AS (
  SELECT min(1::BIGINT << r.i) AS buckets FROM range(4, 40) r(i)
  WHERE (SELECT count(*) FROM dict) * 4 <= (1::BIGINT << r.i) * 3
),
member AS (
  SELECT d.trip_id, t.csv_row_number AS trip_row, t.route_id,
    first_value(d.trip_id) OVER (
      PARTITION BY coalesce(t.route_id, ''), d.stop_key
      ORDER BY gtfs_vr_stoptimes_java_bucket(d.trip_id, capacity.buckets), d.first_row) AS lead_trip_id
  FROM dict d
  JOIN gtfs_vr_stoptimes_trip_by_id() t ON t.trip_id = d.trip_id
  CROSS JOIN capacity
),
lead_trip AS (
  SELECT m.trip_id, gtfs_vr_stoptimes_max_speed_kph(r.route_type) AS max_kph
  FROM member m JOIN gtfs_vr_stoptimes_route_by_id() r ON r.route_id = m.route_id
  WHERE m.trip_id = m.lead_trip_id
),
ls AS MATERIALIZED (
  SELECT st.*, lt.max_kph, p.stop_id IS NOT NULL AS stop_found, p.stop_name, p.lat, p.lon
  FROM st JOIN lead_trip lt ON lt.trip_id = st.trip_id
  LEFT JOIN gtfs_vr_stoptimes_stop_latlng() p ON p.stop_id = st.stop_id
),
-- validateConsecutiveStops: the start stop time only moves to an end stop time whose distance and times are known;
-- nothing happens when the first stop time lacks a location or a departure, and the start sticks to the first
-- accepted end without a departure.
accepted AS (
  SELECT c.*,
    coalesce(sum((c.idx > 0 AND c.departure_time IS NULL)::INTEGER) OVER (
      PARTITION BY c.trip_id ORDER BY c.idx ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS stuck_before
  FROM (
    SELECT ls.*, first_value(ls.lat IS NOT NULL AND ls.departure_time IS NOT NULL) OVER (
      PARTITION BY ls.trip_id ORDER BY ls.idx) AS start_ok
    FROM ls
  ) c
  WHERE c.start_ok AND (c.idx = 0 OR (c.lat IS NOT NULL AND c.arrival_time IS NOT NULL))
),
consecutive AS (
  SELECT q.*,
    q.distance_km * 3600 / gtfs_vr_stoptimes_seconds_between(q.arrival_time, q.departure1) AS speed_kph
  FROM (
    SELECT a.*,
      lag(a.csv_row_number) OVER w AS row1, lag(a.stop_sequence) OVER w AS sequence1, lag(a.stop_id) OVER w AS stop1,
      lag(a.stop_name) OVER w AS name1, lag(a.departure_time) OVER w AS departure1,
      gtfs_validation_distance_m(lag(a.lat) OVER w, lag(a.lon) OVER w, a.lat, a.lon) / 1000 AS distance_km
    FROM accepted a
    WHERE a.stuck_before = 0
    WINDOW w AS (PARTITION BY a.trip_id ORDER BY a.idx)
  ) q
  WHERE q.idx > 0
),
-- validateFarStops: distancesKm[i] is the distance from the last located stop (the first stop counting as located,
-- at (0, 0) when it has no location) to stop i + 1, 0 when stop i + 1 has no location. cum is its prefix sum.
seg AS (
  SELECT g.*,
    sum(CASE WHEN g.idx > 0 AND g.clat IS NOT NULL
             THEN gtfs_validation_distance_m(g.plat, g.plon, g.clat, g.clon) / 1000 ELSE 0 END)
      OVER (PARTITION BY g.trip_id ORDER BY g.idx ROWS UNBOUNDED PRECEDING) AS cum
  FROM (
    SELECT c.*,
      last_value(c.clat IGNORE NULLS) OVER wp AS plat,
      last_value(c.clon IGNORE NULLS) OVER wp AS plon
    FROM (
      SELECT ls.*,
        CASE WHEN ls.idx = 0 THEN coalesce(ls.lat, 0.0) ELSE ls.lat END AS clat,
        CASE WHEN ls.idx = 0 THEN coalesce(ls.lon, 0.0) ELSE ls.lon END AS clon
      FROM ls
    ) c
    WINDOW wp AS (PARTITION BY c.trip_id ORDER BY c.idx ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
  ) g
),
-- The scan stops at the first event in (end ascending, start descending) order: an end stop time with an arrival
-- whose stop is missing, a fast pair whose start stop is missing, or a fast pair more than 10 km apart (reported).
far_event AS (
  SELECT e.trip_id, e.idx AS end_idx, e.idx AS start_idx, false AS report, NULL::DOUBLE AS speed_kph,
    NULL::DOUBLE AS distance_km
  FROM seg e WHERE e.arrival_time IS NOT NULL AND NOT e.stop_found
  UNION ALL
  SELECT p.trip_id, p.end_idx, p.start_idx, p.start_found, p.speed_kph, p.distance_km
  FROM (
    SELECT e.trip_id, e.idx AS end_idx, s.idx AS start_idx, s.stop_found AS start_found, e.cum - s.cum AS distance_km,
      (e.cum - s.cum) * 3600 / gtfs_vr_stoptimes_seconds_between(e.arrival_time, s.departure_time) AS speed_kph,
      e.max_kph
    FROM seg e JOIN seg s
      ON s.trip_id = e.trip_id AND s.idx < e.idx AND (NOT s.stop_found OR e.cum - s.cum > 10.0)
    WHERE e.arrival_time IS NOT NULL AND s.departure_time IS NOT NULL
  ) p
  WHERE p.speed_kph > p.max_kph
),
far AS (
  SELECT * FROM far_event
  QUALIFY row_number() OVER (PARTITION BY trip_id ORDER BY end_idx, start_idx DESC) = 1
)
SELECT 'fast_travel_between_consecutive_stops' AS code, gtfs_validation_notice(json_object(
  'tripCsvRowNumber', m.trip_row, 'tripId', m.trip_id, 'routeId', coalesce(m.route_id, ''),
  'speedKph', c.speed_kph, 'distanceKm', c.distance_km,
  'csvRowNumber1', c.row1, 'stopSequence1', c.sequence1, 'stopId1', c.stop1, 'stopName1', coalesce(c.name1, ''),
  'departureTime1', gtfs_validation_time_text(c.departure1),
  'csvRowNumber2', c.csv_row_number, 'stopSequence2', c.stop_sequence, 'stopId2', c.stop_id,
  'stopName2', coalesce(c.stop_name, ''), 'arrivalTime2', gtfs_validation_time_text(c.arrival_time))) AS notice
FROM consecutive c JOIN member m ON m.lead_trip_id = c.trip_id
WHERE c.speed_kph > c.max_kph
UNION ALL
SELECT 'fast_travel_between_far_stops', gtfs_validation_notice(json_object(
  'tripCsvRowNumber', m.trip_row, 'tripId', m.trip_id, 'routeId', coalesce(m.route_id, ''),
  'speedKph', f.speed_kph, 'distanceKm', f.distance_km,
  'csvRowNumber1', s1.csv_row_number, 'stopSequence1', s1.stop_sequence, 'stopId1', s1.stop_id,
  'stopName1', coalesce(n1.stop_name, ''), 'departureTime1', gtfs_validation_time_text(coalesce(s1.departure_time, 0)),
  'csvRowNumber2', s2.csv_row_number, 'stopSequence2', s2.stop_sequence, 'stopId2', s2.stop_id,
  'stopName2', coalesce(n2.stop_name, ''), 'arrivalTime2', gtfs_validation_time_text(coalesce(s2.arrival_time, 0))))
FROM far f
JOIN member m ON m.lead_trip_id = f.trip_id
JOIN st s1 ON s1.trip_id = m.trip_id AND s1.idx = f.start_idx
JOIN st s2 ON s2.trip_id = m.trip_id AND s2.idx = f.end_idx
JOIN ls n1 ON n1.trip_id = f.trip_id AND n1.idx = f.start_idx
JOIN ls n2 ON n2.trip_id = f.trip_id AND n2.idx = f.end_idx
WHERE f.report;

-- ------------------------------------------------------------------------------------------------------ entry point

CREATE OR REPLACE MACRO gtfs_validate_rules_stop_times() AS TABLE
SELECT code, notice FROM gtfs_vr_stoptimes_pickup_drop_off_window()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_pickup_drop_off_type()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_geography_id()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_shape_dist_presence()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_increasing_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_record()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_timepoint()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_trip_edge()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_arrival_departure()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_same_time()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_block_order()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_trip_usage()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_duplicate_trips()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_continuous_pickup_drop_off()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_trip_shape_id()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_bikes_allowance()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_block_route_type()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_trip_headsign()
UNION ALL SELECT code, notice FROM gtfs_vr_stoptimes_travel_speed();
