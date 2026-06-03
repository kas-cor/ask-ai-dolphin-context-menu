#!/usr/bin/env python3
"""
CI test: verify ASK_AI_THEME=dark|light selects the correct dialog style.

Tests:
  1. detect_dark_theme() with ASK_AI_THEME=dark → True
  2. detect_dark_theme() with ASK_AI_THEME=light → False
  3. detect_dark_theme() with ASK_AI_THEME=DARK (case insensitive) → True
  4. detect_dark_theme() with ASK_AI_THEME unset + dark palette → True
  5. detect_dark_theme() with ASK_AI_THEME unset + light palette → False
  6. Check that STYLE_DARK and STYLE_LIGHT are different strings
"""

import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")


def test_ask_theme_dark():
    """ASK_AI_THEME=dark → detect_dark_theme() returns True."""
    from PyQt5.QtWidgets import QApplication
    import importlib.util

    spec = importlib.util.spec_from_file_location("dialog", "src/ask-ai-dolphin-dialog.py")
    dialog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dialog)

    app = QApplication.instance() or QApplication(sys.argv[:1])
    old_val = os.environ.pop("ASK_AI_THEME", None)
    os.environ["ASK_AI_THEME"] = "dark"
    try:
        result = dialog.detect_dark_theme(app)
    finally:
        del os.environ["ASK_AI_THEME"]
        if old_val is not None:
            os.environ["ASK_AI_THEME"] = old_val
    assert result is True, f"ASK_AI_THEME=dark should return True, got {result}"
    print("  ✅ ASK_AI_THEME=dark → True")


def test_ask_theme_light():
    """ASK_AI_THEME=light → detect_dark_theme() returns False."""
    from PyQt5.QtWidgets import QApplication
    import importlib.util

    spec = importlib.util.spec_from_file_location("dialog", "src/ask-ai-dolphin-dialog.py")
    dialog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dialog)

    app = QApplication.instance() or QApplication(sys.argv[:1])
    old_val = os.environ.pop("ASK_AI_THEME", None)
    os.environ["ASK_AI_THEME"] = "light"
    try:
        result = dialog.detect_dark_theme(app)
    finally:
        del os.environ["ASK_AI_THEME"]
        if old_val is not None:
            os.environ["ASK_AI_THEME"] = old_val
    assert result is False, f"ASK_AI_THEME=light should return False, got {result}"
    print("  ✅ ASK_AI_THEME=light → False")


def test_ask_theme_case_insensitive():
    """ASK_AI_THEME=DARK (uppercase) → detect_dark_theme() returns True."""
    from PyQt5.QtWidgets import QApplication
    import importlib.util

    spec = importlib.util.spec_from_file_location("dialog", "src/ask-ai-dolphin-dialog.py")
    dialog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dialog)

    app = QApplication.instance() or QApplication(sys.argv[:1])
    for variant in ("DARK", "Dark", "dark", "D"):
        old_val = os.environ.pop("ASK_AI_THEME", None)
        os.environ["ASK_AI_THEME"] = variant
        try:
            result = dialog.detect_dark_theme(app)
        finally:
            del os.environ["ASK_AI_THEME"]
            if old_val is not None:
                os.environ["ASK_AI_THEME"] = old_val
        assert result is True, f"ASK_AI_THEME={variant!r} should return True, got {result}"
    print("  ✅ ASK_AI_THEME=DARK/Dark/dark/D → True (case insensitive)")


def test_auto_detect_dark_palette():
    """Without ASK_AI_THEME, dark palette → detect_dark_theme() returns True."""
    from PyQt5.QtGui import QPalette, QColor
    from PyQt5.QtWidgets import QApplication
    import importlib.util

    spec = importlib.util.spec_from_file_location("dialog", "src/ask-ai-dolphin-dialog.py")
    dialog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dialog)

    app = QApplication.instance() or QApplication(sys.argv[:1])
    dark_palette = app.palette()
    dark_palette.setColor(QPalette.Window, QColor("#2b2b2b"))
    old = app.palette()
    app.setPalette(dark_palette)
    result = dialog.detect_dark_theme(app)
    app.setPalette(old)
    assert result is True, f"Dark palette should return True, got {result}"
    print("  ✅ Dark palette (no ASK_AI_THEME) → True")


def test_auto_detect_light_palette():
    """Without ASK_AI_THEME, light palette → detect_dark_theme() returns False."""
    from PyQt5.QtGui import QPalette, QColor
    from PyQt5.QtWidgets import QApplication
    import importlib.util

    spec = importlib.util.spec_from_file_location("dialog", "src/ask-ai-dolphin-dialog.py")
    dialog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dialog)

    app = QApplication.instance() or QApplication(sys.argv[:1])
    light_palette = app.palette()
    light_palette.setColor(QPalette.Window, QColor("#eff0f1"))
    old = app.palette()
    app.setPalette(light_palette)
    result = dialog.detect_dark_theme(app)
    app.setPalette(old)
    assert result is False, f"Light palette should return False, got {result}"
    print("  ✅ Light palette (no ASK_AI_THEME) → False")


def test_styles_are_different():
    """STYLE_DARK and STYLE_LIGHT are different strings."""
    import importlib.util

    spec = importlib.util.spec_from_file_location("dialog", "src/ask-ai-dolphin-dialog.py")
    dialog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dialog)

    assert dialog.STYLE_DARK != dialog.STYLE_LIGHT, "STYLE_DARK and STYLE_LIGHT should differ"
    assert "#2b2b2b" in dialog.STYLE_DARK, "STYLE_DARK should contain dark bg"
    assert "#eff0f1" in dialog.STYLE_LIGHT, "STYLE_LIGHT should contain light bg"
    print("  ✅ STYLE_DARK ≠ STYLE_LIGHT (different color schemes)")


def main():
    print("=" * 60)
    print("ASK_AI_THEME style selection test")
    print("=" * 60)

    tests = [
        ("ASK_AI_THEME=dark → True", test_ask_theme_dark),
        ("ASK_AI_THEME=light → False", test_ask_theme_light),
        ("Case insensitive", test_ask_theme_case_insensitive),
        ("Auto-detect dark palette", test_auto_detect_dark_palette),
        ("Auto-detect light palette", test_auto_detect_light_palette),
        ("STYLE_DARK ≠ STYLE_LIGHT", test_styles_are_different),
    ]

    failed = 0
    for name, func in tests:
        print(f"\n  Test: {name}")
        try:
            func()
        except Exception as e:
            print(f"  ❌ FAILED: {e}")
            failed += 1
            import traceback
            traceback.print_exc()

    print()
    print("=" * 60)
    if failed:
        print(f"\n❌ {failed} test(s) FAILED")
        sys.exit(1)
    else:
        print("✅ ALL TESTS PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
