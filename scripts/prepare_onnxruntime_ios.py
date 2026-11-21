"""Prepare the pinned iOS SwiftPM binary from Microsoft's NuGet distribution."""
import hashlib
import json
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname

VERSION = "1.15.1"
PACKAGE = f"microsoft.ml.onnxruntime.{VERSION}.nupkg"
URL = f"https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/{VERSION}/{PACKAGE}"
SHA256 = "da45c9bf6472637fc97eec243eac979cdc3456d0e4380ecfeffdeec75a627431"
FRAMEWORK = "onnxruntime.xcframework"


def prepare(manifest, archive):
    digest = hashlib.sha256()
    with archive.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != SHA256:
        raise ValueError("Unexpected Microsoft ONNX Runtime package digest")
    original = manifest.read_text()
    start = f'url: "https://onnxruntimepackages.z14.web.core.windows.net/pod-archive-onnxruntime-c-{VERSION}.zip",'
    checksum = 'checksum: "f3c88ff2a8a49101efb65f6c578dc8fa99ca6e5298ed876e42b9f171a6d99724"'
    block = start + "\n            " + checksum
    local = f'path: "{FRAMEWORK}"'
    if block not in original and local not in original:
        raise ValueError("Unexpected onnxruntime_plus Swift package manifest")
    with zipfile.ZipFile(archive) as package:
        prefix = f"runtimes/ios/native/{FRAMEWORK}/"
        entries = [entry for entry in package.infolist() if entry.filename.startswith(prefix) and not entry.is_dir()]
        for required in ["Info.plist"] + [
            f"{platform}/onnxruntime.framework/onnxruntime"
            for platform in ("ios-arm64", "ios-arm64_x86_64-simulator")
        ]:
            package.getinfo(prefix + required)
        for entry in entries:
            target = manifest.parent / FRAMEWORK / entry.filename.removeprefix(prefix)
            target.parent.mkdir(parents=True, exist_ok=True)
            with package.open(entry) as source, target.open("wb") as dest:
                shutil.copyfileobj(source, dest)
    manifest.write_text(original.replace(block, local))


if __name__ == "__main__":
    config = Path(".dart_tool/package_config.json").resolve()
    plugin = next(p for p in json.loads(config.read_text())["packages"] if p["name"] == "onnxruntime_plus")
    uri = urlparse(urljoin(config.as_uri(), plugin["rootUri"]))
    manifest = Path(url2pathname(uri.path)) / "ios/onnxruntime_plus/Package.swift"
    with tempfile.TemporaryDirectory() as folder:
        archive = Path(folder) / PACKAGE
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--silent", "--show-error",
                        "--output", str(archive), URL], check=True)
        prepare(manifest, archive)
