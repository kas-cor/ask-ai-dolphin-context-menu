#!/usr/bin/env python3
"""
ask-ai-dolphin-dialog.py — PyQt dialog for selecting/entering an AI query.
Used from ask-ai-dolphin.sh.

CLI arguments: preset queries.
Stdin: a string describing selected files (optional).
Stdout: the selected/entered query.
Exit code: 0 — OK, 1 — Cancel.

Locale: ASK_AI_LOCALE → LANG (ru_RU* / ru_UA* / be_BY* / uk_UA* → Russian).
Supports PyQt5 (preferred) and PyQt6.
"""

import os
import sys

# --- Qt imports (PyQt5 preferred, PyQt6 fallback) ---
QT_API = 5
try:
    from PyQt5.QtWidgets import (
        QApplication, QDialog, QVBoxLayout, QPushButton,
        QTextEdit, QLabel, QDialogButtonBox, QFrame, QSizePolicy,
        QScrollArea, QWidget,
    )
    from PyQt5.QtCore import Qt
    from PyQt5.QtGui import QIcon, QFont, QPalette
except ImportError:
    from PyQt6.QtWidgets import (  # type: ignore
        QApplication, QDialog, QVBoxLayout, QPushButton,
        QTextEdit, QLabel, QDialogButtonBox, QFrame, QSizePolicy,
        QScrollArea, QWidget,
    )
    from PyQt6.QtCore import Qt  # type: ignore
    from PyQt6.QtGui import QIcon, QFont, QPalette  # type: ignore
    QT_API = 6


def _qt_selectable():
    if QT_API == 5:
        return Qt.TextSelectableByMouse
    return Qt.TextInteractionFlag.TextSelectableByMouse


def _qt_accepted():
    if QT_API == 5:
        return QDialog.Accepted
    return QDialog.DialogCode.Accepted


def _qt_scroll_as_needed():
    if QT_API == 5:
        return Qt.ScrollBarAsNeeded
    return Qt.ScrollBarPolicy.ScrollBarAsNeeded


def _qt_align_top():
    if QT_API == 5:
        return Qt.AlignTop
    return Qt.AlignmentFlag.AlignTop


def _size_policy(h, v):
    """Return QSizePolicy for Expanding/Fixed/Preferred/Minimum across Qt5/6."""
    def _pol(name):
        if QT_API == 6:
            return getattr(QSizePolicy.Policy, name)
        return getattr(QSizePolicy, name)

    return QSizePolicy(_pol(h), _pol(v))


def _dialog_exec(dialog):
    if hasattr(dialog, "exec_"):
        return dialog.exec_()
    return dialog.exec()


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
    if QT_API == 5:
        bg = palette.color(palette.Window)
    else:
        bg = palette.color(QPalette.ColorRole.Window)
    return bg.lightness() < 128


# Color tokens → stylesheet (shared structure for light/dark)
def build_style(dark: bool) -> str:
    if dark:
        c = {
            "bg": "#2b2b2b",
            "header": "#1a7dc9",
            "header_text": "#ffffff",
            "card_bg": "#353535",
            "card_border": "#555555",
            "text": "#d3d7cf",
            "muted": "#aaaaaa",
            "btn_bg": "#353535",
            "btn_border": "#555555",
            "btn_hover_bg": "#444444",
            "btn_hover_border": "#1d99f3",
            "btn_hover_text": "#5dbaff",
            "btn_pressed": "#505050",
            "input_bg": "#353535",
            "input_focus_bg": "#3a3a3a",
            "input_border": "#555555",
            "accent": "#1d99f3",
            "accent_hover": "#2ea6ff",
            "accent_pressed": "#1a7dc9",
            "accent_border": "#1a7dc9",
            "accent_text": "#ffffff",
            "hist_bg": "#2f2f2f",
            "scroll_bg": "#2b2b2b",
        }
    else:
        c = {
            "bg": "#eff0f1",
            "header": "#1d99f3",
            "header_text": "#ffffff",
            "card_bg": "#fcfcfc",
            "card_border": "#bdc3c7",
            "text": "#31363b",
            "muted": "#62686e",
            "btn_bg": "#fcfcfc",
            "btn_border": "#bdc3c7",
            "btn_hover_bg": "#d6eaff",
            "btn_hover_border": "#1d99f3",
            "btn_hover_text": "#1d99f3",
            "btn_pressed": "#b3d9f9",
            "input_bg": "#fcfcfc",
            "input_focus_bg": "#ffffff",
            "input_border": "#bdc3c7",
            "accent": "#1d99f3",
            "accent_hover": "#2ea6ff",
            "accent_pressed": "#1a7dc9",
            "accent_border": "#1a7dc9",
            "accent_text": "#ffffff",
            "hist_bg": "#f5f5f5",
            "scroll_bg": "#eff0f1",
        }

    return f"""
QDialog {{
    background-color: {c['bg']};
}}

QFrame#headerFrame {{
    background-color: {c['header']};
    border-radius: 6px;
}}

QLabel#headerTitle {{
    color: {c['header_text']};
    font-size: 16px;
    font-weight: bold;
    background: transparent;
}}

QLabel#headerMeta {{
    color: {c['header_text']};
    font-size: 11px;
    background: transparent;
}}

QFrame#fileFrame {{
    background-color: {c['card_bg']};
    border: 1px solid {c['card_border']};
    border-radius: 5px;
}}

QLabel#fileLabel {{
    color: {c['text']};
    font-size: 12px;
    background: transparent;
}}

QLabel#sectionLabel {{
    color: {c['muted']};
    font-size: 11px;
    font-weight: bold;
    background: transparent;
}}

QScrollArea#presetsScroll {{
    background-color: {c['scroll_bg']};
    border: none;
}}

QScrollArea#presetsScroll > QWidget > QWidget {{
    background-color: {c['scroll_bg']};
}}

QWidget#presetsInner {{
    background-color: {c['scroll_bg']};
}}

QPushButton {{
    background-color: {c['btn_bg']};
    border: 1px solid {c['btn_border']};
    border-radius: 4px;
    padding: 8px 16px;
    font-size: 12px;
    color: {c['text']};
    min-height: 20px;
    text-align: left;
}}

QPushButton:hover {{
    background-color: {c['btn_hover_bg']};
    border-color: {c['btn_hover_border']};
    color: {c['btn_hover_text']};
}}

QPushButton:pressed {{
    background-color: {c['btn_pressed']};
    border-color: {c['accent_border']};
}}

QPushButton#historyButton {{
    background-color: {c['hist_bg']};
    font-size: 11px;
    min-height: 16px;
    padding: 6px 12px;
}}

QTextEdit {{
    background-color: {c['input_bg']};
    border: 1px solid {c['input_border']};
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 13px;
    color: {c['text']};
}}

QTextEdit:focus {{
    border-color: {c['accent']};
    background-color: {c['input_focus_bg']};
}}

QDialogButtonBox QPushButton {{
    min-width: 80px;
    min-height: 28px;
    padding: 6px 20px;
    font-size: 12px;
    text-align: center;
}}

#okButton {{
    background-color: {c['accent']};
    border-color: {c['accent_border']};
    color: {c['accent_text']};
    font-weight: bold;
    text-align: center;
}}

#okButton:hover {{
    background-color: {c['accent_hover']};
}}

#okButton:pressed {{
    background-color: {c['accent_pressed']};
}}
"""


# Keep names used by CI tests
STYLE_LIGHT = build_style(False)
STYLE_DARK = build_style(True)


# --- Locale ---
def detect_locale():
    """Detect locale: ASK_AI_LOCALE env → $LANG → en_EN.

    ASK_AI_LOCALE is handled case-insensitively (RU, ru, en, EN, etc.).
    """
    ask_locale = os.environ.get("ASK_AI_LOCALE", "").strip().lower()
    if ask_locale in ("ru_RU", "ru"):
        return "ru_RU"
    if ask_locale in ("en_EN", "en"):
        return "en_EN"

    lang = os.environ.get("LANG", "")
    if lang.startswith(("ru_RU", "ru_UA", "be_BY", "uk_UA")):
        return "ru_RU"
    return "en_EN"


def load_locale(locale):
    """Load locale strings from file. Returns dict with dialog_* keys."""
    strings = {}
    script_dir = os.path.dirname(os.path.abspath(__file__))

    locale_path = os.path.join(script_dir, "locales", locale)
    if not os.path.isfile(locale_path):
        locale_path = os.path.join(os.path.dirname(script_dir), "locales", locale)

    if os.path.isfile(locale_path):
        with open(locale_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip()
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                        value = value[1:-1]
                    strings[key] = value
    return strings


LOCALE = detect_locale()
LOCALE_STRINGS = load_locale(LOCALE)


def _(key, default=""):
    """Get localized string by key, fallback to default."""
    return LOCALE_STRINGS.get(key, default)


# --- Query history ---
HISTORY_PATH = os.path.expanduser("~/.config/ask-ai-dolphin.history")
HISTORY_MAX = 10


def load_history():
    """Return list of recent queries (most recent first), max HISTORY_MAX."""
    if not os.path.isfile(HISTORY_PATH):
        return []
    try:
        with open(HISTORY_PATH, "r", encoding="utf-8") as f:
            lines = [ln.rstrip("\n") for ln in f if ln.strip()]
        return list(reversed(lines[-HISTORY_MAX:]))
    except OSError:
        return []


def save_history_entry(query):
    """Append query to history, dedupe, keep last HISTORY_MAX."""
    query = (query or "").strip()
    if not query:
        return
    try:
        os.makedirs(os.path.dirname(HISTORY_PATH), exist_ok=True)
        existing = []
        if os.path.isfile(HISTORY_PATH):
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                existing = [ln.rstrip("\n") for ln in f if ln.strip()]
        existing = [e for e in existing if e != query]
        existing.append(query)
        existing = existing[-HISTORY_MAX:]
        with open(HISTORY_PATH, "w", encoding="utf-8") as f:
            f.write("\n".join(existing) + "\n")
    except OSError:
        pass


class AskDialog(QDialog):
    def __init__(self, presets, file_info, locale="en_EN", style=""):
        super().__init__()
        self.locale = locale
        self.setWindowIcon(QIcon.fromTheme("utilities-terminal"))
        self.setMinimumWidth(640)
        self.setMinimumHeight(480)
        self.resize(680, 560)
        self.setModal(True)
        self.setStyleSheet(style)

        win_title = _("dialog_win_title", "Ask AI")
        hdr_title = _("dialog_hdr_title", "Ask AI")
        presets_label_text = _("dialog_presets_label", "Quick queries:")
        history_label_text = _("dialog_history_label", "Recent:")
        input_label_text = _("dialog_input_label", "Or type your query:")
        input_placeholder = _("dialog_input_placeholder", "Your question…")
        ok_text = _("dialog_ok_text", "Send")
        cancel_text = _("dialog_cancel_text", "Cancel")
        model_label = _("dialog_model_label", "Model:")

        self.setWindowTitle(win_title)

        # Root layout: header + file (fixed) | scroll (stretch) | input + buttons (fixed)
        root = QVBoxLayout(self)
        root.setSpacing(10)
        root.setContentsMargins(20, 20, 20, 20)

        # --- Header (must not shrink) ---
        header = QFrame()
        header.setObjectName("headerFrame")
        header.setSizePolicy(_size_policy("Expanding", "Fixed"))
        hdr_layout = QVBoxLayout(header)
        hdr_layout.setContentsMargins(16, 12, 16, 12)
        hdr_layout.setSpacing(4)

        title = QLabel(hdr_title)
        title.setObjectName("headerTitle")
        title.setWordWrap(True)
        title.setSizePolicy(_size_policy("Expanding", "Preferred"))
        hdr_layout.addWidget(title)

        model = os.environ.get("ASK_AI_MODEL", "opencode/deepseek-v4-flash-free")
        meta_parts = [f"{model_label} {model}"]
        if os.environ.get("ASK_AI_EFFORT"):
            meta_parts.append(f"effort={os.environ['ASK_AI_EFFORT']}")
        if os.environ.get("ASK_AI_MODE"):
            meta_parts.append(f"mode={os.environ['ASK_AI_MODE']}")
        meta = QLabel(" · ".join(meta_parts))
        meta.setObjectName("headerMeta")
        meta.setWordWrap(True)
        meta.setSizePolicy(_size_policy("Expanding", "Preferred"))
        hdr_layout.addWidget(meta)

        root.addWidget(header, 0)

        # --- File info card (must not shrink) ---
        file_info = (file_info or "").strip()
        if file_info:
            file_frame = QFrame()
            file_frame.setObjectName("fileFrame")
            file_frame.setSizePolicy(_size_policy("Expanding", "Maximum"))
            fl_layout = QVBoxLayout(file_frame)
            fl_layout.setContentsMargins(12, 8, 12, 8)

            file_label = QLabel(file_info)
            file_label.setObjectName("fileLabel")
            file_label.setWordWrap(True)
            file_label.setTextInteractionFlags(_qt_selectable())
            file_label.setSizePolicy(_size_policy("Expanding", "Preferred"))
            # Cap very long file lists so they don't eat the whole dialog
            file_label.setMaximumHeight(120)
            fl_layout.addWidget(file_label)

            root.addWidget(file_frame, 0)

        # --- Scrollable: presets + history ---
        scroll = QScrollArea()
        scroll.setObjectName("presetsScroll")
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame if QT_API == 6 else QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarAlwaysOff if QT_API == 5 else Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        scroll.setVerticalScrollBarPolicy(_qt_scroll_as_needed())
        scroll.setSizePolicy(_size_policy("Expanding", "Expanding"))
        scroll.setMinimumHeight(120)

        inner = QWidget()
        inner.setObjectName("presetsInner")
        inner_layout = QVBoxLayout(inner)
        inner_layout.setContentsMargins(0, 0, 4, 0)
        inner_layout.setSpacing(8)
        inner_layout.setAlignment(_qt_align_top())

        presets_label = QLabel(presets_label_text)
        presets_label.setObjectName("sectionLabel")
        inner_layout.addWidget(presets_label)

        for preset in presets:
            btn = QPushButton(preset)
            btn.setSizePolicy(_size_policy("Expanding", "Fixed"))
            btn.setMinimumHeight(36)
            btn.clicked.connect(lambda checked=False, p=preset: self.on_preset(p))
            inner_layout.addWidget(btn)

        history = load_history()
        preset_set = set(presets)
        history = [h for h in history if h not in preset_set][:5]
        if history:
            hist_label = QLabel(history_label_text)
            hist_label.setObjectName("sectionLabel")
            inner_layout.addWidget(hist_label)
            for item in history:
                display = item if len(item) <= 80 else item[:77] + "…"
                hbtn = QPushButton(display)
                hbtn.setObjectName("historyButton")
                hbtn.setToolTip(item)
                hbtn.setSizePolicy(_size_policy("Expanding", "Fixed"))
                hbtn.clicked.connect(lambda checked=False, p=item: self.on_preset(p))
                inner_layout.addWidget(hbtn)

        inner_layout.addStretch(1)
        scroll.setWidget(inner)
        root.addWidget(scroll, 1)  # stretch — takes leftover space

        # --- Input (fixed height band, never overlapped) ---
        input_label = QLabel(input_label_text)
        input_label.setObjectName("sectionLabel")
        input_label.setSizePolicy(_size_policy("Expanding", "Fixed"))
        root.addWidget(input_label, 0)

        self.input_field = QTextEdit()
        self.input_field.setPlaceholderText(input_placeholder)
        self.input_field.setAcceptRichText(False)
        self.input_field.setFixedHeight(88)
        self.input_field.setSizePolicy(_size_policy("Expanding", "Fixed"))
        root.addWidget(self.input_field, 0)

        # --- OK / Cancel (always at bottom) ---
        if QT_API == 5:
            buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
            ok_btn = buttons.button(QDialogButtonBox.Ok)
            cancel_btn = buttons.button(QDialogButtonBox.Cancel)
        else:
            buttons = QDialogButtonBox(
                QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
            )
            ok_btn = buttons.button(QDialogButtonBox.StandardButton.Ok)
            cancel_btn = buttons.button(QDialogButtonBox.StandardButton.Cancel)

        ok_btn.setObjectName("okButton")
        ok_btn.setText(ok_text)
        cancel_btn.setText(cancel_text)
        buttons.accepted.connect(self.on_ok)
        buttons.rejected.connect(self.reject)
        buttons.setSizePolicy(_size_policy("Expanding", "Fixed"))
        root.addWidget(buttons, 0)

        self.input_field.setFocus()

    def _emit_query(self, text):
        text = (text or "").strip()
        if not text:
            return False
        save_history_entry(text)
        print(text, flush=True)
        self.accept()
        return True

    def on_preset(self, text):
        self._emit_query(text)

    def on_ok(self):
        query = self.input_field.toPlainText().strip()
        if not self._emit_query(query):
            self.input_field.setFocus()
            self.input_field.setPlaceholderText(
                _("dialog_empty_placeholder", "Type your query!")
            )


def main():
    fallback_preset = _("dialog_fallback_preset", "Explain these files")
    presets = sys.argv[1:] if len(sys.argv) > 1 else [fallback_preset]
    file_info = sys.stdin.read().strip() if not sys.stdin.isatty() else ""

    app = QApplication(sys.argv)
    try:
        app.setStyle("Breeze")
    except Exception:
        pass

    font = QFont()
    try:
        font.setFamilies(["Noto Sans", "Noto Color Emoji", "Segoe UI Emoji", "Symbola"])
    except AttributeError:
        font.setFamily("Noto Sans")
    font.setPointSize(10)
    app.setFont(font)

    is_dark = detect_dark_theme(app)
    style = STYLE_DARK if is_dark else STYLE_LIGHT

    dialog = AskDialog(presets, file_info, locale=LOCALE, style=style)
    accepted = _dialog_exec(dialog) == _qt_accepted()
    sys.exit(0 if accepted else 1)


if __name__ == "__main__":
    main()
