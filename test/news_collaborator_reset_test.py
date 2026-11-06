"""Integration checks for the collaborator reset endpoint, with isolated local data.
Run: python test/news_collaborator_reset_test.py [path-to-endpoint.php]
"""
import http.client
import json
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode

SOURCE = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path('server/add_community_news_source.php')
COLLABORATOR = 'NicoloLaFerla'

class CollaboratorResetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory(prefix='sonarpad-feed-reset-test-')
        cls.root = Path(cls.work.name)
        (cls.root / 'api').mkdir()
        (cls.root / 'data_private').mkdir()
        source = SOURCE.read_text(encoding='utf-8-sig')
        (cls.root / 'api' / 'add.php').write_text(source, encoding='utf-8')
        cls.file = cls.root / 'data_private' / 'rate_limits_news_sources.json'
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            cls.port = sock.getsockname()[1]
        php = shutil.which('php')
        extensions = Path(php).parent / 'ext'
        cls.server = subprocess.Popen([php, '-d', 'extension_dir=' + str(extensions),
                                      '-d', 'extension=mbstring', '-d', 'date.timezone=UTC', '-S',
                                      f'127.0.0.1:{cls.port}', '-t', str(cls.root)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                with socket.create_connection(('127.0.0.1', cls.port), timeout=.2):
                    break
            except OSError:
                time.sleep(.05)
        else:
            cls.server.terminate()
            raise RuntimeError('PHP test server did not start')

    @classmethod
    def tearDownClass(cls):
        cls.server.terminate()
        cls.server.wait(timeout=10)
        cls.work.cleanup()

    def setUp(self):
        self.today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
        self.initial = {self.today: {'127.0.0.1': 5, '192.0.2.7': 5}, '2020-01-01': {'192.0.2.8': 2}}
        self.file.write_text(json.dumps(self.initial), encoding='utf-8')

    def request(self, method='GET', data=None, headers=None, path='/api/add.php?collaborator=NicoloLaFerla'):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=5)
        request_headers = {'Content-Type': 'application/x-www-form-urlencoded', **(headers or {})}
        conn.request(method, path, urlencode(data) if data is not None else None, request_headers)
        response = conn.getresponse()
        result = response.status, dict(response.getheaders()), response.read().decode('utf-8')
        conn.close()
        return result

    def test_get_shows_ip_without_resetting(self):
        status, headers, body = self.request()
        self.assertEqual(status, 200)
        self.assertIn('127.0.0.1', body)
        self.assertIn('Azzera il mio limite', body)
        self.assertIn('no-store', headers['Cache-Control'])
        self.assertEqual(headers['Referrer-Policy'], 'no-referrer')
        self.assertNotIn('disabled', body)
        self.assertNotIn('<script', body)
        self.assertEqual(json.loads(self.file.read_text()), self.initial)

    def test_invalid_links_cannot_reset(self):
        for query in ['collaborator=1', 'collaborator=', 'collaborator=wrong',
                      'collaborator[]=NicoloLaFerla']:
            for method in ['GET', 'POST']:
                status, _, body = self.request(method, {}, path='/api/add.php?' + query)
                self.assertEqual(status, 403)
                self.assertNotIn('<button', body)
                self.assertEqual(json.loads(self.file.read_text()), self.initial)

    def test_only_request_ip_resets_and_repeat_is_safe(self):
        for _ in range(2):
            status, _, body = self.request('POST', {'ip': '192.0.2.7'},
                                          {'X-Forwarded-For': '192.0.2.7', 'X-Real-IP': '192.0.2.7'})
            self.assertEqual(status, 200)
            self.assertIn('Limite azzerato', body)
            expected = json.loads(json.dumps(self.initial))
            expected[self.today]['127.0.0.1'] = 0
            self.assertEqual(json.loads(self.file.read_text()), expected)

    def test_bad_json_is_not_overwritten(self):
        self.file.write_text('{bad data', encoding='utf-8')
        self.assertEqual(self.request('POST', {})[0], 503)
        self.assertEqual(self.file.read_text(), '{bad data')

    def test_standard_quota_still_counts_and_blocks_at_five(self):
        source = (self.root / 'api' / 'add.php').read_text(encoding='utf-8')
        definitions = source.split("\nif ($_SERVER['REQUEST_METHOD'] !== 'POST') {")[0]
        script = definitions + "\necho json_encode([update_news_submission_limit('192.0.2.7'), update_news_submission_limit('192.0.2.9')]);"
        runner = self.root / 'api' / 'quota.php'
        runner.write_text(script, encoding='utf-8')
        result = subprocess.run([shutil.which('php'), '-d', 'date.timezone=UTC', str(runner)],
                                capture_output=True, check=True)
        self.assertEqual(json.loads(result.stdout), [False, True])
        expected = json.loads(json.dumps(self.initial))
        expected[self.today]['192.0.2.9'] = 1
        self.assertEqual(json.loads(self.file.read_text()), expected)

    def test_normal_api_keeps_its_contract(self):
        self.assertEqual(self.request(path='/api/add.php')[0], 405)
        status, _, body = self.request('POST', {}, path='/api/add.php')
        self.assertEqual(status, 400)
        self.assertEqual(json.loads(body)['error_code'], 'NAME_MISSING')
        self.assertEqual(json.loads(self.file.read_text()), self.initial)

if __name__ == '__main__':
    unittest.main()
