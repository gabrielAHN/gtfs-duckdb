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
-- stop_sequence) with shape_dist_traveled, the trip has a shape_id whose points do not all have shape_dist_traveled.
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

-- ShapeToStopMatchingValidator (util/shape/*). S2 points are unit vectors (S2LatLng.toPoint), S2Point.angle(a, b) is
-- atan2(|a x b|, a . b) and S2Earth.getDistanceMeters(S2Point, S2Point) is that angle times 6,371,010 m.
CREATE OR REPLACE MACRO gtfs_vr_shapes_angle(p_ax, p_ay, p_az, p_bx, p_by, p_bz) AS (
  atan2(sqrt((p_ay * p_bz - p_az * p_by) * (p_ay * p_bz - p_az * p_by)
           + (p_az * p_bx - p_ax * p_bz) * (p_az * p_bx - p_ax * p_bz)
           + (p_ax * p_by - p_ay * p_bx) * (p_ax * p_by - p_ay * p_bx)),
        p_ax * p_bx + p_ay * p_by + p_az * p_bz)
);

-- ShapePoints.fromGtfsShape: idx is the 0-based point index, ud the user distance (running maximum of
-- shape_dist_traveled, from 0), geo the geo distance (sum of the S2LatLng distances between consecutive points), and
-- (x, y, z) the S2Point.
CREATE OR REPLACE MACRO gtfs_vr_shapes_match_points() AS TABLE
WITH p AS (
  SELECT shape_id, pt_index - 1 AS idx, lat, lon, dist,
         lag(lat) OVER w AS prev_lat, lag(lon) OVER w AS prev_lon, count(*) OVER (PARTITION BY shape_id) AS n_pts
  FROM gtfs_vr_shapes_points()
  WINDOW w AS (PARTITION BY shape_id ORDER BY pt_index)
), q AS (
  SELECT *, lat * 0.017453292519943295 AS phi, lon * 0.017453292519943295 AS theta,
         CASE WHEN prev_lat IS NULL THEN 0.0
              ELSE greatest(0.0, gtfs_validation_distance_m(prev_lat, prev_lon, lat, lon)) END AS step
  FROM p
)
SELECT shape_id, idx, n_pts, greatest(0.0, max(dist) OVER w) AS ud, sum(step) OVER w AS geo,
       cos(theta) * cos(phi) AS x, sin(theta) * cos(phi) AS y, sin(phi) AS z
FROM q
WINDOW w AS (PARTITION BY shape_id ORDER BY idx ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW);

-- The segments (i, i + 1) of each shape with the edge normal S2.robustCrossProd(a, b) = (b + a) x (b - a) that
-- S2EdgeUtil.getClosestPoint(x, a, b) projects on.
CREATE OR REPLACE MACRO gtfs_vr_shapes_match_segments() AS TABLE
WITH s AS (
  SELECT shape_id, idx AS i, geo, x AS a_x, y AS a_y, z AS a_z,
         lead(x) OVER w AS b_x, lead(y) OVER w AS b_y, lead(z) OVER w AS b_z
  FROM gtfs_vr_shapes_match_points()
  WINDOW w AS (PARTITION BY shape_id ORDER BY idx)
), u AS (
  SELECT *, b_x + a_x AS u_x, b_y + a_y AS u_y, b_z + a_z AS u_z, b_x - a_x AS v_x, b_y - a_y AS v_y, b_z - a_z AS v_z
  FROM s WHERE b_x IS NOT NULL
), n AS (
  SELECT shape_id, i, geo, a_x, a_y, a_z, b_x, b_y, b_z,
         u_y * v_z - u_z * v_y AS n_x, u_z * v_x - u_x * v_z AS n_y, u_x * v_y - u_y * v_x AS n_z
  FROM u
)
SELECT *, n_x * n_x + n_y * n_y + n_z * n_z AS n2 FROM n;

-- One assignment step of StopToShapeMatcher.findBestMatches for list_reduce. Each element is
-- {k, cands, assigns, fail, fm, pm}: the stop's index and potential matches. The accumulator carries the best
-- feasible assignment ending at each match of the previous stop (constructBestIncrementalAssignments), each as
-- {score, maxg, path}, path being the matches chosen so far. When no match of stop k is feasible, fail = k, fm is the
-- stop's closest match and pm the previous stop's match in the best-scoring assignment (constructOutOfOrderError),
-- and the accumulator is carried unchanged.
CREATE OR REPLACE MACRO gtfs_vr_shapes_assign_step(acc, el) AS (
  CASE WHEN acc.fail IS NOT NULL THEN acc ELSE list_transform(
    [list_filter(list_transform(el.cands, lambda cc: list_transform(
        [list_filter(acc.assigns, lambda pp: NOT (pp.maxg > cc.g))],
        lambda ff: CASE WHEN len(ff) = 0 THEN NULL ELSE list_transform(
          [list_filter(ff, lambda p2: p2.score = list_min(list_transform(ff, lambda q2: q2.score)))[1]],
          lambda bb: {'score': bb.score + cc.d, 'maxg': cc.g, 'path': list_append(bb.path, cc)})[1] END)[1]),
      lambda xx: xx IS NOT NULL)],
    lambda nx: CASE WHEN len(nx) > 0
      THEN {'k': el.k, 'cands': el.cands, 'assigns': nx, 'fail': NULL::BIGINT, 'fm': NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE), 'pm': NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE)}
      ELSE {'k': el.k, 'cands': el.cands, 'assigns': acc.assigns, 'fail': el.k,
            'fm': list_filter(el.cands, lambda c3: c3.d = list_min(list_transform(el.cands, lambda q3: q3.d)))[1],
            'pm': list_filter(acc.assigns,
                    lambda p4: p4.score = list_min(list_transform(acc.assigns, lambda q4: q4.score)))[1].path[-1]}
      END)[1]
  END
);

-- ShapeToStopMatchingValidator.validate: per shape, the trips using it (trips.txt order), skipping a trip whose stop
-- times (stop_id, shape_dist_traveled) equal an earlier trip's (tripHash, checked before the route) and a trip whose
-- route is missing. Returns one row per reported problem.
CREATE OR REPLACE MACRO gtfs_vr_shapes_stop_matching() AS TABLE
WITH pts AS MATERIALIZED (
  SELECT * FROM gtfs_vr_shapes_match_points()
), shapes AS (
  SELECT shape_id, max(n_pts) AS n_pts, arg_max(ud, idx) AS last_ud FROM pts GROUP BY shape_id
), stop_first AS (
  SELECT DISTINCT ON (stop_id) stop_id, coalesce(stop_name, '') AS stop_name, stop_lat, stop_lon, parent_station
  FROM gtfs_v_stops WHERE stop_id IS NOT NULL ORDER BY stop_id, csv_row_number
), stop_loc AS (
  -- StopUtil.getStopOrParentLatLng: the stop's coordinates, else its parent's, else its grandparent's, else (0, 0).
  SELECT s0.stop_id, s0.stop_name,
         CASE WHEN s0.stop_lat IS NOT NULL AND s0.stop_lon IS NOT NULL THEN s0.stop_lat
              WHEN s1.stop_lat IS NOT NULL AND s1.stop_lon IS NOT NULL THEN s1.stop_lat
              WHEN s2.stop_lat IS NOT NULL AND s2.stop_lon IS NOT NULL THEN s2.stop_lat ELSE 0.0 END AS s_lat,
         CASE WHEN s0.stop_lat IS NOT NULL AND s0.stop_lon IS NOT NULL THEN s0.stop_lon
              WHEN s1.stop_lat IS NOT NULL AND s1.stop_lon IS NOT NULL THEN s1.stop_lon
              WHEN s2.stop_lat IS NOT NULL AND s2.stop_lon IS NOT NULL THEN s2.stop_lon ELSE 0.0 END AS s_lon
  FROM stop_first s0
  LEFT JOIN stop_first s1 ON s1.stop_id = s0.parent_station
  LEFT JOIN stop_first s2 ON s2.stop_id = s1.parent_station
), st AS MATERIALIZED (
  SELECT * FROM gtfs_vr_shapes_stop_times()
), pat AS (
  SELECT trip_id, list({'s': coalesce(stop_id, ''), 'd': coalesce(shape_dist_traveled, 0.0)} ORDER BY st_index) AS pattern
  FROM st GROUP BY trip_id
), shape_trips AS (
  SELECT t.csv_row_number AS trip_row, coalesce(t.trip_id, '') AS trip_id, coalesce(t.shape_id, '') AS shape_id,
         coalesce(t.route_id, '') AS route_id, p.pattern
  FROM gtfs_v_trips t
  JOIN shapes s ON s.shape_id = coalesce(t.shape_id, '')
  JOIN pat p ON p.trip_id = coalesce(t.trip_id, '')
), first_trips AS (
  SELECT min(trip_row) AS trip_row FROM shape_trips GROUP BY shape_id, pattern
), jobs AS (
  SELECT t.trip_row, t.trip_id, t.shape_id, r.route_type
  FROM first_trips f
  JOIN shape_trips t ON t.trip_row = f.trip_row
  JOIN (SELECT DISTINCT ON (route_id) route_id, route_type FROM gtfs_v_routes WHERE route_id IS NOT NULL
        ORDER BY route_id, csv_row_number) r ON r.route_id = t.route_id
), job_stops AS MATERIALIZED (
  -- StopPoints.fromStopTimes: rail (route_type 2) first and last stops are large stations (threshold x 4).
  SELECT j.trip_row, j.trip_id, j.shape_id, st.st_index - 1 AS k, st.st_count AS n_st, st.csv_row_number AS st_row,
         coalesce(st.stop_id, '') AS stop_id, coalesce(l.stop_name, '') AS stop_name,
         coalesce(st.shape_dist_traveled, 0.0) AS sud, coalesce(l.s_lat, 0.0) AS s_lat, coalesce(l.s_lon, 0.0) AS s_lon,
         CASE WHEN j.route_type = 2 AND (st.st_index = 1 OR st.st_index = st.st_count) THEN 100.0 * 4.0
              ELSE 100.0 END AS maxd
  FROM jobs j
  JOIN st ON st.trip_id = j.trip_id
  LEFT JOIN stop_loc l ON l.stop_id = st.stop_id
), pairs AS MATERIALIZED (
  -- Potential matches only depend on the shape, the stop's location and the distance threshold.
  SELECT row_number() OVER () AS pair_id, shape_id, s_lat, s_lon, maxd,
         cos(s_lon * 0.017453292519943295) * cos(s_lat * 0.017453292519943295) AS s_x,
         sin(s_lon * 0.017453292519943295) * cos(s_lat * 0.017453292519943295) AS s_y,
         sin(s_lat * 0.017453292519943295) AS s_z
  FROM (SELECT DISTINCT shape_id, s_lat, s_lon, maxd FROM job_stops)
), proj AS (
  SELECT pr.pair_id, pr.maxd, pr.s_x, pr.s_y, pr.s_z, sg.*,
         CASE WHEN sg.n2 = 0 THEN 0.0 ELSE (pr.s_x * sg.n_x + pr.s_y * sg.n_y + pr.s_z * sg.n_z) / sg.n2 END AS t
  FROM pairs pr JOIN gtfs_vr_shapes_match_segments() sg ON sg.shape_id = pr.shape_id
), proj2 AS (
  SELECT *, s_x - n_x * t AS p_x, s_y - n_y * t AS p_y, s_z - n_z * t AS p_z FROM proj
), proj3 AS (
  -- S2EdgeUtil.getClosestPoint: the projection when it falls inside the edge, else the closer endpoint.
  SELECT *,
         n2 <> 0
           AND a_x * (p_y * n_z - p_z * n_y) + a_y * (p_z * n_x - p_x * n_z) + a_z * (p_x * n_y - p_y * n_x) > 0
           AND b_x * (n_y * p_z - n_z * p_y) + b_y * (n_z * p_x - n_x * p_z) + b_z * (n_x * p_y - n_y * p_x) > 0
           AS inside,
         (s_x - a_x) * (s_x - a_x) + (s_y - a_y) * (s_y - a_y) + (s_z - a_z) * (s_z - a_z)
           <= (s_x - b_x) * (s_x - b_x) + (s_y - b_y) * (s_y - b_y) + (s_z - b_z) * (s_z - b_z) AS a_closer,
         1.0 / sqrt(p_x * p_x + p_y * p_y + p_z * p_z) AS p_inv
  FROM proj2
), proj4 AS (
  SELECT pair_id, maxd, s_x, s_y, s_z, i, geo, a_x, a_y, a_z, b_x, b_y, b_z,
         CASE WHEN inside THEN p_x * p_inv WHEN a_closer THEN a_x ELSE b_x END AS c_x,
         CASE WHEN inside THEN p_y * p_inv WHEN a_closer THEN a_y ELSE b_y END AS c_y,
         CASE WHEN inside THEN p_z * p_inv WHEN a_closer THEN a_z ELSE b_z END AS c_z
  FROM proj3
), seg_d AS (
  SELECT pair_id, maxd, i,
         gtfs_vr_shapes_angle(s_x, s_y, s_z, c_x, c_y, c_z) * 6371010.0 AS d,
         gtfs_vr_shapes_angle(s_x, s_y, s_z, b_x, b_y, b_z) * 6371010.0 AS e,
         {'g': geo + gtfs_vr_shapes_angle(c_x, c_y, c_z, a_x, a_y, a_z) * 6371010.0,
          'd': gtfs_vr_shapes_angle(s_x, s_y, s_z, c_x, c_y, c_z) * 6371010.0,
          'i': i::BIGINT, 't': 0::INTEGER, 'f': 0.0::DOUBLE} AS m
  FROM proj4
), seg_w AS (
  -- ShapePoints.matchesFromLocation: one local match per run of segments within maxd, a new run starting where the
  -- previous segment was getting further away and this one comes back closer than its end.
  SELECT *, d <= maxd AS in_range, lag(d <= maxd) OVER w AS prev_in, lag(d) OVER w AS prev_d, lag(e) OVER w AS prev_e
  FROM seg_d
  WINDOW w AS (PARTITION BY pair_id ORDER BY i)
), seg_g AS (
  SELECT *, sum(CASE WHEN in_range AND (prev_in IS NULL OR NOT prev_in OR (prev_e > prev_d AND d < prev_e))
                     THEN 1 ELSE 0 END) OVER (PARTITION BY pair_id ORDER BY i ROWS UNBOUNDED PRECEDING) AS grp
  FROM seg_w
), local_matches AS (
  SELECT pair_id, grp, min(i) AS i, arg_min(m, {'d': d, 'i': i}) AS m FROM seg_g WHERE in_range GROUP BY pair_id, grp
), pair_matches AS (
  SELECT pair_id, list(m ORDER BY i) AS cands, count(*) AS cnt, arg_min(m, {'d': m.d, 'i': i}) AS best
  FROM local_matches GROUP BY pair_id
), pair_closest AS (
  -- ShapePoints.matchFromLocation: the closest point of the shape (first segment on ties), or its only point.
  SELECT pair_id, arg_min(m, {'d': d, 'i': i}) AS closest FROM seg_d GROUP BY pair_id
  UNION ALL
  SELECT pr.pair_id, {'g': 0.0::DOUBLE, 'd': gtfs_vr_shapes_angle(pr.s_x, pr.s_y, pr.s_z, p.x, p.y, p.z) * 6371010.0,
                      'i': 0::BIGINT, 't': 1::INTEGER, 'f': 0.0::DOUBLE}
  FROM pairs pr JOIN pts p ON p.shape_id = pr.shape_id AND p.n_pts = 1
), stops_geo AS MATERIALIZED (
  SELECT js.*, coalesce(pm.cands, []) AS cands, coalesce(pm.cnt, 0) AS cnt, pm.best, pc.closest
  FROM job_stops js
  JOIN pairs pr ON pr.shape_id = js.shape_id AND pr.s_lat = js.s_lat AND pr.s_lon = js.s_lon AND pr.maxd = js.maxd
  LEFT JOIN pair_matches pm ON pm.pair_id = pr.pair_id
  LEFT JOIN pair_closest pc ON pc.pair_id = pr.pair_id
), user_jobs AS (
  -- stopPoints.hasUserDistance() && shapePoints.hasUserDistance(): the last stop and the last shape point.
  SELECT js.trip_row FROM job_stops js JOIN shapes s ON s.shape_id = js.shape_id
  WHERE js.k = js.n_st - 1 AND js.sud > 0 AND s.last_ud > 0
), ud_steps AS (
  SELECT shape_id, ud, max(idx) AS last_idx FROM pts GROUP BY shape_id, ud
), user_idx AS (
  -- ShapePoints.getVertexDistFromUserDist: the search starts at the previous user-distance stop's vertex, so the
  -- vertex is the running maximum of the last point whose user distance is <= the stop's.
  SELECT js.trip_row, js.k, js.shape_id, js.sud, js.s_lat, js.s_lon, s.n_pts, coalesce(u.last_idx, -1) AS cm1
  FROM job_stops js
  JOIN user_jobs uj ON uj.trip_row = js.trip_row
  JOIN shapes s ON s.shape_id = js.shape_id
  ASOF LEFT JOIN ud_steps u ON u.shape_id = js.shape_id AND u.ud <= js.sud
  WHERE js.sud > 0
), user_idx2 AS (
  SELECT *, greatest(0, coalesce(max(cm1) OVER (PARTITION BY trip_row ORDER BY k
                                                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0)) AS start_idx
  FROM user_idx
), user_vertex AS (
  SELECT ui.*, greatest(ui.start_idx, ui.cm1) AS prev_idx,
         CASE WHEN greatest(ui.start_idx, ui.cm1) + 1 = ui.n_pts THEN greatest(ui.start_idx, ui.cm1)
              ELSE greatest(ui.start_idx, ui.cm1) + 1 END AS next_idx,
         ui.cm1 >= ui.start_idx AND ui.cm1 + 1 < ui.n_pts AS interpolated
  FROM user_idx2 ui
), user_frac AS (
  SELECT uv.trip_row, uv.k, uv.s_lat, uv.s_lon, pa.geo AS a_geo, pb.geo AS b_geo,
         pa.x AS a_x, pa.y AS a_y, pa.z AS a_z, pb.x AS b_x, pb.y AS b_y, pb.z AS b_z,
         CASE WHEN NOT uv.interpolated THEN 0.0
              WHEN abs(pa.ud - pb.ud) <= greatest(1e-9 * 32, 1e-9 * 32 * greatest(abs(pa.ud), abs(pb.ud))) THEN 0.0
              ELSE (uv.sud - pa.ud) / (pb.ud - pa.ud) END AS f,
         gtfs_vr_shapes_angle(pa.x, pa.y, pa.z, pb.x, pb.y, pb.z) AS ab, uv.prev_idx
  FROM user_vertex uv
  JOIN pts pa ON pa.shape_id = uv.shape_id AND pa.idx = uv.prev_idx
  JOIN pts pb ON pb.shape_id = uv.shape_id AND pb.idx = uv.next_idx
), user_loc AS (
  -- ShapePoints.interpolate: S2EdgeUtil.interpolate(f, a, b) unless the vertices are S2.approxEquals (1e-15 rad).
  -- Native trig here: only the distance to the stop is used, the notice location is recomputed exactly later.
  SELECT *,
         CASE WHEN ab <= 1e-15 OR f = 0 THEN 0.0 WHEN f = 1 THEN 1.0 ELSE sin(f * ab) / sin(ab) END AS wb,
         CASE WHEN ab <= 1e-15 OR f = 0 THEN 1.0 WHEN f = 1 THEN 0.0
              ELSE cos(f * ab) - sin(f * ab) / sin(ab) * cos(ab) END AS wa
  FROM user_frac
), user_loc2 AS (
  SELECT *, a_x * wa + b_x * wb AS q_x, a_y * wa + b_y * wb AS q_y, a_z * wa + b_z * wb AS q_z FROM user_loc
), user_loc3 AS (
  SELECT *,
         CASE WHEN wa = 1.0 AND wb = 0.0 THEN 1.0 WHEN wa = 0.0 AND wb = 1.0 THEN 1.0
              ELSE 1.0 / sqrt(q_x * q_x + q_y * q_y + q_z * q_z) END AS q_inv
  FROM user_loc2
), user_match AS (
  SELECT trip_row, k, {'g': a_geo + f * (b_geo - a_geo),
                       'd': gtfs_vr_shapes_angle(cos(s_lon * 0.017453292519943295) * cos(s_lat * 0.017453292519943295),
                                                 sin(s_lon * 0.017453292519943295) * cos(s_lat * 0.017453292519943295),
                                                 sin(s_lat * 0.017453292519943295),
                                                 q_x * q_inv, q_y * q_inv, q_z * q_inv) * 6371010.0,
                       'i': prev_idx::BIGINT, 't': 2::INTEGER, 'f': f::DOUBLE} AS m
  FROM user_loc3
), stops_both AS (
  -- mode 0 = GEO (matchUsingGeoDistance), 1 = USER (matchUsingUserDistance).
  SELECT 0 AS mode, sg.*, sg.cands AS mcands, false AS is_user FROM stops_geo sg
  UNION ALL
  SELECT 1 AS mode, sg.*, CASE WHEN sg.sud > 0 THEN [um.m] ELSE sg.cands END AS mcands, sg.sud > 0 AS is_user
  FROM stops_geo sg
  JOIN user_jobs uj ON uj.trip_row = sg.trip_row
  LEFT JOIN user_match um ON um.trip_row = sg.trip_row AND um.k = sg.k
), stops_scope AS (
  -- GEO evaluates every stop, USER returns at the first stop without user distance and without a potential match.
  SELECT *, min(CASE WHEN NOT is_user AND cnt = 0 THEN k END) OVER (PARTITION BY trip_row, mode) AS k_stop
  FROM stops_both
), cand_problems AS (
  SELECT trip_row, mode, 0 AS phase, k, CASE WHEN cnt = 0 THEN 'far' ELSE 'many' END AS kind,
         CASE WHEN cnt = 0 THEN closest ELSE best END AS m, cnt
  FROM stops_scope
  WHERE NOT is_user AND (mode = 0 OR k_stop IS NULL OR k <= k_stop)
    AND ((cnt = 0 AND closest.d > maxd) OR cnt > 20)
), dp AS (
  SELECT trip_row, mode,
         list_reduce(list_prepend(
           {'k': -1::BIGINT, 'cands': []::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE)[],
            'assigns': [{'score': 0.0::DOUBLE, 'maxg': 0.0::DOUBLE,
                         'path': []::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE)[]}],
            'fail': NULL::BIGINT, 'fm': NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE),
            'pm': NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE)},
           list({'k': k::BIGINT, 'cands': mcands,
                 'assigns': []::STRUCT(score DOUBLE, maxg DOUBLE, path STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE)[])[],
                 'fail': NULL::BIGINT, 'fm': NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE),
                 'pm': NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE)} ORDER BY k)),
           lambda acc, el: gtfs_vr_shapes_assign_step(acc, el)) AS r
  FROM stops_scope
  GROUP BY trip_row, mode
  HAVING bool_and(len(mcands) > 0)
), order_problems AS (
  SELECT trip_row, mode, 1 AS phase, r.fail AS k, 'order' AS kind, r.fm AS m, 0 AS cnt, r.pm AS pm
  FROM dp WHERE r.fail IS NOT NULL
), user_checks AS (
  -- isValidStopsToShapeMatchFromUserDistance: every match of the best assignment within 100 m (no large stations).
  SELECT trip_row, mode, unnest(list_transform(
           list_filter(r.assigns, lambda p5: p5.score = list_min(list_transform(r.assigns, lambda q5: q5.score)))[1].path,
           lambda m5, i5: {'k': i5 - 1, 'm': m5})) AS km
  FROM dp WHERE mode = 1 AND r.fail IS NULL
), problems AS (
  SELECT trip_row, mode, phase, k, kind, m, cnt, NULL::STRUCT(g DOUBLE, d DOUBLE, i BIGINT, t INTEGER, f DOUBLE) AS pm
  FROM cand_problems
  UNION ALL SELECT trip_row, mode, phase, k, kind, m, cnt, pm FROM order_problems
  UNION ALL SELECT trip_row, mode, 2, km.k, 'far', km.m, 0, NULL FROM user_checks WHERE km.m.d > 100.0
)
SELECT p.*, js.trip_id, js.shape_id, js.st_row, js.stop_id, js.stop_name, js.s_lat, js.s_lon,
       pv.st_row AS prev_st_row, pv.stop_id AS prev_stop_id, pv.stop_name AS prev_stop_name,
       pv.s_lat AS prev_s_lat, pv.s_lon AS prev_s_lon
FROM problems p
JOIN job_stops js ON js.trip_row = p.trip_row AND js.k = p.k
LEFT JOIN job_stops pv ON p.kind = 'order' AND pv.trip_row = p.trip_row AND pv.k = p.k - 1
WHERE js.stop_id <> '';

-- The notices. A notice's match location (an S2LatLng) is recomputed here, only for the reported matches: the stop and
-- shape S2Points, then S2EdgeUtil.getClosestPoint (t = 0), the shape's only point (t = 1) or S2EdgeUtil.interpolate
-- (t = 2), then new S2LatLng(point). DuckDB's sin, cos and atan2 can differ from Java's Math in the last bit, so the
-- coordinates can differ from the official validator's in the last digit.
CREATE OR REPLACE MACRO gtfs_vr_shapes_stop_matching_notices() AS TABLE
WITH p AS MATERIALIZED (
  SELECT row_number() OVER () AS nid, * FROM (
    SELECT *, row_number() OVER (PARTITION BY shape_id, stop_id, kind = 'far' ORDER BY trip_row, mode, phase, k) AS nth
    FROM gtfs_vr_shapes_stop_matching()
    WHERE gtfs_validation_parsed(['stops.txt', 'trips.txt', 'routes.txt', 'stop_times.txt', 'shapes.txt'])
      AND EXISTS (SELECT 1 FROM gtfs_v_stops) AND EXISTS (SELECT 1 FROM gtfs_v_trips)
      AND EXISTS (SELECT 1 FROM gtfs_v_stop_times) AND EXISTS (SELECT 1 FROM gtfs_v_shapes))
  WHERE kind <> 'far' OR nth = 1
), loc AS (
  SELECT nid, 1 AS w, shape_id, m, s_lat, s_lon FROM p
  UNION ALL SELECT nid, 2 AS w, shape_id, pm, prev_s_lat, prev_s_lon FROM p WHERE kind = 'order'
), loc2 AS MATERIALIZED (
  -- Vertex a = point m.i, b = the next point (a itself at the end of the shape).
  SELECT l.nid, l.w, l.m, [l.s_lat, l.s_lon, a.lat, a.lon, coalesce(b.lat, a.lat), coalesce(b.lon, a.lon)] AS degs
  FROM loc l
  JOIN gtfs_vr_shapes_points() a ON a.shape_id = l.shape_id AND a.pt_index = l.m.i + 1
  LEFT JOIN gtfs_vr_shapes_points() b ON b.shape_id = l.shape_id AND b.pt_index = l.m.i + 2
), pts AS (
  -- S1Angle.degrees: radians = degrees * (Math.PI / 180).
  SELECT nid, w, m,
         list_transform(degs, lambda d: sin(d * '0.017453292519943295'::DOUBLE)) AS sn,
         list_transform(degs, lambda d: cos(d * '0.017453292519943295'::DOUBLE)) AS cs
  FROM loc2
), xyz AS (
  -- S2LatLng.toPoint: (cos(lng) cos(lat), sin(lng) cos(lat), sin(lat)).
  SELECT nid, w, m,
         cs[2] * cs[1] AS s_x, sn[2] * cs[1] AS s_y, sn[1] AS s_z,
         cs[4] * cs[3] AS a_x, sn[4] * cs[3] AS a_y, sn[3] AS a_z,
         cs[6] * cs[5] AS b_x, sn[6] * cs[5] AS b_y, sn[5] AS b_z
  FROM pts
), proj AS (
  -- S2EdgeUtil.getClosestPoint(x, a, b): project on the edge normal S2.robustCrossProd(a, b) = (b + a) x (b - a).
  SELECT *,
         (b_y + a_y) * (b_z - a_z) - (b_z + a_z) * (b_y - a_y) AS n_x,
         (b_z + a_z) * (b_x - a_x) - (b_x + a_x) * (b_z - a_z) AS n_y,
         (b_x + a_x) * (b_y - a_y) - (b_y + a_y) * (b_x - a_x) AS n_z
  FROM xyz
), proj2 AS (
  SELECT *, n_x * n_x + n_y * n_y + n_z * n_z AS n2 FROM proj
), proj3 AS (
  SELECT *, CASE WHEN n2 = 0 THEN 0.0 ELSE (s_x * n_x + s_y * n_y + s_z * n_z) / n2 END AS tt FROM proj2
), proj4 AS (
  SELECT *, s_x - n_x * tt AS p_x, s_y - n_y * tt AS p_y, s_z - n_z * tt AS p_z FROM proj3
), proj5 AS (
  SELECT *,
         n2 <> 0
           AND a_x * (p_y * n_z - p_z * n_y) + a_y * (p_z * n_x - p_x * n_z) + a_z * (p_x * n_y - p_y * n_x) > 0
           AND b_x * (n_y * p_z - n_z * p_y) + b_y * (n_z * p_x - n_x * p_z) + b_z * (n_x * p_y - n_y * p_x) > 0
           AS inside,
         (s_x - a_x) * (s_x - a_x) + (s_y - a_y) * (s_y - a_y) + (s_z - a_z) * (s_z - a_z)
           <= (s_x - b_x) * (s_x - b_x) + (s_y - b_y) * (s_y - b_y) + (s_z - b_z) * (s_z - b_z) AS a_closer,
         1.0 / sqrt(p_x * p_x + p_y * p_y + p_z * p_z) AS p_inv
  FROM proj4
), proj6 AS (
  -- S2.approxEquals(a, b) and the angle S2EdgeUtil.interpolate uses, both a.angle(b) = atan2(|a x b|, a . b).
  SELECT *, gtfs_vr_shapes_angle(a_x, a_y, a_z, b_x, b_y, b_z) AS ab FROM proj5
), interp AS (
  -- ShapePoints.interpolate: wb = sin(f ab) / sin(ab), wa = cos(f ab) - wb cos(ab).
  SELECT *,
         CASE WHEN m.t <> 2 OR ab <= 1e-15 OR m.f = 0 THEN 0.0 WHEN m.f = 1 THEN 1.0 ELSE sin(m.f * ab) / sin(ab) END AS wb,
         CASE WHEN m.t <> 2 OR ab <= 1e-15 OR m.f = 0 THEN 1.0 WHEN m.f = 1 THEN 0.0
              ELSE cos(m.f * ab) - sin(m.f * ab) / sin(ab) * cos(ab) END AS wa
  FROM proj6
), interp2 AS (
  SELECT *, a_x * wa + b_x * wb AS q_x, a_y * wa + b_y * wb AS q_y, a_z * wa + b_z * wb AS q_z FROM interp
), located AS (
  SELECT nid, w,
         CASE WHEN m.t = 1 THEN [a_x, a_y, a_z]
              WHEN m.t = 2 AND ((wa = 1.0 AND wb = 0.0) OR (wa = 0.0 AND wb = 1.0)) THEN [q_x, q_y, q_z]
              WHEN m.t = 2 THEN list_transform([q_x, q_y, q_z], lambda qv: qv * (1.0 / sqrt(q_x * q_x + q_y * q_y + q_z * q_z)))
              WHEN inside THEN [p_x * p_inv, p_y * p_inv, p_z * p_inv]
              WHEN a_closer THEN [a_x, a_y, a_z] ELSE [b_x, b_y, b_z] END AS c
  FROM interp2
), ll AS (
  -- new S2LatLng(point) in degrees: [atan2(z, sqrt(x^2 + y^2)), atan2(y, x)].
  SELECT nid, w, slot, atan2(yx[1], yx[2]) * '57.29577951308232'::DOUBLE AS deg
  FROM (SELECT nid, w, unnest([[c[3], sqrt(c[1] * c[1] + c[2] * c[2])], [c[2], c[1]]]) AS yx, unnest([1, 2]) AS slot
        FROM located)
), latlng AS (
  SELECT nid, list(deg ORDER BY slot) FILTER (WHERE w = 1) AS m1, list(deg ORDER BY slot) FILTER (WHERE w = 2) AS m2
  FROM ll GROUP BY nid
)
SELECT CASE WHEN kind = 'far' AND mode = 0 THEN 'stop_too_far_from_shape'
            WHEN kind = 'far' THEN 'stop_too_far_from_shape_using_user_distance'
            WHEN kind = 'many' THEN 'stop_has_too_many_matches_for_shape'
            ELSE 'stops_match_shape_out_of_order' END AS code,
       CASE WHEN kind = 'order' THEN gtfs_validation_notice(json_object(
              'tripCsvRowNumber', trip_row, 'shapeId', shape_id, 'tripId', trip_id,
              'stopTimeCsvRowNumber1', st_row, 'stopId1', stop_id, 'stopName1', stop_name, 'match1', l.m1,
              'stopTimeCsvRowNumber2', prev_st_row, 'stopId2', prev_stop_id, 'stopName2', prev_stop_name,
              'match2', l.m2))
            ELSE gtfs_validation_notice(json_object(
              'tripCsvRowNumber', trip_row, 'shapeId', shape_id, 'tripId', trip_id, 'stopTimeCsvRowNumber', st_row,
              'stopId', stop_id, 'stopName', stop_name, 'match', l.m1,
              'geoDistanceToShape', CASE WHEN kind = 'far' THEN m.d END,
              'matchCount', CASE WHEN kind = 'many' THEN cnt END)) END AS notice
FROM p
JOIN latlng l ON l.nid = p.nid;

CREATE OR REPLACE MACRO gtfs_validate_rules_shapes() AS TABLE
SELECT code, notice FROM gtfs_vr_shapes_missing_file()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_stop_matching_notices()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_increasing_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_single_point()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_unused()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_trip_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_trip_dist_no_shape_dist();
