#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LCARS paint pass — run AFTER `./setup install` (user level, no sudo).
#
# Installs the Voyager LCARS wallpaper and profile, then lays the live LCARS
# rice over the stock impasto config from files/: palette, Antonio typeface,
# island band + clock metrics, the left-edge taskbar dock (LCARS tiles, black
# mono icons), the 62 px top/left reserve strips, the corner CPU/RAM gauge +
# band buttons (LcarsButtons.qml), the 4 px LCARS window borders, gaps_out=0
# and the LCARS key/gesture module.
#
# Every file under files/ is a snapshot of the live, verified config — it is
# installed wholesale, so run this again after `./setup update` to re-apply.
# Idempotent: safe to run twice.
#
#   LCARS_SKIP_HOME=1 ./lcars-apply.sh
#       keeps your own shell rc instead of installing files/home/ (the
#       greeting snippet is then yours to paste — see README).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

T="${IMPASTO_HOME:-$HOME}"
CFG="$T/.config/quickshell"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '  \033[38;2;255;156;0m%s\033[0m %s\n' "$1" "$2"; }

[[ -f "$CFG/shell.qml" ]] || { echo "lcars-apply: $CFG not found — run ./setup install first" >&2; exit 1; }

# ── 1. wallpapers ────────────────────────────────────────────────────────────
# The whole LCARS family: one frame, a different centre for each scene.
mkdir -p "$T/.local/share/wallpapers"
for piece in "$SRC"/wallpapers/lcars-*.png; do
    [[ -f "$piece" ]] || continue
    install -m 644 "$piece" "$T/.local/share/wallpapers/"
done
say ok "wallpaper  LCARS set — $(find "$SRC/wallpapers" -maxdepth 1 -name 'lcars-*.png' | wc -l) pieces in ~/.local/share/wallpapers"

# The picker lists only top-level images, so anything that is not LCARS moves
# to stock/ — kept on disk, hidden from the selector. A setup update re-ships
# the stock impasto wallpapers; this pass hides them again. The wallpaper
# currently on screen is left alone.
mkdir -p "$T/.local/share/wallpapers/stock"
current="$(python3 "$CFG/scripts/theme_manager.py" get-current 2>/dev/null || true)"
stock=0
for piece in "$T/.local/share/wallpapers"/*; do
    [[ -f "$piece" ]] || continue
    case "$(basename "$piece")" in lcars-*) continue ;; esac
    [[ "$piece" == "$current" ]] && continue
    mv "$piece" "$T/.local/share/wallpapers/stock/"
    stock=$((stock + 1))
done
say ok "stock      $stock non-LCARS wallpapers archived to stock/ (out of the picker)"

# ── 2. fonts: Anton + Antonio ship in fonts/ ─────────────────────────────────
for f in Anton-Regular.ttf Antonio-Variable.ttf; do
    if [[ -f "$SRC/fonts/$f" && ! -f "$T/.local/share/fonts/$f" ]]; then
        install -D -m 644 "$SRC/fonts/$f" "$T/.local/share/fonts/$f"
    fi
done
if command -v fc-cache >/dev/null; then fc-cache -f >/dev/null 2>&1 || true; fi
say ok "fonts      Anton + Antonio in the fontconfig cache"

# ── 3. the LCARS profile ────────────────────────────────────────────────────
# Named 0-… so it sorts first: on a fresh install impasto adopts the first
# shipped profile automatically, which makes this one the default desk.
python3 - "$T" <<'PY'
import json, os, sys
home = sys.argv[1]
doc = {
    "impasto": 1,
    "name": "LCARS Voyager",
    "wallpaper": os.path.join(home, ".local/share/wallpapers/lcars-voyager.png"),
    "palette": "lcars_voyager",
    "settings": {},
}
path = os.path.join(home, ".local/share/impasto/profiles/0-lcars-voyager.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
print("profile", path)
PY
say ok "profile    LCARS Voyager (auto-selected on first start)"

# ── 4. the config snapshots ─────────────────────────────────────────────────
# files/ mirrors .config/: quickshell/… and hypr/… go into .config/… as they
# are on the verified, running system.
while IFS= read -r rel; do
    # LCARS_SKIP_HOME=1 keeps the reader's own shell rc — files/home/ is the
    # author's snapshot of it.
    if [[ -n "${LCARS_SKIP_HOME:-}" && "$rel" == home/* ]]; then
        continue
    fi
    # Scripts run straight from .config (quickshell spawns them by path),
    # so they keep their exec bit; everything else is a config file.
    mode=644
    case "$rel" in *.py|*.sh) mode=755 ;; esac
    # files/home/… mirrors $HOME itself — .zshrc and friends live above
    # .config; everything else mirrors .config/.
    if [[ "$rel" == home/* ]]; then
        install -D -m "$mode" "$SRC/files/$rel" "$T/${rel#home/}"
    else
        install -D -m "$mode" "$SRC/files/$rel" "$T/.config/$rel"
    fi
done < <(cd "$SRC/files" && find . -type f | sed 's|^\./||')
say ok "config     LCARS shell, Hyprland, kitty, fastfetch greeting"

# The autostart snapshot carries the author's home in its Exec= line — rewrite
# it for this machine, or the KDE colour restore points at a path that does not
# exist here. (On the author's machine this rewrites to the same bytes.)
AUTO="$T/.config/autostart/restore-impasto-colors.desktop"
if [[ -f "$AUTO" ]]; then
    sed -i "s|^Exec=.*restore_kde_scheme\.py$|Exec=/usr/bin/python3 $T/.config/quickshell/scripts/restore_kde_scheme.py|" "$AUTO"
fi

# ── 5. persisted shell settings, if the shell has already run ───────────────
# A fresh install never wrote settings.json — the patched SettingsService
# defaults cover it. If it exists (shell ran before this pass), align the
# LCARS keys explicitly.
SETTINGS="$T/.local/state/quickshell/settings.json"
if [[ -f "$SETTINGS" ]]; then
    python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    doc = json.load(f)
doc.update({
    "barHeight": 62, "barMargin": 0, "islandAttached": True,
    "dockEdge": "left", "dockAlignment": "end", "dockIconSize": 36,
})
with open(path, "w") as f:
    json.dump(doc, f, indent=4)
    f.write("\n")
print("settings aligned")
PY
    say ok "settings   island band 62, taskbar left/start, icons 36"
else
    say ok "settings   no settings.json yet — stock defaults already LCARS"
fi

# ── 6. Dolphin: LCARS color scheme + default file manager ───────────────────
# KDE has exactly one global scheme (kdeglobals); the session hooks own that
# key — LCARS at Hyprland start, Impasto at Plasma start (see files/autostart/
# restore-impasto-colors.desktop). This step only installs the scheme itself
# and points folders at Dolphin; thunar was the stock default.
install -D -m 644 "$SRC/LCARS.colors" "$T/.local/share/color-schemes/LCARS.colors"
if command -v xdg-mime >/dev/null; then
    xdg-mime default org.kde.dolphin.desktop inode/directory
fi
say ok "dolphin    LCARS colors installed, folders open in Dolphin"

echo
say ok "LCARS pass complete."
