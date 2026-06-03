#!/usr/bin/env python3
"""
Validate locale files in the locales/ directory.

Checks:
  1. File is valid UTF-8 (no invalid byte sequences)
  2. File has no UTF-8 BOM (Byte Order Mark)
  3. Every non-blank, non-comment line matches KEY="value" format
  4. No duplicate keys within a file
  5. Keys contain only alphanumeric characters and underscores
  6. Values are properly double-quoted
  7. All locale files have the same set of keys

Usage:
  python3 .github/scripts/validate-locales.py [files...]
  If no files given, all files under locales/ are checked.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(HERE))
LOCALES_DIR = os.path.join(PROJECT_ROOT, "locales")

LINE_RE = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*)="(.*)"$')
KEY_RE = re.compile(r'^[a-zA-Z_][a-zA-Z0-9_]*$')


def validate_file(filepath: str) -> list[str]:
    """Validate a single locale file. Returns a list of error messages."""
    errors: list[str] = []
    keys_seen: dict[str, int] = {}

    # Read raw bytes first to check for BOM and invalid UTF-8
    try:
        with open(filepath, "rb") as f:
            raw_bytes = f.read()
    except IOError as e:
        return [f"  Cannot read file: {e}"]

    # Check for UTF-8 BOM (Byte Order Mark)
    if raw_bytes.startswith(b"\xef\xbb\xbf"):
        errors.append(r"  File has UTF-8 BOM (\xef\xbb\xbf) at the beginning — remove it")

    # Decode as UTF-8, catching invalid byte sequences
    try:
        text = raw_bytes.decode("utf-8")
    except UnicodeDecodeError as e:
        errors.append(f"  Invalid UTF-8 encoding: {e}")
        return errors

    lines = text.splitlines(keepends=True)

    for lineno, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()

        # Skip blank lines and comments
        if not line or line.startswith("#"):
            continue

        m = LINE_RE.match(line)
        if not m:
            errors.append(f"  Line {lineno}: invalid format — expected KEY=\"value\", got: {raw_line.rstrip()}")
            continue

        key = m.group(1)
        value = m.group(2)

        # Check key pattern (redundant given LINE_RE, but explicit)
        if not KEY_RE.match(key):
            errors.append(f"  Line {lineno}: invalid key name '{key}' — use only a-z, A-Z, 0-9, _")

        # Check for duplicate keys
        if key in keys_seen:
            errors.append(f"  Line {lineno}: duplicate key '{key}' (first seen on line {keys_seen[key]})")
        else:
            keys_seen[key] = lineno

        # Check value is not empty (optional — some values might legitimately be empty)
        # if not value:
        #     errors.append(f"  Line {lineno}: key '{key}' has empty value")

    return errors


def get_keys(filepath: str) -> set[str]:
    """Extract the set of keys from a locale file."""
    keys: set[str] = set()
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for raw_line in f:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                m = LINE_RE.match(line)
                if m:
                    keys.add(m.group(1))
    except IOError:
        pass
    return keys


def main() -> int:
    # Determine which files to check
    if len(sys.argv) > 1:
        files = sys.argv[1:]
    else:
        # Find all locale files
        if not os.path.isdir(LOCALES_DIR):
            print(f"❌ locales/ directory not found at {LOCALES_DIR}")
            return 1
        files = sorted(
            os.path.join(LOCALES_DIR, f)
            for f in os.listdir(LOCALES_DIR)
            if os.path.isfile(os.path.join(LOCALES_DIR, f))
        )

    if not files:
        print("❌ No locale files found to validate")
        return 1

    all_ok = True

    # Phase 1: Validate each file individually
    print("🔍 Checking locale files...")
    print()
    for fpath in files:
        fname = os.path.basename(fpath)
        errors = validate_file(fpath)
        if errors:
            all_ok = False
            print(f"  ❌ {fname}")
            for err in errors:
                print(err)
        else:
            n_keys = len(get_keys(fpath))
            print(f"  ✅ {fname}  ({n_keys} keys)")
    print()

    # Phase 2: Cross-check that all files have the same keys
    if len(files) > 1:
        keysets = {}
        for fpath in files:
            keysets[os.path.basename(fpath)] = get_keys(fpath)

        all_keysets = list(keysets.values())
        reference = all_keysets[0]
        reference_name = list(keysets.keys())[0]

        for name, ks in keysets.items():
            missing = reference - ks
            extra = ks - reference
            if missing:
                all_ok = False
                print(f"  ❌ {name}: missing keys vs {reference_name}: {', '.join(sorted(missing))}")
            if extra:
                all_ok = False
                print(f"  ❌ {name}: extra keys vs {reference_name}: {', '.join(sorted(extra))}")

        if all_ok and len(files) > 1:
            print(f"  ✅ All {len(files)} locale files have identical key sets")

    print()
    if all_ok:
        print("✅ All locale files are valid")
        return 0
    else:
        print("❌ Locale validation failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
