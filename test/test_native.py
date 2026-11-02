import json
import os
from pathlib import Path
import subprocess
import unittest
import functools
import gzip
import http.server
import tempfile
import threading


class NativeExtensionTests(unittest.TestCase):
    def query(self, sql):
        extension = os.environ.get("GTFS_EXTENSION")
        prefix = ""
        if extension:
            escaped = str(Path(extension).resolve()).replace("'", "''")
            prefix = f"LOAD '{escaped}';"
        commands = ["-cmd", prefix] if prefix else []
        result = subprocess.run(
            [os.environ.get("DUCKDB_BIN", "duckdb"), "-unsigned", "-json", *commands, ":memory:", "-c", sql],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_route_type_matches_existing_gtfs_contract(self):
        self.assertEqual(
            self.query("SELECT route_type_to_name(3) AS name"),
            [{"name": "Bus"}],
        )

    def test_all_route_types_and_unknowns(self):
        rows = self.query(
            "SELECT route_type_to_name(i) AS name FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(11),(12),(99),(NULL)) t(i)"
        )
        self.assertEqual(
            [row["name"] for row in rows],
            [
                "Tram, Streetcar, Light rail",
                "Subway, Metro",
                "Rail",
                "Bus",
                "Ferry",
                "Cable tram",
                "Aerial lift",
                "Funicular",
                "Trolleybus",
                "Monorail",
                "Other",
                "Other",
            ],
        )

    def test_load_creates_no_user_tables(self):
        self.assertEqual(self.query("SELECT count(*) AS n FROM information_schema.tables"), [{"n": 0}])

    def test_repeated_load_preserves_user_data(self):
        extension = str(Path(os.environ["GTFS_EXTENSION"]).resolve()).replace("'", "''")
        self.assertEqual(
            self.query(
                f"CREATE TABLE user_data AS SELECT 42 AS value; LOAD '{extension}'; "
                "SELECT value, route_type_to_name(3) AS name FROM user_data"
            ),
            [{"value": 42, "name": "Bus"}],
        )

    def test_function_registered_in_system_catalog(self):
        rows = self.query(
            "SELECT database_name, internal, function_type FROM duckdb_functions() WHERE function_name='route_type_to_name'"
        )
        self.assertEqual(rows, [{"database_name": "system", "internal": True, "function_type": "macro"}])

    def test_unsigned_artifact_rejected_by_default(self):
        extension = str(Path(os.environ["GTFS_EXTENSION"]).resolve()).replace("'", "''")
        result = subprocess.run(
            [os.environ["DUCKDB_BIN"], ":memory:", "-c", f"LOAD '{extension}'"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsigned", result.stderr.lower())

    def test_install_downloads_from_repository_into_clean_cache(self):
        binary = os.environ["DUCKDB_BIN"]
        version = self.query("SELECT version() AS version")[0]["version"]
        platform = self.query("PRAGMA platform")[0]["platform"]
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            artifact = base / "repository" / version / platform / "gtfs.duckdb_extension.gz"
            artifact.parent.mkdir(parents=True)
            artifact.write_bytes(gzip.compress(Path(os.environ["GTFS_EXTENSION"]).read_bytes()))
            handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(base / "repository"))
            server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                cache = str(base / "cache").replace("'", "''")
                sql = (
                    f"SET home_directory='{str(base).replace(chr(39), chr(39) * 2)}'; "
                    f"SET extension_directories=['{cache}']; "
                    f"INSTALL gtfs FROM 'http://127.0.0.1:{server.server_port}'; "
                    "LOAD gtfs; SELECT route_type_to_name(3) AS name;"
                )
                result = subprocess.run(
                    [binary, "-unsigned", "-json", ":memory:", "-c", sql], capture_output=True, text=True
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), [{"name": "Bus"}])
                self.assertTrue(list((base / "cache").rglob("gtfs.duckdb_extension")))
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == "__main__":
    unittest.main()
