#!/usr/bin/env python3
"""Patch vendored ONNX Runtime iOS frameworks with a valid MinimumOSVersion.

App Store Connect rejects an embedded framework when its Info.plist has a
missing or empty MinimumOSVersion (errors 90360/90530). Run this after
`pod install` and before the iOS build so Xcode embeds/signs the corrected
framework.
"""

from __future__ import annotations

import argparse
import plistlib
from pathlib import Path
import sys


def candidate_roots(project_root: Path) -> list[Path]:
    roots: list[Path] = []

    for relative in (
        Path("ios/Pods"),
        Path("ios/.symlinks/plugins/onnxruntime_plus"),
    ):
        path = project_root / relative
        if path.exists():
            roots.append(path)

    pub_hosted = Path.home() / ".pub-cache" / "hosted" / "pub.dev"
    if pub_hosted.is_dir():
        roots.extend(
            sorted(path for path in pub_hosted.glob("onnxruntime_plus-*") if path.is_dir())
        )

    unique: list[Path] = []
    seen: set[Path] = set()
    for root in roots:
        try:
            key = root.resolve()
        except OSError:
            key = root.absolute()
        if key not in seen:
            seen.add(key)
            unique.append(root)
    return unique


def framework_plists(root: Path) -> list[Path]:
    matches: list[Path] = []
    try:
        for plist in root.rglob("Info.plist"):
            if plist.parent.name == "onnxruntime.framework":
                matches.append(plist)
    except OSError as exc:
        print(f"Warning: impossibile scandire {root}: {exc}", file=sys.stderr)
    return matches


def patch_plist(path: Path, minimum_os: str) -> None:
    raw = path.read_bytes()
    fmt = plistlib.FMT_BINARY if raw.startswith(b"bplist00") else plistlib.FMT_XML
    data = plistlib.loads(raw)
    previous = data.get("MinimumOSVersion")
    data["MinimumOSVersion"] = minimum_os
    path.write_bytes(plistlib.dumps(data, fmt=fmt, sort_keys=False))
    print(f"ONNX Runtime MinimumOSVersion: {path} {previous!r} -> {minimum_os!r}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minimum", default="15.5")
    parser.add_argument("--project-root", default=".")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    matches: list[Path] = []
    seen: set[Path] = set()

    for root in candidate_roots(project_root):
        for plist in framework_plists(root):
            try:
                key = plist.resolve()
            except OSError:
                key = plist.absolute()
            if key not in seen:
                seen.add(key)
                matches.append(plist)

    if not matches:
        print(
            "ERRORE: nessun onnxruntime.framework/Info.plist trovato dopo pod install; "
            "non posso garantire un IPA accettabile da App Store Connect.",
            file=sys.stderr,
        )
        return 1

    for plist in matches:
        patch_plist(plist, args.minimum)

    print(
        f"Patch ONNX Runtime completata: {len(matches)} framework, "
        f"iOS minimo {args.minimum}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
