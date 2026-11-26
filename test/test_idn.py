"""Differential test of the IDN emulation in sql/validate_core.sql (stdlib only).

test/validation/idn/corpus.tsv holds inputs with the oracle's answers, generated on Java 17 by
test/validation/idn/GenIdn.java: `host` rows give java.net.IDN.toASCII(input) (or ERROR), `url` rows give
commons-validator 1.6 UrlValidator.getInstance().isValid(input). This test only reads the corpus (no Java needed) and
checks gtfs_vc_idn_to_ascii and gtfs_vc_url_ok on every DuckDB CLI in harness.duckdb_bins(). Without GTFS_EXTENSION
the macros come from sql/*.sql as harness.run loads them; with it, from the loaded extension.

Run: python3 -m unittest test.test_idn -v     (from the repository root)
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "validation"))
import harness  # noqa: E402

CORPUS = Path(__file__).resolve().parent / "validation" / "idn" / "corpus.tsv"


def load_corpus():
    cases = []
    for line in CORPUS.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        kind, text, expected = line.split("\t")
        if kind == "host":
            expected = None if expected == "ERROR" else json.loads(expected)
        else:
            expected = {"true": True, "false": False}[expected]
        cases.append((kind, json.loads(text), expected))
    return cases


def evaluate(bin_, cases):
    """{case number: result} of gtfs_vc_idn_to_ascii (host) or gtfs_vc_url_ok (url) on one DuckDB CLI."""
    with tempfile.TemporaryDirectory(prefix="gtfs-idn-") as tmp:
        data = Path(tmp, "cases.json")
        data.write_text(
            "\n".join(json.dumps({"n": i, "kind": k, "input": s}) for i, (k, s, _) in enumerate(cases)),
            encoding="utf-8",
        )
        ext = os.environ.get("GTFS_EXTENSION")
        if ext:
            script = [f"LOAD {harness.quote(ext)};"]
        else:
            script = [harness.section("validate_schema")] + [harness.section(s) for s in harness.MACRO_SECTIONS]
        out = Path(tmp, "out.json")
        script += [
            f"CREATE TABLE idn_cases AS SELECT * FROM read_json({harness.quote(data)}, format = 'newline_delimited', "
            "columns = {'n': 'INTEGER', 'kind': 'VARCHAR', 'input': 'VARCHAR'});",
            "COPY (SELECT n, CASE WHEN kind = 'host' THEN gtfs_vc_idn_to_ascii(input) END AS host, "
            "CASE WHEN kind = 'url' THEN gtfs_vc_url_ok(input) END AS url FROM idn_cases ORDER BY n) "
            f"TO {harness.quote(out)} (FORMAT JSON, ARRAY true);",
        ]
        script_path = Path(tmp, "script.sql")
        script_path.write_text("\n".join(script), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k != "AI_AGENT"}
        cmd = [bin_, "-bail", "-batch"] + (["-unsigned"] if ext else []) + [":memory:", "-c", f".read {script_path}"]
        proc = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=tmp, timeout=3600)
        if proc.returncode != 0 or "Error" in proc.stderr:
            raise RuntimeError(f"{bin_} failed ({proc.returncode}): {proc.stderr.strip()[-4000:]}")
        rows = json.loads(out.read_text(encoding="utf-8"))
    return {r["n"]: r["host"] if cases[r["n"]][0] == "host" else r["url"] for r in rows}


class IdnCorpusTest(unittest.TestCase):
    maxDiff = None

    def test_corpus_is_large_and_covers_both_kinds(self):
        cases = load_corpus()
        self.assertGreaterEqual(len(cases), 2000)
        kinds = {k for k, _, _ in cases}
        self.assertEqual(kinds, {"host", "url"})
        # Accepted and refused inputs of both kinds, including Punycode results.
        self.assertTrue(any(k == "host" and e is None for k, _, e in cases))
        self.assertTrue(any(k == "host" and e and "xn--" in e for k, _, e in cases))
        self.assertTrue(any(k == "url" and e for k, _, e in cases))
        self.assertTrue(any(k == "url" and e is False for k, _, e in cases))

    def test_sql_matches_java_on_the_corpus(self):
        cases = load_corpus()
        for bin_ in harness.duckdb_bins():
            with self.subTest(duckdb=bin_):
                got = evaluate(bin_, cases)
                diffs = [
                    f"{kind} {json.dumps(text)}: java {json.dumps(expected)}, sql {json.dumps(got.get(i))}"
                    for i, (kind, text, expected) in enumerate(cases)
                    if got.get(i) != expected
                ]
                self.assertEqual(diffs, [], f"{len(diffs)} of {len(cases)} cases differ on {bin_}")


if __name__ == "__main__":
    unittest.main()
