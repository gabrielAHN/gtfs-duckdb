"""Dev and test harness for PRAGMA gtfs_validate (stdlib only).

Without GTFS_EXTENSION it emulates the PRAGMA with a stock DuckDB CLI: the same sql/*.sql sections, the same
placeholder substitution and the same order the C++ PRAGMA uses. With GTFS_EXTENSION=<path to gtfs.duckdb_extension>
it runs the real PRAGMA instead.

Environment:
  GTFS_VALIDATION_DUCKDB_BINS  os.pathsep-separated DuckDB CLIs to test with (default: DUCKDB_BIN, else the two
                               reference CLIs under GTFS_VALIDATION_REF, else `duckdb`)
  GTFS_VALIDATION_REF          optional directory of reference tools: tools/duckdb-2.0.0/duckdb, tools/duckdb-1.4.3/duckdb,
                               tools/oracle/jar/gtfs-validator-8.0.2-SNAPSHOT-cli.jar and an oracle-cache/ directory
  GTFS_EXTENSION               run the real extension PRAGMA instead of the emulation
  GTFS_VALIDATION_FIXTURES     glob over fixture names to run (default *)
  GTFS_VALIDATOR_JAR / GTFS_VALIDATOR_JAVA   the MobilityData oracle and a Java 17 binary (default `java`); only
                               `expect` and `diff` use them
  GTFS_VALIDATOR_ORACLE_CACHE  where oracle reports are cached (default GTFS_VALIDATION_REF/oracle-cache)

CLI:
  python3 test/validation/harness.py run <feed dir> [--date D] [--bin B]        our notices, summarized
  python3 test/validation/harness.py expect <fixture> [...]                     write <fixture>/expected.json from the oracle
  python3 test/validation/harness.py diff <feed dir|zip> [--date D] [--bin B]   ours vs oracle (in-scope notices)
"""

import fnmatch
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SQL = REPO / "sql"
FEEDS = Path(__file__).resolve().parent / "feeds"
TYPED_SCHEMA = json.loads((Path(__file__).resolve().parent / "typed_schema.json").read_text())
REF = Path(os.environ["GTFS_VALIDATION_REF"]).expanduser() if os.environ.get("GTFS_VALIDATION_REF") else None
DEFAULT_DATE = "2026-11-24"

# The validated files, in the order PRAGMA gtfs_validate loads them, and GtfsTableDescriptor.isRequired().
FILES = ["stops", "pathways", "routes", "trips", "stop_times", "shapes", "calendar", "calendar_dates"]
REQUIRED = {"routes", "trips", "stop_times"}
GTFS_FILENAMES = {f + ".txt" for f in FILES}
# Sections whose CREATE OR REPLACE MACRO statements the extension registers at LOAD.
MACRO_SECTIONS = [
    "validate_common",
    "validate_registry",
    "validate_core",
    "validate_rules_stops",
    "validate_rules_stop_times",
    "validate_rules_routes_calendar",
    "validate_rules_shapes",
    "validate_rules_generated",
]
# Sections PRAGMA gtfs_validate executes, with placeholders replaced before parsing.
STATEMENT_SECTIONS = ["validate_schema", "validate_begin", "validate_load", "validate_missing", "validate_finish"]
STUB_MARKER = "GTFS_VALIDATION_STUB"


def duckdb_bins():
    env = os.environ.get("GTFS_VALIDATION_DUCKDB_BINS")
    if env:
        return [b for b in env.split(os.pathsep) if b]
    if os.environ.get("DUCKDB_BIN"):
        return [os.environ["DUCKDB_BIN"]]
    refs = [REF / "tools/duckdb-2.0.0/duckdb", REF / "tools/duckdb-1.4.3/duckdb"] if REF else []
    found = [str(p) for p in refs if p.exists()]
    return found or ["duckdb"]


def section(name):
    return (SQL / f"{name}.sql").read_text()


def quote(text):
    return "'" + str(text).replace("'", "''") + "'"


def subst(text, **values):
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def date_expr(date):
    return "current_date" if date is None else f"DATE {quote(date)}"


def file_values(table, path):
    return {
        "TABLE": table,
        "FILE": quote(table + ".txt"),
        "PATH": quote(path),
        "REQUIRED": "true" if table in REQUIRED else "false",
    }


def pragma_sql(feed_dir, date):
    """The statements PRAGMA gtfs_validate(feed_dir, date) executes (src/gtfs_extension.cpp mirrors this)."""
    feed_dir = Path(feed_dir)
    parts = [
        section("validate_schema"),
        subst(section("validate_begin"), DATE=date_expr(date), DIRECTORY=quote(str(feed_dir))),
    ]
    stub = STUB_MARKER in section("validate_load")
    for table in FILES:
        path = feed_dir / f"{table}.txt"
        if path.is_file():
            parts.append(subst(section("validate_load"), **file_values(table, str(path))))
            if stub:
                parts.append(reference_load_sql(table, path))
        else:
            parts.append(subst(section("validate_missing"), **file_values(table, str(path))))
    parts.append(section("validate_finish"))
    return parts


def reference_load_sql(table, path):
    """Naive typed load used only while validate_load.sql is a stub: header-based, no notices, no CSV edge cases."""
    raw = Path(path).read_bytes().decode("utf-8", "replace").lstrip("\ufeff")
    header = [h.strip().strip('"') for h in raw.splitlines()[0].split(",")] if raw.strip() else []
    cols = []
    for col in TYPED_SCHEMA[table][1:]:
        name, kind = col["name"], col["kind"]
        if name not in header:
            cols.append(f"NULL::{col['type']}")
            continue
        v = f"NULLIF(trim(\"{name}\"), '')"
        expr = {
            "float": f"TRY_CAST({v} AS DOUBLE)",
            "latitude": f"TRY_CAST({v} AS DOUBLE)",
            "longitude": f"TRY_CAST({v} AS DOUBLE)",
            "integer": f"TRY_CAST({v} AS INTEGER)",
            "enum": f"TRY_CAST({v} AS INTEGER)",
            "date": f"TRY_STRPTIME({v}, '%Y%m%d')::DATE",
            "time": (
                f"CASE WHEN regexp_full_match({v}, '[0-9]{{1,3}}:[0-9]{{2}}:[0-9]{{2}}') THEN "
                f"split_part({v}, ':', 1)::INTEGER * 3600 + split_part({v}, ':', 2)::INTEGER * 60 + "
                f"split_part({v}, ':', 3)::INTEGER END"
            ),
            "color": f"CASE WHEN regexp_full_match({v}, '[0-9A-Fa-f]{{6}}') THEN ('0x' || {v})::INTEGER END",
        }.get(kind, v)
        cols.append(expr)
    if not header:
        return ""
    columns = "".join(
        f"INSERT INTO gtfs_validation_columns VALUES ({quote(table + '.txt')}, {quote(h)}, {i});\n"
        for i, h in enumerate(header)
    )
    return columns + (
        f"INSERT INTO gtfs_v_{table} SELECT row_number() OVER () + 1, "
        + ", ".join(cols)
        + f" FROM read_csv({quote(path)}, header=true, all_varchar=true, delim=',', quote='\"');\n"
        f"UPDATE gtfs_validation_files SET row_count = (SELECT count(*) FROM gtfs_v_{table}) "
        f"WHERE filename = {quote(table + '.txt')};"
    )


QUERIES = {
    "notices": "SELECT code, severity, filename, csv_row_number, notice::VARCHAR AS notice "
    "FROM gtfs_validation_notices ORDER BY ALL",
    "files": "SELECT * FROM gtfs_validation_files ORDER BY filename",
}


def run(feed_dir, date=DEFAULT_DATE, bin=None, queries=None):
    """Validates feed_dir and returns {query name: rows} for QUERIES plus `queries`."""
    bin = bin or duckdb_bins()[0]
    feed_dir = Path(feed_dir).resolve()
    queries = {**QUERIES, **(queries or {})}
    with tempfile.TemporaryDirectory(prefix="gtfs-validate-") as tmp:
        ext = os.environ.get("GTFS_EXTENSION")
        if ext:
            args = [f"PRAGMA gtfs_validate({quote(str(feed_dir))}, {quote(date) if date else 'NULL'});"]
            script = [f"LOAD {quote(ext)};"] + args
        else:
            script = [section("validate_schema")] + [section(s) for s in MACRO_SECTIONS] + pragma_sql(feed_dir, date)
        for name, sql in queries.items():
            script.append(f"COPY ({sql}) TO {quote(os.path.join(tmp, name + '.json'))} (FORMAT JSON, ARRAY true);")
        script_path = os.path.join(tmp, "script.sql")
        Path(script_path).write_text("\n".join(script))
        env = {k: v for k, v in os.environ.items() if k != "AI_AGENT"}
        cmd = [bin, "-bail", "-batch"] + (["-unsigned"] if ext else []) + [":memory:", "-c", f".read {script_path}"]
        proc = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=tmp, timeout=3600)
        if proc.returncode != 0 or "Error" in proc.stderr:
            raise RuntimeError(f"{bin} failed ({proc.returncode}): {proc.stderr.strip()[-4000:]}")
        out = {}
        for name in queries:
            rows = json.loads(Path(tmp, name + ".json").read_text() or "[]")
            out[name] = rows
        for row in out["notices"]:
            row["notice"] = json.loads(row["notice"]) if row["notice"] is not None else None
        return out


def notices(feed_dir, date=DEFAULT_DATE, bin=None):
    return run(feed_dir, date, bin)["notices"]


# ---------------------------------------------------------------- fixtures


def fixture_names(pattern=None):
    pattern = pattern or os.environ.get("GTFS_VALIDATION_FIXTURES", "*")
    return sorted(
        p.name
        for p in FEEDS.iterdir()
        if p.is_dir() and fnmatch.fnmatch(p.name, pattern) and (p / "expected.json").exists()
    )


def materialize(name, dest):
    """Writes fixture `name` into dest: feeds/base + the fixture's files, minus names listed in its _remove file.
    A fixture with a _standalone file does not start from base."""
    src = FEEDS / name
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    if not (src / "_standalone").exists() and name != "base":
        for f in (FEEDS / "base").iterdir():
            if f.is_file() and not f.name.startswith(("_", "expected")):
                shutil.copyfile(f, dest / f.name)
    for f in src.iterdir():
        if f.is_file() and not f.name.startswith("_") and f.name != "expected.json":
            shutil.copyfile(f, dest / f.name)
    if (src / "_remove").exists():
        for line in (src / "_remove").read_text().split():
            (dest / line).unlink(missing_ok=True)
    return dest


def expected(name):
    return json.loads((FEEDS / name / "expected.json").read_text())


# ---------------------------------------------------------------- oracle


def oracle_report(feed, date=DEFAULT_DATE):
    """MobilityData report.json for a feed dir or zip, cached by content."""
    jar = os.environ.get("GTFS_VALIDATOR_JAR")
    if not jar and REF:
        jar = str(REF / "tools/oracle/jar/gtfs-validator-8.0.2-SNAPSHOT-cli.jar")
    if not jar:
        raise RuntimeError("set GTFS_VALIDATOR_JAR or GTFS_VALIDATION_REF to run the official validator")
    java = os.environ.get("GTFS_VALIDATOR_JAVA", "java")
    h = hashlib.sha256(f"{date}\0{Path(jar).name}".encode())
    feed = Path(feed)
    entries = sorted(feed.iterdir()) if feed.is_dir() else [feed]
    for f in entries:
        if f.is_file():
            h.update(f.name.encode() + b"\0" + hashlib.sha256(f.read_bytes()).digest())
    default_cache = REF / "oracle-cache" if REF else Path(tempfile.gettempdir()) / "gtfs-validator-oracle-cache"
    cache = Path(os.environ.get("GTFS_VALIDATOR_ORACLE_CACHE", default_cache))
    cache.mkdir(parents=True, exist_ok=True)
    cached = cache / f"{h.hexdigest()}.json"
    if cached.exists():
        return json.loads(cached.read_text())
    with tempfile.TemporaryDirectory(prefix="oracle-") as out:
        proc = subprocess.run(
            [java, "-jar", jar, "-i", str(feed), "-o", out, "-d", date, "-svu"],
            capture_output=True,
            text=True,
            timeout=7200,
        )
        report = Path(out, "report.json")
        if not report.exists():
            raise RuntimeError(f"oracle failed ({proc.returncode}): {proc.stderr[-3000:]}")
        cached.write_text(report.read_text())
    return json.loads(cached.read_text())


FILE_KEYS = ("filename", "childFilename", "parentFilename")


def out_of_scope_emitter(code, notice):
    """Oracle notices on validated files whose Java emitter reads a file this port does not read."""
    # RouteAgencyIdValidator (agency.txt + routes.txt): routes.agency_id required or recommended by agency count.
    if (
        code in ("missing_required_field", "missing_recommended_field")
        and notice.get("filename") == "routes.txt"
        and notice.get("fieldName") == "agency_id"
    ):
        return True
    return False


def registry(bin=None):
    bin = bin or duckdb_bins()[0]
    env = {k: v for k, v in os.environ.items() if k != "AI_AGENT"}
    proc = subprocess.run(
        [
            bin,
            "-json",
            ":memory:",
            "-c",
            f".read {SQL / 'validate_registry.sql'}",
            "-c",
            "SELECT * FROM gtfs_validation_rules() ORDER BY code",
        ],
        capture_output=True,
        text=True,
        env=env,
        check=True,
    )
    text = proc.stdout[proc.stdout.index("[") :]
    return {r["code"]: r for r in json.loads(text)}


def in_scope(report, rules, strict=True):
    """The oracle notices this port must reproduce: registered codes whose file fields name only validated files.
    Returns (rows, truncated codes). The oracle exports at most 1000 sample notices per code; strict mode (fixtures)
    refuses truncated codes."""
    keep, truncated = [], set()
    for group in report["notices"]:
        if group["code"] not in rules:
            continue
        for n in group.get("sampleNotices", []):
            # A file field can name alternatives ("calendar.txt or calendar_dates.txt" for trips.service_id foreign
            # keys): in scope when every alternative is a validated file.
            files = [f for k in FILE_KEYS if isinstance(n.get(k), str) for f in n[k].split(" or ")]
            if all(f in GTFS_FILENAMES for f in files) and not out_of_scope_emitter(group["code"], n):
                keep.append({"code": group["code"], "severity": group["severity"], "notice": n})
        if group["totalNotices"] > len(group.get("sampleNotices", [])):
            if strict:
                raise RuntimeError(f"oracle truncated {group['code']} samples; use a smaller fixture")
            truncated.add(group["code"])
    return sorted(keep, key=lambda r: (r["code"], json.dumps(r["notice"], sort_keys=True))), truncated


# ---------------------------------------------------------------- comparison


def _split(notice):
    exact, floats = {}, {}
    for k, v in notice.items():
        if isinstance(v, float) and not float(v).is_integer():
            floats[k] = v
        else:
            exact[k] = v
    return json.dumps(exact, sort_keys=True), floats


def _close(a, b):
    if set(a) != set(b):
        return False
    return all(math.isclose(a[k], b[k], rel_tol=1e-6, abs_tol=1e-9) for k in a)


def compare(ours, theirs):
    """Multiset comparison of [{code, severity, notice}]; float fields match with rel_tol 1e-6.
    Returns (missing: in theirs not ours, extra: in ours not theirs)."""
    buckets = defaultdict(list)
    for t in theirs:
        exact, floats = _split(t["notice"])
        buckets[(t["code"], t["severity"], exact)].append((floats, t))
    extra = []
    for o in ours:
        exact, floats = _split(o["notice"])
        bucket = buckets.get((o["code"], o["severity"], exact), [])
        hit = next((i for i, (f, _) in enumerate(bucket) if _close(f, floats)), None)
        if hit is None:
            extra.append(o)
        else:
            bucket.pop(hit)
    missing = [t for b in buckets.values() for _, t in b]
    return missing, extra


def describe(missing, extra, limit=8):
    lines = []
    for label, rows in (("MISSING (oracle has, we do not)", missing), ("EXTRA (we have, oracle does not)", extra)):
        if rows:
            counts = Counter(r["code"] for r in rows)
            lines.append(f"{label}: " + ", ".join(f"{c}x{n}" for c, n in sorted(counts.items())))
            for r in rows[:limit]:
                lines.append(f"  {r['code']} {json.dumps(r['notice'], sort_keys=True)}")
    return "\n".join(lines)


def strip(rows):
    return [{"code": r["code"], "severity": r["severity"], "notice": r["notice"]} for r in rows]


# ---------------------------------------------------------------- CLI


def _feed_dir(arg, tmp):
    p = Path(arg)
    if p.is_dir():
        return p
    with zipfile.ZipFile(p) as z:
        for info in z.infolist():
            name = Path(info.filename).name
            if name in GTFS_FILENAMES and not info.is_dir():
                (Path(tmp) / name).write_bytes(z.read(info))
    return Path(tmp)


def main(argv):
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["run", "expect", "diff"])
    ap.add_argument("targets", nargs="+")
    ap.add_argument("--date", default=DEFAULT_DATE)
    ap.add_argument("--bin")
    a = ap.parse_args(argv)
    if a.cmd == "expect":
        rules = registry(a.bin)
        for name in a.targets:
            with tempfile.TemporaryDirectory() as tmp:
                feed = materialize(name, Path(tmp) / "feed")
                rows, _ = in_scope(oracle_report(feed, a.date), rules)
            out = {"date": a.date, "oracle": "gtfs-validator-8.0.2-SNAPSHOT (f9f4b9e)", "notices": rows}
            (FEEDS / name / "expected.json").write_text(json.dumps(out, indent=1, sort_keys=True) + "\n")
            print(name, Counter(r["code"] for r in rows))
        return 0
    with tempfile.TemporaryDirectory() as tmp:
        feed = _feed_dir(a.targets[0], tmp)
        ours = strip(notices(feed, a.date, a.bin))
        if a.cmd == "run":
            for (code, sev), n in sorted(Counter((r["code"], r["severity"]) for r in ours).items()):
                print(f"{sev:8} {code} {n}")
            return 0
        report = oracle_report(feed, a.date)
        theirs, truncated = in_scope(report, registry(a.bin), strict=False)
        totals = {g["code"]: g["totalNotices"] for g in report["notices"]}
        missing, extra = compare(ours, theirs)
        # A truncated oracle code only exports 1000 samples: our extras for it are expected, not a difference.
        extra = [r for r in extra if r["code"] not in truncated]
        codes = sorted({r["code"] for r in ours + theirs})
        oc, tc = Counter(r["code"] for r in ours), Counter(r["code"] for r in theirs)
        for c in codes:
            if c in truncated:
                print(f"TRUNC {c}: ours {oc[c]} oracle total {totals[c]} (all files), in-scope samples {tc[c]}")
            else:
                print(f"{'OK  ' if oc[c] == tc[c] else 'DIFF'} {c}: ours {oc[c]} oracle {tc[c]}")
        print(describe(missing, extra))
        return 1 if missing or extra else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
