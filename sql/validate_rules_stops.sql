-- Validation rules for stops.txt and pathways.txt (stops workstream).
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*; the entry point
-- gtfs_validate_rules_stops() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.
--
-- Ports of the MobilityData validators (f9f4b9e, main/.../validator/): BidirectionalExitGateValidator,
-- ParentStationDistanceValidator, PathwayModeFieldsValidator, LocationHasStopTimesValidator,
-- LocationTypeSingleEntityValidator, StopNameValidator, ParentStationValidator, PathwayDanglingGenericNodeValidator,
-- PathwayLoopValidator, PathwayEndpointTypeValidator, PathwayStopAccessValidator, PathwayReachableLocationValidator,
-- UrlConsistencyValidator (stop/route URLs only), StopStationDistanceValidator, StopAccessValidator,
-- StopRequiredLocationValidator.
--
-- Java value semantics used throughout: locationType() is coalesce(location_type, 0) (an out-of-enum value is
-- UNRECOGNIZED and equals no constant); locationTypeValue() is the raw integer (0 when empty); String getters return ''
-- for an empty field, so notice fields built from them are coalesce(x, ''); stopTable.byStopId(id) is the FIRST entity
-- with that stop_id (the index keeps the first entity of a duplicated key). The oracle reports locationTypeValue()
-- of an out-of-enum location_type as -1 (UNRECOGNIZED's number), not as written (stops-parent-station, row SU).

-- S2Earth.isNearOriginOrPole(lat, lon).
CREATE OR REPLACE MACRO gtfs_vr_stops_near_origin_or_pole(p_lat, p_lon) AS (
  (abs(p_lat) <= 1.0 AND abs(p_lon) <= 1.0) OR abs(p_lat) >= 89.0
);

-- Ascii.toLowerCase: only A-Z are lowered.
CREATE OR REPLACE MACRO gtfs_vr_stops_ascii_lower(p_text) AS (
  translate(p_text, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')
);

-- stopTable.byStopId(): the first entity per stop_id.
CREATE OR REPLACE MACRO gtfs_vr_stops_first() AS TABLE
SELECT * FROM gtfs_v_stops
WHERE stop_id IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY stop_id ORDER BY csv_row_number) = 1;

-- StopUtil.getIncludingStation(stopTable, stop_id) for every stop_id: at most 3 byStopId lookups (the location, its
-- parent, its grandparent); the first STATION found is the including station.
CREATE OR REPLACE MACRO gtfs_vr_stops_including_station() AS TABLE
WITH f AS (SELECT stop_id, coalesce(location_type, 0) AS lt, parent_station FROM gtfs_vr_stops_first())
SELECT s0.stop_id,
  CASE WHEN s0.lt = 1 THEN s0.stop_id
       WHEN s1.lt = 1 THEN s1.stop_id
       WHEN s2.lt = 1 THEN s2.stop_id END AS station_id
FROM f s0
LEFT JOIN f s1 ON s1.stop_id = s0.parent_station AND s0.lt <> 1
LEFT JOIN f s2 ON s2.stop_id = s1.parent_station AND s1.lt <> 1;

-- ---------------------------------------------------------------- single-entity validators on stops.txt

-- LocationTypeSingleEntityValidator
CREATE OR REPLACE MACRO gtfs_vr_stops_location_type() AS TABLE
SELECT CASE WHEN parent_station IS NOT NULL THEN 'station_with_parent_station'
            WHEN coalesce(location_type, 0) = 0 THEN 'platform_without_parent_station'
            ELSE 'location_without_parent_station' END AS code,
  gtfs_validation_notice(CASE
    WHEN parent_station IS NOT NULL THEN json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
      'stopName', coalesce(stop_name, ''), 'parentStation', parent_station)
    WHEN coalesce(location_type, 0) = 0 THEN json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
      'stopName', coalesce(stop_name, ''))
    ELSE json_object('csvRowNumber', csv_row_number, 'stopId', stop_id, 'stopName', coalesce(stop_name, ''),
      'locationType', location_type) END) AS notice
FROM gtfs_v_stops
WHERE (parent_station IS NOT NULL AND coalesce(location_type, 0) = 1)
   OR (parent_station IS NULL AND coalesce(location_type, 0) = 0 AND coalesce(platform_code, '') <> '')
   OR (parent_station IS NULL AND coalesce(location_type, 0) IN (2, 3, 4));

-- StopNameValidator (shouldCallValidate: the header has stop_name or location_type)
CREATE OR REPLACE MACRO gtfs_vr_stops_name() AS TABLE
SELECT 'missing_stop_name' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
    'locationType', gtfs_validation_enum_name('GtfsLocationType', coalesce(location_type, 0)))) AS notice
FROM gtfs_v_stops
WHERE coalesce(location_type, 0) IN (0, 1, 2) AND coalesce(stop_name, '') = ''
  AND (gtfs_validation_has_column('stops.txt', 'stop_name') OR gtfs_validation_has_column('stops.txt', 'location_type'))
UNION ALL
SELECT 'same_name_and_description_for_stop',
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id, 'stopDesc', stop_desc))
FROM gtfs_v_stops
WHERE stop_name IS NOT NULL AND stop_desc IS NOT NULL
  AND length(stop_name) = length(stop_desc) AND lower(stop_name) = lower(stop_desc)
  AND (gtfs_validation_has_column('stops.txt', 'stop_name') OR gtfs_validation_has_column('stops.txt', 'location_type'));

-- StopRequiredLocationValidator
CREATE OR REPLACE MACRO gtfs_vr_stops_required_location() AS TABLE
SELECT 'stop_without_location' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
    'locationType', gtfs_validation_enum_name('GtfsLocationType', coalesce(location_type, 0)))) AS notice
FROM gtfs_v_stops
WHERE coalesce(location_type, 0) IN (0, 1, 2) AND (stop_lat IS NULL OR stop_lon IS NULL);

-- StopAccessValidator (shouldCallValidate: the header has stop_access)
CREATE OR REPLACE MACRO gtfs_vr_stops_access() AS TABLE
SELECT CASE WHEN coalesce(location_type, 0) = 0 THEN 'stop_access_specified_for_stop_with_no_parent_station'
            ELSE 'stop_access_specified_for_incorrect_location' END AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
    'stopName', coalesce(stop_name, ''),
    'stopAccess', gtfs_validation_enum_name('GtfsStopAccess', stop_access),
    'locationType', gtfs_validation_enum_name('GtfsLocationType', coalesce(location_type, 0)))) AS notice
FROM gtfs_v_stops
WHERE stop_access IS NOT NULL
  AND (coalesce(location_type, 0) <> 0 OR parent_station IS NULL)
  AND gtfs_validation_has_column('stops.txt', 'stop_access');

-- ---------------------------------------------------------------- single-entity validators on pathways.txt

-- BidirectionalExitGateValidator
CREATE OR REPLACE MACRO gtfs_vr_stops_exit_gate() AS TABLE
SELECT 'bidirectional_exit_gate' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'pathwayMode', pathway_mode,
    'isBidirectional', is_bidirectional)) AS notice
FROM gtfs_v_pathways
WHERE pathway_mode = 7 AND is_bidirectional = 1;

-- PathwayModeFieldsValidator (UNRECOGNIZED pathway_mode is skipped)
CREATE OR REPLACE MACRO gtfs_vr_stops_pathway_mode_fields() AS TABLE
SELECT 'missing_recommended_field' AS code,
  gtfs_validation_notice(json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number,
    'fieldName', field_name)) AS notice
FROM (
  SELECT csv_row_number, 'length' AS field_name FROM gtfs_v_pathways
  WHERE pathway_mode IN (1, 6, 7) AND length IS NULL
  UNION ALL
  SELECT csv_row_number, 'stair_count' FROM gtfs_v_pathways
  WHERE pathway_mode = 2 AND stair_count IS NULL
  UNION ALL
  SELECT csv_row_number, 'traversal_time' FROM gtfs_v_pathways
  WHERE pathway_mode IN (3, 4, 5) AND traversal_time IS NULL
) m
UNION ALL
SELECT 'irrelevant_max_slope_set_for_pathway_mode',
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'pathwayId', pathway_id,
    'pathwayMode', pathway_mode, 'maxSlope', max_slope))
FROM gtfs_v_pathways
WHERE pathway_mode IN (2, 4, 5, 6, 7) AND max_slope IS NOT NULL AND max_slope <> 0;

-- PathwayLoopValidator
CREATE OR REPLACE MACRO gtfs_vr_stops_pathway_loop() AS TABLE
SELECT 'pathway_loop' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'pathwayId', pathway_id,
    'stopId', from_stop_id)) AS notice
FROM gtfs_v_pathways
WHERE from_stop_id IS NOT NULL AND to_stop_id IS NOT NULL AND from_stop_id = to_stop_id;

-- ---------------------------------------------------------------- file validators on stops.txt

-- ParentStationDistanceValidator (stops.txt)
CREATE OR REPLACE MACRO gtfs_vr_stops_parent_distance() AS TABLE
WITH d AS (
  SELECT c.stop_id AS child_id, c.stop_lat AS child_lat, c.stop_lon AS child_lon,
    p.stop_id AS parent_id, p.stop_lat AS parent_lat, p.stop_lon AS parent_lon,
    gtfs_validation_distance_m(c.stop_lat, c.stop_lon, p.stop_lat, p.stop_lon) AS distance_m
  FROM gtfs_v_stops c
  JOIN gtfs_vr_stops_first() p ON p.stop_id = c.parent_station
  WHERE coalesce(c.location_type, 0) = 0 AND c.stop_lat IS NOT NULL AND c.stop_lon IS NOT NULL
    AND NOT gtfs_vr_stops_near_origin_or_pole(c.stop_lat, c.stop_lon)
    AND coalesce(p.location_type, 0) = 1 AND p.stop_lat IS NOT NULL AND p.stop_lon IS NOT NULL
    AND NOT gtfs_vr_stops_near_origin_or_pole(p.stop_lat, p.stop_lon)
    AND gtfs_validation_parsed(['stops.txt'])
)
SELECT CASE WHEN distance_m > 10000.0 THEN 'child_stop_too_far_from_parent_station'
            ELSE 'child_stop_far_from_parent_station' END AS code,
  gtfs_validation_notice(json_object('childStopId', child_id, 'childStopLat', child_lat, 'childStopLon', child_lon,
    'parentStationId', parent_id, 'parentStationLat', parent_lat, 'parentStationLon', parent_lon,
    'distance', distance_m)) AS notice
FROM d
WHERE distance_m > 1000.0;

-- ParentStationValidator (stops.txt): parent_station_missing_timezone, wrong_parent_location_type, unused_station
CREATE OR REPLACE MACRO gtfs_vr_stops_parent_station() AS TABLE
WITH c AS (
  SELECT l.csv_row_number, l.stop_id, l.stop_name, coalesce(l.location_type, 0) AS lt, l.parent_station,
    l.stop_timezone, p.csv_row_number AS parent_row, p.stop_name AS parent_name,
    CASE WHEN coalesce(p.location_type, 0) BETWEEN 0 AND 4 THEN coalesce(p.location_type, 0) ELSE -1 END AS parent_lt,
    p.stop_timezone AS parent_timezone,
    CASE coalesce(l.location_type, 0) WHEN 0 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 0 END AS expected_lt
  FROM gtfs_v_stops l
  JOIN gtfs_vr_stops_first() p ON p.stop_id = l.parent_station
  WHERE coalesce(l.location_type, 0) <> 1 AND gtfs_validation_parsed(['stops.txt'])
),
used AS (SELECT DISTINCT parent_station AS station_id FROM c WHERE lt = 0),
unused AS (
  SELECT DISTINCT stop_id AS station_id FROM gtfs_v_stops
  WHERE coalesce(location_type, 0) = 1 AND gtfs_validation_parsed(['stops.txt'])
  EXCEPT SELECT station_id FROM used
)
SELECT 'parent_station_missing_timezone' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
    'stopTimezone', stop_timezone, 'parentCsvRowNumber', parent_row, 'parentStation', parent_station)) AS notice
FROM c WHERE stop_timezone IS NOT NULL AND parent_timezone IS NULL
UNION ALL
SELECT 'wrong_parent_location_type',
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
    'stopName', coalesce(stop_name, ''), 'locationType', lt, 'parentCsvRowNumber', parent_row,
    'parentStation', parent_station, 'parentStopName', coalesce(parent_name, ''),
    'parentLocationType', parent_lt, 'expectedLocationType', expected_lt))
FROM c WHERE expected_lt IS NOT NULL AND parent_lt <> expected_lt
UNION ALL
SELECT 'unused_station',
  gtfs_validation_notice(json_object('csvRowNumber', f.csv_row_number, 'stopId', f.stop_id,
    'stopName', coalesce(f.stop_name, '')))
FROM unused u JOIN gtfs_vr_stops_first() f ON f.stop_id = u.station_id;

-- StopStationDistanceValidator (stops.txt, levels.txt): stops and stations closer than 2 m. Candidate pairs come from
-- a grid on the unit sphere (cells of 1e-6, about 6.4 m, larger than the 2.1 m S2 query radius), so each location is
-- compared only with the locations of its 27 neighbouring cells. levels.txt is out of scope and treated as absent, so
-- shouldIgnoreByLevel never applies.
CREATE OR REPLACE MACRO gtfs_vr_stops_station_distance() AS TABLE
WITH locs AS (
  SELECT csv_row_number, stop_id, stop_lat, stop_lon, coalesce(location_type, 0) AS lt, parent_station,
    CAST(floor(cos(radians(stop_lat)) * cos(radians(stop_lon)) * 1e6) AS BIGINT) AS cx,
    CAST(floor(cos(radians(stop_lat)) * sin(radians(stop_lon)) * 1e6) AS BIGINT) AS cy,
    CAST(floor(sin(radians(stop_lat)) * 1e6) AS BIGINT) AS cz
  FROM gtfs_v_stops
  WHERE stop_lat IS NOT NULL AND stop_lon IS NOT NULL
    AND NOT gtfs_vr_stops_near_origin_or_pole(stop_lat, stop_lon)
    AND coalesce(location_type, 0) IN (0, 1)
    AND gtfs_validation_parsed(['stops.txt'])
),
offsets AS (
  SELECT a.o AS dx, b.o AS dy, c.o AS dz
  FROM (SELECT unnest([-1, 0, 1]) AS o) a, (SELECT unnest([-1, 0, 1]) AS o) b, (SELECT unnest([-1, 0, 1]) AS o) c
),
pairs AS (
  SELECT l1.csv_row_number AS row1, l1.stop_id AS id1, l1.stop_lat AS lat1, l1.stop_lon AS lon1, l1.lt AS lt1,
    l1.parent_station AS parent1,
    l2.csv_row_number AS row2, l2.stop_id AS id2, l2.stop_lat AS lat2, l2.stop_lon AS lon2, l2.lt AS lt2,
    l2.parent_station AS parent2
  FROM locs l1
  CROSS JOIN offsets o
  JOIN locs l2 ON l2.cx = l1.cx + o.dx AND l2.cy = l1.cy + o.dy AND l2.cz = l1.cz + o.dz
    AND l2.csv_row_number > l1.csv_row_number
  WHERE gtfs_validation_distance_m(l1.stop_lat, l1.stop_lon, l2.stop_lat, l2.stop_lon) < 2.0
)
SELECT CASE WHEN lt1 = 1 THEN 'stations_too_close' ELSE 'stops_too_close' END AS code,
  gtfs_validation_notice(json_object('csvRowNumber1', row1, 'stopId1', id1, 'stopLat1', lat1, 'stopLon1', lon1,
    'csvRowNumber2', row2, 'stopId2', id2, 'stopLat2', lat2, 'stopLon2', lon2)) AS notice
FROM pairs WHERE lt1 = lt2
UNION ALL
SELECT 'stop_too_close_to_non_parent_station',
  gtfs_validation_notice(CASE WHEN lt1 = 0
    THEN json_object('stopCsvRowNumber', row1, 'stopId', id1, 'stopLat', lat1, 'stopLon', lon1,
      'stationCsvRowNumber', row2, 'stationId', id2, 'stationLat', lat2, 'stationLon', lon2)
    ELSE json_object('stopCsvRowNumber', row2, 'stopId', id2, 'stopLat', lat2, 'stopLon', lon2,
      'stationCsvRowNumber', row1, 'stationId', id1, 'stationLat', lat1, 'stationLon', lon1) END)
FROM pairs
WHERE lt1 <> lt2
  AND CASE WHEN lt1 = 0 THEN coalesce(parent1, '') <> id2 ELSE coalesce(parent2, '') <> id1 END;

-- ---------------------------------------------------------------- multi-file validators

-- LocationHasStopTimesValidator (stops.txt, stop_times.txt; location_group_stops.txt is out of scope: no groups)
CREATE OR REPLACE MACRO gtfs_vr_stops_stop_times() AS TABLE
WITH st AS (
  SELECT stop_id AS st_stop_id, min(csv_row_number) AS first_row
  FROM gtfs_v_stop_times
  WHERE stop_id IS NOT NULL AND stop_id <> ''
  GROUP BY stop_id
)
SELECT CASE WHEN coalesce(s.location_type, 0) = 0 THEN 'stop_without_stop_time'
            ELSE 'location_with_unexpected_stop_time' END AS code,
  gtfs_validation_notice(json_object('csvRowNumber', s.csv_row_number, 'stopId', s.stop_id,
    'stopName', coalesce(s.stop_name, ''), 'stopTimeCsvRowNumber', st.first_row)) AS notice
FROM gtfs_v_stops s
LEFT JOIN st ON st.st_stop_id = s.stop_id
WHERE ((coalesce(s.location_type, 0) = 0 AND st.first_row IS NULL)
    OR (coalesce(s.location_type, 0) <> 0 AND st.first_row IS NOT NULL))
  AND gtfs_validation_parsed(['stops.txt', 'stop_times.txt']);

-- UrlConsistencyValidator, stop/route part (routes.txt, stops.txt; agency.txt is out of scope)
CREATE OR REPLACE MACRO gtfs_vr_stops_url() AS TABLE
SELECT 'same_stop_and_route_url' AS code,
  gtfs_validation_notice(json_object('stopCsvRowNumber', s.csv_row_number, 'stopId', s.stop_id,
    'stopUrl', s.stop_url, 'routeId', coalesce(r.route_id, ''), 'routeCsvRowNumber', r.csv_row_number)) AS notice
FROM gtfs_v_stops s
JOIN gtfs_v_routes r ON gtfs_vr_stops_ascii_lower(r.route_url) = gtfs_vr_stops_ascii_lower(s.stop_url)
WHERE s.stop_url IS NOT NULL AND r.route_url IS NOT NULL
  AND gtfs_validation_parsed(['routes.txt', 'stops.txt']);

-- PathwayDanglingGenericNodeValidator (pathways.txt, stops.txt)
CREATE OR REPLACE MACRO gtfs_vr_stops_dangling_node() AS TABLE
WITH incident AS (
  SELECT node_id FROM (
    SELECT from_stop_id AS node_id, to_stop_id AS other_id FROM gtfs_v_pathways
    UNION ALL
    SELECT to_stop_id, from_stop_id FROM gtfs_v_pathways
  ) e
  WHERE node_id IS NOT NULL
  GROUP BY node_id
  HAVING count(DISTINCT other_id) = 1
)
SELECT 'pathway_dangling_generic_node' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', s.csv_row_number, 'stopId', s.stop_id,
    'stopName', coalesce(s.stop_name, ''), 'parentStation', coalesce(s.parent_station, ''))) AS notice
FROM gtfs_v_stops s
JOIN incident i ON i.node_id = s.stop_id
WHERE coalesce(s.location_type, 0) = 3 AND gtfs_validation_parsed(['pathways.txt', 'stops.txt']);

-- PathwayEndpointTypeValidator (pathways.txt, stops.txt)
CREATE OR REPLACE MACRO gtfs_vr_stops_endpoint_type() AS TABLE
WITH ends AS (
  SELECT csv_row_number, pathway_id, 'from_stop_id' AS field_name, from_stop_id AS end_id FROM gtfs_v_pathways
  UNION ALL
  SELECT csv_row_number, pathway_id, 'to_stop_id', to_stop_id FROM gtfs_v_pathways
),
children AS (SELECT DISTINCT parent_station AS parent_id FROM gtfs_v_stops WHERE parent_station IS NOT NULL)
SELECT CASE WHEN coalesce(f.location_type, 0) = 1 THEN 'pathway_to_wrong_location_type'
            ELSE 'pathway_to_platform_with_boarding_areas' END AS code,
  gtfs_validation_notice(json_object('csvRowNumber', e.csv_row_number, 'pathwayId', coalesce(e.pathway_id, ''),
    'fieldName', e.field_name, 'stopId', e.end_id)) AS notice
FROM ends e
JOIN gtfs_vr_stops_first() f ON f.stop_id = e.end_id
LEFT JOIN children c ON c.parent_id = e.end_id
WHERE (coalesce(f.location_type, 0) = 1 OR (coalesce(f.location_type, 0) = 0 AND c.parent_id IS NOT NULL))
  AND gtfs_validation_parsed(['pathways.txt', 'stops.txt']);

-- PathwayStopAccessValidator (pathways.txt, stops.txt; shouldCallValidate: stops.txt has stop_access). The
-- stop_id -> platform_code map is a HashMap filled in entity order: the last entity of a stop_id wins.
CREATE OR REPLACE MACRO gtfs_vr_stops_pathway_access() AS TABLE
WITH ext AS (
  SELECT stop_id AS ext_id, arg_max(coalesce(platform_code, ''), csv_row_number) AS ext_platform_code
  FROM gtfs_v_stops
  WHERE stop_access = 1 AND stop_id IS NOT NULL
  GROUP BY stop_id
),
ends AS (
  SELECT csv_row_number, pathway_id, from_stop_id AS end_id FROM gtfs_v_pathways
  UNION ALL
  SELECT csv_row_number, pathway_id, to_stop_id FROM gtfs_v_pathways
  WHERE from_stop_id IS NULL OR to_stop_id IS DISTINCT FROM from_stop_id
)
SELECT 'pathway_to_stop_with_access_outside_of_station_pathways' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', e.csv_row_number, 'platformCode', x.ext_platform_code,
    'pathwayId', coalesce(e.pathway_id, ''), 'stopId', e.end_id)) AS notice
FROM ends e
JOIN ext x ON x.ext_id = e.end_id
WHERE trim(e.end_id) <> ''
  AND gtfs_validation_has_column('stops.txt', 'stop_access')
  AND gtfs_validation_parsed(['pathways.txt', 'stops.txt']);

-- PathwayReachableLocationValidator (pathways.txt, stops.txt): breadth-first searches from every entrance, forward
-- (FROM_ENTRANCES) and backward (TO_EXITS); a bidirectional pathway is walked both ways in both searches. UNION in
-- the recursive CTEs keeps each stop_id once, so each search visits every location at most once.
CREATE OR REPLACE MACRO gtfs_vr_stops_reachable() AS TABLE
WITH RECURSIVE
edges_in AS (
  SELECT from_stop_id AS src_id, to_stop_id AS dst_id FROM gtfs_v_pathways
  UNION ALL
  SELECT to_stop_id, from_stop_id FROM gtfs_v_pathways WHERE is_bidirectional = 1
),
edges_out AS (
  SELECT to_stop_id AS src_id, from_stop_id AS dst_id FROM gtfs_v_pathways
  UNION ALL
  SELECT from_stop_id, to_stop_id FROM gtfs_v_pathways WHERE is_bidirectional = 1
),
from_entrances(visited_id) AS (
  SELECT stop_id FROM gtfs_v_stops WHERE coalesce(location_type, 0) = 2 AND stop_id IS NOT NULL
  UNION
  SELECT e.dst_id FROM from_entrances v JOIN edges_in e ON e.src_id = v.visited_id WHERE e.dst_id IS NOT NULL
),
to_exits(visited_id) AS (
  SELECT stop_id FROM gtfs_v_stops WHERE coalesce(location_type, 0) = 2 AND stop_id IS NOT NULL
  UNION
  SELECT e.dst_id FROM to_exits v JOIN edges_out e ON e.src_id = v.visited_id WHERE e.dst_id IS NOT NULL
),
incl AS (SELECT * FROM gtfs_vr_stops_including_station()),
stations_with_pathways AS (
  SELECT DISTINCT i.station_id
  FROM (SELECT from_stop_id AS end_id FROM gtfs_v_pathways UNION SELECT to_stop_id FROM gtfs_v_pathways) p
  JOIN incl i ON i.stop_id = p.end_id
  WHERE i.station_id IS NOT NULL
),
children AS (SELECT DISTINCT parent_station AS parent_id FROM gtfs_v_stops WHERE parent_station IS NOT NULL),
candidates AS (
  SELECT s.csv_row_number, s.stop_id, s.stop_name, s.location_type, s.parent_station,
    s.stop_id IN (SELECT visited_id FROM from_entrances) AS has_entrance,
    s.stop_id IN (SELECT visited_id FROM to_exits) AS has_exit
  FROM gtfs_v_stops s
  JOIN incl i ON i.stop_id = s.stop_id
  JOIN stations_with_pathways w ON w.station_id = i.station_id
  LEFT JOIN children c ON c.parent_id = s.stop_id
  WHERE (coalesce(s.location_type, 0) IN (3, 4) OR (coalesce(s.location_type, 0) = 0 AND c.parent_id IS NULL))
    AND gtfs_validation_parsed(['pathways.txt', 'stops.txt'])
)
SELECT 'pathway_unreachable_location' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', csv_row_number, 'stopId', stop_id,
    'stopName', coalesce(stop_name, ''), 'locationType', coalesce(location_type, 0),
    'parentStation', coalesce(parent_station, ''), 'hasEntrance', has_entrance, 'hasExit', has_exit)) AS notice
FROM candidates
WHERE NOT (has_entrance AND has_exit);

-- ---------------------------------------------------------------- entry point

CREATE OR REPLACE MACRO gtfs_validate_rules_stops() AS TABLE
SELECT code, notice FROM gtfs_vr_stops_location_type()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_name()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_required_location()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_access()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_exit_gate()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_pathway_mode_fields()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_pathway_loop()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_parent_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_parent_station()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_station_distance()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_stop_times()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_url()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_dangling_node()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_endpoint_type()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_pathway_access()
UNION ALL SELECT code, notice FROM gtfs_vr_stops_reachable();
