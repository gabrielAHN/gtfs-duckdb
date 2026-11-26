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
import re
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


SQL_DIR = Path(harness.__file__).resolve().parents[2] / "sql"
RULE_STATEMENT = re.compile(r"INSERT INTO gtfs_vc_rule_notices SELECT code, notice FROM (gtfs_vr_\w+)\(\);")
GROUP_HEADER = re.compile(r"-- (gtfs_validate_rules_\w+)\(\)")


def rule_lists(finish_text=None):
    """The rule macros of each gtfs_validate_rules_<group>() macro; the ones validate_finish.sql runs under each group's
    comment, read from its list of group comments and statements, which ends at its first other line; and the other
    lines of validate_finish.sql naming a rule macro, and the group comments after that list. A rule's line must be its
    whole statement, so a statement commented out, edited or moved is reported instead of counted."""
    groups = {}
    for path in sorted(SQL_DIR.glob("validate_rules_*.sql")):
        text = re.sub(r"--[^\n]*", "", path.read_text())
        match = re.search(r"MACRO (gtfs_validate_rules_\w+)\(\) AS TABLE(.*?);", text, re.S)
        groups[match.group(1)] = re.findall(r"\bFROM (gtfs_vr_\w+)\(\)", match.group(2))
    if finish_text is None:
        finish_text = (SQL_DIR / "validate_finish.sql").read_text()
    finish, group, ended, stray = {}, None, False, []
    for line in finish_text.splitlines():
        header, statement = GROUP_HEADER.fullmatch(line), RULE_STATEMENT.fullmatch(line)
        if header and not ended:
            group = finish.setdefault(header.group(1), [])
        elif statement and group is not None:
            group.append(statement.group(1))
        else:
            if header or "gtfs_vr_" in line:
                stray.append(line)
            if finish:
                group, ended = None, True
    return groups, finish, stray


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


# Every line becomes an 'open' record, so validate_load.sql parses every file with the whole-text parser
# (gtfs_vc_parse_records), whose records are never plain.
WHOLE_TEXT_ONLY = """CREATE OR REPLACE MACRO gtfs_vc_line_records() AS TABLE
SELECT line_no AS rec_no, line_no AS csv_row_number, 'open' AS kind, NULL::VARCHAR[] AS fields, NULL::BIGINT AS max_len,
  false AS plain
FROM gtfs_vc_lines;"""


class LoaderTest(unittest.TestCase):
    maxDiff = None

    def test_loader_macros_are_generated(self):
        gen = Path(harness.__file__).resolve().parent / "gen_loader.py"
        proc = subprocess.run([sys.executable, str(gen), "--check"], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_line_records_match_the_whole_text_parser(self):
        # validate_load.sql parses each line on its own (in parallel), skips the per-value character checks of plain
        # rows, and falls back to the whole-text parser only when a quoted value spans lines. Forcing that fallback
        # for every file must not change a notice, a file status or an entity.
        entities = " UNION ALL ".join(
            f"SELECT '{t}' AS t, count(*) AS n, sum(hash(x)) AS h FROM gtfs_v_{t} x" for t in harness.FILES
        )
        queries = {"entities": f"SELECT t, n, h::VARCHAR AS h FROM ({entities}) ORDER BY t"}
        for name in harness.fixture_names():
            with self.subTest(fixture=name):
                with tempfile.TemporaryDirectory() as tmp:
                    feed = harness.materialize(name, Path(tmp) / "feed")
                    lines = harness.run(feed, queries=queries, macro_overrides=[])
                    whole = harness.run(feed, queries=queries, macro_overrides=[WHOLE_TEXT_ONLY])
                for key in ("notices", "files", "entities"):
                    self.assertEqual(lines[key], whole[key], f"{name}: {key}")


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
        tables = ["gtfs_vc_text", "gtfs_vc_lines", "gtfs_vc_records", "gtfs_vc_header", "gtfs_vc_state", "gtfs_vc_pos"]
        tables += [f"gtfs_vc_wide_{t}" for t in harness.FILES]
        tables += ["gtfs_vc_notices", "gtfs_vc_rule_notices"]
        sql = " UNION ALL ".join(f"SELECT '{t}' AS t, count(*) AS n FROM {t}" for t in tables)
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("stops-distance", Path(tmp) / "feed")
            out = harness.run(feed, queries={"left": sql})
        self.assertTrue(out["notices"])
        self.assertEqual({r["t"]: r["n"] for r in out["left"]}, {t: 0 for t in tables})

    def test_finish_runs_every_rule_macro_of_every_group(self):
        # validate_finish.sql runs the rule macros one statement at a time (see its header), listed under a comment
        # naming their group: the lists must be the group macros' own.
        groups, finish, stray = rule_lists()
        self.assertEqual(stray, [])
        self.assertEqual(len(groups), 5)
        self.assertEqual(finish, groups)

    def test_rule_list_check_reports_each_kind_of_drift(self):
        # Each edit of validate_finish.sql below must fail test_finish_runs_every_rule_macro_of_every_group.
        text = (SQL_DIR / "validate_finish.sql").read_text()
        lines = text.splitlines(keepends=True)
        first = next(i for i, line in enumerate(lines) if RULE_STATEMENT.fullmatch(line.rstrip("\n")))
        rule, following = lines[first], lines[first + 1]
        self.assertTrue(RULE_STATEMENT.fullmatch(following.rstrip("\n")))
        last = max(i for i, line in enumerate(lines) if RULE_STATEMENT.fullmatch(line.rstrip("\n")))
        group_of_last = next(line for line in reversed(lines[:last]) if GROUP_HEADER.fullmatch(line.rstrip("\n")))
        edits = {
            "commented out": text.replace(rule, "-- " + rule, 1),
            "removed": text.replace(rule, "", 1),
            "run twice": text.replace(rule, rule + rule, 1),
            "reordered": text.replace(rule + following, following + rule, 1),
            "under another group": text.replace(rule, "", 1).replace(lines[last], lines[last] + rule, 1),
            "after the section": text.replace(rule, "", 1) + rule,
            "last rule after the section": text.replace(lines[last], "", 1) + lines[last],
            "last rule under its group's comment again after the section": text.replace(lines[last], "", 1)
            + group_of_last
            + lines[last],
            "blank line in the section": text.replace(rule, rule + "\n", 1),
            "edited": text.replace(rule, rule.replace("();", "() WHERE false;"), 1),
        }
        for name, edited in edits.items():
            with self.subTest(edit=name):
                self.assertNotEqual(edited, text)
                groups, finish, stray = rule_lists(edited)
                self.assertTrue(stray or finish != groups)

    def test_missing_directory_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, "is not a directory"):
                harness.run(Path(tmp) / "no-such-feed")

    def test_directory_with_pattern_characters_is_an_error(self):
        # read_blob reads "feed[1]/stops.txt" as a pattern: with a sibling feed1 it reads feed1/stops.txt instead.
        for name, sibling in (("feed[1]", "feed1"), ("feed*", "feedx"), ("feed?", "feedx")):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                feed = harness.materialize("base", Path(tmp) / name)
                harness.materialize("base", Path(tmp) / sibling)
                with self.assertRaisesRegex(RuntimeError, "which DuckDB reads as a file pattern"):
                    harness.run(feed)

    def test_validation_date_defaults_to_current_date(self):
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("base", Path(tmp) / "feed")
            out = harness.run(
                feed,
                date=None,
                queries={"state": "SELECT validation_date = current_date AS today FROM gtfs_validation_state"},
            )
        self.assertEqual(out["state"], [{"today": True}])


class PlanTest(unittest.TestCase):
    def test_stop_distance_pairs_come_from_a_hash_join_on_grid_cells(self):
        # When the grid cells were not join keys, DuckDB joined every stop with every later one: 40,000 stops took
        # 158 s on DuckDB v1.4.3 and 5.7 s on v2.0.0, against 0.01 s with the hash join.
        with tempfile.TemporaryDirectory() as tmp:
            feed = harness.materialize("stops-distance", Path(tmp) / "feed")
            for bin_ in harness.duckdb_bins():
                with self.subTest(bin=bin_):
                    ops = harness.plan(feed, "SELECT * FROM gtfs_vr_stops_station_distance()", bin=bin_)
                    joins = [op for op in ops if "JOIN" in op["name"] or "PRODUCT" in op["name"]]
                    self.assertEqual({op["name"] for op in joins} - {"HASH_JOIN", "CROSS_PRODUCT"}, set())
                    keys = []
                    for op in joins:
                        if op["name"] == "HASH_JOIN":
                            conditions = op["extra_info"].get("Conditions", [])
                            keys.append([conditions] if isinstance(conditions, str) else conditions)
                    on_cells = [k for k in keys if all(f"c{a} = n{a}" in k or f"n{a} = c{a}" in k for a in "xyz")]
                    self.assertTrue(on_cells, keys)


if __name__ == "__main__":
    unittest.main()
