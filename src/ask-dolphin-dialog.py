#!/usr/bin/env python3
"""
ask-dolphin-dialog.py — PyQt5 dialog for selecting/entering an AI query.
Used from ask-dolphin.sh.

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


# --- Locale detection ---
def detect_locale():
    """Detect locale: ASK_LOCALE env → $LANG → en_EN.

    Priority:
      1. ASK_LOCALE env var (can be set in ~/.ask_ai alongside ASK_MODEL)
      2. LANG env var (ru_RU/ru_UA/be_BY/uk_UA → ru_RU)
      3. Default: en_EN
    """
    # ASK_LOCALE takes highest priority
    ask_locale = os.environ.get("ASK_LOCALE", "")
    if ask_locale in ("ru_RU", "ru"):
        return "ru_RU"
    if ask_locale in ("en_EN", "en"):
        return "en_EN"

    # Fallback to LANG
    lang = os.environ.get("LANG", "")
    if lang.startswith(("ru_RU", "ru_UA", "be_BY", "uk_UA")):
        return "ru_RU"
    return "en_EN"


LOCALE = detect_locale()


# --- QSS style for KDE Breeze ---
STYLE = """
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

QLabel#headerSubtitle {
    color: #d6eaff;
    font-size: 12px;
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


class AskDialog(QDialog):
    def __init__(self, presets, file_info, locale="en_EN"):
        super().__init__()
        self.locale = locale
        self.setWindowIcon(QIcon.fromTheme("utilities-terminal"))
        self.setMinimumWidth(640)
        self.setModal(True)
        self.setStyleSheet(STYLE)

        # --- Localized strings ---
        if locale == "ru_RU":
            win_title = "🤖  Спросить AI"
            hdr_title = "🤖  Спросить AI"
            presets_label_text = "Быстрые запросы:"
            input_label_text = "Или введите запрос:"
            input_placeholder = "Ваш вопрос…"
            ok_text = "Отправить"
            cancel_text = "Отмена"
        else:
            win_title = "🤖  Ask AI"
            hdr_title = "🤖  Ask AI"
            presets_label_text = "Quick queries:"
            input_label_text = "Or type your query:"
            input_placeholder = "Your question…"
            ok_text = "Send"
            cancel_text = "Cancel"

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

        if file_info:
            sub = QLabel(file_info.replace("\\n", "  ·  "))
            sub.setObjectName("headerSubtitle")
            sub.setWordWrap(True)
            hdr_layout.addWidget(sub)

        layout.addWidget(header)

        # --- File info card (if multiple lines) ---
        if file_info and "\\n" in file_info:
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
        presets_label.setStyleSheet(
            "color: #62686e; font-size: 11px; font-weight: bold; "
            "padding: 0; margin: 0;"
        )
        layout.addWidget(presets_label)

        for preset in presets:
            btn = QPushButton(preset)
            btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            btn.setMinimumHeight(40)
            btn.clicked.connect(lambda checked, p=preset: self.on_preset(p))
            layout.addWidget(btn)

        # --- Custom input field ---
        input_label = QLabel(input_label_text)
        input_label.setStyleSheet(
            "color: #62686e; font-size: 11px; font-weight: bold; "
            "padding: 0; margin-top: 4px;"
        )
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
            if self.locale == "ru_RU":
                self.input_field.setPlaceholderText("Введите запрос!")
            else:
                self.input_field.setPlaceholderText("Type your query!")


def main():
    if LOCALE == "ru_RU":
        fallback_preset = "Опиши эти файлы"
    else:
        fallback_preset = "Explain these files"
    presets = sys.argv[1:] if len(sys.argv) > 1 else [fallback_preset]
    file_info = sys.stdin.read().strip() if not sys.stdin.isatty() else ""

    app = QApplication(sys.argv)
    app.setStyle("Breeze")

    # Default font
    font = QFont("Noto Sans", 10)
    app.setFont(font)

    dialog = AskDialog(presets, file_info, locale=LOCALE)
    sys.exit(0 if dialog.exec_() == QDialog.Accepted else 1)


if __name__ == "__main__":
    main()
