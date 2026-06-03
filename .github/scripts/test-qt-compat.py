#!/usr/bin/env python3
"""
CI test: verify setFamilies() try/except works for Qt < 5.13 compatibility.

Tests:
  1. Normal path: setFamilies() exists → font families are set correctly
  2. Fallback path: setFamilies() raises AttributeError → setFamily() is used
  3. Font is usable (pointSize set, no crashes)
"""

import os
import sys

# Offscreen mode for headless CI
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")


def test_normal_path():
    """Test: setFamilies() exists → font families and point size are set."""
    from PyQt5.QtGui import QFont
    from PyQt5.QtWidgets import QApplication

    app = QApplication.instance() or QApplication(sys.argv[:1])
    font = QFont()
    font.setFamilies(["Noto Sans", "Noto Color Emoji", "Segoe UI Emoji", "Symbola"])
    font.setPointSize(10)
    app.setFont(font)

    families = font.families()
    assert families == ["Noto Sans", "Noto Color Emoji", "Segoe UI Emoji", "Symbola"], (
        f"Expected families, got {families}"
    )
    assert font.pointSize() == 10, f"Expected pointSize 10, got {font.pointSize()}"
    print(f"  ✅ Normal path: families={families}, pointSize={font.pointSize()}")


def test_fallback_path():
    """Test: setFamilies() raises AttributeError → fallback to setFamily()."""
    from PyQt5.QtGui import QFont
    from PyQt5.QtWidgets import QApplication

    app = QApplication.instance() or QApplication(sys.argv[:1])

    class MockFont(QFont):
        """QFont subclass that simulates Qt < 5.13 (no setFamilies)."""
        def setFamilies(self, families):
            raise AttributeError("Not available in Qt < 5.13")

    font = MockFont()
    try:
        font.setFamilies(["Noto Sans", "Noto Color Emoji"])
    except AttributeError:
        font.setFamily("Noto Sans")
    font.setPointSize(10)

    assert font.family() == "Noto Sans", f"Expected 'Noto Sans', got {font.family()}"
    assert font.pointSize() == 10, f"Expected pointSize 10, got {font.pointSize()}"
    print(f"  ✅ Fallback path: family={font.family()}, pointSize={font.pointSize()}")


def test_real_code_path():
    """Test: the exact code from main() without crashing."""
    from PyQt5.QtGui import QFont
    from PyQt5.QtWidgets import QApplication

    app = QApplication.instance() or QApplication(sys.argv[:1])

    # Exact code from ask-ai-dolphin-dialog.py main()
    font = QFont()
    try:
        font.setFamilies(["Noto Sans", "Noto Color Emoji", "Segoe UI Emoji", "Symbola"])
    except AttributeError:
        font.setFamily("Noto Sans")
    font.setPointSize(10)
    app.setFont(font)

    applied = app.font()
    # On Qt >= 5.13, families() returns the list; on older, family() works
    if hasattr(applied, "families") and applied.families():
        print(f"  ✅ Real code: families={applied.families()}, pointSize={applied.pointSize()}")
    else:
        print(f"  ✅ Real code: family={applied.family()}, pointSize={applied.pointSize()}")


def main():
    print("=" * 60)
    print("setFamilies() compatibility test")
    print("=" * 60)

    tests = [
        ("Normal path (Qt >= 5.13)", test_normal_path),
        ("Fallback path (Qt < 5.13 mock)", test_fallback_path),
        ("Real code path", test_real_code_path),
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
