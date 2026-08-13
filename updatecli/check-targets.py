#!/usr/bin/env python3
"""Check that every updatecli file target still matches something.

The failure this exists to catch is silent. updatecli's file target rewrites lines matching a
regex; if the regex matches nothing, there is no error, no warning and no diff. The manifest
simply stops doing its job, and the first anyone notices is an ISO pin that has not moved in
months. Renaming a template, moving it between directories, or reformatting the line the pattern
is anchored to is enough to cause it, and none of those look like they touch updatecli.

So this walks the manifests, and for each `kind: file` target checks two things: the file exists,
and the matchpattern matches at least one line in it.

Deliberately does not talk to the network or run updatecli. `updatecli pipeline diff` would be a
stronger check, but it fetches from cdimage.debian.org and dl-cdn.alpinelinux.org, so it fails
when a mirror is having a bad day and teaches everyone to ignore a red check. This one is
hermetic: it can only fail if the repository is genuinely inconsistent.

Go's regexp and Python's re disagree on some exotic syntax. The patterns here are simple enough
that it does not matter, but a pattern this cannot compile is reported rather than skipped.
"""

import pathlib
import re
import sys

import yaml

MANIFEST_DIR = pathlib.Path(__file__).parent / "updatecli.d"


def targets(manifest: dict):
    """Yield (target_id, file_path, matchpattern) for each file target, one per file."""
    for target_id, target in (manifest.get("targets") or {}).items():
        if target.get("kind") != "file":
            continue
        spec = target.get("spec") or {}
        pattern = spec.get("matchpattern")
        if pattern is None:
            continue
        # A file target takes either `file` or `files`; both are in use here.
        paths = spec.get("files") or ([spec["file"]] if "file" in spec else [])
        for path in paths:
            yield target_id, path, pattern


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    manifests = sorted(MANIFEST_DIR.glob("*.yaml"))
    if not manifests:
        print(f"no manifests found in {MANIFEST_DIR}", file=sys.stderr)
        return 1

    failures = []
    checked = 0

    for manifest_path in manifests:
        manifest = yaml.safe_load(manifest_path.read_text())
        for target_id, rel_path, pattern in targets(manifest):
            checked += 1
            where = f"{manifest_path.name}:{target_id} -> {rel_path}"
            path = root / rel_path

            if not path.is_file():
                failures.append(f"{where}: target file does not exist")
                continue

            try:
                regex = re.compile(pattern)
            except re.error as exc:
                failures.append(f"{where}: matchpattern does not compile: {exc}")
                continue

            hits = sum(
                1 for line in path.read_text().splitlines() if regex.search(line)
            )
            if hits == 0:
                failures.append(
                    f"{where}: matchpattern {pattern!r} matches no line. "
                    "updatecli would rewrite nothing and report success."
                )

    for failure in failures:
        print(f"FAIL  {failure}", file=sys.stderr)

    print(
        f"checked {checked} file target(s) across {len(manifests)} manifest(s): "
        f"{checked - len(failures)} ok, {len(failures)} failed"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
