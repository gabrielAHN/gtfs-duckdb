import functools
import gzip
import hashlib
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
import urllib.request


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get('GTFS_STAGED_REPOSITORY'), 'Set GTFS_STAGED_REPOSITORY to a real staged tree')
class StagedRepositoryIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.repository = Path(os.environ['GTFS_STAGED_REPOSITORY']).resolve()
        self.manifest = json.loads((self.repository / 'manifest.json').read_text())

    def test_http_download_checksums(self):
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(self.repository))
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for item in self.manifest['artifacts']:
                with urllib.request.urlopen(f'http://127.0.0.1:{server.server_port}/{item["path"]}') as response:
                    data = response.read()
                self.assertEqual(len(data), item['size'])
                self.assertEqual(hashlib.sha256(data).hexdigest(), item['sha256'])
                original = gzip.decompress(data) if item['target'] == 'native' else data
                self.assertEqual(hashlib.sha256(original).hexdigest(), item['source_sha256'])
                print(json.dumps(dict(download=item['path'], sha256=item['sha256'])))
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    @unittest.skipUnless(os.environ.get('DUCKDB_BIN'), 'Set DUCKDB_BIN to matching standalone CLI')
    def test_native_fresh_cache_install(self):
        requests = []

        class Handler(http.server.SimpleHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                super().do_GET()

        server = http.server.ThreadingHTTPServer(
            ('127.0.0.1', 0), functools.partial(Handler, directory=str(self.repository))
        )
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                cache = base / 'cache'
                binary = os.environ['DUCKDB_BIN']
                probe = subprocess.run(
                    [binary, '-json', ':memory:', '-c', 'SELECT version() AS version; PRAGMA platform;'],
                    text=True,
                    capture_output=True,
                    check=True,
                )
                decoder = json.JSONDecoder()
                version_rows, end = decoder.raw_decode(probe.stdout)
                platform_rows = json.loads(probe.stdout[end:])
                version = version_rows[0]['version']
                platform = platform_rows[0]['platform']
                quoted = lambda value: str(value).replace("'", "''")
                sql = f"SET home_directory='{quoted(base)}'; SET extension_directories=['{quoted(cache)}']; INSTALL gtfs FROM 'http://127.0.0.1:{server.server_port}'; LOAD gtfs; SELECT route_type_to_name(3) AS name;"
                result = subprocess.run(
                    [binary, '-unsigned', '-json', ':memory:', '-c', sql], text=True, capture_output=True, timeout=60
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), [{'name': 'Bus'}])
                expected = f'{version}/{platform}/gtfs.duckdb_extension.gz'
                self.assertIn('/' + expected, requests)
                item = next(item for item in self.manifest['artifacts'] if item['path'] == expected)
                installed = list(cache.rglob('gtfs.duckdb_extension'))
                self.assertEqual(len(installed), 1)
                self.assertEqual(hashlib.sha256(installed[0].read_bytes()).hexdigest(), item['source_sha256'])
                print(
                    json.dumps(
                        dict(
                            native='PASS',
                            version=version,
                            platform=platform,
                            requests=requests,
                            query=json.loads(result.stdout),
                        )
                    )
                )
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    @unittest.skipUnless((ROOT / 'node_modules/@playwright/test').exists(), 'Run npm ci for browser test dependencies')
    def test_chromium_staged_eh_and_mvp(self):
        source = (ROOT / 'test/test_wasm.mjs').read_text()
        old_root = "const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');"
        old_file = 'resolve(root, `build/wasm_${match[1]}/extension/gtfs/gtfs.duckdb_extension.wasm`)'
        self.assertEqual(source.count(old_root), 1)
        self.assertEqual(source.count(old_file), 1)
        source = source.replace(old_root, f'const root = {json.dumps(str(ROOT))};')
        source = source.replace(
            old_file,
            f'resolve({json.dumps(str(self.repository))}, `v1.4.3/wasm_${{match[1]}}/gtfs.duckdb_extension.wasm`)',
        )
        with tempfile.TemporaryDirectory() as directory:
            harness = Path(directory) / 'staged-wasm.mjs'
            harness.write_text(source)
            result = subprocess.run(
                ['node', str(harness), '--unsigned-only'], text=True, capture_output=True, timeout=180
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        print(result.stdout)
        summary = json.loads(result.stdout.strip().splitlines()[-1])
        self.assertEqual(summary['status'], 'PASS')
        self.assertEqual(summary['scope'], 'unsigned-development-only')
        self.assertEqual(summary['cases'], 2)
        for platform in ['wasm_eh', 'wasm_mvp']:
            self.assertIn(f'/v1.4.3/{platform}/gtfs.duckdb_extension.wasm', summary['requests'])


if __name__ == '__main__':
    unittest.main()
