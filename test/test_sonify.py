import unittest
from pathlib import Path
import test_native

FIXTURE = (Path(__file__).parent / "fixtures" / "normalized.sql").read_text()


class SonifyTests(unittest.TestCase):
    query = test_native.NativeExtensionTests.query

    def test_note_helpers_quantize_to_the_scale(self):
        rows = self.query(
            "SELECT gtfs_note_midi(0.0) AS lo, gtfs_note_midi(1.0) AS hi, "
            "gtfs_note_midi(0.5, 60, 1, [0, 4, 7]) AS mid, gtfs_note_midi(NULL) AS none, "
            "gtfs_midi_to_hz(69) AS a4"
        )
        self.assertEqual(rows, [{"lo": 45, "hi": 78, "mid": 64, "none": None, "a4": 440.0}])

    def test_hex_to_hue_accepts_gtfs_and_css_colors(self):
        rows = self.query(
            "SELECT gtfs_hex_to_hue('#FF0000') AS r, round(gtfs_hex_to_hue('00ff00'), 4) AS g, "
            "round(gtfs_hex_to_hue('#0000FF'), 4) AS b, gtfs_hex_to_hue('zz') AS bad"
        )
        self.assertEqual(rows, [{"r": 0.0, "g": 0.3333, "b": 0.6667, "bad": None}])

    def test_service_day_follows_weekdays_and_exceptions(self):
        rows = self.query(
            FIXTURE
            + """
            PRAGMA gtfs_init;
            INSERT INTO EditCalendarDatesTable (row_id, service_id, date, exception_type, status)
            VALUES ('x1', 'WK', '20260930', 2, 'new'), ('x2', 'WK', '20261003', 1, 'new');
            PRAGMA gtfs_refresh;
            SELECT
              (SELECT count(*) FROM gtfs_sonify_events(p_date := '2026-09-29')) AS tuesday,
              (SELECT count(*) FROM gtfs_sonify_events(p_date := '20260930')) AS removed,
              (SELECT count(*) FROM gtfs_sonify_events(p_date := '2026-10-03')) AS added,
              (SELECT count(*) FROM gtfs_sonify_events(p_date := '2026-10-04')) AS sunday,
              (SELECT count(*) FROM gtfs_sonify_events(p_date := '2027-01-04')) AS expired,
              (SELECT count(*) FROM gtfs_sonify_events()) AS any_day,
              (SELECT count(*) FROM gtfs_sonify_stops(p_date := '2026-09-29')) AS stops_tuesday,
              (SELECT count(*) FROM gtfs_sonify_stops(p_date := '20260930')) AS stops_removed;
        """
        )
        self.assertEqual(
            rows,
            [
                {
                    "tuesday": 2,
                    "removed": 0,
                    "added": 2,
                    "sunday": 0,
                    "expired": 0,
                    "any_day": 2,
                    "stops_tuesday": 2,
                    "stops_removed": 0,
                }
            ],
        )

    def test_stops_get_a_note_from_their_place(self):
        rows = self.query(
            FIXTURE
            + """
            PRAGMA gtfs_init;
            SELECT stop_id, route_ids, pitch_pos, pan, midi, round(freq_hz, 2) AS freq_hz
            FROM gtfs_sonify_stops(p_date := '2026-09-29');
        """
        )
        self.assertEqual(
            rows,
            [
                {"stop_id": "P", "route_ids": ["R"], "pitch_pos": 0.0, "pan": 0.0, "midi": 45, "freq_hz": 110.0},
                {"stop_id": "Q", "route_ids": ["R"], "pitch_pos": 1.0, "pan": 0.0, "midi": 78, "freq_hz": 739.99},
            ],
        )

    def test_events_map_departures_to_notes(self):
        rows = self.query(
            FIXTURE
            + """
            PRAGMA gtfs_init;
            SELECT stop_id, t, t_sec, midi, round(freq_hz, 2) AS freq_hz, pan, density, accent, velocity, voice
            FROM gtfs_sonify_events(p_date := '2026-09-29', p_from := '24:00:00', p_to := '26:00:00');
        """
        )
        self.assertEqual(
            rows,
            [
                {
                    "stop_id": "P",
                    "t": "25:00:00",
                    "t_sec": 90000,
                    "midi": 45,
                    "freq_hz": 110.0,
                    "pan": 0.0,
                    "density": 1.0,
                    "accent": True,
                    "velocity": 1.0,
                    "voice": 0,
                },
                {
                    "stop_id": "Q",
                    "t": "25:10:00",
                    "t_sec": 90600,
                    "midi": 78,
                    "freq_hz": 739.99,
                    "pan": 0.0,
                    "density": 1.0,
                    "accent": True,
                    "velocity": 1.0,
                    "voice": 0,
                },
            ],
        )

    def test_events_respect_window_date_and_routes(self):
        rows = self.query(
            FIXTURE
            + """
            PRAGMA gtfs_init;
            SELECT
              (SELECT count(*) FROM gtfs_sonify_events(p_from := '25:05:00', p_to := '26:00:00')) AS windowed,
              (SELECT count(*) FROM gtfs_sonify_events(p_date := '2026-10-04')) AS sunday,
              (SELECT count(*) FROM gtfs_sonify_events(p_route_ids := ['R'])) AS route,
              (SELECT count(*) FROM gtfs_sonify_events(p_route_ids := ['missing'])) AS other;
        """
        )
        self.assertEqual(rows, [{"windowed": 1, "sunday": 0, "route": 2, "other": 0}])

    EXTRA_TRIPS = """
        INSERT INTO trips VALUES
          (2, 'R', 'WK', 'T2', '', '', 0, '', 'SH', 0, 0),
          (3, 'R', 'WK', 'T3', 'Back', '', 1, '', 'SH', 0, 0);
        INSERT INTO stop_times VALUES
          (3, 'T2', '25:20:00', '25:20:00', 'P', 1, '', 0, 0, 0, 1),
          (4, 'T2', '25:30:00', '25:30:00', 'Q', 2, '', 0, 0, 10, 1),
          (5, 'T3', '25:05:00', '25:05:00', 'Q', 1, '', 0, 0, 0, 1),
          (6, 'T3', '25:15:00', '25:15:00', 'P', 2, '', 0, 0, 10, 1);
    """

    OTHER_ROUTE = """
        INSERT INTO routes VALUES (2, 'G', 'A', 'G', 'Other Route', '', 3, '', 'ff0000', 'ffffff', 2, 'G', 'Bus', '#ff0000', '#ffffff');
        INSERT INTO trips VALUES (4, 'G', 'WK', 'TG', 'Out', '', 0, '', '', 0, 0);
        INSERT INTO stop_times VALUES
          (7, 'TG', '25:02:00', '25:02:00', 'O', 1, '', 0, 0, 0, 1),
          (8, 'TG', '25:12:00', '25:12:00', 'P', 2, '', 0, 0, 10, 1);
    """

    def test_route_filter_keeps_each_route_part_of_the_whole(self):
        rows = self.query(
            FIXTURE
            + self.EXTRA_TRIPS
            + self.OTHER_ROUTE
            + """
            PRAGMA gtfs_init;
            CREATE TEMP TABLE whole AS SELECT * FROM gtfs_sonify_events(p_date := '2026-09-29');
            CREATE TEMP TABLE part_r AS SELECT * FROM gtfs_sonify_events(p_date := '2026-09-29', p_route_ids := ['R']);
            SELECT
              (SELECT count(*) FROM part_r) AS route_rows,
              (SELECT count(*) FROM whole w JOIN part_r p USING (trip_id, stop_id, t_sec)
                WHERE w.midi = p.midi AND w.pan = p.pan AND w.velocity = p.velocity AND w.density = p.density
                  AND w.accent = p.accent AND w.voice = p.voice) AS identical,
              (SELECT count(DISTINCT route_id) FROM part_r) AS routes,
              (SELECT count(*) FROM whole) AS all_rows;
        """
        )
        self.assertEqual(rows, [{"route_rows": 6, "identical": 6, "routes": 1, "all_rows": 8}])

    def test_pitch_axis_can_follow_longitude(self):
        rows = self.query(
            FIXTURE
            + """
            UPDATE stops SET stop_lon = 139.01, stop_lat = 35.0002 WHERE stop_id = 'Q';
            PRAGMA gtfs_init;
            SELECT stop_id, pitch_pos FROM gtfs_sonify_stops(p_pitch_axis := 'auto') ORDER BY stop_id;
        """
        )
        self.assertEqual(rows, [{"stop_id": "P", "pitch_pos": 0.0}, {"stop_id": "Q", "pitch_pos": 1.0}])


if __name__ == "__main__":
    unittest.main()
