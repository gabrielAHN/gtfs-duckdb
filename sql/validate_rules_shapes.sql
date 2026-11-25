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
-- the fdlibm intrinsic of macroAssembler_aarch64_trig.cpp (with fused multiply-adds), Math.atan2 is fdlibm e_atan2.c.
-- Notice fields of type S2LatLng are compared exactly, so the S2Point round trip must match Java to the last bit.
-- Every macro binds its arguments once with a one-element list_transform so nested calls do not expand exponentially.

-- fma(a, b, c) rounded once (Dekker's exact product, then Boldo-Melquiond's round-to-odd emulation).
CREATE OR REPLACE MACRO gtfs_vr_shapes_fma(p_fa, p_fb, p_fc) AS (
  list_transform([[p_fa::DOUBLE, p_fb::DOUBLE, p_fc::DOUBLE]], lambda fv:
    list_transform([[fv[1] * fv[2], 134217729.0e0 * fv[1], 134217729.0e0 * fv[2]]], lambda fq:
      list_transform([[fq[2] - (fq[2] - fv[1]), fq[3] - (fq[3] - fv[2])]], lambda fh:
        list_transform([[fq[1],
                         (fv[1] - fh[1]) * (fv[2] - fh[2])
                           - (((fq[1] - fh[1] * fh[2]) - (fv[1] - fh[1]) * fh[2]) - fh[1] * (fv[2] - fh[2])),
                         fv[3] + fq[1]]], lambda fe:
          list_transform([[fe[3], (fv[3] - (fe[3] - (fe[3] - fv[3]))) + (fe[1] - (fe[3] - fv[3])), fe[2]]], lambda ft:
            list_transform([[ft[2] + ft[3]]], lambda fs:
              list_transform([[(ft[2] - (fs[1] - (fs[1] - ft[2]))) + (ft[3] - (fs[1] - ft[2]))]], lambda fx:
                ft[1] + CASE WHEN fx[1] = 0
                               OR (abs(fs[1]) / (nextafter(abs(fs[1]), 'inf'::DOUBLE) - abs(fs[1]))) % 2 = 1
                             THEN fs[1]
                             ELSE nextafter(fs[1], CASE WHEN fx[1] > 0 THEN 'inf'::DOUBLE ELSE '-inf'::DOUBLE END) END
              )[1])[1])[1])[1])[1])[1])[1]
);

-- High 32 bits of |d| as fdlibm reads them (sign cleared), 0 for 0. Normal numbers only.
CREATE OR REPLACE MACRO gtfs_vr_shapes_hiword(p_hd) AS (
  list_transform([[abs(p_hd::DOUBLE)]], lambda hv:
    CASE WHEN hv[1] = 0 THEN 0::BIGINT ELSE
    list_transform([[floor(log2(hv[1]))]], lambda he:
      list_transform([[CASE WHEN pow(2.0, he[1]) > hv[1] THEN he[1] - 1
                            WHEN pow(2.0, he[1] + 1) <= hv[1] THEN he[1] + 1 ELSE he[1] END]], lambda hc:
        ((hc[1] + 1023) * 1048576 + floor((hv[1] / pow(2.0, hc[1]) - 1) * 1048576))::BIGINT)[1])[1] END)[1]
);

-- The double whose high word is p_hw and low word 0.
CREATE OR REPLACE MACRO gtfs_vr_shapes_from_hiword(p_hw) AS (
  (1.0 + (p_hw % 1048576) / 1048576.0) * pow(2.0, (p_hw // 1048576) - 1023)
);

CREATE OR REPLACE MACRO gtfs_vr_shapes_kernel_sin(p_kx, p_ky, p_kiy) AS (
  list_transform([[p_kx::DOUBLE, p_ky::DOUBLE, p_kx::DOUBLE * p_kx::DOUBLE, p_kiy::DOUBLE]], lambda kv:
    list_transform([[kv[3] * kv[1],
                     gtfs_vr_shapes_fma(kv[3], gtfs_vr_shapes_fma(kv[3], gtfs_vr_shapes_fma(kv[3],
                       gtfs_vr_shapes_fma(kv[3], '1.58969099521155e-10'::DOUBLE, '-2.5050760253406863e-08'::DOUBLE), '2.7557313707070068e-06'::DOUBLE), '-0.0001984126982985795'::DOUBLE), '0.00833333333332249'::DOUBLE)]], lambda kr:
      CASE WHEN kv[4] = 0 THEN gtfs_vr_shapes_fma(kr[1], gtfs_vr_shapes_fma(kv[3], kr[2], '-0.16666666666666632'::DOUBLE), kv[1])
           ELSE kv[1] + gtfs_vr_shapes_fma(kr[1], '-0.16666666666666632'::DOUBLE,
                  gtfs_vr_shapes_fma(-kv[3], gtfs_vr_shapes_fma(-kr[1], kr[2], 0.5e0 * kv[2]), kv[2])) END
    )[1])[1]
);

-- p_kix is the high word of the ORIGINAL argument: the aarch64 intrinsic keeps it after argument reduction.
CREATE OR REPLACE MACRO gtfs_vr_shapes_kernel_cos(p_kx, p_ky, p_kix) AS (
  list_transform([[p_kx::DOUBLE, p_ky::DOUBLE, p_kx::DOUBLE * p_kx::DOUBLE, p_kix::DOUBLE]], lambda cv:
    list_transform([[gtfs_vr_shapes_fma(cv[3], gtfs_vr_shapes_fma(cv[3], gtfs_vr_shapes_fma(cv[3],
                       gtfs_vr_shapes_fma(cv[3], gtfs_vr_shapes_fma(cv[3], '-1.1359647557788195e-11'::DOUBLE, '2.087572321298175e-09'::DOUBLE), '-2.7557314351390663e-07'::DOUBLE), '2.480158728947673e-05'::DOUBLE), '-0.001388888888887411'::DOUBLE), '0.0416666666666666'::DOUBLE),
                     cv[1] * cv[2], cv[3] * cv[3]]], lambda cr:
      CASE WHEN cv[4] <= 1070805811 THEN
             1.0e0 - gtfs_vr_shapes_fma(0.5e0, cv[3], gtfs_vr_shapes_fma(-cr[3], cr[1], cr[2]))
           ELSE list_transform([[CASE WHEN cv[4] > 1072234496 THEN 0.28125e0
                                      ELSE gtfs_vr_shapes_from_hiword(cv[4]::BIGINT - 2097152) END]], lambda cq:
                  (1.0e0 - cq[1]) - (gtfs_vr_shapes_fma(0.5e0, cv[3], -cq[1]) - gtfs_vr_shapes_fma(cr[3], cr[1], -cr[2]))
                )[1] END
    )[1])[1]
);

-- __ieee754_rem_pio2 for pi/4 < |x| <= 2^19*pi/2 as [n, y0, y1].
CREATE OR REPLACE MACRO gtfs_vr_shapes_rem_pio2(p_rx, p_rix) AS (
  list_transform([[p_rx::DOUBLE, p_rix::DOUBLE]], lambda rv:
    CASE WHEN rv[2] < 1073928572 THEN
      CASE WHEN rv[1] > 0 THEN
        CASE WHEN rv[2] <> 1073291771 THEN
          list_transform([[rv[1] - '1.5707963267341256'::DOUBLE]], lambda rz: list_transform([[rz[1] - '6.077100506506192e-11'::DOUBLE]], lambda ry:
            [1.0e0, ry[1], (rz[1] - ry[1]) - '6.077100506506192e-11'::DOUBLE])[1])[1]
        ELSE
          list_transform([[(rv[1] - '1.5707963267341256'::DOUBLE) - '6.077100506303966e-11'::DOUBLE]], lambda rz: list_transform([[rz[1] - '2.0222662487959506e-21'::DOUBLE]], lambda ry:
            [1.0e0, ry[1], (rz[1] - ry[1]) - '2.0222662487959506e-21'::DOUBLE])[1])[1] END
      ELSE
        CASE WHEN rv[2] <> 1073291771 THEN
          list_transform([[rv[1] + '1.5707963267341256'::DOUBLE]], lambda rz: list_transform([[rz[1] + '6.077100506506192e-11'::DOUBLE]], lambda ry:
            [-1.0e0, ry[1], (rz[1] - ry[1]) + '6.077100506506192e-11'::DOUBLE])[1])[1]
        ELSE
          list_transform([[(rv[1] + '1.5707963267341256'::DOUBLE) + '6.077100506303966e-11'::DOUBLE]], lambda rz: list_transform([[rz[1] + '2.0222662487959506e-21'::DOUBLE]], lambda ry:
            [-1.0e0, ry[1], (rz[1] - ry[1]) + '2.0222662487959506e-21'::DOUBLE])[1])[1] END
      END
    ELSE
      list_transform([[trunc(gtfs_vr_shapes_fma(abs(rv[1]), '0.6366197723675814'::DOUBLE, 0.5e0))]], lambda rn:
        list_transform([[gtfs_vr_shapes_fma(-rn[1], '1.5707963267341256'::DOUBLE, abs(rv[1])), rn[1] * '6.077100506506192e-11'::DOUBLE]], lambda r1:
          list_transform([CASE WHEN rn[1] <= 32 AND rv[2] <> [1073291771, 1074340347, 1074977148, 1075388923, 1075800698, 1076025724, 1076231611, 1076437499, 1076643386, 1076849274, 1076971356, 1077074300, 1077177244, 1077280187, 1077383131, 1077486075, 1077589019, 1077691962, 1077794906, 1077897850, 1077968460, 1078019932, 1078071404, 1078122876, 1078174348, 1078225820, 1078277292, 1078328763, 1078380235, 1078431707, 1078483179, 1078534651][rn[1]::INTEGER] THEN r1
                               WHEN (rv[2]::BIGINT // 1048576) - (gtfs_vr_shapes_hiword(r1[1] - r1[2]) // 1048576) <= 16
                               THEN r1
                               ELSE list_transform([[r1[1], rn[1] * '6.077100506303966e-11'::DOUBLE]], lambda r2a:
                                      list_transform([[r2a[1] - r2a[2]]], lambda r2b:
                                        [r2b[1], gtfs_vr_shapes_fma(rn[1], '2.0222662487959506e-21'::DOUBLE, r2a[2] - (r2a[1] - r2b[1]))]
                                      )[1])[1] END], lambda r2:
            list_transform([CASE WHEN r2 = r1 THEN r2
                                 WHEN (rv[2]::BIGINT // 1048576) - (gtfs_vr_shapes_hiword(r2[1] - r2[2]) // 1048576) <= 49
                                 THEN r2
                                 ELSE list_transform([[r2[1], rn[1] * '2.0222662487111665e-21'::DOUBLE]], lambda r3a:
                                        list_transform([[r3a[1] - r3a[2]]], lambda r3b:
                                          [r3b[1], gtfs_vr_shapes_fma(rn[1], '8.4784276603689e-32'::DOUBLE, r3a[2] - (r3a[1] - r3b[1]))]
                                        )[1])[1] END], lambda r3:
              list_transform([[r3[1] - r3[2]]], lambda ry:
                CASE WHEN rv[1] > 0 THEN [rn[1], ry[1], (r3[1] - ry[1]) - r3[2]]
                     ELSE [-rn[1], -ry[1], -((r3[1] - ry[1]) - r3[2])] END)[1]
            )[1])[1])[1])[1]
    END)[1]
);

-- Java Math.sin / Math.cos.
CREATE OR REPLACE MACRO gtfs_vr_shapes_sin(p_sx) AS (
  list_transform([[p_sx::DOUBLE, gtfs_vr_shapes_hiword(p_sx)::DOUBLE]], lambda sv:
    CASE WHEN sv[2] < 1044381696 THEN sv[1]
         WHEN sv[2] <= 1072243195 THEN gtfs_vr_shapes_kernel_sin(sv[1], 0.0e0, 0)
         ELSE list_transform([gtfs_vr_shapes_rem_pio2(sv[1], sv[2])], lambda sr:
                CASE ((sr[1]::BIGINT % 4) + 4) % 4
                  WHEN 0 THEN gtfs_vr_shapes_kernel_sin(sr[2], sr[3], 1)
                  WHEN 1 THEN gtfs_vr_shapes_kernel_cos(sr[2], sr[3], sv[2])
                  WHEN 2 THEN -gtfs_vr_shapes_kernel_sin(sr[2], sr[3], 1)
                  ELSE -gtfs_vr_shapes_kernel_cos(sr[2], sr[3], sv[2]) END)[1] END)[1]
);

CREATE OR REPLACE MACRO gtfs_vr_shapes_cos(p_cx) AS (
  list_transform([[p_cx::DOUBLE, gtfs_vr_shapes_hiword(p_cx)::DOUBLE]], lambda sv:
    CASE WHEN sv[2] < 1044381696 THEN 1.0e0
         WHEN sv[2] <= 1072243195 THEN gtfs_vr_shapes_kernel_cos(sv[1], 0.0e0, sv[2])
         ELSE list_transform([gtfs_vr_shapes_rem_pio2(sv[1], sv[2])], lambda sr:
                CASE ((sr[1]::BIGINT % 4) + 4) % 4
                  WHEN 0 THEN gtfs_vr_shapes_kernel_cos(sr[2], sr[3], sv[2])
                  WHEN 1 THEN -gtfs_vr_shapes_kernel_sin(sr[2], sr[3], 1)
                  WHEN 2 THEN -gtfs_vr_shapes_kernel_cos(sr[2], sr[3], sv[2])
                  ELSE gtfs_vr_shapes_kernel_sin(sr[2], sr[3], 1) END)[1] END)[1]
);

-- fdlibm atan(x) for 2^-27 <= |x| < 2^66: the polynomial part shared by all cases.
CREATE OR REPLACE MACRO gtfs_vr_shapes_atan_sum(p_ax) AS (
  list_transform([[p_ax::DOUBLE * p_ax::DOUBLE]], lambda az:
    list_transform([[az[1] * az[1]]], lambda aw:
      az[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][1] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][3] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][5] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][7] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][9] + aw[1] * ['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][11])))))
      + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][2] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][4] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][6] + aw[1] * (['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][8] + aw[1] * ['0.3333333333333293'::DOUBLE, '-0.19999999999876483'::DOUBLE, '0.14285714272503466'::DOUBLE, '-0.11111110405462356'::DOUBLE, '0.09090887133436507'::DOUBLE, '-0.0769187620504483'::DOUBLE, '0.06661073137387531'::DOUBLE, '-0.058335701337905735'::DOUBLE, '0.049768779946159324'::DOUBLE, '-0.036531572744216916'::DOUBLE, '0.016285820115365782'::DOUBLE][10]))))
    )[1])[1]
);

CREATE OR REPLACE MACRO gtfs_vr_shapes_atan(p_tx) AS (
  list_transform([[p_tx::DOUBLE, gtfs_vr_shapes_hiword(p_tx)::DOUBLE, abs(p_tx::DOUBLE)]], lambda av:
    CASE WHEN av[2] >= 1141899264 THEN CASE WHEN av[1] > 0 THEN ['0.4636476090008061'::DOUBLE, '0.7853981633974483'::DOUBLE, '0.982793723247329'::DOUBLE, '1.5707963267948966'::DOUBLE][4] + ['2.2698777452961687e-17'::DOUBLE, '3.061616997868383e-17'::DOUBLE, '1.3903311031230998e-17'::DOUBLE, '6.123233995736766e-17'::DOUBLE][4]
                                            ELSE -['0.4636476090008061'::DOUBLE, '0.7853981633974483'::DOUBLE, '0.982793723247329'::DOUBLE, '1.5707963267948966'::DOUBLE][4] - ['2.2698777452961687e-17'::DOUBLE, '3.061616997868383e-17'::DOUBLE, '1.3903311031230998e-17'::DOUBLE, '6.123233995736766e-17'::DOUBLE][4] END
         WHEN av[2] < 1042284544 THEN av[1]
         WHEN av[2] < 1071382528 THEN av[1] - av[1] * gtfs_vr_shapes_atan_sum(av[1])
         ELSE list_transform([CASE WHEN av[2] < 1072037888 THEN [1, (2.0e0 * av[3] - 1.0e0) / (2.0e0 + av[3])]
                                   WHEN av[2] < 1072889856 THEN [2, (av[3] - 1.0e0) / (av[3] + 1.0e0)]
                                   WHEN av[2] < 1073971200 THEN [3, (av[3] - 1.5e0) / (1.0e0 + 1.5e0 * av[3])]
                                   ELSE [4, -1.0e0 / av[3]] END], lambda ai:
                list_transform([[['0.4636476090008061'::DOUBLE, '0.7853981633974483'::DOUBLE, '0.982793723247329'::DOUBLE, '1.5707963267948966'::DOUBLE][ai[1]::INTEGER]
                                 - ((ai[2] * gtfs_vr_shapes_atan_sum(ai[2]) - ['2.2698777452961687e-17'::DOUBLE, '3.061616997868383e-17'::DOUBLE, '1.3903311031230998e-17'::DOUBLE, '6.123233995736766e-17'::DOUBLE][ai[1]::INTEGER]) - ai[2])]],
                               lambda ar: CASE WHEN av[1] < 0 THEN -ar[1] ELSE ar[1] END)[1])[1] END)[1]
);

-- Java Math.atan2(y, x) (fdlibm) for finite arguments.
CREATE OR REPLACE MACRO gtfs_vr_shapes_atan2(p_ty, p_tx) AS (
  list_transform([[p_ty::DOUBLE, p_tx::DOUBLE]], lambda tv:
    CASE WHEN tv[2] = 1.0e0 THEN gtfs_vr_shapes_atan(tv[1])
         WHEN tv[1] = 0 THEN CASE WHEN tv[2] < 0 THEN '3.141592653589793'::DOUBLE ELSE tv[1] END
         WHEN tv[2] = 0 THEN CASE WHEN tv[1] < 0 THEN -'1.5707963267948966'::DOUBLE ELSE '1.5707963267948966'::DOUBLE END
         ELSE list_transform([[floor((gtfs_vr_shapes_hiword(tv[1]) - gtfs_vr_shapes_hiword(tv[2])) / 1048576.0e0)]],
                lambda tk:
                list_transform([[CASE WHEN tk[1] > 60 THEN '1.5707963267948966'::DOUBLE + 0.5e0 * '1.2246467991473532e-16'::DOUBLE
                                      WHEN tv[2] < 0 AND tk[1] < -60 THEN 0.0e0
                                      ELSE gtfs_vr_shapes_atan(abs(tv[1] / tv[2])) END]], lambda tz:
                  CASE WHEN tv[2] > 0 THEN CASE WHEN tv[1] < 0 THEN -tz[1] ELSE tz[1] END
                       WHEN tv[1] > 0 THEN '3.141592653589793'::DOUBLE - (tz[1] - '1.2246467991473532e-16'::DOUBLE)
                       ELSE (tz[1] - '1.2246467991473532e-16'::DOUBLE) - '3.141592653589793'::DOUBLE END)[1])[1] END)[1]
);

-- ShapeToStopMatchingValidator (util/shape/*). S2 points are unit vectors (S2LatLng.toPoint), S2Point.angle(a, b) is
-- atan2(|a x b|, a . b) and S2Earth.getDistanceMeters(S2Point, S2Point) is that angle times 6,371,010 m.
CREATE OR REPLACE MACRO gtfs_vr_shapes_angle(p_ax, p_ay, p_az, p_bx, p_by, p_bz) AS (
  atan2(sqrt((p_ay * p_bz - p_az * p_by) * (p_ay * p_bz - p_az * p_by)
           + (p_az * p_bx - p_ax * p_bz) * (p_az * p_bx - p_ax * p_bz)
           + (p_ax * p_by - p_ay * p_bx) * (p_ax * p_by - p_ay * p_bx)),
        p_ax * p_bx + p_ay * p_by + p_az * p_bz)
);

-- new S2LatLng(S2Point) in degrees, as notices write it: [lat, lng].
CREATE OR REPLACE MACRO gtfs_vr_shapes_point_latlng(p_x, p_y, p_z) AS (
  [gtfs_vr_shapes_atan2(p_z + 0.0, sqrt(p_x * p_x + p_y * p_y)) * 57.29577951308232,
   gtfs_vr_shapes_atan2(p_y + 0.0, p_x + 0.0) * 57.29577951308232]
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
       gtfs_vr_shapes_cos(theta) * gtfs_vr_shapes_cos(phi) AS x, gtfs_vr_shapes_sin(theta) * gtfs_vr_shapes_cos(phi) AS y,
       gtfs_vr_shapes_sin(phi) AS z
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
      THEN {'k': el.k, 'cands': el.cands, 'assigns': nx, 'fail': NULL::BIGINT, 'fm': NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE), 'pm': NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE)}
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
         gtfs_vr_shapes_cos(s_lon * 0.017453292519943295) * gtfs_vr_shapes_cos(s_lat * 0.017453292519943295) AS s_x,
         gtfs_vr_shapes_sin(s_lon * 0.017453292519943295) * gtfs_vr_shapes_cos(s_lat * 0.017453292519943295) AS s_y,
         gtfs_vr_shapes_sin(s_lat * 0.017453292519943295) AS s_z
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
          'x': c_x, 'y': c_y, 'z': c_z} AS m
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
                      'x': p.x, 'y': p.y, 'z': p.z}
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
         gtfs_vr_shapes_atan2(
           sqrt((pa.y * pb.z - pa.z * pb.y) * (pa.y * pb.z - pa.z * pb.y)
              + (pa.z * pb.x - pa.x * pb.z) * (pa.z * pb.x - pa.x * pb.z)
              + (pa.x * pb.y - pa.y * pb.x) * (pa.x * pb.y - pa.y * pb.x)),
           pa.x * pb.x + pa.y * pb.y + pa.z * pb.z) AS ab
  FROM user_vertex uv
  JOIN pts pa ON pa.shape_id = uv.shape_id AND pa.idx = uv.prev_idx
  JOIN pts pb ON pb.shape_id = uv.shape_id AND pb.idx = uv.next_idx
), user_loc AS (
  -- ShapePoints.interpolate: S2EdgeUtil.interpolate(f, a, b) unless the vertices are S2.approxEquals (1e-15 rad).
  SELECT *,
         CASE WHEN ab <= 1e-15 OR f = 0 THEN 0.0 WHEN f = 1 THEN 1.0
              ELSE gtfs_vr_shapes_sin(f * ab) / gtfs_vr_shapes_sin(ab) END AS wb,
         CASE WHEN ab <= 1e-15 OR f = 0 THEN 1.0 WHEN f = 1 THEN 0.0
              ELSE gtfs_vr_shapes_cos(f * ab)
                   - gtfs_vr_shapes_sin(f * ab) / gtfs_vr_shapes_sin(ab) * gtfs_vr_shapes_cos(ab) END AS wa
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
                       'd': gtfs_vr_shapes_angle(cos(s_lon * (pi() / 180)) * cos(s_lat * (pi() / 180)),
                                                 sin(s_lon * (pi() / 180)) * cos(s_lat * (pi() / 180)),
                                                 sin(s_lat * (pi() / 180)), q_x * q_inv, q_y * q_inv, q_z * q_inv) * 6371010.0,
                       'x': q_x * q_inv, 'y': q_y * q_inv, 'z': q_z * q_inv} AS m
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
           {'k': -1::BIGINT, 'cands': []::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE)[],
            'assigns': [{'score': 0.0::DOUBLE, 'maxg': 0.0::DOUBLE,
                         'path': []::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE)[]}],
            'fail': NULL::BIGINT, 'fm': NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE),
            'pm': NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE)},
           list({'k': k::BIGINT, 'cands': mcands,
                 'assigns': []::STRUCT(score DOUBLE, maxg DOUBLE, path STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE)[])[],
                 'fail': NULL::BIGINT, 'fm': NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE),
                 'pm': NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE)} ORDER BY k)),
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
  SELECT trip_row, mode, phase, k, kind, m, cnt, NULL::STRUCT(g DOUBLE, d DOUBLE, x DOUBLE, y DOUBLE, z DOUBLE) AS pm
  FROM cand_problems
  UNION ALL SELECT trip_row, mode, phase, k, kind, m, cnt, pm FROM order_problems
  UNION ALL SELECT trip_row, mode, 2, km.k, 'far', km.m, 0, NULL FROM user_checks WHERE km.m.d > 100.0
)
SELECT p.*, js.trip_id, js.shape_id, js.st_row, js.stop_id, js.stop_name,
       pv.st_row AS prev_st_row, pv.stop_id AS prev_stop_id, pv.stop_name AS prev_stop_name
FROM problems p
JOIN job_stops js ON js.trip_row = p.trip_row AND js.k = p.k
LEFT JOIN job_stops pv ON p.kind = 'order' AND pv.trip_row = p.trip_row AND pv.k = p.k - 1
WHERE js.stop_id <> '';

CREATE OR REPLACE MACRO gtfs_vr_shapes_stop_matching_notices() AS TABLE
WITH p AS (
  SELECT *, row_number() OVER (PARTITION BY shape_id, stop_id, kind = 'far' ORDER BY trip_row, mode, phase, k) AS nth
  FROM gtfs_vr_shapes_stop_matching()
  WHERE gtfs_validation_parsed(['stops.txt', 'trips.txt', 'routes.txt', 'stop_times.txt', 'shapes.txt'])
    AND EXISTS (SELECT 1 FROM gtfs_v_stops) AND EXISTS (SELECT 1 FROM gtfs_v_trips)
    AND EXISTS (SELECT 1 FROM gtfs_v_stop_times) AND EXISTS (SELECT 1 FROM gtfs_v_shapes)
)
SELECT CASE WHEN kind = 'far' AND mode = 0 THEN 'stop_too_far_from_shape'
            WHEN kind = 'far' THEN 'stop_too_far_from_shape_using_user_distance'
            WHEN kind = 'many' THEN 'stop_has_too_many_matches_for_shape'
            ELSE 'stops_match_shape_out_of_order' END AS code,
       CASE WHEN kind = 'order' THEN gtfs_validation_notice(json_object(
              'tripCsvRowNumber', trip_row, 'shapeId', shape_id, 'tripId', trip_id,
              'stopTimeCsvRowNumber1', st_row, 'stopId1', stop_id, 'stopName1', stop_name, 'match1', gtfs_vr_shapes_point_latlng(m.x, m.y, m.z),
              'stopTimeCsvRowNumber2', prev_st_row, 'stopId2', prev_stop_id, 'stopName2', prev_stop_name,
              'match2', gtfs_vr_shapes_point_latlng(pm.x, pm.y, pm.z)))
            ELSE gtfs_validation_notice(json_object(
              'tripCsvRowNumber', trip_row, 'shapeId', shape_id, 'tripId', trip_id, 'stopTimeCsvRowNumber', st_row,
              'stopId', stop_id, 'stopName', stop_name, 'match', gtfs_vr_shapes_point_latlng(m.x, m.y, m.z),
              'geoDistanceToShape', CASE WHEN kind = 'far' THEN m.d END,
              'matchCount', CASE WHEN kind = 'many' THEN cnt END)) END AS notice
FROM p
WHERE kind <> 'far' OR nth = 1;

CREATE OR REPLACE MACRO gtfs_validate_rules_shapes() AS TABLE
SELECT code, notice FROM gtfs_vr_shapes_missing_file()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_stop_matching_notices()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_increasing_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_single_point()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_unused()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_trip_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_shapes_trip_dist_no_shape_dist();
