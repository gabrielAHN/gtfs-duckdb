#!/usr/bin/env python3
"""Generate the per-table loader tables and macros of PRAGMA gtfs_validate (stdlib only).

    python3 test/validation/gen_loader.py          rewrite the LOADER-GENERATED blocks
    python3 test/validation/gen_loader.py --check  exit 1 when a block is out of date

Input: gtfs_vc_schema() in sql/validate_core.sql (per schema column: order, kind, Java type, level, bounds) and the
gtfs_v_<table> columns in sql/validate_schema.sql.
Output, between the LOADER-GENERATED-BEGIN and LOADER-GENERATED-END lines:
  sql/validate_schema.sql  gtfs_vc_wide_<table>: one row per data row of the header's length, with the raw value
                           r_<column> of each schema column (NULL when the header lacks it) and, for typed kinds, the
                           value p_<column> Java parses
  sql/validate_core.sql    gtfs_vc_wide_build_<table>(), gtfs_vc_cell_notices_<table>(), gtfs_vc_entities_<table>()
The checks are RowParser's and DefaultFieldValidator's, one column at a time (docs/validation-internals.md).
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CORE = REPO / "sql" / "validate_core.sql"
SCHEMA = REPO / "sql" / "validate_schema.sql"
BEGIN = "-- LOADER-GENERATED-BEGIN (test/validation/gen_loader.py; do not edit)"
END = "-- LOADER-GENERATED-END"

PARSE = {
    "integer": "gtfs_vc_int",
    "enum": "gtfs_vc_int",
    "time": "gtfs_vc_time",
    "color": "gtfs_vc_color",
    "float": "gtfs_vc_double",
    "latitude": "gtfs_vc_double",
    "longitude": "gtfs_vc_double",
    "date": "gtfs_vc_date",
}
SQL_TYPE = {
    "integer": "INTEGER",
    "enum": "INTEGER",
    "time": "INTEGER",
    "color": "INTEGER",
    "float": "DOUBLE",
    "latitude": "DOUBLE",
    "longitude": "DOUBLE",
    "date": "DATE",
}
INVALID = {
    "integer": "invalid_integer",
    "enum": "invalid_integer",
    "time": "invalid_time",
    "color": "invalid_color",
    "float": "invalid_float",
    "latitude": "invalid_float",
    "longitude": "invalid_float",
    "date": "invalid_date",
}
STRING_KINDS = {"text", "id", "url", "timezone"}
BOUND_TEXT = {"POSITIVE": "positive ", "NON_NEGATIVE": "non-negative ", "NON_ZERO": "non-zero "}
BOUND_TEST = {"POSITIVE": "<= 0", "NON_NEGATIVE": "< 0", "NON_ZERO": "= 0"}


def schema():
    """{table: [column dict in schema order]} from gtfs_vc_schema()."""
    text = CORE.read_text()
    body = text.split("CREATE OR REPLACE MACRO gtfs_vc_schema() AS TABLE", 1)[1].split(") s(filename", 1)[0]
    row = re.compile(r"\('(\w+)\.txt', (\d+), '(\w+)', '(\w+)', '(\w+)', '(\w+)', (NULL|'\w+')\)")
    tables = {}
    for m in row.finditer(body):
        table, order, name, kind, java_type, level, bounds = m.groups()
        tables.setdefault(table, []).append(
            {
                "order": int(order),
                "name": name,
                "kind": kind,
                "java_type": java_type,
                "level": level,
                "bounds": None if bounds == "NULL" else bounds.strip("'"),
            }
        )
    for table, cols in tables.items():
        assert [c["order"] for c in cols] == list(range(1, len(cols) + 1)), table
        for c in cols:
            assert c["kind"] in STRING_KINDS or c["kind"] in PARSE, (table, c)
            assert c["bounds"] is None or c["kind"] in ("integer", "float"), (table, c)
    return tables


def entity_columns(table):
    """[(name, type)] of gtfs_v_<table> in validate_schema.sql, after csv_row_number."""
    text = SCHEMA.read_text()
    body = text.split(f"CREATE OR REPLACE TEMP TABLE gtfs_v_{table} (", 1)[1].split(");", 1)[0]
    cols = [tuple(part.split()) for part in body.replace("\n", " ").split(",")]
    assert cols[0] == ("csv_row_number", "BIGINT"), table
    return cols[1:]


def value(c):
    """The trimmed value (CsvRow.asString): the parser already trimmed every value of a plain row."""
    return f"CASE WHEN plain THEN r_{c['name']} ELSE gtfs_vc_trim(r_{c['name']}) END"


def wide_table(table, cols):
    parts = ["csv_row_number BIGINT", "plain BOOLEAN"]
    for c in cols:
        parts.append(f"r_{c['name']} VARCHAR")
        if c["kind"] in PARSE:
            parts.append(f"p_{c['name']} {SQL_TYPE[c['kind']]}")
    return f"CREATE OR REPLACE TEMP TABLE gtfs_vc_wide_{table} (\n  " + ",\n  ".join(parts) + ");"


def wide_build(table, cols):
    outer = ["csv_row_number", "plain"]
    inner = ["d.csv_row_number", "d.plain"]
    for c in cols:
        outer.append(f"r_{c['name']}")
        if c["kind"] in PARSE:
            outer.append(f"{PARSE[c['kind']]}({value(c)}) AS p_{c['name']}")
        inner.append(f"d.fields[p.pos[{c['order']}]] AS r_{c['name']}")
    return (
        f"-- Data rows of {table}.txt with the header's length: the raw value of each schema column (the header's column\n"
        f"-- of that name, NULL without one) and the value Java parses from the trimmed one.\n"
        f"CREATE OR REPLACE MACRO gtfs_vc_wide_build_{table}() AS TABLE\n"
        f"SELECT " + ",\n  ".join(outer) + "\n"
        "FROM (\n  SELECT " + ",\n    ".join(inner) + "\n"
        "  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p\n  WHERE d.length_ok);"
    )


def checks(table, c):
    """[(condition, code, json_object)] for one column: gtfs_vc_cell_notices' checks of one cell, in its order."""
    name, kind, raw, v, p = c["name"], c["kind"], f"r_{c['name']}", value(c), f"p_{c['name']}"
    out = []
    if c["level"] in ("REQUIRED", "RECOMMENDED"):
        code = "missing_required_field" if c["level"] == "REQUIRED" else "missing_recommended_field"
        out.append((f"{raw} IS NULL", code, ""))
    # A plain row has only chars from '!' to '~': none of these four notices can apply to it.
    out.append((f"NOT plain AND contains({raw}, chr(65533))", "invalid_character", f", 'fieldValue', {raw}"))
    out.append(
        (
            f"NOT plain AND (contains({raw}, chr(10)) OR contains({raw}, chr(13)))",
            "new_line_in_value",
            f", 'fieldValue', {raw}",
        )
    )
    out.append(
        (f"NOT plain AND gtfs_vc_trim({raw}) <> {raw}", "leading_or_trailing_whitespaces", f", 'fieldValue', {raw}")
    )
    if kind == "id":
        out.append(
            (
                f"NOT plain AND regexp_matches({v}, '[^\\x20-\\x7E]')",
                "non_ascii_or_non_printable_char",
                f", 'fieldValue', {v}",
            )
        )
    if kind == "url":
        out.append((f"{raw} IS NOT NULL AND NOT gtfs_vc_url_ok({v})", "invalid_url", f", 'fieldValue', {v}"))
    if kind == "timezone":
        out.append((f"{raw} IS NOT NULL AND NOT gtfs_vc_timezone_ok({v})", "invalid_timezone", f", 'fieldValue', {v}"))
    if kind in PARSE:
        out.append((f"{raw} IS NOT NULL AND {p} IS NULL", INVALID[kind], f", 'fieldValue', {v}"))
    if kind == "enum":
        out.append(
            (
                f"gtfs_validation_enum_name('{c['java_type']}', {p}) = 'UNRECOGNIZED'",
                "unexpected_enum_value",
                f", 'fieldValue', {p}::INTEGER",
            )
        )
    # checkBounds: Integer/Double.compareTo(0) (-0.0 is below 0.0, NaN above), asLatitude / asLongitude ranges
    if kind in ("latitude", "longitude"):
        limit = 90 if kind == "latitude" else 180
        out.append(
            (
                f"isnan({p}) OR NOT (-{limit} <= {p} AND {p} <= {limit})",
                "number_out_of_range",
                f", 'fieldType', '{kind} within [-{limit}, {limit}]', 'fieldValue', to_json({p})",
            )
        )
    elif kind == "integer" and c["bounds"]:
        out.append(
            (
                f"{p} {BOUND_TEST[c['bounds']]}",
                "number_out_of_range",
                f", 'fieldType', '{BOUND_TEXT[c['bounds']]}integer', 'fieldValue', to_json({p}::INTEGER)",
            )
        )
    elif kind == "float" and c["bounds"]:
        out.append(
            (
                f"gtfs_vc_cmp0('float', NULL::INTEGER, {p}) {BOUND_TEST[c['bounds']]}",
                "number_out_of_range",
                f", 'fieldType', '{BOUND_TEXT[c['bounds']]}float', 'fieldValue', to_json({p})",
            )
        )
    return [
        (
            cond,
            code,
            f"json_object('filename', '{table}.txt', 'csvRowNumber', csv_row_number, 'fieldName', '{name}'{extra})",
        )
        for cond, code, extra in out
    ]


def cell_notices(table, cols):
    all_checks = [chk for c in cols for chk in checks(table, c)]
    branches = [
        f"  SELECT csv_row_number, '{code}' AS code,\n    {notice} AS notice\n  FROM w WHERE {cond}"
        for cond, code, notice in all_checks
    ]
    return (
        f"-- RowParser / DefaultFieldValidator notices of the values of {table}.txt (fieldValue: raw for the character\n"
        f"-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.\n"
        f"CREATE OR REPLACE MACRO gtfs_vc_cell_notices_{table}() AS TABLE\n"
        f"WITH w AS MATERIALIZED (\n  SELECT * FROM gtfs_vc_wide_{table}\n  WHERE "
        + "\n    OR ".join(f"({cond})" for cond, _, _ in all_checks)
        + "\n),\n"
        "n AS (\n" + "\n  UNION ALL\n".join(branches) + "\n)\n"
        "SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err\n"
        "FROM n JOIN gtfs_validation_rules() r USING (code);"
    )


def entities(table, cols):
    want = entity_columns(table)
    assert [n for n, _ in want] == [c["name"] for c in cols], table
    out = ["w.csv_row_number"]
    for (name, sql_type), c in zip(want, cols):
        expected = "VARCHAR" if c["kind"] in STRING_KINDS else SQL_TYPE[c["kind"]]
        assert sql_type == expected, (table, name, sql_type)
        out.append(f"({value(c)})::{sql_type} AS {name}" if c["kind"] in STRING_KINDS else f"p_{name} AS {name}")
    return (
        f"-- Entities of {table}.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).\n"
        f"CREATE OR REPLACE MACRO gtfs_vc_entities_{table}() AS TABLE\n"
        "SELECT " + ",\n  ".join(out) + f"\nFROM gtfs_vc_wide_{table} w\n"
        "WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);"
    )


def blocks():
    tables = schema()
    schema_block = [wide_table(t, cols) for t, cols in tables.items()]
    core_block = [
        part for t, cols in tables.items() for part in (wide_build(t, cols), cell_notices(t, cols), entities(t, cols))
    ]
    return {SCHEMA: "\n".join(schema_block), CORE: "\n".join(core_block)}


def replace_block(text, block):
    start, end = text.index(BEGIN), text.index(END)
    return text[: start + len(BEGIN)] + "\n" + block + "\n" + text[end:]


def main(argv):
    check = argv[1:] == ["--check"]
    stale = []
    for path, block in blocks().items():
        text = path.read_text()
        new = replace_block(text, block)
        if new != text:
            stale.append(path.name)
            if not check:
                path.write_text(new)
    if check and stale:
        print(f"out of date: {', '.join(stale)} (run python3 test/validation/gen_loader.py)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
