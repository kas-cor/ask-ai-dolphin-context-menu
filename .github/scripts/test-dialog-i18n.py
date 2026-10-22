#!/usr/bin/env python3
"""
CI test: dialog locale detection and query-history round-trip.

Tests:
  1. detect_locale() honours the documented full forms (ru_RU / en_EN),
     mixed case, dashes, short forms, and falls back to $LANG
  2. History keeps a multi-line query as ONE entry (escaped in the file)
  3. History dedupes, keeps the newest 10, and round-trips backslashes
  4. A legacy plain-text history file still loads
  5. Locale strings resolve from locales/ (used by the dialog)
"""

import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(HERE))
DIALOG_PATH = os.path.join(PROJECT_ROOT, "src", "ask-ai-dolphin-dialog.py")

spec = importlib.util.spec_from_file_location("dialog", DIALOG_PATH)
dialog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dialog)

FAILED = 0


def pass_(msg):
    print(f"  ✅ {msg}")


def fail(msg):
    global FAILED
    print(f"  ❌ FAILED: {msg}")
    FAILED = 1


def header(title):
    print("")
    print("=" * 60)
    print(f"  {title}")
    print("=" * 60)


def detect(ask_locale, lang):
    os.environ.pop("ASK_AI_LOCALE", None)
    if ask_locale is not None:
        os.environ["ASK_AI_LOCALE"] = ask_locale
    old_lang = os.environ.get("LANG", "")
    os.environ["LANG"] = lang
    try:
        return dialog.detect_locale()
    finally:
        os.environ["LANG"] = old_lang
        os.environ.pop("ASK_AI_LOCALE", None)


def test_detect_locale():
    header("1. detect_locale()")
    cases = [
        ("ru_RU", "en_US.UTF-8", "ru_RU", "documented full form ru_RU"),
        ("RU_RU", "en_US.UTF-8", "ru_RU", "upper case RU_RU"),
        ("ru-RU", "en_US.UTF-8", "ru_RU", "dash form ru-RU"),
        ("ru", "en_US.UTF-8", "ru_RU", "short form ru"),
        ("en_EN", "ru_RU.UTF-8", "en_EN", "documented full form en_EN wins over LANG"),
        ("En_En", "ru_RU.UTF-8", "en_EN", "mixed case En_En"),
        (None, "ru_RU.UTF-8", "ru_RU", "LANG=ru_RU.UTF-8"),
        (None, "be_BY.UTF-8", "ru_RU", "LANG=be_BY.UTF-8"),
        (None, "fr_FR.UTF-8", "en_EN", "unsupported LANG → en_EN"),
    ]
    for ask_locale, lang, expected, label in cases:
        got = detect(ask_locale, lang)
        if got == expected:
            pass_(f"{label} → {got}")
        else:
            fail(f"{label}: expected {expected}, got {got}")


def test_history_roundtrip():
    header("2. History: multi-line query")
    tmpdir = tempfile.mkdtemp()
    dialog.HISTORY_PATH = os.path.join(tmpdir, "history")

    query = "line one\nline two"
    dialog.save_history_entry(query)

    with open(dialog.HISTORY_PATH, encoding="utf-8") as fh:
        raw = [ln for ln in fh.read().splitlines() if ln.strip()]
    if len(raw) == 1:
        pass_("Multi-line query stored as a single history line")
    else:
        fail(f"Expected 1 line, got {len(raw)}: {raw}")

    loaded = dialog.load_history()
    if loaded == [query]:
        pass_("Multi-line query round-trips intact")
    else:
        fail(f"Round-trip mismatch: {loaded!r}")


def test_history_dedupe_and_limit():
    header("3. History: dedupe, limit, backslashes")
    tmpdir = tempfile.mkdtemp()
    dialog.HISTORY_PATH = os.path.join(tmpdir, "history")

    dialog.save_history_entry("same")
    dialog.save_history_entry("same")
    if dialog.load_history() == ["same"]:
        pass_("Duplicate query deduped")
    else:
        fail(f"Dedupe failed: {dialog.load_history()!r}")

    tricky = r"C:\path\new"
    dialog.save_history_entry(tricky)
    if dialog.load_history()[0] == tricky:
        pass_("Backslashes round-trip")
    else:
        fail(f"Backslash mismatch: {dialog.load_history()!r}")

    for i in range(12):
        dialog.save_history_entry(f"query {i}")
    loaded = dialog.load_history()
    if len(loaded) == dialog.HISTORY_MAX:
        pass_(f"History capped at {dialog.HISTORY_MAX}")
    else:
        fail(f"Expected {dialog.HISTORY_MAX} entries, got {len(loaded)}")
    if loaded[0] == "query 11":
        pass_("Newest entry first")
    else:
        fail(f"Order wrong: {loaded[0]!r}")


def test_legacy_history():
    header("4. History: legacy plain file")
    tmpdir = tempfile.mkdtemp()
    dialog.HISTORY_PATH = os.path.join(tmpdir, "history")
    with open(dialog.HISTORY_PATH, "w", encoding="utf-8") as fh:
        fh.write("old query\nsecond old query\n")
    loaded = dialog.load_history()
    if loaded == ["second old query", "old query"]:
        pass_("Legacy single-line entries load unchanged")
    else:
        fail(f"Legacy load mismatch: {loaded!r}")


def test_language_strings():
    header("5. Locale strings")
    strings = dialog.load_locale("ru_RU")
    if strings.get("dialog_ok_text") == "Отправить":
        pass_("ru_RU dialog strings resolve from locales/")
    else:
        fail(f"dialog_ok_text wrong: {strings.get('dialog_ok_text')!r}")
    en = dialog.load_locale("en_EN")
    if en.get("dialog_ok_text") == "Send":
        pass_("en_EN dialog strings resolve from locales/")
    else:
        fail(f"dialog_ok_text wrong: {en.get('dialog_ok_text')!r}")


def main():
    test_detect_locale()
    test_history_roundtrip()
    test_history_dedupe_and_limit()
    test_legacy_history()
    test_language_strings()

    print("")
    print("=" * 60)
    if FAILED:
        print("❌ SOME TESTS FAILED")
        return 1
    print("✅ ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
