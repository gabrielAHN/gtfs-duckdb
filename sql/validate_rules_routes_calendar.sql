-- Validation rules for routes.txt, calendar.txt, calendar_dates.txt and blocks (routescal workstream).
-- Macro section: only CREATE OR REPLACE MACRO statements. Helper macros are named gtfs_vr_<group>_*; the entry point
-- gtfs_validate_rules_routes_calendar() returns (code VARCHAR, notice JSON), one row per notice. See docs/validation-internals.md.
--
-- Ported from MobilityData gtfs-validator f9f4b9e (main/.../validator/):
--   RouteNameValidator, DuplicateRouteNameValidator, RouteColorContrastValidator, ServiceSpreadValidator
--   (util/ServiceIntervalCache + ServiceInterval), ExpiredCalendarValidator (util/CalendarUtil + ServicePeriod),
--   MissingCalendarAndCalendarDateValidator, ServiceHasNoActiveDayOfTheWeekValidator,
--   BlockTripsWithOverlappingStopTimesValidator (util/ServiceIdIntersectionCache), GtfsTripServiceIdForeignKeyValidator.

-- GtfsRouteType.getNumber(): the value for a known route type, UNRECOGNIZED (-1) otherwise.
CREATE OR REPLACE MACRO gtfs_vr_routescal_route_type_number(p_value) AS (
  CASE WHEN p_value IN (0, 1, 2, 3, 4, 5, 6, 7, 11, 12) THEN p_value ELSE -1 END
);

-- GtfsColor.rec601Luma(): (int) (0.30 * r + 0.59 * g + 0.11 * b) in double arithmetic (DOUBLE literals, not DECIMAL,
-- so 0x101010 gives 15 as in Java).
CREATE OR REPLACE MACRO gtfs_vr_routescal_luma(p_rgb) AS (
  CAST(trunc(0.30::DOUBLE * ((p_rgb >> 16) & 255) + 0.59::DOUBLE * ((p_rgb >> 8) & 255)
             + 0.11::DOUBLE * (p_rgb & 255)) AS INTEGER)
);

-- The calendar flag of the weekday of p_day (ISO day of week: 1 = Monday) among a calendar row's seven flags.
CREATE OR REPLACE MACRO gtfs_vr_routescal_pattern_day(p_day, p_mo, p_tu, p_we, p_th, p_fr, p_sa, p_su) AS (
  coalesce(CASE isodow(p_day) WHEN 1 THEN p_mo WHEN 2 THEN p_tu WHEN 3 THEN p_we WHEN 4 THEN p_th
                              WHEN 5 THEN p_fr WHEN 6 THEN p_sa ELSE p_su END, 0)
);

-- CalendarUtil.servicePeriodToServiceDatesMap(CalendarUtil.buildServicePeriodMap(calendar, calendar_dates)):
-- the active dates of each service. calendar.txt: the last row of a service_id wins (HashMap.put); start > end
-- becomes [start, start]; a day is active when (1 & raw flag) = 1. calendar_dates.txt: SERVICE_ADDED adds a date, any
-- other exception type removes it, and removals win over additions (ServicePeriod.toDates).
CREATE OR REPLACE MACRO gtfs_vr_routescal_service_dates() AS TABLE
WITH cal AS (
  SELECT c.* FROM gtfs_v_calendar c
  QUALIFY row_number() OVER (PARTITION BY c.service_id ORDER BY c.csv_row_number DESC) = 1
), cal_days AS (
  SELECT g.service_id, g.day
  FROM (
    SELECT c.service_id, c.monday, c.tuesday, c.wednesday, c.thursday, c.friday, c.saturday, c.sunday,
      CAST(unnest(generate_series(CAST(coalesce(c.start_date, DATE '1970-01-01') AS TIMESTAMP),
                                  CAST(greatest(coalesce(c.start_date, DATE '1970-01-01'),
                                                coalesce(c.end_date, DATE '1970-01-01')) AS TIMESTAMP),
                                  INTERVAL 1 DAY)) AS DATE) AS day
    FROM cal c
    WHERE ((coalesce(c.monday, 0) | coalesce(c.tuesday, 0) | coalesce(c.wednesday, 0) | coalesce(c.thursday, 0)
            | coalesce(c.friday, 0) | coalesce(c.saturday, 0) | coalesce(c.sunday, 0)) & 1) = 1
  ) g
  WHERE (gtfs_vr_routescal_pattern_day(g.day, g.monday, g.tuesday, g.wednesday, g.thursday, g.friday, g.saturday,
                                       g.sunday) & 1) = 1
)
SELECT service_id, day FROM (
  (SELECT service_id, day FROM cal_days
   UNION
   SELECT cd.service_id, cd.date FROM gtfs_v_calendar_dates cd WHERE cd.exception_type = 1)
  EXCEPT
  SELECT cd.service_id, cd.date FROM gtfs_v_calendar_dates cd WHERE cd.exception_type IS DISTINCT FROM 1
);

-- ServiceIntervalCache: the active dates of each service as ServiceSpreadValidator sees them. Every calendar.txt row
-- of a service adds its days (rows with start > end are skipped; the pattern takes the enum number, UNRECOGNIZED = -1,
-- so any non-zero flag is active); then calendar_dates.txt rows apply in file order, so the last SERVICE_ADDED /
-- SERVICE_REMOVED row of a date decides; other exception types are ignored.
CREATE OR REPLACE MACRO gtfs_vr_routescal_interval_dates() AS TABLE
WITH cal_days AS (
  SELECT g.service_id, g.day
  FROM (
    SELECT c.service_id, c.monday, c.tuesday, c.wednesday, c.thursday, c.friday, c.saturday, c.sunday,
      CAST(unnest(generate_series(CAST(c.start_date AS TIMESTAMP), CAST(c.end_date AS TIMESTAMP),
                                  INTERVAL 1 DAY)) AS DATE) AS day
    FROM gtfs_v_calendar c
    WHERE c.start_date IS NOT NULL AND c.end_date IS NOT NULL AND c.start_date <= c.end_date
      AND (coalesce(c.monday, 0) <> 0 OR coalesce(c.tuesday, 0) <> 0 OR coalesce(c.wednesday, 0) <> 0
           OR coalesce(c.thursday, 0) <> 0 OR coalesce(c.friday, 0) <> 0 OR coalesce(c.saturday, 0) <> 0
           OR coalesce(c.sunday, 0) <> 0)
  ) g
  WHERE gtfs_vr_routescal_pattern_day(g.day, g.monday, g.tuesday, g.wednesday, g.thursday, g.friday, g.saturday,
                                      g.sunday) <> 0
), last_op AS (
  SELECT cd.service_id, cd.date AS day, cd.exception_type
  FROM gtfs_v_calendar_dates cd
  WHERE cd.exception_type IN (1, 2) AND cd.date IS NOT NULL
  QUALIFY row_number() OVER (PARTITION BY cd.service_id, cd.date ORDER BY cd.csv_row_number DESC) = 1
)
SELECT service_id, day FROM (
  (SELECT service_id, day FROM cal_days
   UNION
   SELECT service_id, day FROM last_op WHERE exception_type = 1)
  EXCEPT
  SELECT service_id, day FROM last_op WHERE exception_type = 2
);

-- RouteNameValidator and RouteColorContrastValidator (single-entity validators over routes.txt: every entity).
CREATE OR REPLACE MACRO gtfs_vr_routescal_route_entities() AS TABLE
SELECT 'route_both_short_and_long_name_missing' AS code,
  gtfs_validation_notice(json_object('routeId', coalesce(r.route_id, ''), 'csvRowNumber', r.csv_row_number)) AS notice
FROM gtfs_v_routes r
WHERE r.route_long_name IS NULL AND r.route_short_name IS NULL
UNION ALL
SELECT 'route_short_name_too_long',
  gtfs_validation_notice(json_object('routeId', coalesce(r.route_id, ''), 'csvRowNumber', r.csv_row_number,
                                     'routeShortName', r.route_short_name))
FROM gtfs_v_routes r
WHERE r.route_short_name IS NOT NULL AND length(r.route_short_name) > 12
UNION ALL
-- route_long_name starts (ignoring case) with route_short_name, followed by nothing or by an optional whitespace and
-- one of whitespace, '-', '(' or ')'.
SELECT 'route_long_name_contains_short_name',
  gtfs_validation_notice(json_object('routeId', coalesce(r.route_id, ''), 'csvRowNumber', r.csv_row_number,
                                     'routeShortName', r.route_short_name, 'routeLongName', r.route_long_name))
FROM gtfs_v_routes r
WHERE r.route_long_name IS NOT NULL AND r.route_short_name IS NOT NULL
  AND starts_with(lower(r.route_long_name), lower(r.route_short_name))
  AND (length(r.route_long_name) = length(r.route_short_name)
       OR regexp_full_match(substr(r.route_long_name, length(r.route_short_name) + 1), '\s?[\s\-\(\)].*'))
UNION ALL
-- route_desc equal (ignoring case) to route_short_name, else to route_long_name: one notice at most.
SELECT 'same_name_and_description_for_route',
  gtfs_validation_notice(json_object('csvRowNumber', r.csv_row_number, 'routeId', coalesce(r.route_id, ''),
                                     'routeDesc', r.route_desc,
                                     'specifiedField', CASE WHEN r.route_short_name IS NOT NULL
                                                             AND lower(r.route_desc) = lower(r.route_short_name)
                                                            THEN 'route_short_name' ELSE 'route_long_name' END))
FROM gtfs_v_routes r
WHERE r.route_desc IS NOT NULL
  AND ((r.route_short_name IS NOT NULL AND lower(r.route_desc) = lower(r.route_short_name))
       OR (r.route_long_name IS NOT NULL AND lower(r.route_desc) = lower(r.route_long_name)))
UNION ALL
SELECT 'route_color_contrast',
  gtfs_validation_notice(json_object('routeId', coalesce(r.route_id, ''), 'csvRowNumber', r.csv_row_number,
                                     'routeColor', gtfs_validation_color_text(r.route_color),
                                     'routeTextColor', gtfs_validation_color_text(r.route_text_color)))
FROM gtfs_v_routes r
WHERE r.route_color IS NOT NULL AND r.route_text_color IS NOT NULL
  AND abs(gtfs_vr_routescal_luma(r.route_color) - gtfs_vr_routescal_luma(r.route_text_color)) < 72;

-- DuplicateRouteNameValidator: routes keyed by (long name, short name, route type number, agency id), in file order;
-- every later route of a key is reported against the first one.
CREATE OR REPLACE MACRO gtfs_vr_routescal_duplicate_route_name() AS TABLE
WITH keyed AS (
  SELECT r.csv_row_number, r.route_id,
    first_value(r.csv_row_number) OVER w AS first_row,
    first_value(r.route_id) OVER w AS first_route_id,
    first_value(r.route_short_name) OVER w AS first_short,
    first_value(r.route_long_name) OVER w AS first_long,
    first_value(r.route_type) OVER w AS first_type,
    first_value(r.agency_id) OVER w AS first_agency,
    row_number() OVER w AS rn
  FROM gtfs_v_routes r
  WHERE gtfs_validation_parsed(['routes.txt'])
  WINDOW w AS (PARTITION BY coalesce(r.route_long_name, ''), coalesce(r.route_short_name, ''),
                            gtfs_vr_routescal_route_type_number(coalesce(r.route_type, 0)), coalesce(r.agency_id, '')
               ORDER BY r.csv_row_number ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT 'duplicate_route_name' AS code,
  gtfs_validation_notice(json_object(
    'csvRowNumber1', k.first_row, 'routeId1', coalesce(k.first_route_id, ''),
    'csvRowNumber2', k.csv_row_number, 'routeId2', coalesce(k.route_id, ''),
    'routeShortName', coalesce(k.first_short, ''), 'routeLongName', coalesce(k.first_long, ''),
    'routeTypeValue', gtfs_vr_routescal_route_type_number(coalesce(k.first_type, 0)),
    'agencyId', coalesce(k.first_agency, ''))) AS notice
FROM keyed k
WHERE k.rn > 1;

-- ServiceSpreadValidator: for every calendar.txt row, each gap of more than 13 days between consecutive active dates
-- of its service, and a last active date more than 2 * 365 days after the validation date.
CREATE OR REPLACE MACRO gtfs_vr_routescal_service_spread() AS TABLE
WITH dates AS (
  SELECT d.service_id, d.day, lag(d.day) OVER (PARTITION BY d.service_id ORDER BY d.day) AS prev_day
  FROM gtfs_vr_routescal_interval_dates() d
  WHERE gtfs_validation_parsed(['calendar.txt', 'calendar_dates.txt'])
    AND d.service_id IN (SELECT c.service_id FROM gtfs_v_calendar c)
), gaps AS (
  SELECT service_id, prev_day, day, CAST(day - prev_day - 1 AS BIGINT) AS gap_days
  FROM dates WHERE prev_day IS NOT NULL AND day - prev_day - 1 > 13
), last_day AS (
  SELECT service_id, max(day) AS last_day FROM dates GROUP BY service_id
)
SELECT 'big_gap_in_service' AS code,
  gtfs_validation_notice(json_object('serviceId', c.service_id, 'gapStartDate', strftime(g.prev_day, '%Y-%m-%d'),
                                     'gapEndDate', strftime(g.day, '%Y-%m-%d'), 'gapDurationDays', g.gap_days)) AS notice
FROM gtfs_v_calendar c JOIN gaps g ON g.service_id = c.service_id
UNION ALL
SELECT 'service_extends_far_in_the_future',
  gtfs_validation_notice(json_object('serviceId', c.service_id,
                                     'serviceWindowEndDate', strftime(l.last_day, '%Y-%m-%d')))
FROM gtfs_v_calendar c JOIN last_day l ON l.service_id = c.service_id
WHERE l.last_day - gtfs_validation_date() > 2 * 365;

-- ExpiredCalendarValidator: services whose last active date is before the validation date. With calendar.txt rows,
-- only services of calendar.txt are reported (row of the first calendar row of the service). Without any, every
-- service of calendar_dates.txt is reported (its first row) only when all services with dates are expired.
CREATE OR REPLACE MACRO gtfs_vr_routescal_expired_calendar() AS TABLE
WITH last_day AS (
  SELECT d.service_id, max(d.day) AS last_day
  FROM gtfs_vr_routescal_service_dates() d
  WHERE gtfs_validation_parsed(['calendar.txt', 'calendar_dates.txt'])
  GROUP BY d.service_id
), cal_first AS (
  SELECT c.service_id, min(c.csv_row_number) AS csv_row_number FROM gtfs_v_calendar c GROUP BY c.service_id
), cd_first AS (
  SELECT cd.service_id, min(cd.csv_row_number) AS csv_row_number FROM gtfs_v_calendar_dates cd GROUP BY cd.service_id
), flags AS (
  SELECT EXISTS (SELECT 1 FROM gtfs_v_calendar) AS has_calendar,
         coalesce(bool_and(l.last_day < gtfs_validation_date()), true) AS all_expired
  FROM last_day l
)
SELECT 'expired_calendar' AS code,
  gtfs_validation_notice(json_object('csvRowNumber', c.csv_row_number, 'serviceId', l.service_id)) AS notice
FROM last_day l JOIN cal_first c ON c.service_id = l.service_id CROSS JOIN flags f
WHERE f.has_calendar AND l.last_day < gtfs_validation_date()
UNION ALL
SELECT 'expired_calendar',
  gtfs_validation_notice(json_object('csvRowNumber', coalesce(cd.csv_row_number, 0), 'serviceId', l.service_id))
FROM last_day l LEFT JOIN cd_first cd ON cd.service_id = l.service_id CROSS JOIN flags f
WHERE NOT f.has_calendar AND f.all_expired;

-- MissingCalendarAndCalendarDateValidator and ServiceHasNoActiveDayOfTheWeekValidator.
CREATE OR REPLACE MACRO gtfs_vr_routescal_calendar_presence() AS TABLE
SELECT 'missing_calendar_and_calendar_date_files' AS code, gtfs_validation_notice(json_object()) AS notice
WHERE gtfs_validation_parsed(['calendar.txt', 'calendar_dates.txt'])
  AND (SELECT count(*) FROM gtfs_validation_files f
       WHERE f.filename IN ('calendar.txt', 'calendar_dates.txt') AND f.status = 'MISSING_FILE') = 2
UNION ALL
SELECT 'service_has_no_active_day_of_the_week',
  gtfs_validation_notice(json_object('csvRowNumber', c.csv_row_number, 'serviceId', c.service_id))
FROM gtfs_v_calendar c
WHERE gtfs_validation_parsed(['calendar.txt']) AND c.service_id IS NOT NULL
  AND coalesce(c.monday, 0) = 0 AND coalesce(c.tuesday, 0) = 0 AND coalesce(c.wednesday, 0) = 0
  AND coalesce(c.thursday, 0) = 0 AND coalesce(c.friday, 0) = 0 AND coalesce(c.saturday, 0) = 0
  AND coalesce(c.sunday, 0) = 0;

-- GtfsTripServiceIdForeignKeyValidator: trips.service_id must exist in calendar.txt or calendar_dates.txt.
CREATE OR REPLACE MACRO gtfs_vr_routescal_trip_service_fk() AS TABLE
SELECT 'foreign_key_violation' AS code,
  gtfs_validation_notice(json_object('childFilename', 'trips.txt', 'childFieldName', 'service_id',
                                     'parentFilename', 'calendar.txt or calendar_dates.txt',
                                     'parentFieldName', 'service_id', 'fieldValue', coalesce(t.service_id, ''),
                                     'csvRowNumber', t.csv_row_number)) AS notice
FROM gtfs_v_trips t
WHERE gtfs_validation_parsed(['trips.txt', 'calendar.txt', 'calendar_dates.txt'])
  AND coalesce(t.service_id, '') NOT IN (SELECT c.service_id FROM gtfs_v_calendar c WHERE c.service_id IS NOT NULL)
  AND coalesce(t.service_id, '') NOT IN (SELECT cd.service_id FROM gtfs_v_calendar_dates cd
                                         WHERE cd.service_id IS NOT NULL);

-- BlockTripsWithOverlappingStopTimesValidator: within a block, trips ordered by (first arrival, last departure, file
-- order), using the first and last stop time by stop_sequence; a later trip whose first arrival is before an earlier
-- trip's last departure overlaps it, unless the earlier trip's last arrival/departure equal the later trip's first
-- arrival/departure; it is reported when both services share a date (CalendarUtil dates; the first common date).
CREATE OR REPLACE MACRO gtfs_vr_routescal_block_overlaps() AS TABLE
WITH block_trips AS (
  SELECT t.csv_row_number, t.trip_id, t.service_id, t.block_id
  FROM gtfs_v_trips t
  WHERE t.block_id IS NOT NULL
    AND gtfs_validation_parsed(['trips.txt', 'stop_times.txt', 'calendar.txt', 'calendar_dates.txt'])
), st AS (
  SELECT s.trip_id, s.arrival_time, s.departure_time,
    row_number() OVER (PARTITION BY s.trip_id ORDER BY s.stop_sequence, s.csv_row_number) AS rn_first,
    row_number() OVER (PARTITION BY s.trip_id ORDER BY s.stop_sequence DESC, s.csv_row_number DESC) AS rn_last
  FROM gtfs_v_stop_times s
  WHERE s.trip_id IN (SELECT b.trip_id FROM block_trips b)
), edges AS (
  SELECT f.trip_id, f.arrival_time AS first_arr, f.departure_time AS first_dep,
         l.arrival_time AS last_arr, l.departure_time AS last_dep
  FROM st f JOIN st l ON l.trip_id = f.trip_id AND l.rn_last = 1
  WHERE f.rn_first = 1
), intervals AS (
  SELECT b.csv_row_number, b.trip_id, b.service_id, b.block_id, e.first_arr, e.first_dep, e.last_arr, e.last_dep,
    row_number() OVER (PARTITION BY b.block_id ORDER BY e.first_arr, e.last_dep, b.csv_row_number) AS pos
  FROM block_trips b JOIN edges e ON e.trip_id = b.trip_id
  WHERE e.first_arr IS NOT NULL AND e.first_dep IS NOT NULL AND e.last_arr IS NOT NULL AND e.last_dep IS NOT NULL
), overlapping AS (
  SELECT a.block_id, a.csv_row_number AS row_a, a.trip_id AS trip_a, a.service_id AS service_a,
         b.csv_row_number AS row_b, b.trip_id AS trip_b, b.service_id AS service_b
  FROM intervals a JOIN intervals b
    ON b.block_id = a.block_id AND b.pos > a.pos AND b.first_arr < a.last_dep
  WHERE NOT (a.last_arr = b.first_arr AND a.last_dep = b.first_dep)
), service_pairs AS (
  SELECT DISTINCT service_a, service_b FROM overlapping
), wanted AS (
  SELECT d.service_id, d.day FROM gtfs_vr_routescal_service_dates() d
  WHERE d.service_id IN (SELECT service_a FROM service_pairs UNION SELECT service_b FROM service_pairs)
), intersections AS (
  SELECT p.service_a, p.service_b, min(d1.day) AS day
  FROM service_pairs p
  JOIN wanted d1 ON d1.service_id = p.service_a
  JOIN wanted d2 ON d2.service_id = p.service_b AND d2.day = d1.day
  GROUP BY p.service_a, p.service_b
)
SELECT 'block_trips_with_overlapping_stop_times' AS code,
  gtfs_validation_notice(json_object(
    'csvRowNumberA', o.row_a, 'tripIdA', o.trip_a, 'serviceIdA', o.service_a,
    'csvRowNumberB', o.row_b, 'tripIdB', o.trip_b, 'serviceIdB', o.service_b,
    'blockId', o.block_id, 'intersection', gtfs_validation_date_text(i.day))) AS notice
FROM overlapping o
JOIN intersections i ON i.service_a = o.service_a AND i.service_b = o.service_b;

CREATE OR REPLACE MACRO gtfs_validate_rules_routes_calendar() AS TABLE
SELECT code, notice FROM gtfs_vr_routescal_route_entities()
UNION ALL SELECT code, notice FROM gtfs_vr_routescal_duplicate_route_name()
UNION ALL SELECT code, notice FROM gtfs_vr_routescal_service_spread()
UNION ALL SELECT code, notice FROM gtfs_vr_routescal_expired_calendar()
UNION ALL SELECT code, notice FROM gtfs_vr_routescal_calendar_presence()
UNION ALL SELECT code, notice FROM gtfs_vr_routescal_trip_service_fk()
UNION ALL SELECT code, notice FROM gtfs_vr_routescal_block_overlaps();
