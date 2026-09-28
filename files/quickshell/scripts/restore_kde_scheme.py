#!/usr/bin/env python3
"""Put kdeglobals back to the daily-driver colours when Plasma starts.

The LCARS session's palette push writes inline [Colors:*] sections into
kdeglobals, and those sections outrank the ColorScheme name — flipping the
name alone would leave Plasma's KDE apps wearing LCARS. This regenerates the
sections from the stock impasto palette (catppuccin_mocha, the default in
Palettes.qml) through theme_manager's own builder, so Plasma comes back to
exactly the state a fresh impasto install ships, name included.

Run by autostart/restore-impasto-colors.desktop; the LCARS session reverses
this on its own startup, when quickshell's ThemeService re-pushes the active
palette. Harmless if run twice.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import theme_manager as tm

STOCK = {
    "background": "#1e1e2e", "surface": "#181825", "surfaceHover": "#313244",
    "border": "#45475a", "text": "#cdd6f4", "textMuted": "#a6adc8",
    "accent": "#89b4fa", "accentHover": "#b4befe", "accentText": "#11111b",
    "red": "#f38ba8", "green": "#a6e3a1", "yellow": "#f9e2af", "blue": "#89b4fa",
}

tm.KDE_SCHEME_NAME = "Impasto"
tm.write_kde_colors(STOCK)
