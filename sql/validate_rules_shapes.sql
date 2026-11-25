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

-- Bit-exact ports of the Java math the S2 library uses on this platform (HotSpot 17, aarch64): Math.sin/Math.cos are
-- the fdlibm intrinsic of macroAssembler_aarch64_trig.cpp (polynomials with fused multiply-adds, argument reduction
-- __ieee754_rem_pio2 for |x| < 2^19 pi/2), Math.atan2 is fdlibm e_atan2.c with s_atan.c. Notices write S2LatLng
-- fields as exact doubles, so a reported match location must match Java to the last bit, and DuckDB's native trig
-- differs from Java's in about 1 result in 10. Checked against 163,382 Java results (0 differences).
-- Machine-generated from straight-line code: column vN of layer k is one assignment, each layer projects only what
-- later layers read, so there are no lambdas or nested macros to expand. fma(a, b, c) is Dekker's exact product plus
-- Boldo-Melquiond round-to-odd. The high word of |d| (fdlibm's GET_HIGH_WORD) is computed with log2/pow (normal
-- numbers only). Call them laterally: FROM t, gtfs_vr_shapes_java_sincos(t.x) s.
CREATE OR REPLACE MACRO gtfs_vr_shapes_java_sincos(p_x) AS TABLE
WITH sc0 AS (SELECT p_x::DOUBLE AS v1),
  sc1 AS (SELECT v1, abs(v1) AS v2, CASE WHEN v1 > 0 THEN 1.0 ELSE -1.0 END AS v6, CASE WHEN v1 > 0 THEN v1 - '1.5707963267341256'::DOUBLE ELSE v1 + '1.5707963267341256'::DOUBLE END AS v7, abs(v1) AS v12, '134217729.0'::DOUBLE * '0.6366197723675814'::DOUBLE AS v15, '134217729.0'::DOUBLE * '1.5707963267341256'::DOUBLE AS v29, '134217729.0'::DOUBLE * '2.0222662487959506e-21'::DOUBLE AS v53, '134217729.0'::DOUBLE * '8.4784276603689e-32'::DOUBLE AS v74, '134217729.0'::DOUBLE * '1.58969099521155e-10'::DOUBLE AS v97, '134217729.0'::DOUBLE * '-0.16666666666666632'::DOUBLE AS v202, '134217729.0'::DOUBLE * '-1.1359647557788195e-11'::DOUBLE AS v216, '134217729.0'::DOUBLE * '0.5'::DOUBLE AS v295, '134217729.0'::DOUBLE * '0.5'::DOUBLE AS v322 FROM sc0),
  sc2 AS (SELECT v1, v2, v6, v7, v12, v15, v29, v53, v74, v97, v202, v216, v295, v322, CASE WHEN v2 = 0 THEN 0.0 ELSE floor(log2(v2)) END AS v3, v12 * '0.6366197723675814'::DOUBLE AS v13, '134217729.0'::DOUBLE * v12 AS v14, v15 - (v15 - '0.6366197723675814'::DOUBLE) AS v17, v29 - (v29 - '1.5707963267341256'::DOUBLE) AS v31, v53 - (v53 - '2.0222662487959506e-21'::DOUBLE) AS v55, v74 - (v74 - '8.4784276603689e-32'::DOUBLE) AS v76, v97 - (v97 - '1.58969099521155e-10'::DOUBLE) AS v99, v202 - (v202 - '-0.16666666666666632'::DOUBLE) AS v204, v216 - (v216 - '-1.1359647557788195e-11'::DOUBLE) AS v218, v295 - (v295 - '0.5'::DOUBLE) AS v297, v322 - (v322 - '0.5'::DOUBLE) AS v324 FROM sc1),
  sc3 AS (SELECT v1, v2, v3, v6, v7, v12, v13, v14, v17, v31, v55, v76, v99, v204, v218, v297, v324, CASE WHEN pow(2.0, v3) > v2 THEN v3 - 1 WHEN pow(2.0, v3 + 1) <= v2 THEN v3 + 1 ELSE v3 END AS v4, v14 - (v14 - v12) AS v16, '0.5'::DOUBLE + v13 AS v19 FROM sc2),
  sc4 AS (SELECT v1, v2, v4, v6, v7, v12, v13, v16, v17, v19, v31, v55, v76, v99, v204, v218, v297, v324, CASE WHEN v2 = 0 THEN 0.0 ELSE (v4 + 1023) * 1048576 + floor((v2 / pow(2.0, v4) - 1) * 1048576) END AS v5, (v12 - v16) * ('0.6366197723675814'::DOUBLE - v17) - (((v13 - v16 * v17) - (v12 - v16) * v17) - v16 * ('0.6366197723675814'::DOUBLE - v17)) AS v18, v19 - '0.5'::DOUBLE AS v20 FROM sc3),
  sc5 AS (SELECT v1, v5, v6, v7, v12, v13, v18, v19, v20, v31, v55, v76, v99, v204, v218, v297, v324, CASE WHEN v5 <> 1073291771 THEN v7 WHEN v1 > 0 THEN v7 - '6.077100506303966e-11'::DOUBLE ELSE v7 + '6.077100506303966e-11'::DOUBLE END AS v8, CASE WHEN v5 <> 1073291771 THEN '6.077100506506192e-11'::DOUBLE ELSE '2.0222662487959506e-21'::DOUBLE END AS v9, ('0.5'::DOUBLE - (v19 - v20)) + (v13 - v20) AS v21, floor(v5 / 1048576) AS v43, CASE WHEN v5 > 1072234496 THEN '0.28125'::DOUBLE ELSE (1.0 + ((v5 - 2097152) % 1048576) / 1048576.0) * pow(2.0, floor((v5 - 2097152) / 1048576) - 1023) END AS v307 FROM sc4),
  sc6 AS (SELECT v1, v5, v6, v8, v9, v12, v18, v19, v21, v31, v43, v55, v76, v99, v204, v218, v297, v307, v324, CASE WHEN v1 > 0 THEN v8 - v9 ELSE v8 + v9 END AS v10, v21 + v18 AS v22 FROM sc5),
  sc7 AS (SELECT v1, v5, v6, v8, v9, v10, v12, v18, v19, v21, v22, v31, v43, v55, v76, v99, v204, v218, v297, v307, v324, CASE WHEN v1 > 0 THEN (v8 - v10) - v9 ELSE (v8 - v10) + v9 END AS v11, v22 - v21 AS v23 FROM sc6),
  sc8 AS (SELECT v1, v5, v6, v10, v11, v12, v18, v19, v21, v22, v23, v31, v43, v55, v76, v99, v204, v218, v297, v307, v324, (v21 - (v22 - v23)) + (v18 - v23) AS v24 FROM sc7),
  sc9 AS (SELECT v1, v5, v6, v10, v11, v12, v19, v22, v24, v31, v43, v55, v76, v99, v204, v218, v297, v307, v324, v19 + CASE WHEN v24 = 0 OR (abs(v22) / (nextafter(abs(v22), 'inf'::DOUBLE) - abs(v22))) % 2 = 1 THEN v22 ELSE nextafter(v22, CASE WHEN v24 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v25 FROM sc8),
  sc10 AS (SELECT v1, v5, v6, v10, v11, v12, v25, v31, v43, v55, v76, v99, v204, v218, v297, v307, v324, trunc(v25) AS v26 FROM sc9),
  sc11 AS (SELECT v1, v5, v6, v10, v11, v12, v26, v31, v43, v55, v76, v99, v204, v218, v297, v307, v324, -v26 * '1.5707963267341256'::DOUBLE AS v27, '134217729.0'::DOUBLE * -v26 AS v28, v26 * '6.077100506506192e-11'::DOUBLE AS v40, v26 > 32 OR (v26 >= 1 AND v5 = [1073291771, 1074340347, 1074977148, 1075388923, 1075800698, 1076025724, 1076231611, 1076437499, 1076643386, 1076849274, 1076971356, 1077074300, 1077177244, 1077280187, 1077383131, 1077486075, 1077589019, 1077691962, 1077794906, 1077897850, 1077968460, 1078019932, 1078071404, 1078122876, 1078174348, 1078225820, 1078277292, 1078328763, 1078380235, 1078431707, 1078483179, 1078534651][greatest(1, least(32, v26))::INTEGER]) AS v42, v26 * '6.077100506303966e-11'::DOUBLE AS v49, v26 * '2.0222662487959506e-21'::DOUBLE AS v51, '134217729.0'::DOUBLE * v26 AS v52, v26 * '2.0222662487111665e-21'::DOUBLE AS v70, v26 * '8.4784276603689e-32'::DOUBLE AS v72, '134217729.0'::DOUBLE * v26 AS v73, CASE WHEN v5 <= 1072243195 THEN 0.0 WHEN v5 < 1073928572 THEN v6 WHEN v1 <= 0 THEN -v26 ELSE v26 END AS v90 FROM sc10),
  sc12 AS (SELECT v1, v5, v10, v11, v12, v26, v27, v28, v31, v40, v42, v43, v49, v51, v52, v55, v70, v72, v73, v76, v90, v99, v204, v218, v297, v307, v324, v28 - (v28 - -v26) AS v30, v12 + v27 AS v33, v52 - (v52 - v26) AS v54, v73 - (v73 - v26) AS v75, (((v90)::BIGINT % 4) + 4) % 4 AS v335 FROM sc11),
  sc13 AS (SELECT v1, v5, v10, v11, v12, v26, v27, v30, v31, v33, v40, v42, v43, v49, v51, v54, v55, v70, v72, v75, v76, v99, v204, v218, v297, v307, v324, v335, (-v26 - v30) * ('1.5707963267341256'::DOUBLE - v31) - (((v27 - v30 * v31) - (-v26 - v30) * v31) - v30 * ('1.5707963267341256'::DOUBLE - v31)) AS v32, v33 - v12 AS v34, (v26 - v54) * ('2.0222662487959506e-21'::DOUBLE - v55) - (((v51 - v54 * v55) - (v26 - v54) * v55) - v54 * ('2.0222662487959506e-21'::DOUBLE - v55)) AS v56, (v26 - v75) * ('8.4784276603689e-32'::DOUBLE - v76) - (((v72 - v75 * v76) - (v26 - v75) * v76) - v75 * ('8.4784276603689e-32'::DOUBLE - v76)) AS v77 FROM sc12),
  sc14 AS (SELECT v1, v5, v10, v11, v12, v27, v32, v33, v34, v40, v42, v43, v49, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, (v12 - (v33 - v34)) + (v27 - v34) AS v35 FROM sc13),
  sc15 AS (SELECT v1, v5, v10, v11, v32, v33, v35, v40, v42, v43, v49, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, v35 + v32 AS v36 FROM sc14),
  sc16 AS (SELECT v1, v5, v10, v11, v32, v33, v35, v36, v40, v42, v43, v49, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, v36 - v35 AS v37 FROM sc15),
  sc17 AS (SELECT v1, v5, v10, v11, v32, v33, v35, v36, v37, v40, v42, v43, v49, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, (v35 - (v36 - v37)) + (v32 - v37) AS v38 FROM sc16),
  sc18 AS (SELECT v1, v5, v10, v11, v33, v36, v38, v40, v42, v43, v49, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, v33 + CASE WHEN v38 = 0 OR (abs(v36) / (nextafter(abs(v36), 'inf'::DOUBLE) - abs(v36))) % 2 = 1 THEN v36 ELSE nextafter(v36, CASE WHEN v38 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v39 FROM sc17),
  sc19 AS (SELECT v1, v5, v10, v11, v39, v40, v42, v43, v49, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, v39 - v40 AS v41, v39 - v49 AS v50 FROM sc18),
  sc20 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v42, v43, v49, v50, v51, v56, v70, v72, v77, v99, v204, v218, v297, v307, v324, v335, abs(v41) AS v44, (v49 - (v39 - v50)) + v51 AS v57, v50 - v70 AS v71 FROM sc19),
  sc21 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v42, v43, v44, v49, v50, v51, v56, v57, v70, v71, v72, v77, v99, v204, v218, v297, v307, v324, v335, CASE WHEN v44 = 0 THEN 0.0 ELSE floor(log2(v44)) END AS v45, v57 - (v49 - (v39 - v50)) AS v58, (v70 - (v50 - v71)) + v72 AS v78 FROM sc20),
  sc22 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v42, v43, v44, v45, v49, v50, v51, v56, v57, v58, v70, v71, v72, v77, v78, v99, v204, v218, v297, v307, v324, v335, CASE WHEN pow(2.0, v45) > v44 THEN v45 - 1 WHEN pow(2.0, v45 + 1) <= v44 THEN v45 + 1 ELSE v45 END AS v46, ((v49 - (v39 - v50)) - (v57 - v58)) + (v51 - v58) AS v59, v78 - (v70 - (v50 - v71)) AS v79 FROM sc21),
  sc23 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v42, v43, v44, v46, v50, v56, v57, v59, v70, v71, v72, v77, v78, v79, v99, v204, v218, v297, v307, v324, v335, CASE WHEN v44 = 0 THEN 0.0 ELSE (v46 + 1023) * 1048576 + floor((v44 / pow(2.0, v46) - 1) * 1048576) END AS v47, v59 + v56 AS v60, ((v70 - (v50 - v71)) - (v78 - v79)) + (v72 - v79) AS v80 FROM sc22),
  sc24 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v42, v43, v47, v50, v56, v57, v59, v60, v71, v77, v78, v80, v99, v204, v218, v297, v307, v324, v335, v42 AND v43 - floor(v47 / 1048576) > 16 AS v48, v60 - v59 AS v61, v80 + v77 AS v81 FROM sc23),
  sc25 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v56, v57, v59, v60, v61, v71, v77, v78, v80, v81, v99, v204, v218, v297, v307, v324, v335, (v59 - (v60 - v61)) + (v56 - v61) AS v62, v81 - v80 AS v82 FROM sc24),
  sc26 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v57, v60, v62, v71, v77, v78, v80, v81, v82, v99, v204, v218, v297, v307, v324, v335, v57 + CASE WHEN v62 = 0 OR (abs(v60) / (nextafter(abs(v60), 'inf'::DOUBLE) - abs(v60))) % 2 = 1 THEN v60 ELSE nextafter(v60, CASE WHEN v62 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v63, (v80 - (v81 - v82)) + (v77 - v82) AS v83 FROM sc25),
  sc27 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v63, v71, v78, v81, v83, v99, v204, v218, v297, v307, v324, v335, v50 - v63 AS v64, v78 + CASE WHEN v83 = 0 OR (abs(v81) / (nextafter(abs(v81), 'inf'::DOUBLE) - abs(v81))) % 2 = 1 THEN v81 ELSE nextafter(v81, CASE WHEN v83 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v84 FROM sc26),
  sc28 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v63, v64, v71, v84, v99, v204, v218, v297, v307, v324, v335, abs(v64) AS v65, v71 - v84 AS v85 FROM sc27),
  sc29 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v63, v64, v65, v71, v84, v85, v99, v204, v218, v297, v307, v324, v335, CASE WHEN v65 = 0 THEN 0.0 ELSE floor(log2(v65)) END AS v66 FROM sc28),
  sc30 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v63, v64, v65, v66, v71, v84, v85, v99, v204, v218, v297, v307, v324, v335, CASE WHEN pow(2.0, v66) > v65 THEN v66 - 1 WHEN pow(2.0, v66 + 1) <= v65 THEN v66 + 1 ELSE v66 END AS v67 FROM sc29),
  sc31 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v63, v64, v65, v67, v71, v84, v85, v99, v204, v218, v297, v307, v324, v335, CASE WHEN v65 = 0 THEN 0.0 ELSE (v67 + 1023) * 1048576 + floor((v65 / pow(2.0, v67) - 1) * 1048576) END AS v68 FROM sc30),
  sc32 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v43, v48, v50, v63, v64, v68, v71, v84, v85, v99, v204, v218, v297, v307, v324, v335, v48 AND v43 - floor(v68 / 1048576) > 49 AS v69 FROM sc31),
  sc33 AS (SELECT v1, v5, v10, v11, v39, v40, v41, v48, v50, v63, v64, v69, v71, v84, v85, v99, v204, v218, v297, v307, v324, v335, CASE WHEN v69 THEN v71 WHEN v48 THEN v50 ELSE v39 END AS v86, CASE WHEN v69 THEN v84 WHEN v48 THEN v63 ELSE v40 END AS v87, CASE WHEN v69 THEN v85 WHEN v48 THEN v64 ELSE v41 END AS v88 FROM sc32),
  sc34 AS (SELECT v1, v5, v10, v11, v86, v87, v88, v99, v204, v218, v297, v307, v324, v335, (v86 - v88) - v87 AS v89, CASE WHEN v5 <= 1072243195 THEN v1 WHEN v5 < 1073928572 THEN v10 WHEN v1 <= 0 THEN -v88 ELSE v88 END AS v91 FROM sc33),
  sc35 AS (SELECT v1, v5, v11, v89, v91, v99, v204, v218, v297, v307, v324, v335, CASE WHEN v5 <= 1072243195 THEN 0.0 WHEN v5 < 1073928572 THEN v11 WHEN v1 <= 0 THEN -v89 ELSE v89 END AS v92, v91 * v91 AS v93 FROM sc34),
  sc36 AS (SELECT v1, v5, v91, v92, v93, v99, v204, v218, v297, v307, v324, v335, v93 * v91 AS v94, v93 * '1.58969099521155e-10'::DOUBLE AS v95, '134217729.0'::DOUBLE * v93 AS v96, '134217729.0'::DOUBLE * v93 AS v109, '134217729.0'::DOUBLE * v93 AS v122, '134217729.0'::DOUBLE * v93 AS v135, '134217729.0'::DOUBLE * v93 AS v148, 0.5::DOUBLE * v92 AS v173, '134217729.0'::DOUBLE * -v93 AS v188, v93 * '-1.1359647557788195e-11'::DOUBLE AS v214, '134217729.0'::DOUBLE * v93 AS v215, '134217729.0'::DOUBLE * v93 AS v228, v91 * v92 AS v240, '134217729.0'::DOUBLE * v93 AS v242, '134217729.0'::DOUBLE * v93 AS v255, v93 * v93 AS v267, '134217729.0'::DOUBLE * v93 AS v269, '0.5'::DOUBLE * v93 AS v294, '134217729.0'::DOUBLE * v93 AS v296, '0.5'::DOUBLE * v93 AS v321, '134217729.0'::DOUBLE * v93 AS v323 FROM sc35),
  sc37 AS (SELECT v1, v5, v91, v92, v93, v94, v95, v96, v99, v109, v122, v135, v148, v173, v188, v204, v214, v215, v218, v228, v240, v242, v255, v267, v269, v294, v296, v297, v307, v321, v323, v324, v335, v96 - (v96 - v93) AS v98, '-2.5050760253406863e-08'::DOUBLE + v95 AS v101, v109 - (v109 - v93) AS v111, v122 - (v122 - v93) AS v124, v135 - (v135 - v93) AS v137, v148 - (v148 - v93) AS v150, '134217729.0'::DOUBLE * v94 AS v161, '134217729.0'::DOUBLE * -v94 AS v175, v188 - (v188 - -v93) AS v190, v94 * '-0.16666666666666632'::DOUBLE AS v200, '134217729.0'::DOUBLE * v94 AS v201, v215 - (v215 - v93) AS v217, '2.087572321298175e-09'::DOUBLE + v214 AS v220, v228 - (v228 - v93) AS v230, v242 - (v242 - v93) AS v244, v255 - (v255 - v93) AS v257, v269 - (v269 - v93) AS v271, '134217729.0'::DOUBLE * -v267 AS v282, v296 - (v296 - v93) AS v298, '134217729.0'::DOUBLE * v267 AS v309, v323 - (v323 - v93) AS v325, -v307 + v321 AS v327 FROM sc36),
  sc38 AS (SELECT v1, v5, v91, v92, v93, v94, v95, v98, v99, v101, v111, v124, v137, v150, v161, v173, v175, v190, v200, v201, v204, v214, v217, v218, v220, v230, v240, v244, v257, v267, v271, v282, v294, v297, v298, v307, v309, v321, v324, v325, v327, v335, (v93 - v98) * ('1.58969099521155e-10'::DOUBLE - v99) - (((v95 - v98 * v99) - (v93 - v98) * v99) - v98 * ('1.58969099521155e-10'::DOUBLE - v99)) AS v100, v101 - '-2.5050760253406863e-08'::DOUBLE AS v102, v161 - (v161 - v94) AS v163, v175 - (v175 - -v94) AS v177, v201 - (v201 - v94) AS v203, (v93 - v217) * ('-1.1359647557788195e-11'::DOUBLE - v218) - (((v214 - v217 * v218) - (v93 - v217) * v218) - v217 * ('-1.1359647557788195e-11'::DOUBLE - v218)) AS v219, v220 - '2.087572321298175e-09'::DOUBLE AS v221, v282 - (v282 - -v267) AS v284, ('0.5'::DOUBLE - v297) * (v93 - v298) - (((v294 - v297 * v298) - ('0.5'::DOUBLE - v297) * v298) - v297 * (v93 - v298)) AS v299, v309 - (v309 - v267) AS v311, ('0.5'::DOUBLE - v324) * (v93 - v325) - (((v321 - v324 * v325) - ('0.5'::DOUBLE - v324) * v325) - v324 * (v93 - v325)) AS v326, v327 - -v307 AS v328 FROM sc37),
  sc39 AS (SELECT v1, v5, v91, v92, v93, v94, v95, v100, v101, v102, v111, v124, v137, v150, v163, v173, v177, v190, v200, v203, v204, v214, v219, v220, v221, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v321, v326, v327, v328, v335, ('-2.5050760253406863e-08'::DOUBLE - (v101 - v102)) + (v95 - v102) AS v103, (v94 - v203) * ('-0.16666666666666632'::DOUBLE - v204) - (((v200 - v203 * v204) - (v94 - v203) * v204) - v203 * ('-0.16666666666666632'::DOUBLE - v204)) AS v205, ('2.087572321298175e-09'::DOUBLE - (v220 - v221)) + (v214 - v221) AS v222, (-v307 - (v327 - v328)) + (v321 - v328) AS v329 FROM sc38),
  sc40 AS (SELECT v1, v5, v91, v92, v93, v94, v100, v101, v103, v111, v124, v137, v150, v163, v173, v177, v190, v200, v205, v219, v220, v222, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v326, v327, v329, v335, v103 + v100 AS v104, v222 + v219 AS v223, v329 + v326 AS v330 FROM sc39),
  sc41 AS (SELECT v1, v5, v91, v92, v93, v94, v100, v101, v103, v104, v111, v124, v137, v150, v163, v173, v177, v190, v200, v205, v219, v220, v222, v223, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v326, v327, v329, v330, v335, v104 - v103 AS v105, v223 - v222 AS v224, v330 - v329 AS v331 FROM sc40),
  sc42 AS (SELECT v1, v5, v91, v92, v93, v94, v100, v101, v103, v104, v105, v111, v124, v137, v150, v163, v173, v177, v190, v200, v205, v219, v220, v222, v223, v224, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v326, v327, v329, v330, v331, v335, (v103 - (v104 - v105)) + (v100 - v105) AS v106, (v222 - (v223 - v224)) + (v219 - v224) AS v225, (v329 - (v330 - v331)) + (v326 - v331) AS v332 FROM sc41),
  sc43 AS (SELECT v1, v5, v91, v92, v93, v94, v101, v104, v106, v111, v124, v137, v150, v163, v173, v177, v190, v200, v205, v220, v223, v225, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v327, v330, v332, v335, v101 + CASE WHEN v106 = 0 OR (abs(v104) / (nextafter(abs(v104), 'inf'::DOUBLE) - abs(v104))) % 2 = 1 THEN v104 ELSE nextafter(v104, CASE WHEN v106 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v107, v220 + CASE WHEN v225 = 0 OR (abs(v223) / (nextafter(abs(v223), 'inf'::DOUBLE) - abs(v223))) % 2 = 1 THEN v223 ELSE nextafter(v223, CASE WHEN v225 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v226, v327 + CASE WHEN v332 = 0 OR (abs(v330) / (nextafter(abs(v330), 'inf'::DOUBLE) - abs(v330))) % 2 = 1 THEN v330 ELSE nextafter(v330, CASE WHEN v332 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v333 FROM sc42),
  sc44 AS (SELECT v1, v5, v91, v92, v93, v94, v107, v111, v124, v137, v150, v163, v173, v177, v190, v200, v205, v226, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v93 * v107 AS v108, '134217729.0'::DOUBLE * v107 AS v110, v93 * v226 AS v227, '134217729.0'::DOUBLE * v226 AS v229 FROM sc43),
  sc45 AS (SELECT v1, v5, v91, v92, v93, v94, v107, v108, v110, v111, v124, v137, v150, v163, v173, v177, v190, v200, v205, v226, v227, v229, v230, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v110 - (v110 - v107) AS v112, '2.7557313707070068e-06'::DOUBLE + v108 AS v114, v229 - (v229 - v226) AS v231, '-2.7557314351390663e-07'::DOUBLE + v227 AS v233 FROM sc44),
  sc46 AS (SELECT v1, v5, v91, v92, v93, v94, v107, v108, v111, v112, v114, v124, v137, v150, v163, v173, v177, v190, v200, v205, v226, v227, v230, v231, v233, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, (v93 - v111) * (v107 - v112) - (((v108 - v111 * v112) - (v93 - v111) * v112) - v111 * (v107 - v112)) AS v113, v114 - '2.7557313707070068e-06'::DOUBLE AS v115, (v93 - v230) * (v226 - v231) - (((v227 - v230 * v231) - (v93 - v230) * v231) - v230 * (v226 - v231)) AS v232, v233 - '-2.7557314351390663e-07'::DOUBLE AS v234 FROM sc45),
  sc47 AS (SELECT v1, v5, v91, v92, v93, v94, v108, v113, v114, v115, v124, v137, v150, v163, v173, v177, v190, v200, v205, v227, v232, v233, v234, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, ('2.7557313707070068e-06'::DOUBLE - (v114 - v115)) + (v108 - v115) AS v116, ('-2.7557314351390663e-07'::DOUBLE - (v233 - v234)) + (v227 - v234) AS v235 FROM sc46),
  sc48 AS (SELECT v1, v5, v91, v92, v93, v94, v113, v114, v116, v124, v137, v150, v163, v173, v177, v190, v200, v205, v232, v233, v235, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v116 + v113 AS v117, v235 + v232 AS v236 FROM sc47),
  sc49 AS (SELECT v1, v5, v91, v92, v93, v94, v113, v114, v116, v117, v124, v137, v150, v163, v173, v177, v190, v200, v205, v232, v233, v235, v236, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v117 - v116 AS v118, v236 - v235 AS v237 FROM sc48),
  sc50 AS (SELECT v1, v5, v91, v92, v93, v94, v113, v114, v116, v117, v118, v124, v137, v150, v163, v173, v177, v190, v200, v205, v232, v233, v235, v236, v237, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, (v116 - (v117 - v118)) + (v113 - v118) AS v119, (v235 - (v236 - v237)) + (v232 - v237) AS v238 FROM sc49),
  sc51 AS (SELECT v1, v5, v91, v92, v93, v94, v114, v117, v119, v124, v137, v150, v163, v173, v177, v190, v200, v205, v233, v236, v238, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v114 + CASE WHEN v119 = 0 OR (abs(v117) / (nextafter(abs(v117), 'inf'::DOUBLE) - abs(v117))) % 2 = 1 THEN v117 ELSE nextafter(v117, CASE WHEN v119 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v120, v233 + CASE WHEN v238 = 0 OR (abs(v236) / (nextafter(abs(v236), 'inf'::DOUBLE) - abs(v236))) % 2 = 1 THEN v236 ELSE nextafter(v236, CASE WHEN v238 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v239 FROM sc50),
  sc52 AS (SELECT v1, v5, v91, v92, v93, v94, v120, v124, v137, v150, v163, v173, v177, v190, v200, v205, v239, v240, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v93 * v120 AS v121, '134217729.0'::DOUBLE * v120 AS v123, v93 * v239 AS v241, '134217729.0'::DOUBLE * v239 AS v243 FROM sc51),
  sc53 AS (SELECT v1, v5, v91, v92, v93, v94, v120, v121, v123, v124, v137, v150, v163, v173, v177, v190, v200, v205, v239, v240, v241, v243, v244, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v123 - (v123 - v120) AS v125, '-0.0001984126982985795'::DOUBLE + v121 AS v127, v243 - (v243 - v239) AS v245, '2.480158728947673e-05'::DOUBLE + v241 AS v247 FROM sc52),
  sc54 AS (SELECT v1, v5, v91, v92, v93, v94, v120, v121, v124, v125, v127, v137, v150, v163, v173, v177, v190, v200, v205, v239, v240, v241, v244, v245, v247, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, (v93 - v124) * (v120 - v125) - (((v121 - v124 * v125) - (v93 - v124) * v125) - v124 * (v120 - v125)) AS v126, v127 - '-0.0001984126982985795'::DOUBLE AS v128, (v93 - v244) * (v239 - v245) - (((v241 - v244 * v245) - (v93 - v244) * v245) - v244 * (v239 - v245)) AS v246, v247 - '2.480158728947673e-05'::DOUBLE AS v248 FROM sc53),
  sc55 AS (SELECT v1, v5, v91, v92, v93, v94, v121, v126, v127, v128, v137, v150, v163, v173, v177, v190, v200, v205, v240, v241, v246, v247, v248, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, ('-0.0001984126982985795'::DOUBLE - (v127 - v128)) + (v121 - v128) AS v129, ('2.480158728947673e-05'::DOUBLE - (v247 - v248)) + (v241 - v248) AS v249 FROM sc54),
  sc56 AS (SELECT v1, v5, v91, v92, v93, v94, v126, v127, v129, v137, v150, v163, v173, v177, v190, v200, v205, v240, v246, v247, v249, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v129 + v126 AS v130, v249 + v246 AS v250 FROM sc55),
  sc57 AS (SELECT v1, v5, v91, v92, v93, v94, v126, v127, v129, v130, v137, v150, v163, v173, v177, v190, v200, v205, v240, v246, v247, v249, v250, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v130 - v129 AS v131, v250 - v249 AS v251 FROM sc56),
  sc58 AS (SELECT v1, v5, v91, v92, v93, v94, v126, v127, v129, v130, v131, v137, v150, v163, v173, v177, v190, v200, v205, v240, v246, v247, v249, v250, v251, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, (v129 - (v130 - v131)) + (v126 - v131) AS v132, (v249 - (v250 - v251)) + (v246 - v251) AS v252 FROM sc57),
  sc59 AS (SELECT v1, v5, v91, v92, v93, v94, v127, v130, v132, v137, v150, v163, v173, v177, v190, v200, v205, v240, v247, v250, v252, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v127 + CASE WHEN v132 = 0 OR (abs(v130) / (nextafter(abs(v130), 'inf'::DOUBLE) - abs(v130))) % 2 = 1 THEN v130 ELSE nextafter(v130, CASE WHEN v132 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v133, v247 + CASE WHEN v252 = 0 OR (abs(v250) / (nextafter(abs(v250), 'inf'::DOUBLE) - abs(v250))) % 2 = 1 THEN v250 ELSE nextafter(v250, CASE WHEN v252 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v253 FROM sc58),
  sc60 AS (SELECT v1, v5, v91, v92, v93, v94, v133, v137, v150, v163, v173, v177, v190, v200, v205, v240, v253, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v93 * v133 AS v134, '134217729.0'::DOUBLE * v133 AS v136, v93 * v253 AS v254, '134217729.0'::DOUBLE * v253 AS v256 FROM sc59),
  sc61 AS (SELECT v1, v5, v91, v92, v93, v94, v133, v134, v136, v137, v150, v163, v173, v177, v190, v200, v205, v240, v253, v254, v256, v257, v267, v271, v284, v294, v299, v307, v311, v333, v335, v136 - (v136 - v133) AS v138, '0.00833333333332249'::DOUBLE + v134 AS v140, v256 - (v256 - v253) AS v258, '-0.001388888888887411'::DOUBLE + v254 AS v260 FROM sc60),
  sc62 AS (SELECT v1, v5, v91, v92, v93, v94, v133, v134, v137, v138, v140, v150, v163, v173, v177, v190, v200, v205, v240, v253, v254, v257, v258, v260, v267, v271, v284, v294, v299, v307, v311, v333, v335, (v93 - v137) * (v133 - v138) - (((v134 - v137 * v138) - (v93 - v137) * v138) - v137 * (v133 - v138)) AS v139, v140 - '0.00833333333332249'::DOUBLE AS v141, (v93 - v257) * (v253 - v258) - (((v254 - v257 * v258) - (v93 - v257) * v258) - v257 * (v253 - v258)) AS v259, v260 - '-0.001388888888887411'::DOUBLE AS v261 FROM sc61),
  sc63 AS (SELECT v1, v5, v91, v92, v93, v94, v134, v139, v140, v141, v150, v163, v173, v177, v190, v200, v205, v240, v254, v259, v260, v261, v267, v271, v284, v294, v299, v307, v311, v333, v335, ('0.00833333333332249'::DOUBLE - (v140 - v141)) + (v134 - v141) AS v142, ('-0.001388888888887411'::DOUBLE - (v260 - v261)) + (v254 - v261) AS v262 FROM sc62),
  sc64 AS (SELECT v1, v5, v91, v92, v93, v94, v139, v140, v142, v150, v163, v173, v177, v190, v200, v205, v240, v259, v260, v262, v267, v271, v284, v294, v299, v307, v311, v333, v335, v142 + v139 AS v143, v262 + v259 AS v263 FROM sc63),
  sc65 AS (SELECT v1, v5, v91, v92, v93, v94, v139, v140, v142, v143, v150, v163, v173, v177, v190, v200, v205, v240, v259, v260, v262, v263, v267, v271, v284, v294, v299, v307, v311, v333, v335, v143 - v142 AS v144, v263 - v262 AS v264 FROM sc64),
  sc66 AS (SELECT v1, v5, v91, v92, v93, v94, v139, v140, v142, v143, v144, v150, v163, v173, v177, v190, v200, v205, v240, v259, v260, v262, v263, v264, v267, v271, v284, v294, v299, v307, v311, v333, v335, (v142 - (v143 - v144)) + (v139 - v144) AS v145, (v262 - (v263 - v264)) + (v259 - v264) AS v265 FROM sc65),
  sc67 AS (SELECT v1, v5, v91, v92, v93, v94, v140, v143, v145, v150, v163, v173, v177, v190, v200, v205, v240, v260, v263, v265, v267, v271, v284, v294, v299, v307, v311, v333, v335, v140 + CASE WHEN v145 = 0 OR (abs(v143) / (nextafter(abs(v143), 'inf'::DOUBLE) - abs(v143))) % 2 = 1 THEN v143 ELSE nextafter(v143, CASE WHEN v145 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v146, v260 + CASE WHEN v265 = 0 OR (abs(v263) / (nextafter(abs(v263), 'inf'::DOUBLE) - abs(v263))) % 2 = 1 THEN v263 ELSE nextafter(v263, CASE WHEN v265 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v266 FROM sc66),
  sc68 AS (SELECT v1, v5, v91, v92, v93, v94, v146, v150, v163, v173, v177, v190, v200, v205, v240, v266, v267, v271, v284, v294, v299, v307, v311, v333, v335, v93 * v146 AS v147, '134217729.0'::DOUBLE * v146 AS v149, -v94 * v146 AS v174, '134217729.0'::DOUBLE * v146 AS v176, v93 * v266 AS v268, '134217729.0'::DOUBLE * v266 AS v270 FROM sc67),
  sc69 AS (SELECT v1, v5, v91, v92, v93, v94, v146, v147, v149, v150, v163, v173, v174, v176, v177, v190, v200, v205, v240, v266, v267, v268, v270, v271, v284, v294, v299, v307, v311, v333, v335, v149 - (v149 - v146) AS v151, '-0.16666666666666632'::DOUBLE + v147 AS v153, v176 - (v176 - v146) AS v178, v173 + v174 AS v180, v270 - (v270 - v266) AS v272, '0.0416666666666666'::DOUBLE + v268 AS v274 FROM sc68),
  sc70 AS (SELECT v1, v5, v91, v92, v93, v94, v146, v147, v150, v151, v153, v163, v173, v174, v177, v178, v180, v190, v200, v205, v240, v266, v267, v268, v271, v272, v274, v284, v294, v299, v307, v311, v333, v335, (v93 - v150) * (v146 - v151) - (((v147 - v150 * v151) - (v93 - v150) * v151) - v150 * (v146 - v151)) AS v152, v153 - '-0.16666666666666632'::DOUBLE AS v154, (-v94 - v177) * (v146 - v178) - (((v174 - v177 * v178) - (-v94 - v177) * v178) - v177 * (v146 - v178)) AS v179, v180 - v173 AS v181, (v93 - v271) * (v266 - v272) - (((v268 - v271 * v272) - (v93 - v271) * v272) - v271 * (v266 - v272)) AS v273, v274 - '0.0416666666666666'::DOUBLE AS v275 FROM sc69),
  sc71 AS (SELECT v1, v5, v91, v92, v93, v94, v147, v152, v153, v154, v163, v173, v174, v179, v180, v181, v190, v200, v205, v240, v267, v268, v273, v274, v275, v284, v294, v299, v307, v311, v333, v335, ('-0.16666666666666632'::DOUBLE - (v153 - v154)) + (v147 - v154) AS v155, (v173 - (v180 - v181)) + (v174 - v181) AS v182, ('0.0416666666666666'::DOUBLE - (v274 - v275)) + (v268 - v275) AS v276 FROM sc70),
  sc72 AS (SELECT v1, v5, v91, v92, v93, v94, v152, v153, v155, v163, v179, v180, v182, v190, v200, v205, v240, v267, v273, v274, v276, v284, v294, v299, v307, v311, v333, v335, v155 + v152 AS v156, v182 + v179 AS v183, v276 + v273 AS v277 FROM sc71),
  sc73 AS (SELECT v1, v5, v91, v92, v93, v94, v152, v153, v155, v156, v163, v179, v180, v182, v183, v190, v200, v205, v240, v267, v273, v274, v276, v277, v284, v294, v299, v307, v311, v333, v335, v156 - v155 AS v157, v183 - v182 AS v184, v277 - v276 AS v278 FROM sc72),
  sc74 AS (SELECT v1, v5, v91, v92, v93, v94, v152, v153, v155, v156, v157, v163, v179, v180, v182, v183, v184, v190, v200, v205, v240, v267, v273, v274, v276, v277, v278, v284, v294, v299, v307, v311, v333, v335, (v155 - (v156 - v157)) + (v152 - v157) AS v158, (v182 - (v183 - v184)) + (v179 - v184) AS v185, (v276 - (v277 - v278)) + (v273 - v278) AS v279 FROM sc73),
  sc75 AS (SELECT v1, v5, v91, v92, v93, v94, v153, v156, v158, v163, v180, v183, v185, v190, v200, v205, v240, v267, v274, v277, v279, v284, v294, v299, v307, v311, v333, v335, v153 + CASE WHEN v158 = 0 OR (abs(v156) / (nextafter(abs(v156), 'inf'::DOUBLE) - abs(v156))) % 2 = 1 THEN v156 ELSE nextafter(v156, CASE WHEN v158 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v159, v180 + CASE WHEN v185 = 0 OR (abs(v183) / (nextafter(abs(v183), 'inf'::DOUBLE) - abs(v183))) % 2 = 1 THEN v183 ELSE nextafter(v183, CASE WHEN v185 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v186, v274 + CASE WHEN v279 = 0 OR (abs(v277) / (nextafter(abs(v277), 'inf'::DOUBLE) - abs(v277))) % 2 = 1 THEN v277 ELSE nextafter(v277, CASE WHEN v279 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v280 FROM sc74),
  sc76 AS (SELECT v1, v5, v91, v92, v93, v94, v159, v163, v186, v190, v200, v205, v240, v267, v280, v284, v294, v299, v307, v311, v333, v335, v94 * v159 AS v160, '134217729.0'::DOUBLE * v159 AS v162, -v93 * v186 AS v187, '134217729.0'::DOUBLE * v186 AS v189, -v267 * v280 AS v281, '134217729.0'::DOUBLE * v280 AS v283, v267 * v280 AS v308, '134217729.0'::DOUBLE * v280 AS v310 FROM sc75),
  sc77 AS (SELECT v1, v5, v91, v92, v93, v94, v159, v160, v162, v163, v186, v187, v189, v190, v200, v205, v240, v267, v280, v281, v283, v284, v294, v299, v307, v308, v310, v311, v333, v335, v162 - (v162 - v159) AS v164, v91 + v160 AS v166, v189 - (v189 - v186) AS v191, v92 + v187 AS v193, v283 - (v283 - v280) AS v285, v240 + v281 AS v287, v310 - (v310 - v280) AS v312, -v240 + v308 AS v314 FROM sc76),
  sc78 AS (SELECT v1, v5, v91, v92, v93, v94, v159, v160, v163, v164, v166, v186, v187, v190, v191, v193, v200, v205, v240, v267, v280, v281, v284, v285, v287, v294, v299, v307, v308, v311, v312, v314, v333, v335, (v94 - v163) * (v159 - v164) - (((v160 - v163 * v164) - (v94 - v163) * v164) - v163 * (v159 - v164)) AS v165, v166 - v91 AS v167, (-v93 - v190) * (v186 - v191) - (((v187 - v190 * v191) - (-v93 - v190) * v191) - v190 * (v186 - v191)) AS v192, v193 - v92 AS v194, (-v267 - v284) * (v280 - v285) - (((v281 - v284 * v285) - (-v267 - v284) * v285) - v284 * (v280 - v285)) AS v286, v287 - v240 AS v288, (v267 - v311) * (v280 - v312) - (((v308 - v311 * v312) - (v267 - v311) * v312) - v311 * (v280 - v312)) AS v313, v314 - -v240 AS v315 FROM sc77),
  sc79 AS (SELECT v1, v5, v91, v92, v160, v165, v166, v167, v187, v192, v193, v194, v200, v205, v240, v281, v286, v287, v288, v294, v299, v307, v308, v313, v314, v315, v333, v335, (v91 - (v166 - v167)) + (v160 - v167) AS v168, (v92 - (v193 - v194)) + (v187 - v194) AS v195, (v240 - (v287 - v288)) + (v281 - v288) AS v289, (-v240 - (v314 - v315)) + (v308 - v315) AS v316 FROM sc78),
  sc80 AS (SELECT v1, v5, v91, v165, v166, v168, v192, v193, v195, v200, v205, v286, v287, v289, v294, v299, v307, v313, v314, v316, v333, v335, v168 + v165 AS v169, v195 + v192 AS v196, v289 + v286 AS v290, v316 + v313 AS v317 FROM sc79),
  sc81 AS (SELECT v1, v5, v91, v165, v166, v168, v169, v192, v193, v195, v196, v200, v205, v286, v287, v289, v290, v294, v299, v307, v313, v314, v316, v317, v333, v335, v169 - v168 AS v170, v196 - v195 AS v197, v290 - v289 AS v291, v317 - v316 AS v318 FROM sc80),
  sc82 AS (SELECT v1, v5, v91, v165, v166, v168, v169, v170, v192, v193, v195, v196, v197, v200, v205, v286, v287, v289, v290, v291, v294, v299, v307, v313, v314, v316, v317, v318, v333, v335, (v168 - (v169 - v170)) + (v165 - v170) AS v171, (v195 - (v196 - v197)) + (v192 - v197) AS v198, (v289 - (v290 - v291)) + (v286 - v291) AS v292, (v316 - (v317 - v318)) + (v313 - v318) AS v319 FROM sc81),
  sc83 AS (SELECT v1, v5, v91, v166, v169, v171, v193, v196, v198, v200, v205, v287, v290, v292, v294, v299, v307, v314, v317, v319, v333, v335, v166 + CASE WHEN v171 = 0 OR (abs(v169) / (nextafter(abs(v169), 'inf'::DOUBLE) - abs(v169))) % 2 = 1 THEN v169 ELSE nextafter(v169, CASE WHEN v171 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v172, v193 + CASE WHEN v198 = 0 OR (abs(v196) / (nextafter(abs(v196), 'inf'::DOUBLE) - abs(v196))) % 2 = 1 THEN v196 ELSE nextafter(v196, CASE WHEN v198 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v199, v287 + CASE WHEN v292 = 0 OR (abs(v290) / (nextafter(abs(v290), 'inf'::DOUBLE) - abs(v290))) % 2 = 1 THEN v290 ELSE nextafter(v290, CASE WHEN v292 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v293, v314 + CASE WHEN v319 = 0 OR (abs(v317) / (nextafter(abs(v317), 'inf'::DOUBLE) - abs(v317))) % 2 = 1 THEN v317 ELSE nextafter(v317, CASE WHEN v319 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v320 FROM sc82),
  sc84 AS (SELECT v1, v5, v91, v172, v199, v200, v205, v293, v294, v299, v307, v320, v333, v335, v199 + v200 AS v206, v293 + v294 AS v300 FROM sc83),
  sc85 AS (SELECT v1, v5, v91, v172, v199, v200, v205, v206, v293, v294, v299, v300, v307, v320, v333, v335, v206 - v199 AS v207, v300 - v293 AS v301 FROM sc84),
  sc86 AS (SELECT v1, v5, v91, v172, v199, v200, v205, v206, v207, v293, v294, v299, v300, v301, v307, v320, v333, v335, (v199 - (v206 - v207)) + (v200 - v207) AS v208, (v293 - (v300 - v301)) + (v294 - v301) AS v302 FROM sc85),
  sc87 AS (SELECT v1, v5, v91, v172, v205, v206, v208, v299, v300, v302, v307, v320, v333, v335, v208 + v205 AS v209, v302 + v299 AS v303 FROM sc86),
  sc88 AS (SELECT v1, v5, v91, v172, v205, v206, v208, v209, v299, v300, v302, v303, v307, v320, v333, v335, v209 - v208 AS v210, v303 - v302 AS v304 FROM sc87),
  sc89 AS (SELECT v1, v5, v91, v172, v205, v206, v208, v209, v210, v299, v300, v302, v303, v304, v307, v320, v333, v335, (v208 - (v209 - v210)) + (v205 - v210) AS v211, (v302 - (v303 - v304)) + (v299 - v304) AS v305 FROM sc88),
  sc90 AS (SELECT v1, v5, v91, v172, v206, v209, v211, v300, v303, v305, v307, v320, v333, v335, v206 + CASE WHEN v211 = 0 OR (abs(v209) / (nextafter(abs(v209), 'inf'::DOUBLE) - abs(v209))) % 2 = 1 THEN v209 ELSE nextafter(v209, CASE WHEN v211 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v212, v300 + CASE WHEN v305 = 0 OR (abs(v303) / (nextafter(abs(v303), 'inf'::DOUBLE) - abs(v303))) % 2 = 1 THEN v303 ELSE nextafter(v303, CASE WHEN v305 > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END AS v306 FROM sc89),
  sc91 AS (SELECT v1, v5, v91, v172, v212, v306, v307, v320, v333, v335, CASE WHEN v5 <= 1072243195 THEN v172 ELSE v91 + v212 END AS v213, CASE WHEN v5 <= 1070805811 THEN 1.0::DOUBLE - v306 ELSE (1.0::DOUBLE - v307) - (v333 - v320) END AS v334 FROM sc90),
  sc92 AS (SELECT v1, v5, v213, v334, v335, CASE WHEN v5 < 1044381696 THEN v1 WHEN v335 = 0 THEN v213 WHEN v335 = 1 THEN v334 WHEN v335 = 2 THEN -v213 ELSE -v334 END AS v336, CASE WHEN v5 < 1044381696 THEN 1.0::DOUBLE WHEN v335 = 0 THEN v334 WHEN v335 = 1 THEN -v213 WHEN v335 = 2 THEN -v334 ELSE v213 END AS v337 FROM sc91),
  sc AS (SELECT v336 AS sn, v337 AS cs FROM sc92)
SELECT sn, cs FROM sc;

CREATE OR REPLACE MACRO gtfs_vr_shapes_java_atan2(p_y, p_x) AS TABLE
WITH ta0 AS (SELECT p_y::DOUBLE AS v1, p_x::DOUBLE AS v2),
  ta1 AS (SELECT v1, v2, abs(v2) AS v3, abs(v1) AS v7, CASE WHEN v2 = 1.0 THEN v1 WHEN v2 = 0 THEN 0.0 ELSE abs(v1 / v2) END AS v11 FROM ta0),
  ta2 AS (SELECT v1, v2, v3, v7, v11, CASE WHEN v3 = 0 THEN 0.0 ELSE floor(log2(v3)) END AS v4, CASE WHEN v7 = 0 THEN 0.0 ELSE floor(log2(v7)) END AS v8, abs(v11) AS v12, abs(v11) AS v16 FROM ta1),
  ta3 AS (SELECT v1, v2, v3, v4, v7, v8, v11, v12, v16, CASE WHEN pow(2.0, v4) > v3 THEN v4 - 1 WHEN pow(2.0, v4 + 1) <= v3 THEN v4 + 1 ELSE v4 END AS v5, CASE WHEN pow(2.0, v8) > v7 THEN v8 - 1 WHEN pow(2.0, v8 + 1) <= v7 THEN v8 + 1 ELSE v8 END AS v9, CASE WHEN v12 = 0 THEN 0.0 ELSE floor(log2(v12)) END AS v13 FROM ta2),
  ta4 AS (SELECT v1, v2, v3, v5, v7, v9, v11, v12, v13, v16, CASE WHEN v3 = 0 THEN 0.0 ELSE (v5 + 1023) * 1048576 + floor((v3 / pow(2.0, v5) - 1) * 1048576) END AS v6, CASE WHEN v7 = 0 THEN 0.0 ELSE (v9 + 1023) * 1048576 + floor((v7 / pow(2.0, v9) - 1) * 1048576) END AS v10, CASE WHEN pow(2.0, v13) > v12 THEN v13 - 1 WHEN pow(2.0, v13 + 1) <= v12 THEN v13 + 1 ELSE v13 END AS v14 FROM ta3),
  ta5 AS (SELECT v1, v2, v6, v10, v11, v12, v14, v16, CASE WHEN v12 = 0 THEN 0.0 ELSE (v14 + 1023) * 1048576 + floor((v12 / pow(2.0, v14) - 1) * 1048576) END AS v15, floor((v10 - v6) / 1048576) AS v27 FROM ta4),
  ta6 AS (SELECT v1, v2, v11, v15, v16, v27, CASE WHEN v15 < 1071382528 THEN -1 WHEN v15 < 1072037888 THEN 0 WHEN v15 < 1072889856 THEN 1 WHEN v15 < 1073971200 THEN 2 ELSE 3 END AS v17 FROM ta5),
  ta7 AS (SELECT v1, v2, v11, v15, v16, v17, v27, CASE WHEN v17 = -1 THEN v11 WHEN v17 = 0 THEN (2.0::DOUBLE * v16 - 1.0::DOUBLE) / (2.0::DOUBLE + v16) WHEN v17 = 1 THEN (v16 - 1.0::DOUBLE) / (v16 + 1.0::DOUBLE) WHEN v17 = 2 THEN (v16 - 1.5::DOUBLE) / (1.0::DOUBLE + 1.5::DOUBLE * v16) ELSE -1.0::DOUBLE / v16 END AS v18, CASE v17 WHEN 0 THEN '0.4636476090008061'::DOUBLE WHEN 1 THEN '0.7853981633974483'::DOUBLE WHEN 2 THEN '0.982793723247329'::DOUBLE ELSE '1.5707963267948966'::DOUBLE END AS v23, CASE v17 WHEN 0 THEN '2.2698777452961687e-17'::DOUBLE WHEN 1 THEN '3.061616997868383e-17'::DOUBLE WHEN 2 THEN '1.3903311031230998e-17'::DOUBLE ELSE '6.123233995736766e-17'::DOUBLE END AS v24 FROM ta6),
  ta8 AS (SELECT v1, v2, v11, v15, v17, v18, v23, v24, v27, v18 * v18 AS v19 FROM ta7),
  ta9 AS (SELECT v1, v2, v11, v15, v17, v18, v19, v23, v24, v27, v19 * v19 AS v20 FROM ta8),
  ta10 AS (SELECT v1, v2, v11, v15, v17, v18, v19, v20, v23, v24, v27, v19 * ('0.3333333333333293'::DOUBLE + v20 * ('0.14285714272503466'::DOUBLE + v20 * ('0.09090887133436507'::DOUBLE + v20 * ('0.06661073137387531'::DOUBLE + v20 * ('0.049768779946159324'::DOUBLE + v20 * '0.016285820115365782'::DOUBLE))))) AS v21, v20 * ('-0.19999999999876483'::DOUBLE + v20 * ('-0.11111110405462356'::DOUBLE + v20 * ('-0.0769187620504483'::DOUBLE + v20 * ('-0.058335701337905735'::DOUBLE + v20 * '-0.036531572744216916'::DOUBLE)))) AS v22 FROM ta9),
  ta11 AS (SELECT v1, v2, v11, v15, v17, v18, v21, v22, v23, v24, v27, v23 - ((v18 * (v21 + v22) - v24) - v18) AS v25 FROM ta10),
  ta12 AS (SELECT v1, v2, v11, v15, v17, v18, v21, v22, v25, v27, CASE WHEN v15 >= 1141899264 THEN CASE WHEN v11 < 0 THEN -'1.5707963267948966'::DOUBLE - '6.123233995736766e-17'::DOUBLE ELSE '1.5707963267948966'::DOUBLE + '6.123233995736766e-17'::DOUBLE END WHEN v15 < 1042284544 THEN v11 WHEN v17 = -1 THEN v18 - v18 * (v21 + v22) WHEN v11 < 0 THEN -v25 ELSE v25 END AS v26 FROM ta11),
  ta13 AS (SELECT v1, v2, v26, v27, CASE WHEN v27 > 60 THEN '1.5707963267948966'::DOUBLE + 0.5::DOUBLE * '1.2246467991473532e-16'::DOUBLE WHEN v2 < 0 AND v27 < -60 THEN 0.0::DOUBLE ELSE v26 END AS v28 FROM ta12),
  ta14 AS (SELECT v1, v2, v26, v28, CASE WHEN v2 = 1.0 THEN v26 WHEN v1 = 0 THEN CASE WHEN v2 >= 0 THEN v1 WHEN v1 < 0 THEN -'3.141592653589793'::DOUBLE ELSE '3.141592653589793'::DOUBLE END WHEN v2 = 0 THEN CASE WHEN v1 < 0 THEN -'1.5707963267948966'::DOUBLE ELSE '1.5707963267948966'::DOUBLE END WHEN v2 > 0 THEN CASE WHEN v1 < 0 THEN -v28 ELSE v28 END WHEN v1 > 0 THEN '3.141592653589793'::DOUBLE - (v28 - '1.2246467991473532e-16'::DOUBLE) ELSE (v28 - '1.2246467991473532e-16'::DOUBLE) - '3.141592653589793'::DOUBLE END AS v29 FROM ta13),
  ta AS (SELECT v29 AS tn FROM ta14)
SELECT tn FROM ta;

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
-- {k, cands, assigns, fail, fm, pm}: the stop's index and potential matches; the accumulator carries the best
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
  -- GEO evaluates every stop; USER returns at the first stop without user distance and without a potential match.
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

-- The notices. The matcher above runs on DuckDB's native trig, but a notice's match location (an S2LatLng, which the
-- notice writes as exact doubles) is recomputed here, only for the reported matches, with the bit-exact ports of
-- Java's Math.sin/cos/atan2: the stop and shape S2Points, then S2EdgeUtil.getClosestPoint (t = 0), the shape's only
-- point (t = 1) or S2EdgeUtil.interpolate (t = 2), then new S2LatLng(point). Each exact function is expanded once
-- per round (trig macros are large, so the inputs of a round are unnested into one column).
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
), trig1 AS MATERIALIZED (
  -- S1Angle.degrees: radians = degrees * (Math.PI / 180).
  SELECT a.deg, j.sn, j.cs
  FROM (SELECT DISTINCT unnest(degs) AS deg FROM loc2) a,
       gtfs_vr_shapes_java_sincos(a.deg * '0.017453292519943295'::DOUBLE) j
), pts AS (
  SELECT v.nid, v.w, any_value(v.m) AS m, list(t.sn ORDER BY v.slot) AS sn, list(t.cs ORDER BY v.slot) AS cs
  FROM (SELECT nid, w, m, unnest(degs) AS deg, unnest(range(6)) AS slot FROM loc2) v
  JOIN trig1 t ON t.deg = v.deg
  GROUP BY v.nid, v.w
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
), proj6 AS MATERIALIZED (
  -- S2.approxEquals(a, b) and the angle S2EdgeUtil.interpolate uses, both a.angle(b) = atan2(|a x b|, a . b).
  SELECT q.*, j.tn AS ab
  FROM proj5 q,
       gtfs_vr_shapes_java_atan2(sqrt((q.a_y * q.b_z - q.a_z * q.b_y) * (q.a_y * q.b_z - q.a_z * q.b_y)
                                    + (q.a_z * q.b_x - q.a_x * q.b_z) * (q.a_z * q.b_x - q.a_x * q.b_z)
                                    + (q.a_x * q.b_y - q.a_y * q.b_x) * (q.a_x * q.b_y - q.a_y * q.b_x)),
                                 q.a_x * q.b_x + q.a_y * q.b_y + q.a_z * q.b_z) j
), trig2 AS MATERIALIZED (
  -- ShapePoints.interpolate: the sines and cosines of f * ab and ab.
  SELECT a.rad, j.sn, j.cs
  FROM (SELECT DISTINCT unnest([m.f * ab, ab]) AS rad FROM proj6 WHERE m.t = 2 AND ab > 1e-15 AND m.f <> 0 AND m.f <> 1) a,
       gtfs_vr_shapes_java_sincos(a.rad) j
), interp AS (
  SELECT q.*,
         CASE WHEN m.t <> 2 OR ab <= 1e-15 OR m.f = 0 THEN 0.0 WHEN m.f = 1 THEN 1.0 ELSE tf.sn / ta.sn END AS wb,
         CASE WHEN m.t <> 2 OR ab <= 1e-15 OR m.f = 0 THEN 1.0 WHEN m.f = 1 THEN 0.0
              ELSE tf.cs - tf.sn / ta.sn * ta.cs END AS wa
  FROM proj6 q
  LEFT JOIN trig2 tf ON tf.rad = q.m.f * q.ab
  LEFT JOIN trig2 ta ON ta.rad = q.ab
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
  -- (+ 0.0 turns -0.0 into 0.0.)
  SELECT a.nid, a.w, a.slot, j.tn * '57.29577951308232'::DOUBLE AS deg
  FROM (SELECT nid, w, unnest([[c[3] + 0.0, sqrt(c[1] * c[1] + c[2] * c[2])], [c[2] + 0.0, c[1] + 0.0]]) AS yx,
               unnest([1, 2]) AS slot
        FROM located) a,
       gtfs_vr_shapes_java_atan2(a.yx[1], a.yx[2]) j
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
