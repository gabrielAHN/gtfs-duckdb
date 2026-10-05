# Local development extension repository

This is an **UNSIGNED DEVELOPMENT-ONLY** repository, not a signed release. The staging command does not build, sign, upload, commit, or alter its inputs. It accepts only the currently verified `native/osx_arm64`, `wasm/wasm_eh`, and `wasm/wasm_mvp` targets.

## Stage existing artifacts

Run from the extension repository root with Python 3. The output directory must not already exist; choose a new name for subsequent staging runs.

```sh
python3 scripts/stage-repository.py \
  --output build/staged-repository \
  --artifact native v1.5.4 osx_arm64 \
    build/release/extension/gtfs/gtfs.duckdb_extension \
  --artifact wasm v1.4.3 wasm_eh \
    build/wasm_eh/extension/gtfs/gtfs.duckdb_extension.wasm \
  --artifact wasm v1.4.3 wasm_mvp \
    build/wasm_mvp/extension/gtfs/gtfs.duckdb_extension.wasm
```

Each `--artifact` takes `TARGET VERSION PLATFORM FILE`. Versions and platforms must be observed from the clients, not inferred from build directory names. Native `SELECT version()` and `PRAGMA platform` returned `v1.5.4` and **`osx_arm64`**. The real browser engines returned `v1.4.3`, requesting the `wasm_eh` and `wasm_mvp` paths below. There is no extra `duckdb-wasm` directory in these custom-repository requests.

```text
build/staged-repository/
  manifest.json
  v1.5.4/osx_arm64/gtfs.duckdb_extension.gz
  v1.4.3/wasm_eh/gtfs.duckdb_extension.wasm
  v1.4.3/wasm_mvp/gtfs.duckdb_extension.wasm
```

Before creating output, the tool reads every input and checks the footer format from `extension-ci-tools/scripts/append_extension_metadata.py`: the `duckdb_signature` custom-section prefix, eight 32-byte padded ASCII fields, `4` identifier, `CPP` ABI, engine version, platform, nonempty extension version, reserved fields, and 256 zero signature bytes. It checks the native Mach-O or WASM binary magic as well. Missing, truncated, mismatched, nonzero-signature, unsupported, and duplicate inputs fail. Invalid arguments cannot introduce path traversal. This validates declared compatibility, not the authenticity of executable code; the footer does not encode the extension name. Only stage trusted local builds, and verify execution separately.

Native bytes are gzip-compressed at level 9 with timestamp zero and no embedded filename. Browser bytes are copied uncompressed. Manifest entries contain target, engine version, platform, ABI, extension version, relative path, byte size, SHA-256 of served bytes, SHA-256 of original bytes, and the development-only status. The manifest contains no machine-specific paths or timestamps. Identical inputs and argument order produce identical trees using the same Python/zlib toolchain; cross-zlib compressed-byte identity is not promised. No checksum is a signature.

All inputs are validated before any copying. Existing output directories are refused rather than merged or replaced. A filesystem failure during writing can leave a partial newly created output directory; discard that directory before retrying. A completed tree has `manifest.json`, written last.

## Tests and real downloads

Unit tests use temporary mock binary fixtures only; real staging above uses the built extension files.

```sh
python3 -m unittest discover -s test -p 'test_stage_repository.py' -v

GTFS_STAGED_REPOSITORY="$PWD/build/staged-repository" \
DUCKDB_BIN=/path/to/standalone-duckdb-1.5.4 \
python3 -m unittest discover -s test -p 'test_staged_repository_integration.py' -v
```

Set `TMPDIR` to your scratch directory if your environment requires it. Integration tests skip explicitly when their environment inputs are absent. The browser case needs `npm ci` and a Playwright Chromium install in this repository.

The integration suite:

- Serves the actual staged tree over loopback HTTP, downloads all three files, verifies sizes and SHA-256 checksums, and verifies decompressed native bytes against their original checksum.
- Queries the standalone native client's engine version/platform, sets both home and extension directories to fresh temporary locations, performs HTTP `INSTALL` and `LOAD`, checks the `Bus` query result, observes the exact requested path, and checks the installed cache's SHA-256.
- Copies `test/test_wasm.mjs` to a temporary directory, changes only its repository file source and root resolution, then runs its existing unsigned-positive EH/MVP cases in real Chromium. The app and repository use different loopback origins with CORS. All 72 macros, lifecycle, shortest path, pending edits, route types, and non-destructive load assertions remain intact.

To compare two complete real staging runs, repeat the staging command with `--output build/staged-repository-repeat` and run:

```sh
diff -r build/staged-repository build/staged-repository-repeat
```

For manual native testing, serve the directory locally:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/staged-repository
```

The plain Python server is for native/download checks; the browser integration suite provides its own CORS-enabled repository server. Unsigned permission is enabled only inside the isolated test processes. Do not weaken a production consumer's signature policy.

## Verified local result

The unit suite passed, including 13 invalid-input subcases, deterministic output, and refusal to overwrite an existing tree. All three integration tests passed using the staged real artifacts. Chromium `147.0.7727.15` passed both browser variants; the standalone native CLI downloaded from `/v1.5.4/osx_arm64/gtfs.duckdb_extension.gz` into a clean cache and returned `Bus`. Every artifact HTTP download returned 200 and matched the manifest. A second real staging run was byte-identical across all four files, including the manifest.

Served-byte SHA-256:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Native gzip | 24271 | `e26be4f919331675da9a9fcc80855a76a9973ac704e8ce500ec00ef519b2d155` |
| WASM EH | 104182 | `8ab9fa7a1d9a4d685c6c547050fe7d84a386bbc05c1880f7f49de3f8a4b858f4` |
| WASM MVP | 101803 | `27d691e77ad26e8262d8a2fede44bb2ea1cfeda69ca36aff375ba5fcfcedbc06` |

The uncompressed native SHA-256 is `6f9b8f34223b0b73dc79742b07ca48c7f996da4b7b051d4ded628b26d209aec5`. `manifest.json` SHA-256 is `47e8cc07b2c3beb83ded36a0150c68f94f23498e6303d166ee020456ffb590ad`. The footer extension version is `cfaf3e2`; this is build metadata, not a published release version.

The complete integration output is in `build/staged-repository-integration.log`. Artifacts and logs are ignored build outputs. These checks do not prove signed distribution, public availability, cross-platform CI, or production readiness. The known MVP `_setThrew` strict-signature/error-path defect is unchanged; positive unsigned staging tests do not waive it. No public upload, release, commit, or rebuild was performed.
