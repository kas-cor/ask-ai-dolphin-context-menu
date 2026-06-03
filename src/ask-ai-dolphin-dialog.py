#!/usr/bin/env python3
"""
ask-ai-dolphin-dialog.py — PyQt5 dialog for selecting/entering an AI query.
Used from ask-ai-dolphin.sh.

CLI arguments: preset queries.
Stdin: a string describing selected files (optional).
Stdout: the selected/entered query.
Exit code: 0 — OK, 1 — Cancel.

Locale: auto-detected from LANG environment variable (ru_RU* / ru_UA* / be_BY* / uk_UA* → Russian).
"""

import os
import sys
from PyQt5.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QPushButton,
    QLineEdit, QLabel, QDialogButtonBox, QFrame, QSizePolicy,
)
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QIcon, QFont


# --- Theme detection ---
def detect_dark_theme(app):
    """Detect if the OS theme is dark.

    Priority:
      1. ASK_AI_THEME env var ("dark" or "light")
      2. Auto-detect from QPalette.Window lightness
    """
    theme_override = os.environ.get("ASK_AI_THEME", "").strip().lower()
    if theme_override in ("dark", "d"):
        return True
    if theme_override in ("light", "l"):
        return False

    palette = app.palette()
    bg = palette.color(palette.Window)
    return bg.lightness() < 128


# --- Light style (KDE Breeze) ---
STYLE_LIGHT = """
QDialog {
    background-color: #eff0f1;
}

QFrame#headerFrame {
    background-color: #1d99f3;
    border-radius: 6px;
    padding: 12px;
}

QLabel#headerTitle {
    color: #ffffff;
    font-size: 16px;
    font-weight: bold;
}

QFrame#fileFrame {
    background-color: #fcfcfc;
    border: 1px solid #bdc3c7;
    border-radius: 5px;
    padding: 10px;
}

QLabel#fileLabel {
    color: #31363b;
    font-size: 12px;
    line-height: 1.4;
}

QLabel#presetsLabel {
    color: #62686e;
    font-size: 11px;
    font-weight: bold;
    padding: 0;
    margin: 0;
}

QLabel#inputLabel {
    color: #62686e;
    font-size: 11px;
    font-weight: bold;
    padding: 0;
    margin-top: 4px;
}

QPushButton {
    background-color: #fcfcfc;
    border: 1px solid #bdc3c7;
    border-radius: 4px;
    padding: 8px 16px;
    font-size: 12px;
    color: #31363b;
    min-height: 20px;
}

QPushButton:hover {
    background-color: #d6eaff;
    border-color: #1d99f3;
    color: #1d99f3;
}

QPushButton:pressed {
    background-color: #b3d9f9;
    border-color: #1a7dc9;
}

QLineEdit {
    background-color: #fcfcfc;
    border: 1px solid #bdc3c7;
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 13px;
    color: #31363b;
    min-height: 22px;
}

QLineEdit:focus {
    border-color: #1d99f3;
    background-color: #ffffff;
}

QDialogButtonBox QPushButton {
    min-width: 80px;
    min-height: 16px;
    padding: 6px 20px;
    font-size: 12px;
}

#okButton {
    background-color: #1d99f3;
    border-color: #1a7dc9;
    color: #ffffff;
    font-weight: bold;
}

#okButton:hover {
    background-color: #2ea6ff;
}

#okButton:pressed {
    background-color: #1a7dc9;
}
"""


# --- Dark style (KDE Breeze Dark) ---
STYLE_DARK = """
QDialog {
    background-color: #2b2b2b;
}

QFrame#headerFrame {
    background-color: #1a7dc9;
    border-radius: 6px;
    padding: 12px;
}

QLabel#headerTitle {
    color: #ffffff;
    font-size: 16px;
    font-weight: bold;
}

QFrame#fileFrame {
    background-color: #353535;
    border: 1px solid #555555;
    border-radius: 5px;
    padding: 10px;
}

QLabel#fileLabel {
    color: #d3d7cf;
    font-size: 12px;
    line-height: 1.4;
}

QLabel#presetsLabel {
    color: #aaaaaa;
    font-size: 11px;
    font-weight: bold;
    padding: 0;
    margin: 0;
}

QLabel#inputLabel {
    color: #aaaaaa;
    font-size: 11px;
    font-weight: bold;
    padding: 0;
    margin-top: 4px;
}

QPushButton {
    background-color: #353535;
    border: 1px solid #555555;
    border-radius: 4px;
    padding: 8px 16px;
    font-size: 12px;
    color: #d3d7cf;
    min-height: 20px;
}

QPushButton:hover {
    background-color: #444444;
    border-color: #1d99f3;
    color: #5dbaff;
}

QPushButton:pressed {
    background-color: #505050;
    border-color: #1a7dc9;
}

QLineEdit {
    background-color: #353535;
    border: 1px solid #555555;
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 13px;
    color: #d3d7cf;
    min-height: 22px;
}

QLineEdit:focus {
    border-color: #1d99f3;
    background-color: #3a3a3a;
}

QDialogButtonBox QPushButton {
    min-width: 80px;
    min-height: 16px;
    padding: 6px 20px;
    font-size: 12px;
}

#okButton {
    background-color: #1d99f3;
    border-color: #1a7dc9;
    color: #ffffff;
    font-weight: bold;
}

#okButton:hover {
    background-color: #2ea6ff;
}

#okButton:pressed {
    background-color: #1a7dc9;
}
"""


# --- Locale detection ---
def detect_locale():
    """Detect locale: ASK_AI_LOCALE env → $LANG → en_EN.

    Priority:
      1. ASK_AI_LOCALE env var (can be set in ~/.ask_ai alongside ASK_AI_MODEL)
      2. LANG env var (ru_RU/ru_UA/be_BY/uk_UA → ru_RU)
      3. Default: en_EN
    """
    # ASK_AI_LOCALE takes highest priority
    ask_locale = os.environ.get("ASK_AI_LOCALE", "")
    if ask_locale in ("ru_RU", "ru"):
        return "ru_RU"
    if ask_locale in ("en_EN", "en"):
        return "en_EN"

    # Fallback to LANG
    lang = os.environ.get("LANG", "")
    if lang.startswith(("ru_RU", "ru_UA", "be_BY", "uk_UA")):
        return "ru_RU"
    return "en_EN"


def load_locale(locale):
    """Load locale strings from file. Returns dict with dialog_* keys."""
    strings = {}
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Check locale file next to the script (installed path: ~/.local/bin/locales/xx)
    locale_path = os.path.join(script_dir, "locales", locale)

    # Fallback: project root (for running from source: src/../locales/xx)
    if not os.path.isfile(locale_path):
        locale_path = os.path.join(os.path.dirname(script_dir), "locales", locale)

    if os.path.isfile(locale_path):
        with open(locale_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                # Skip blanks and comments
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip()
                    # Strip surrounding quotes
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                        value = value[1:-1]
                    strings[key] = value
    return strings


LOCALE = detect_locale()
LOCALE_STRINGS = load_locale(LOCALE)


def _(key, default=""):
    """Get localized string by key, fallback to default."""
    return LOCALE_STRINGS.get(key, default)


class AskDialog(QDialog):
    def __init__(self, presets, file_info, locale="en_EN", style=""):
        super().__init__()
        self.locale = locale
        self.setWindowIcon(QIcon.fromTheme("utilities-terminal"))
        self.setMinimumWidth(640)
        self.setModal(True)
        self.setStyleSheet(style)

        # --- Localized strings (from locale file, fallback to inline) ---
        win_title = _("dialog_win_title", "🤖  Ask AI")
        hdr_title = _("dialog_hdr_title", "🤖  Ask AI")
        presets_label_text = _("dialog_presets_label", "Quick queries:")
        input_label_text = _("dialog_input_label", "Or type your query:")
        input_placeholder = _("dialog_input_placeholder", "Your question…")
        ok_text = _("dialog_ok_text", "Send")
        cancel_text = _("dialog_cancel_text", "Cancel")

        self.setWindowTitle(win_title)

        layout = QVBoxLayout(self)
        layout.setSpacing(12)
        layout.setContentsMargins(20, 20, 20, 20)

        # --- Header ---
        header = QFrame()
        header.setObjectName("headerFrame")
        hdr_layout = QVBoxLayout(header)
        hdr_layout.setContentsMargins(16, 12, 16, 12)
        hdr_layout.setSpacing(2)

        title = QLabel(hdr_title)
        title.setObjectName("headerTitle")
        hdr_layout.addWidget(title)

        layout.addWidget(header)

        # --- File info card (if multiple lines) ---
        if file_info and "\n" in file_info:
            file_frame = QFrame()
            file_frame.setObjectName("fileFrame")
            fl_layout = QVBoxLayout(file_frame)
            fl_layout.setContentsMargins(12, 8, 12, 8)

            file_label = QLabel(file_info)
            file_label.setObjectName("fileLabel")
            file_label.setWordWrap(True)
            file_label.setTextInteractionFlags(Qt.TextSelectableByMouse)
            fl_layout.addWidget(file_label)

            layout.addWidget(file_frame)

        # --- Preset buttons ---
        presets_label = QLabel(presets_label_text)
        presets_label.setObjectName("presetsLabel")
        layout.addWidget(presets_label)

        for preset in presets:
            btn = QPushButton(preset)
            btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            btn.setMinimumHeight(40)
            btn.clicked.connect(lambda checked, p=preset: self.on_preset(p))
            layout.addWidget(btn)

        # --- Custom input field ---
        input_label = QLabel(input_label_text)
        input_label.setObjectName("inputLabel")
        layout.addWidget(input_label)

        self.input_field = QLineEdit()
        self.input_field.setPlaceholderText(input_placeholder)
        layout.addWidget(self.input_field)

        # --- OK / Cancel buttons ---
        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        ok_btn = buttons.button(QDialogButtonBox.Ok)
        ok_btn.setObjectName("okButton")
        ok_btn.setText(ok_text)
        buttons.button(QDialogButtonBox.Cancel).setText(cancel_text)
        buttons.accepted.connect(self.on_ok)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def on_preset(self, text):
        print(text, flush=True)
        self.accept()

    def on_ok(self):
        query = self.input_field.text().strip()
        if query:
            print(query, flush=True)
            self.accept()
        else:
            self.input_field.setFocus()
            self.input_field.setPlaceholderText(_("dialog_empty_placeholder", "Type your query!"))


def main():
    fallback_preset = _("dialog_fallback_preset", "Explain these files")
    presets = sys.argv[1:] if len(sys.argv) > 1 else [fallback_preset]
    file_info = sys.stdin.read().strip() if not sys.stdin.isatty() else ""

    app = QApplication(sys.argv)
    app.setStyle("Breeze")

    # Default font with emoji fallback (setFamilies requires Qt ≥ 5.13)
    font = QFont()
    try:
        font.setFamilies(["Noto Sans", "Noto Color Emoji", "Segoe UI Emoji", "Symbola"])
    except AttributeError:
        # Qt < 5.13 — fallback to single font family
        font.setFamily("Noto Sans")
    font.setPointSize(10)
    app.setFont(font)

    is_dark = detect_dark_theme(app)
    style = STYLE_DARK if is_dark else STYLE_LIGHT

    dialog = AskDialog(presets, file_info, locale=LOCALE, style=style)
    sys.exit(0 if dialog.exec_() == QDialog.Accepted else 1)


if __name__ == "__main__":
    main()
