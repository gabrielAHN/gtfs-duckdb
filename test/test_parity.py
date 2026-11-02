import json
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = (ROOT / "test/fixtures/normalized.sql").read_text()
QUERIES = {
    "availability": "SELECT * FROM get_gtfs_data_availability()",
    "stations": "SELECT * FROM get_stations_table_data() ORDER BY stop_id",
    "stops": "SELECT * FROM get_stops_table_data() ORDER BY stop_id",
    "station_summary": "SELECT * FROM get_station_info('S')",
    "station_pathways": "SELECT * FROM get_station_pathways('S') ORDER BY pathway_id",
    "station_shortest_paths": "SELECT * FROM find_shortest_path('S', 'E', 'Q')",
    "routes": "SELECT * FROM get_routes_table_data() ORDER BY route_id",
    "route_trips": "SELECT * FROM get_trips_table_data() ORDER BY trip_id",
    "trip_stop_times": "SELECT * FROM get_trip_stops('T', [], NULL, NULL) ORDER BY stop_sequence",
    "trip_window": "SELECT * FROM get_trip_map_bounds('T')",
    "trip_bounds": "SELECT * FROM get_trips_time_bounds()",
    "services": "SELECT * FROM get_calendar_table_data() ORDER BY service_id",
    "route_bands": "INSERT INTO RouteShapeLanesTable SELECT * FROM prepare_route_shape_lanes(['R']); SELECT * FROM finish_route_shape_bands(['R']) ORDER BY route_id, shape_pt_sequence",
    "reroute_stop_sequences": "SELECT * FROM get_trip_stops('T', [], 'Platform P', 'Platform Q') ORDER BY stop_sequence",
}


class LegacyParityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = Path(os.environ.get("GTFS_LEGACY_HEADER", ROOT / "test/fixtures/legacy-gtfs_sql.hpp.txt")).read_text()
        sections = re.split(r'static const char \*GTFS_\w+_SQL\s*=', text)[1:]
        cls.blocks = [''.join(re.findall(r'R"SQL\((.*?)\)SQL"', section, re.S)) for section in sections]
        if len(cls.blocks) != 3:
            raise ValueError("Expected the three original SQL blocks")
        cls.names = sorted(re.findall(r"CREATE OR REPLACE MACRO\s+(\w+)", "\n".join(cls.blocks)))

    def execute(self, sql, legacy=False):
        extension = str(Path(os.environ["GTFS_EXTENSION"]).resolve()).replace("'", "''")
        cache = os.environ.get("GTFS_DEPENDENCY_CACHE")
        config = ""
        if cache:
            config = "SET extension_directories=['" + cache.replace("'", "''") + "'];"
        prelude = config + "LOAD spatial;" + ("" if legacy else f"LOAD '{extension}';")
        setup = self.blocks[0] + FIXTURE + self.blocks[1] + self.blocks[2] if legacy else FIXTURE + "PRAGMA gtfs_init;"
        result = subprocess.run(
            [
                os.environ.get("DUCKDB_BIN", "duckdb"),
                "-unsigned",
                "-json",
                "-cmd",
                prelude,
                ":memory:",
                "-c",
                setup + sql,
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_all_legacy_macros_registered_in_system_catalog(self):
        names_sql = ",".join("'" + name + "'" for name in self.names)
        rows = self.execute(
            "SELECT function_name FROM duckdb_functions() WHERE database_name='system' AND function_name IN ("
            + names_sql
            + ") ORDER BY function_name"
        )
        self.assertEqual([row["function_name"] for row in rows], self.names)

    def test_extracted_sql_is_identical_to_original(self):
        for name, original in zip(["load", "init", "reroute"], self.blocks):
            with self.subTest(name=name):
                self.assertEqual((ROOT / "sql" / (name + ".sql")).read_text().strip(), original.strip())


def parity_test(sql):
    def test(self):
        expected = self.execute(sql, legacy=True)
        self.assertTrue(expected, "Fixture must exercise a nonempty result")
        self.assertEqual(self.execute(sql), expected)

    return test


for name, sql in QUERIES.items():
    setattr(LegacyParityTests, "test_parity_" + name, parity_test(sql))


if __name__ == "__main__":
    unittest.main()
