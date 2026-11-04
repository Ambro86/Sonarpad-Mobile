"""Real HTTP and SQLite checks against an isolated temporary installation."""
import concurrent.futures
import json
import pathlib
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main():
    source = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="sonarpad-sync-test-") as temp:
        root = pathlib.Path(temp) / 'sonarpad_sync'
        webroot = pathlib.Path(temp) / 'httpdocs'
        shutil.copytree(source / 'deploy/synk', webroot / 'synk')
        for directory in ("src", "public", "private"):
            shutil.copytree(source / directory, root / directory,
                            ignore=shutil.ignore_patterns("config.php"))
        (root / "private/config.php").write_text(
            "<?php return ['require_https' => false];", encoding="utf-8")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        process = subprocess.Popen(
            ["php", "-d", "extension=pdo_sqlite", "-S", f"127.0.0.1:{port}",
             "-t", str(webroot)], stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
        url = f"http://127.0.0.1:{port}/synk/index.php?action="

        def call(action, token=None, body=None):
            headers = {"Content-Type": "application/json"}
            if token:
                headers["Authorization"] = "Bearer " + token
            request = urllib.request.Request(url + action,
                data=None if body is None else json.dumps(body).encode(), headers=headers)
            try:
                with urllib.request.urlopen(request, timeout=5) as response:
                    return response.status, json.load(response)
            except urllib.error.HTTPError as error:
                return error.code, json.load(error)

        try:
            for _ in range(50):
                try:
                    assert call("health")[1]["ok"]
                    break
                except urllib.error.URLError:
                    time.sleep(.1)
            else:
                raise AssertionError("Server failed to start")
            assert call("create", body={})[0] == 401
            a, b = "a" * 64, "b" * 64
            assert call("create", a, {"device_name": "Windows"})[0] == 200
            code = call("code", a, {})[1]["code"]
            assert call("join", b, {"code": code})[0] == 200
            bodies = [dict(sequence=1, baseline={}, state={"radio": [
                {"id": name, "data": {"name": name}}]}) for name in ("A", "B")]
            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                results = list(pool.map(lambda args: call("sync", *args), zip((a, b), bodies)))
            assert all(status == 200 for status, _ in results)
            assert len(call("state", a, {})[1]["state"]["radio"]) == 2
            assert call("sync", a, bodies[0]) == results[0]
            assert call("state", a)[0] == 405
            assert call("devices", a, {})[0] == 200
            pref = lambda value: {"preferences": [{"id":"cutter.mode","data":{"value":value}}]}
            assert "preferences" in call("health")[1]["collections"]
            assert call("sync", a, dict(sequence=2, baseline={}, state=pref("advanced")))[0] == 200
            status, response = call("sync", b, dict(sequence=2, baseline={}, state=pref("guided")))
            assert status == 200 and response["state"]["preferences"] == pref("advanced")["preferences"]
            assert len(response["state"]["radio"]) == 2
            status, response = call("sync", b, dict(sequence=3, baseline=pref("advanced"), state=pref("guided")))
            assert status == 200 and response["state"]["preferences"] == pref("guided")["preferences"]

            # Database and source code are outside the served document root.
            for path in ("/data/sync.sqlite", "/src/Sync.php", "/private/config.php"):
                try:
                    urllib.request.urlopen(f"http://127.0.0.1:{port}" + path)
                    raise AssertionError("Private path exposed")
                except urllib.error.HTTPError as error:
                    assert error.code == 404
            log = (root / 'data/sync.log').read_text(encoding='utf-8')
            assert a not in log and b not in log and code not in log
            assert 'duration_ms' in log and 'request_id' in log
            print("OK: /synk deployment, HTTP health/auth/pairing/sync/retry/methods/private-path isolation and logs.")
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
