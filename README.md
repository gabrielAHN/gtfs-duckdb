# GTFS DuckDB

This repository is based on https://github.com/duckdb/extension-template, check it out if you want to build and ship your own DuckDB extension.

---

`gtfs` adds GTFS transit functions to DuckDB: stop/pathway/route normalization, station and route analysis, pathway shortest paths, trip editing and route-shape lane geometry. It is used by [GTFS Viz](https://github.com/gabrielAHN/gtfs-viz) in the browser (DuckDB-WASM) and in its CLI.

```sql
INSTALL gtfs FROM '<repository>';
LOAD gtfs;
SELECT route_type_to_name(3);  -- Bus
```

`LOAD` only registers functions. Datasets are managed explicitly:

```sql
PRAGMA gtfs_import('feed');          -- read a GTFS folder and build every table
PRAGMA gtfs_refresh;                 -- rebuild after edits, keeping pending edits
```

`gtfs_import` requires `stops.txt`, turns missing optional files into empty tables and keeps pending edits when a feed is imported again. Pass `''` to read files from the working directory or, in DuckDB-WASM, files registered by name. The lower-level steps it runs are also available: `gtfs_prepare` (edit tables), `gtfs_normalize_<table>` for raw `<table>_raw` staging tables, `gtfs_empty_<table>` and `gtfs_init` (views, materialized tables and indexes). Route-shape caches use `gtfs_prepare_route_cache`, `gtfs_reset_route_cache` and `gtfs_route_cache_version`. Spatial geometry functions need the `spatial` extension loaded. See the [docs](https://gtfs-viz-production-f1a4.up.railway.app/docs/gtfs-duckdb/usage/) and the [function reference](https://gtfs-viz-production-f1a4.up.railway.app/docs/gtfs-duckdb/functions/), where every example runs on a real feed, or [docs/functions.md](docs/functions.md).

The extension is not yet in the DuckDB community repository, so `INSTALL gtfs FROM community` does not work yet. See [Releasing](#releasing).

## Layout

- `sql/*.sql`: function and lifecycle SQL, embedded at build time through `src/include/gtfs_sql.hpp.in`.
- `src/gtfs_extension.cpp`: registers macros in the system catalog and the lifecycle pragmas.
- `test/sql/gtfs.test`: SQLLogicTests run by `make test`.
- `test/test_*.py`, `test/*.mjs`: native, parity, lifecycle, staging and browser tests against built artifacts.
- `community/description.yml`: descriptor for the DuckDB community-extensions repository.

## Building

Builds run locally with the template Makefile. No vcpkg dependencies are required.

```sh
git submodule update --init --recursive
GEN=ninja make            # build/release/duckdb, build/release/extension/gtfs/gtfs.duckdb_extension
make test                 # SQLLogicTests
make format-check         # needs clang-format 11, black 24, cmake-format
```

The main binaries are:

- `build/release/duckdb`: DuckDB shell with the extension linked in.
- `build/release/test/unittest`: DuckDB test runner.
- `build/release/extension/gtfs/gtfs.duckdb_extension`: the loadable binary.

### WASM

GTFS Viz uses DuckDB-WASM with DuckDB v1.4.3, so the browser artifacts are built against a separate v1.4.3 checkout using Emscripten 3.1.71:

```sh
EMSDK=/path/to/emsdk DUCKDB_WASM_SOURCE=/path/to/duckdb-v1.4.3 bash scripts/build-wasm.sh
```

This produces `build/wasm_eh` and `build/wasm_mvp` artifacts.

## Testing

```sh
npm ci && npx playwright install chromium    # browser test dependencies

DUCKDB_BIN=/path/to/duckdb-1.5.4 \
GTFS_EXTENSION="$PWD/build/release/extension/gtfs/gtfs.duckdb_extension" \
GTFS_DEPENDENCY_CACHE=/path/to/extension-cache \
python3 -m unittest discover -s test -p 'test_*.py' -v

npm run test:js
npm run test:wasm:unsigned
npm run test:wasm
```

`GTFS_DEPENDENCY_CACHE` must contain the `spatial` extension for the native engine. Parity tests compare against the test-only reference `test/fixtures/legacy-gtfs_sql.hpp.txt` (provenance in `test/fixtures/legacy-reference.md`).

Unsigned loading (`-unsigned`, `allowUnsignedExtensions`) is enabled only inside these test processes. The strict browser run (`npm run test:wasm`) currently fails on the DuckDB-WASM MVP bundle with `_setThrew is not defined`, which also reproduces without this extension.

To serve locally built artifacts as an extension repository for GTFS Viz development, see [docs/local-extension-repository.md](docs/local-extension-repository.md).

## Releasing

The current release is **1.0.1**. Each version is listed in [CHANGELOG.md](CHANGELOG.md).

GitHub Actions (`.github/workflows/MainDistributionPipeline.yml`) runs on pull requests, pushes to `main` and manual dispatch. It builds native binaries against DuckDB v1.5.4 and `wasm_eh`/`wasm_mvp` against DuckDB-WASM v1.4.3, runs the format checks and test suites, and uploads an unsigned development repository artifact. These artifacts are for testing only.

Each push to `main` also republishes the unsigned development repository as `gtfs-extension-repository.tar.gz` on the moving [`main-latest`](https://github.com/gabrielAHN/gtfs-duckdb/releases/tag/main-latest) pre-release. GTFS Viz's deploy downloads it, checks the WASM files against the SHA-256 sums in its `manifest.json` and serves them from its own `/extensions/` path; because the build is unsigned, GTFS Viz enables unsigned loading only in that deploy build.

Signed distribution goes through the [DuckDB community extensions](https://duckdb.org/community_extensions/documentation) repository, whose CI builds and signs every platform:

1. Merge to `main` and tag the merge commit `v1.0.1`, so built binaries report `v1.0.1` instead of a commit hash.
2. Copy the merged commit SHA into `community/description.yml` (`repo.ref`); `extension.version` is `1.0.1`.
3. Open a pull request to `duckdb/community-extensions` adding `extensions/gtfs/description.yml`.

After it is merged, `INSTALL gtfs FROM community; LOAD gtfs;` works with default signature checks.

## Updating DuckDB

See [docs/UPDATING.md](docs/UPDATING.md).
