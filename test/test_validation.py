"""Parity tests for PRAGMA gtfs_validate against the MobilityData gtfs-validator (stdlib only).

Every fixture in test/validation/feeds/<name>/ (base files + overlay, see harness.materialize) carries expected.json:
the in-scope notices the official validator jar reported for it. Each fixture runs on every DuckDB CLI in
harness.duckdb_bins() (DuckDB 2.0.0 and 1.4.3 by default).

GTFS_VALIDATION_SCOPE=<group>[,<group>] (groups: core, generated, stops, stoptimes, routescal, shapes) limits the comparison to
codes owned by those groups: a code owned only by in-scope groups must match exactly; a code shared with an
out-of-scope group must produce no notice the oracle lacks. Unset means every group, compared exactly.

Run: python3 -m unittest test.test_validation -v     (from the repository root)
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "validation"))
import harness  # noqa: E402

GROUPS = ["core", "generated", "stops", "stoptimes", "routescal", "shapes"]


def scope():
    raw = os.environ.get("GTFS_VALIDATION_SCOPE", "").strip()
    groups = [g.strip() for g in raw.split(",") if g.strip()] or GROUPS
    unknown = set(groups) - set(GROUPS)
    if unknown:
        raise ValueError(f"unknown GTFS_VALIDATION_SCOPE groups: {sorted(unknown)}")
    return set(groups)


RULES = harness.registry()
SCOPE = scope()
EXACT = {c for c, r in RULES.items() if set(r["owners"]) <= SCOPE}
NO_EXTRA = {c for c, r in RULES.items() if set(r["owners"]) & SCOPE} - EXACT


def compare_in_scope(ours, theirs):
    ours = [r for r in ours if r["code"] in EXACT | NO_EXTRA]
    theirs = [r for r in theirs if r["code"] in EXACT | NO_EXTRA]
    missing, extra = harness.compare(ours, theirs)
    missing = [r for r in missing if r["code"] in EXACT]
    return missing, extra


class RegistryTest(unittest.TestCase):
    def test_every_rule_has_a_known_owner_and_severity(self):
        self.assertEqual(len(RULES), 111)
        for code, rule in RULES.items():
            self.assertTrue(set(rule["owners"]) <= set(GROUPS), code)
            self.assertIn(rule["severity"], {"ERROR", "WARNING", "INFO"}, code)

    def test_notices_use_registered_codes_and_fields(self):
        # Checked on every fixture: a notice's code is registered and its keys are that code's notice fields.
        for name in harness.fixture_names():
            with tempfile.TemporaryDirectory() as tmp:
                feed = harness.materialize(name, Path(tmp) / "feed")
                for row in harness.notices(feed):
                    self.assertIn(row["code"], RULES, f"{name}: unregistered code")
                    fields = set(RULES[row["code"]]["notice_fields"])
                    self.assertTrue(
                        set(row["notice"]) <= fields,
                        f"{name}: {row['code']} has unknown keys {set(row['notice']) - fields}",
                    )
                    self.assertEqual(row["severity"], RULES[row["code"]]["severity"], f"{name}: {row['code']}")


class FixtureParityTest(unittest.TestCase):
    maxDiff = None

    def test_fixtures_match_the_oracle(self):
        names = harness.fixture_names()
        self.assertTrue(names, "no fixtures found")
        failures = []
        for bin_ in harness.duckdb_bins():
            for name in names:
                with self.subTest(fixture=name, duckdb=bin_):
                    expected = harness.expected(name)
                    with tempfile.TemporaryDirectory() as tmp:
                        feed = harness.materialize(name, Path(tmp) / "feed")
                        ours = harness.strip(harness.notices(feed, expected["date"], bin_))
                    missing, extra = compare_in_scope(ours, expected["notices"])
                    if missing or extra:
                        failures.append(f"{name} [{bin_}]\n{harness.describe(missing, extra)}")
                        self.fail(f"{name}:\n{harness.describe(missing, extra)}")
        if failures:
            Path(os.environ.get("GTFS_VALIDATION_REPORT", os.devnull)).write_text("\n\n".join(failures))


class PipelineTest(unittest.TestCase):
    def test_summary_and_files_are_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("base", Path(tmp) / "feed")
            out = harness.run(feed, queries={"summary": "SELECT * FROM gtfs_validation_summary()"})
        files = {r["filename"]: r for r in out["files"]}
        self.assertEqual(set(files), {f + ".txt" for f in harness.FILES})
        self.assertEqual(files["stops.txt"]["status"], "PARSABLE_HEADERS_AND_ROWS")
        self.assertEqual(files["pathways.txt"]["status"], "MISSING_FILE")
        self.assertTrue(files["pathways.txt"]["parsed"])
        counts = Counter(r["code"] for r in out["notices"])
        self.assertEqual({r["code"]: r["total_notices"] for r in out["summary"]}, dict(counts))

    def test_placeholders_are_not_in_comments(self):
        # The PRAGMA substitutes the directory into every placeholder; inside a -- comment a newline would end the
        # comment and run the rest of the directory name as SQL.
        for path in sorted((Path(harness.__file__).resolve().parents[2] / "sql").glob("validate_*.sql")):
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if "--" in line:
                    self.assertNotIn("{{", line[line.index("--") :], f"{path.name}:{number}")

    def test_directory_text_cannot_run_sql(self):
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("base", Path(tmp) / "x\nCREATE TABLE pwned AS SELECT 42 AS x;\n--")
            out = harness.run(
                feed, queries={"pwned": "SELECT count(*) AS n FROM duckdb_tables() WHERE table_name = 'pwned'"}
            )
        self.assertEqual(out["pwned"], [{"n": 0}])
        self.assertTrue(out["notices"] is not None)

    def test_working_tables_are_emptied(self):
        tables = ["gtfs_vc_text", "gtfs_vc_records", "gtfs_vc_header", "gtfs_vc_state", "gtfs_vc_rows", "gtfs_vc_cells"]
        sql = " UNION ALL ".join(f"SELECT '{t}' AS t, count(*) AS n FROM {t}" for t in tables + ["gtfs_vc_notices"])
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("base", Path(tmp) / "feed")
            out = harness.run(feed, queries={"left": sql})
        self.assertEqual({r["t"]: r["n"] for r in out["left"]}, {t: 0 for t in tables + ["gtfs_vc_notices"]})

    def test_missing_directory_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, "is not a directory"):
                harness.run(Path(tmp) / "no-such-feed")

    def test_validation_date_defaults_to_current_date(self):
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("base", Path(tmp) / "feed")
            out = harness.run(
                feed,
                date=None,
                queries={"state": "SELECT validation_date = current_date AS today FROM gtfs_validation_state"},
            )
        self.assertEqual(out["state"], [{"today": True}])


if __name__ == "__main__":
    unittest.main()
