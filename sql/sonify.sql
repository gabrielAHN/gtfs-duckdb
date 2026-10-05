CREATE OR REPLACE MACRO gtfs_hex_channel(hex, i) AS (
  (instr('0123456789abcdef', lower(substr(ltrim(CAST(hex AS VARCHAR), '#'), 2 * i + 1, 1))) - 1) * 16
  + (instr('0123456789abcdef', lower(substr(ltrim(CAST(hex AS VARCHAR), '#'), 2 * i + 2, 1))) - 1)
);

CREATE OR REPLACE MACRO gtfs_rgb_hue(r, g, b) AS (
  CASE
    WHEN greatest(r, g, b) = least(r, g, b) THEN 0.0
    WHEN greatest(r, g, b) = r THEN ((((g - b) / (greatest(r, g, b) - least(r, g, b))) + 6.0) % 6.0) / 6.0
    WHEN greatest(r, g, b) = g THEN (((b - r) / (greatest(r, g, b) - least(r, g, b))) + 2.0) / 6.0
    ELSE (((r - g) / (greatest(r, g, b) - least(r, g, b))) + 4.0) / 6.0
  END
);

CREATE OR REPLACE MACRO gtfs_hex_to_hue(hex) AS (
  CASE
    WHEN NOT regexp_full_match(ltrim(COALESCE(CAST(hex AS VARCHAR), ''), '#'), '[0-9A-Fa-f]{6}') THEN NULL
    ELSE gtfs_rgb_hue(gtfs_hex_channel(hex, 0) / 255.0, gtfs_hex_channel(hex, 1) / 255.0, gtfs_hex_channel(hex, 2) / 255.0)
  END
);

CREATE OR REPLACE MACRO gtfs_note_midi(value, low_midi := 45, octaves := 3, scale := [0, 2, 4, 7, 9]) AS (
  CASE WHEN value IS NULL THEN NULL ELSE
    low_midi
    + 12 * (least(CAST(floor(greatest(0.0, least(1.0, value)) * octaves * len(scale)) AS INTEGER), octaves * len(scale) - 1) // len(scale))
    + scale[(least(CAST(floor(greatest(0.0, least(1.0, value)) * octaves * len(scale)) AS INTEGER), octaves * len(scale) - 1) % len(scale)) + 1]
  END
);

CREATE OR REPLACE MACRO gtfs_midi_to_hz(midi) AS (
  440.0 * pow(2.0, (midi - 69) / 12.0)
);

CREATE OR REPLACE MACRO gtfs_sonify_stops(
  p_date := NULL,
  p_route_ids := NULL,
  low_midi := 45,
  octaves := 3,
  scale := [0, 2, 4, 7, 9],
  p_pitch_axis := 'lat'
) AS TABLE (
  WITH
  day AS (
    SELECT CAST(try_strptime(replace(CAST(p_date AS VARCHAR), '-', ''), '%Y%m%d') AS DATE) AS d
  ),
  services AS MATERIALIZED (
    SELECT DISTINCT service_id FROM TripsView WHERE p_date IS NULL
    UNION
    (SELECT c.service_id FROM CalendarView c, day
     WHERE CAST(try_strptime(c.start_date, '%Y%m%d') AS DATE) <= day.d
       AND CAST(try_strptime(c.end_date, '%Y%m%d') AS DATE) >= day.d
       AND [c.monday, c.tuesday, c.wednesday, c.thursday, c.friday, c.saturday, c.sunday][isodow(day.d)] = 1
     UNION
     SELECT cd.service_id FROM CalendarDatesView cd, day
     WHERE cd.date = strftime(day.d, '%Y%m%d') AND cd.exception_type = 1
     EXCEPT
     SELECT cd.service_id FROM CalendarDatesView cd, day
     WHERE cd.date = strftime(day.d, '%Y%m%d') AND cd.exception_type = 2)
  ),
  served AS MATERIALIZED (
    SELECT st.stop_id, list(DISTINCT t.route_id ORDER BY t.route_id) AS route_ids
    FROM StopTimesView st
    JOIN TripsView t ON t.trip_id = st.trip_id
    JOIN services s ON s.service_id = t.service_id
    GROUP BY st.stop_id
  ),
  stops AS MATERIALIZED (
    SELECT sv.stop_id, sv.stop_name, sv.stop_lat AS lat, sv.stop_lon AS lon, sd.route_ids
    FROM served sd
    JOIN StopsView sv ON sv.stop_id = sd.stop_id
    WHERE sv.stop_lat IS NOT NULL AND sv.stop_lon IS NOT NULL
  ),
  bounds AS (
    SELECT min(lon) AS min_lon, max(lon) AS max_lon, min(lat) AS min_lat, max(lat) AS max_lat,
           p_pitch_axis = 'lon' OR (p_pitch_axis = 'auto'
             AND (max(lon) - min(lon)) * cos(radians((min(lat) + max(lat)) / 2)) > max(lat) - min(lat)) AS by_lon
    FROM stops
  )
  SELECT s.stop_id, s.stop_name, s.lat, s.lon, s.route_ids,
         COALESCE(CASE WHEN b.by_lon THEN (s.lon - b.min_lon) / NULLIF(b.max_lon - b.min_lon, 0)
                       ELSE (s.lat - b.min_lat) / NULLIF(b.max_lat - b.min_lat, 0) END, 0.5) AS pitch_pos,
         COALESCE(2.0 * (s.lon - b.min_lon) / NULLIF(b.max_lon - b.min_lon, 0) - 1.0, 0.0) AS pan,
         gtfs_note_midi(pitch_pos, low_midi, octaves, scale) AS midi,
         gtfs_midi_to_hz(midi) AS freq_hz
  FROM stops s
  CROSS JOIN bounds b
  WHERE p_route_ids IS NULL OR len(list_intersect(s.route_ids, p_route_ids)) > 0
  ORDER BY s.stop_id
);

CREATE OR REPLACE MACRO gtfs_sonify_events(
  p_date := NULL,
  p_from := '00:00:00',
  p_to := '48:00:00',
  p_route_ids := NULL,
  low_midi := 45,
  octaves := 3,
  scale := [0, 2, 4, 7, 9],
  p_pitch_axis := 'lat'
) AS TABLE (
  WITH
  day AS (
    SELECT CAST(try_strptime(replace(CAST(p_date AS VARCHAR), '-', ''), '%Y%m%d') AS DATE) AS d
  ),
  services AS MATERIALIZED (
    SELECT DISTINCT service_id FROM TripsView WHERE p_date IS NULL
    UNION
    (SELECT c.service_id FROM CalendarView c, day
     WHERE CAST(try_strptime(c.start_date, '%Y%m%d') AS DATE) <= day.d
       AND CAST(try_strptime(c.end_date, '%Y%m%d') AS DATE) >= day.d
       AND [c.monday, c.tuesday, c.wednesday, c.thursday, c.friday, c.saturday, c.sunday][isodow(day.d)] = 1
     UNION
     SELECT cd.service_id FROM CalendarDatesView cd, day
     WHERE cd.date = strftime(day.d, '%Y%m%d') AND cd.exception_type = 1
     EXCEPT
     SELECT cd.service_id FROM CalendarDatesView cd, day
     WHERE cd.date = strftime(day.d, '%Y%m%d') AND cd.exception_type = 2)
  ),
  day_trips AS MATERIALIZED (
    SELECT t.trip_id, t.route_id
    FROM TripsView t
    JOIN services s ON s.service_id = t.service_id
  ),
  day_routes AS MATERIALIZED (
    SELECT r.route_id, r.route_name, r.route_color_hex,
           gtfs_hex_to_hue(r.route_color_hex) AS hue,
           CAST(dense_rank() OVER (ORDER BY COALESCE(r.route_sort_order, 2147483647), r.route_name, r.route_id) - 1 AS INTEGER) AS voice
    FROM RoutesView r
    WHERE r.route_id IN (SELECT route_id FROM day_trips)
  ),
  notes AS MATERIALIZED (
    SELECT stop_id, stop_name, lat, lon, pan, midi, freq_hz
    FROM gtfs_sonify_stops(p_date := p_date, low_midi := low_midi, octaves := octaves, scale := scale, p_pitch_axis := p_pitch_axis)
  ),
  calls AS MATERIALIZED (
    SELECT st.trip_id, dt.route_id, st.stop_id, st.stop_sequence,
           gtfs_time_to_seconds(COALESCE(NULLIF(st.departure_time, ''), st.arrival_time)) AS t_sec,
           lag(st.stop_sequence) OVER w IS NULL OR lead(st.stop_sequence) OVER w IS NULL AS accent
    FROM StopTimesView st
    JOIN day_trips dt ON dt.trip_id = st.trip_id
    WINDOW w AS (PARTITION BY st.trip_id ORDER BY st.stop_sequence)
  ),
  windowed AS MATERIALIZED (
    SELECT c.*, c.t_sec // 60 AS minute, n.stop_name, n.lat, n.lon, n.pan, n.midi, n.freq_hz
    FROM calls c
    JOIN notes n ON n.stop_id = c.stop_id
    WHERE c.t_sec >= gtfs_time_to_seconds(p_from) AND c.t_sec < gtfs_time_to_seconds(p_to)
  ),
  minutes AS (
    SELECT minute, sum(count(*)) OVER (ORDER BY minute RANGE BETWEEN 7 PRECEDING AND 7 FOLLOWING) / 15.0 AS n
    FROM windowed GROUP BY 1
  ),
  peak AS (
    SELECT max(n) AS n FROM minutes
  )
  SELECT w.trip_id, w.route_id, r.route_name, r.route_color_hex, r.hue, r.voice,
         w.stop_id, w.stop_name, w.stop_sequence, w.lat, w.lon,
         CAST(w.t_sec AS INTEGER) AS t_sec, seconds_to_gtfs_time(w.t_sec) AS t,
         w.midi, w.freq_hz, w.pan,
         m.n / p.n AS density,
         w.accent,
         least(1.0, 0.35 + 0.5 * (m.n / p.n) + CASE WHEN w.accent THEN 0.15 ELSE 0.0 END) AS velocity
  FROM windowed w
  JOIN day_routes r ON r.route_id = w.route_id
  JOIN minutes m ON m.minute = w.minute
  CROSS JOIN peak p
  WHERE p_route_ids IS NULL OR list_contains(p_route_ids, w.route_id)
  ORDER BY w.t_sec, r.voice, w.stop_sequence, w.trip_id
);
