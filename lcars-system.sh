#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LCARS system bits — needs sudo.
#
#   1. a distinct, selectable "LCARS · Voyager (Hyprland)" session at login
#   2. LCARS fonts system-wide (so the greeter can use them)
#   3. the Voyager LCARS art as the Plasma Login Manager background
#   4. Relogin=false so logging out shows the session picker (boot autologin
#      to Plasma is kept — it is the "first login" path)
#   5. the lock screen's fingerprint PAM service (beside `login`, the way
#      impasto-face sits beside it for the camera)
#
# Idempotent: safe to run twice.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run this with sudo" >&2; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_HOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
WALL="$SRC/wallpapers/lcars-voyager.png"
CONF=/etc/plasmalogin.conf

say() { printf '  \033[38;2;255;156;0m%s\033[0m %s\n' "$1" "$2"; }

# ── 1. the session entry ────────────────────────────────────────────────────
install -d -m 755 /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/lcars-impasto.desktop <<'EOF'
[Desktop Entry]
Name=LCARS · Voyager (Hyprland)
Comment=Hyprland with the impasto shell, painted in Voyager LCARS colours
Exec=/usr/bin/Hyprland
Type=Application
DesktopNames=Hyprland
EOF
say ok "session    /usr/share/wayland-sessions/lcars-impasto.desktop"

# CachyOS ships "Hyprland (uwsm-managed)" with the hyprland package, but this
# machine has no uwsm: picking it authenticates fine and then the session dies
# with exit 127 (command not found), bouncing straight back to the picker —
# it looks like a rejected password. Hide the entry while uwsm is absent.
if [[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] && ! command -v uwsm >/dev/null; then
    mv /usr/share/wayland-sessions/hyprland-uwsm.desktop \
       /usr/share/wayland-sessions/hyprland-uwsm.desktop.no-uwsm
    say ok "picker     hid the broken Hyprland (uwsm-managed) entry (uwsm is not installed)"
fi

# ── 2. fonts for every user, greeter included ───────────────────────────────
install -d -m 755 /usr/share/fonts/truetype/lcars
for f in Anton-Regular.ttf Antonio-Variable.ttf; do
    [[ -f "$REAL_HOME/.local/share/fonts/$f" ]] \
        && install -m 644 "$REAL_HOME/.local/share/fonts/$f" "/usr/share/fonts/truetype/lcars/$f"
done
if command -v fc-cache >/dev/null; then fc-cache -f >/dev/null 2>&1 || true; fi
say ok "fonts      /usr/share/fonts/truetype/lcars"

# ── 3. the greeter's wallpaper ──────────────────────────────────────────────
if [[ -f "$WALL" ]]; then
    # The greeter reads its picture from the plasmalogin system user's home.
    PW=$(getent passwd plasmalogin | cut -d: -f6)
    PG=$(id -g plasmalogin)
    PU=$(id -u plasmalogin)
    install -d -m 755 "$PW"
    install -d -o "$PU" -g "$PG" -m 755 "$PW/wallpapers"
    install -o "$PU" -g "$PG" -m 644 "$WALL" "$PW/wallpapers/lcars-voyager.png"
    say ok "greeter    $PW/wallpapers/lcars-voyager.png"
else
    say "--  " "greeter wallpaper not found at $WALL (skipped)"
fi

# ── 4. the login screen's config ────────────────────────────────────────────
touch "$CONF"
if ! grep -q "^WallpaperPluginId=" "$CONF"; then
    cat >> "$CONF" <<'EOF'

[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///var/lib/plasmalogin/wallpapers/lcars-voyager.png
EOF
    say ok "config     greeter background = the LCARS art"
else
    say ok "config     greeter background already set"
fi

# Boot still autologins to Plasma ("first login"), but Relogin=true would
# bounce back into Plasma after every logout and hide the session picker.
if grep -q "^Relogin=true$" "$CONF"; then
    sed -i 's/^Relogin=true$/Relogin=false/' "$CONF"
    say ok "relogin    false — logout now shows the session picker"
else
    say ok "relogin    already correct"
fi

# ── 5. the lock screen's fingerprint service ────────────────────────────────
# Beside `login`, the way impasto-face sits beside it for the camera: the
# lock screen runs this conversation on its own, so a matching enrolled
# finger unlocks the screen while the password never waits on the sensor,
# and a finger that is not recognised costs the password nothing.
FPAM=/etc/pam.d/impasto-fprint
if [[ ! -f "$FPAM" ]]; then
    cat > "$FPAM" <<'EOF'
#%PAM-1.0
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   I M P A S T O - F P R I N T                                            │
# │   pam · fingerprint unlock for the lock screen, beside the password      │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

# The lock screen's third service, run beside `login` rather than inside it.
# pam_fprintd looks at every enrolled finger and never asks for a word, so
# the password's conversation is never held up waiting for the sensor, and a
# scan that fails never counts against the password's attempts. Only the
# lock screen uses it.
auth        sufficient  pam_fprintd.so
auth        required    pam_deny.so
EOF
    say ok "fprint    $FPAM"
else
    say ok "fprint    $FPAM already present"
fi

echo
say ok "LCARS system pass complete."
