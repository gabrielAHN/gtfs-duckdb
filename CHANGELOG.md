# Changelog

## Unreleased

- Native builds now target DuckDB v2.0.0, the version the DuckDB community extensions build against. Browser builds stay on DuckDB-WASM v1.4.3, which GTFS Viz uses.
- The extension compiles against both: it uses `Parser::GetBuiltinParser()` and `CreateInfo::SetSchema()` when DuckDB provides them, and quotes `gtfs_import` paths without the deprecated `KeywordHelper::WriteQuoted`.
- CI builds `osx_amd64` explicitly, since extension-ci-tools v2.0 makes it opt-in.
- Tests set `extension_directories` instead of `extension_directory`. DuckDB 2.0 deprecates the old setting and its CLI prints the warning on stdout, which broke `-json` output parsing.

## 1.0.1

Adds sonification macros that turn a feed's schedule into notes. `LOAD` now registers 96 functions.

- `gtfs_sonify_stops`: a note and a pan for every stop served that day, from its place in the network.
- `gtfs_sonify_events`: a note for every departure, taken from its stop, with density, velocity, accent and the route colour's hue. A `p_route_ids` filter returns those routes' rows of the unfiltered result.
- Both take a `p_date` and keep the services that run that day, from `calendar` and `calendar_dates`.
- Helpers: `gtfs_note_midi`, `gtfs_midi_to_hz` and `gtfs_hex_to_hue`.

## 1.0.0

First release of GTFS DuckDB, the `gtfs` DuckDB extension.

- GTFS functions registered at `LOAD` (89 functions), with explicit `gtfs_prepare`, `gtfs_init` and `gtfs_refresh` lifecycle pragmas.
- `PRAGMA gtfs_import(directory)` imports a whole GTFS folder in one call; GTFS Viz uses it for both the web app and the CLI.
- Raw-file normalization, geometry, pathway shortest paths, trip editing and route-shape lane geometry used by GTFS Viz.
- Native builds against DuckDB v1.5.4 (Linux, macOS, Windows) and browser builds against DuckDB-WASM v1.4.3 (EH, MVP).
- GitHub Actions builds, tests and stages an unsigned development repository; signed distribution is through DuckDB community extensions.
