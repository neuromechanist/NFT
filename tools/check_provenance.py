#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Provenance gate: every shipped binary artifact must have a matching,
correct entry in provenance/binaries.yaml.

This does NOT use a hardcoded list of filenames. It walks the repository and
classifies each file by inspecting its actual bytes (ELF magic, Mach-O magic
in all four byte-order/word-size variants plus fat/universal binaries, PE32
"MZ" header, or a "#!" shebang line for POSIX shell scripts) so that a newly
added binary cannot silently ship without a provenance record just because it
wasn't on someone's list when this script was written.

Usage:
    uv run tools/check_provenance.py
    uv run tools/check_provenance.py --manifest provenance/binaries.yaml

Exit status: 0 if every discovered binary is covered by a manifest entry with
a matching sha256, non-zero otherwise. Intended to run in CI on every push.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

# Directories never walked at all (VCS internals, not repo content).
ALWAYS_SKIP_DIRS = {".git"}

# Paths excluded from the provenance requirement, WITH a stated reason.
# Every exclusion must be justified here and is announced in the report --
# nothing is silently skipped.
EXCLUDED_PATHS: dict[str, str] = {
    "nft_dipfit": (
        "dead, unsynchronized vendored FieldTrip snapshot (55 files, ~716K); "
        "never on the MATLAB path and unreferenced from outside itself except "
        "two broken ft_voltype/ft_senstype calls. Not a shipped feature of "
        "NFT; tracked as a removal candidate elsewhere, not as a provenance gap."
    ),
}


def is_excluded(rel_path: Path) -> str | None:
    """Return the exclusion reason if rel_path falls under an excluded path."""
    parts = rel_path.parts
    for excluded, reason in EXCLUDED_PATHS.items():
        excluded_parts = Path(excluded).parts
        if parts[: len(excluded_parts)] == excluded_parts:
            return reason
    return None


# --- File-type sniffing -----------------------------------------------------
#
# Deliberately magic-byte based, not extension based: a stripped executable
# with no extension (e.g. `quadmesh`, `forward`) must be caught exactly like
# `foo.exe` would be.

ELF_MAGIC = b"\x7fELF"

MACHO_MAGICS = {
    b"\xfe\xed\xfa\xce",  # 32-bit big-endian
    b"\xce\xfa\xed\xfe",  # 32-bit little-endian
    b"\xfe\xed\xfa\xcf",  # 64-bit big-endian
    b"\xcf\xfa\xed\xfe",  # 64-bit little-endian
    b"\xca\xfe\xba\xbe",  # fat/universal binary, big-endian
    b"\xbe\xba\xfe\xca",  # fat/universal binary, little-endian
}

SHELL_INTERPRETER_NAMES = {"sh", "bash", "zsh", "dash", "ash", "ksh"}


def sniff_file_type(path: Path) -> str | None:
    """Return a short type tag if `path` looks like a shipped binary artifact,
    else None. Reads only the first 256 bytes of each file."""
    try:
        with path.open("rb") as f:
            head = f.read(256)
    except OSError:
        return None

    if not head:
        return None

    if head.startswith(ELF_MAGIC):
        return "ELF"

    if head[:4] in MACHO_MAGICS:
        return "Mach-O"

    if head[:2] == b"MZ":
        return "PE32"

    if head[:2] == b"#!":
        first_line = head.split(b"\n", 1)[0].decode("utf-8", errors="ignore")
        tokens = first_line[2:].strip().split()
        if tokens:
            interpreter = Path(tokens[0]).name
            if interpreter == "env" and len(tokens) > 1:
                # Resolve `#!/usr/bin/env <interpreter> ...` to the real
                # interpreter rather than matching on "env" itself -- e.g.
                # `#!/usr/bin/env -S uv run --script` invokes uv, not a shell.
                remaining = [t for t in tokens[1:] if not t.startswith("-")]
                interpreter = Path(remaining[0]).name if remaining else ""
            if interpreter in SHELL_INTERPRETER_NAMES:
                return "shell script"

    return None


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


@dataclass
class ManifestEntry:
    name: str
    variant_hashes: dict[str, str] = field(default_factory=dict)


def load_manifest(manifest_path: Path) -> dict[str, ManifestEntry]:
    """Return {relative_path_str: ManifestEntry} covering every declared
    shipped_variant, keyed by its path in the manifest (as written, e.g.
    "geodesic/geodesic.mexa64" or "asc1.osx")."""
    with manifest_path.open() as f:
        data = yaml.safe_load(f)

    if not isinstance(data, list):
        raise ValueError(f"{manifest_path}: expected a top-level YAML list of entries")

    by_path: dict[str, ManifestEntry] = {}
    for entry in data:
        name = entry.get("name", "<unnamed entry>")
        variants = entry.get("shipped_variants", [])
        sha_map = entry.get("sha256", {})
        me = ManifestEntry(name=name)
        for variant in variants:
            if variant not in sha_map:
                print(
                    f"MANIFEST ERROR: entry '{name}' lists shipped_variant "
                    f"'{variant}' but has no sha256 recorded for it",
                    file=sys.stderr,
                )
            me.variant_hashes[variant] = sha_map.get(variant, "")
            by_path[variant] = me
    return by_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "provenance" / "binaries.yaml",
        help="path to provenance/binaries.yaml (default: repo-relative)",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=None,
        help="repository root to scan (default: manifest's parent's parent)",
    )
    args = parser.parse_args()

    manifest_path: Path = args.manifest
    repo_root: Path = args.repo_root or manifest_path.resolve().parent.parent

    if not manifest_path.exists():
        print(f"FAIL: manifest not found at {manifest_path}", file=sys.stderr)
        return 1

    manifest = load_manifest(manifest_path)

    discovered: list[Path] = []
    excluded_count = 0
    excluded_reasons_shown: set[str] = set()

    for path in sorted(repo_root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(repo_root)
        if rel.parts and rel.parts[0] in ALWAYS_SKIP_DIRS:
            continue

        reason = is_excluded(rel)
        if reason is not None:
            file_type = sniff_file_type(path)
            if file_type is not None:
                excluded_count += 1
                if reason not in excluded_reasons_shown:
                    print(f"EXCLUDED: {rel.parts[0]}/ -- {reason}")
                    excluded_reasons_shown.add(reason)
            continue

        file_type = sniff_file_type(path)
        if file_type is not None:
            discovered.append(rel)

    if excluded_count:
        print(f"  ({excluded_count} binary-shaped files under excluded paths, not checked)\n")

    failures: list[str] = []
    ok_count = 0

    for rel in discovered:
        rel_str = str(rel)
        entry = manifest.get(rel_str)
        if entry is None:
            failures.append(
                f"MISSING PROVENANCE: {rel_str} looks like a shipped binary "
                f"({sniff_file_type(repo_root / rel)}) but has no entry in "
                f"{manifest_path.name}"
            )
            continue

        recorded_sha = entry.variant_hashes.get(rel_str, "")
        actual_sha = sha256_of(repo_root / rel)
        if not recorded_sha:
            failures.append(
                f"MISSING SHA256: {rel_str} is listed under manifest entry "
                f"'{entry.name}' but has no recorded sha256"
            )
        elif recorded_sha != actual_sha:
            failures.append(
                f"SHA256 MISMATCH: {rel_str} (manifest entry '{entry.name}')\n"
                f"    recorded: {recorded_sha}\n"
                f"    actual:   {actual_sha}"
            )
        else:
            ok_count += 1

    print(f"Checked {len(discovered)} binary-shaped file(s) against {manifest_path.name}:")
    print(f"  OK: {ok_count}")
    print(f"  FAILED: {len(failures)}")

    if failures:
        print("\n--- Failures ---")
        for msg in failures:
            print(msg)
        print(
            "\nEvery shipped binary artifact must have an entry in "
            f"{manifest_path} with a sha256 matching the file on disk. "
            "Add or update the entry, or remove the stray artifact."
        )
        return 1

    print("\nAll shipped binaries are covered by provenance/binaries.yaml.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
