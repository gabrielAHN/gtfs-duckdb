-- Validation rules for shapes.txt (shapes workstream).
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*; the entry point
-- gtfs_validate_rules_shapes() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.

-- MissingShapesFileValidator. Injects GtfsFeedContainer, so it runs only when every file is parsed. Fires when
-- shapes.txt is missing or has no entity, unless the feed has zone-based DRT (a stop time with trip_id and location_id
-- but no stop_id). Fixed-stops DRT needs location_groups.txt, which this port does not read (treated as absent).
CREATE OR REPLACE MACRO gtfs_vr_shapes_missing_file() AS TABLE
SELECT 'missing_recommended_file' AS code, gtfs_validation_notice(json_object('filename', 'shapes.txt')) AS notice
WHERE gtfs_validation_parsed(['stops.txt', 'pathways.txt', 'routes.txt', 'trips.txt', 'stop_times.txt', 'shapes.txt',
                              'calendar.txt', 'calendar_dates.txt'])
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_shapes)
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_stop_times st
                  WHERE st.trip_id IS NOT NULL AND st.location_id IS NOT NULL AND st.stop_id IS NULL);

-- Shape points as GtfsShapeTableContainer.byShapeId() returns them: sorted by shape_pt_sequence.
CREATE OR REPLACE MACRO gtfs_vr_shapes_points() AS TABLE
SELECT s.csv_row_number, s.shape_id, s.shape_pt_sequence, s.shape_dist_traveled,
       coalesce(s.shape_pt_lat, 0) AS lat, coalesce(s.shape_pt_lon, 0) AS lon,
       coalesce(s.shape_dist_traveled, 0) AS dist,
       row_number() OVER (PARTITION BY s.shape_id ORDER BY s.shape_pt_sequence, s.csv_row_number) AS pt_index
FROM gtfs_v_shapes s;

-- ShapeIncreasingDistanceValidator: consecutive points (by shape_pt_sequence) that both have shape_dist_traveled.
-- DecreasingShapeDistanceNotice is constructed as (current, previous) but called with (prev, curr): the notice's
-- csvRowNumber/shapeDistTraveled/shapePtSequence are the previous point's and its prev* fields the current point's.
CREATE OR REPLACE MACRO gtfs_vr_shapes_increasing_distance() AS TABLE
WITH pairs AS (
  SELECT p.*, lag(p.csv_row_number) OVER w AS prev_row, lag(p.shape_dist_traveled) OVER w AS prev_dist,
         lag(p.shape_pt_sequence) OVER w AS prev_seq, lag(p.lat) OVER w AS prev_lat, lag(p.lon) OVER w AS prev_lon
  FROM gtfs_vr_shapes_points() p
  WINDOW w AS (PARTITION BY p.shape_id ORDER BY p.pt_index)
), checked AS (
  SELECT *, gtfs_validation_distance_m(lat, lon, prev_lat, prev_lon) AS gap_m
  FROM pairs
  WHERE prev_row IS NOT NULL AND prev_dist IS NOT NULL AND shape_dist_traveled IS NOT NULL
    AND prev_dist >= shape_dist_traveled
)
SELECT CASE
         WHEN prev_dist > shape_dist_traveled THEN 'decreasing_shape_distance'
         WHEN lon = prev_lon AND lat = prev_lat THEN 'equal_shape_distance_same_coordinates'
         WHEN gap_m >= 1.11 THEN 'equal_shape_distance_diff_coordinates'
         ELSE 'equal_shape_distance_diff_coordinates_distance_below_threshold' END AS code,
       CASE WHEN prev_dist > shape_dist_traveled THEN gtfs_validation_notice(json_object(
              'shapeId', shape_id, 'csvRowNumber', prev_row, 'shapeDistTraveled', prev_dist,
              'shapePtSequence', prev_seq, 'prevCsvRowNumber', csv_row_number,
              'prevShapeDistTraveled', shape_dist_traveled, 'prevShapePtSequence', shape_pt_sequence))
            ELSE gtfs_validation_notice(json_object(
              'shapeId', shape_id, 'csvRowNumber', csv_row_number, 'shapeDistTraveled', shape_dist_traveled,
              'shapePtSequence', shape_pt_sequence, 'prevCsvRowNumber', prev_row,
              'prevShapeDistTraveled', prev_dist, 'prevShapePtSequence', prev_seq,
              'actualDistanceBetweenShapePoints',
              CASE WHEN NOT (lon = prev_lon AND lat = prev_lat) THEN gap_m END)) END AS notice
FROM checked
WHERE gtfs_validation_parsed(['shapes.txt'])
  AND (prev_dist > shape_dist_traveled OR (lon = prev_lon AND lat = prev_lat) OR gap_m > 0);

-- SingleShapePointValidator
CREATE OR REPLACE MACRO gtfs_vr_shapes_single_point() AS TABLE
SELECT 'single_shape_point' AS code,
       gtfs_validation_notice(json_object('shapeId', shape_id, 'csvRowNumber', max(csv_row_number))) AS notice
FROM gtfs_v_shapes
WHERE gtfs_validation_parsed(['shapes.txt'])
GROUP BY shape_id
HAVING count(*) = 1;

-- ShapeUsageValidator: the first shapes.txt row of a shape_id no trip references.
CREATE OR REPLACE MACRO gtfs_vr_shapes_unused() AS TABLE
SELECT 'unused_shape' AS code,
       gtfs_validation_notice(json_object('shapeId', s.shape_id, 'csvRowNumber', min(s.csv_row_number))) AS notice
FROM gtfs_v_shapes s
WHERE gtfs_validation_parsed(['trips.txt', 'shapes.txt'])
  AND NOT EXISTS (SELECT 1 FROM gtfs_v_trips t WHERE coalesce(t.shape_id, '') = s.shape_id)
GROUP BY s.shape_id;

-- Stop times as GtfsStopTimeTableContainer.byTripId() returns them: sorted by stop_sequence.
CREATE OR REPLACE MACRO gtfs_vr_shapes_stop_times() AS TABLE
SELECT st.csv_row_number, st.trip_id, st.stop_id, st.stop_sequence, st.shape_dist_traveled,
       row_number() OVER (PARTITION BY st.trip_id ORDER BY st.stop_sequence, st.csv_row_number) AS st_index,
       count(*) OVER (PARTITION BY st.trip_id) AS st_count
FROM gtfs_v_stop_times st;

-- TripAndShapeDistanceValidator: the trip's last stop time (by stop_sequence) has a shape_dist_traveled greater than
-- the shape's largest one (first point with the maximum, by shape_pt_sequence). The distance is from that shape point
-- to the last stop's own coordinates.
CREATE OR REPLACE MACRO gtfs_vr_shapes_trip_distance() AS TABLE
WITH max_shape AS (
  SELECT shape_id, arg_min(lat, rk) AS lat, arg_min(lon, rk) AS lon, max(dist) AS dist
  FROM (SELECT p.*, row_number() OVER (PARTITION BY p.shape_id ORDER BY p.dist DESC, p.pt_index) AS rk
        FROM gtfs_vr_shapes_points() p)
  GROUP BY shape_id
), last_stop AS (
  SELECT trip_id, stop_id, coalesce(shape_dist_traveled, 0) AS dist
  FROM gtfs_vr_shapes_stop_times() WHERE st_index = st_count
), found AS (
  SELECT t.trip_id, coalesce(t.shape_id, '') AS shape_id, ls.dist AS trip_dist, ms.dist AS shape_dist,
         gtfs_validation_distance_m(ms.lat, ms.lon, coalesce(s.stop_lat, 0), coalesce(s.stop_lon, 0)) AS gap_m
  FROM gtfs_v_trips t
  JOIN last_stop ls ON ls.trip_id = coalesce(t.trip_id, '')
  JOIN (SELECT DISTINCT ON (stop_id) * FROM gtfs_v_stops ORDER BY stop_id, csv_row_number) s
    ON s.stop_id = coalesce(ls.stop_id, '')
  JOIN max_shape ms ON ms.shape_id = coalesce(t.shape_id, '')
  WHERE ms.dist <> 0 AND ls.dist > ms.dist
)
SELECT CASE WHEN gap_m > 11.1 THEN 'trip_distance_exceeds_shape_distance'
            ELSE 'trip_distance_exceeds_shape_distance_below_threshold' END AS code,
       gtfs_validation_notice(json_object('tripId', trip_id, 'shapeId', shape_id, 'maxTripDistanceTraveled', trip_dist,
         'maxShapeDistanceTraveled', shape_dist, 'geoDistanceToShape', gap_m)) AS notice
FROM found
WHERE gtfs_validation_parsed(['trips.txt', 'stop_times.txt', 'stops.txt', 'shapes.txt']);

-- TripWithShapeDistTraveledButNoShapeDistancesValidator: per trip_id of stop_times.txt, the first stop time (by
-- stop_sequence) with shape_dist_traveled; the trip has a shape_id whose points do not all have shape_dist_traveled.
CREATE OR REPLACE MACRO gtfs_vr_shapes_trip_dist_no_shape_dist() AS TABLE
WITH first_dist AS (
  SELECT trip_id, arg_min(csv_row_number, st_index) AS st_row
  FROM gtfs_vr_shapes_stop_times() WHERE shape_dist_traveled IS NOT NULL GROUP BY trip_id
), shape_missing AS (
  SELECT shape_id FROM gtfs_v_shapes GROUP BY shape_id HAVING count(*) > count(shape_dist_traveled)
), trip AS (
  SELECT DISTINCT ON (trip_id) * FROM gtfs_v_trips ORDER BY trip_id, csv_row_number
)
SELECT 'trip_with_shape_dist_traveled_but_no_shape_distances' AS code,
       gtfs_validation_notice(json_object('tripCsvRowNumber', t.csv_row_number, 'tripId', t.trip_id,
         'shapeId', t.shape_id, 'stopTimeCsvRowNumber', f.st_row)) AS notice
FROM first_dist f
JOIN trip t ON t.trip_id = f.trip_id
JOIN shape_missing m ON m.shape_id = t.shape_id
WHERE gtfs_validation_parsed(['trips.txt', 'stop_times.txt', 'shapes.txt'])
  AND gtfs_validation_has_column('stop_times.txt', 'shape_dist_traveled')
  AND t.shape_id <> '';

CREATE OR REPLACE MACRO gtfs_validate_rules_shapes() AS TABLE
SELECT code, notice FROM gtfs_vr_shapes_missing_file()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_increasing_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_single_point()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_unused()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_trip_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_trip_dist_no_shape_dist();
