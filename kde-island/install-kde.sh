#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 zickrian
# Installs Isle for KDE Plasma for this user, no root: the daemon, the island
# frontend and their service files. Builds them first unless --no-build.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BINDIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0

step() { printf '\033[1m==> %s\033[0m\n' "$*"; }
die() { printf 'Isle: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run this as yourself, without sudo: it installs into your home folder"

# --- dependencies already on the system ------------------------------------
step "Checking what the island needs"
# Read once: piping ldconfig into `grep -q` gives it SIGPIPE, and with pipefail
# that reads as a missing library.
CACHE="$(ldconfig -p 2>/dev/null || true)"
missing=()
for lib in libQt5Quick.so.5 libQt5DBus.so.5 libgio-2.0.so.0 libX11.so.6; do
    grep -qF -- "$lib" <<<"$CACHE" || missing+=("$lib")
done
if [ "${#missing[@]}" -gt 0 ]; then
    die "missing libraries: ${missing[*]}
On Debian/Ubuntu: sudo apt install libqt5quick5 libqt5dbus5 libglib2.0-0 libx11-6"
fi
if ! grep -qF LayerShellQtInterface <<<"$CACHE"; then
    printf 'Note: LayerShellQt not found; the island will only work in an X11 session.\n'
fi

# --- build ------------------------------------------------------------------
if [ "$BUILD" = 1 ]; then
    step "Building isled"
    ( cd "$ROOT" && cargo build --release -p isle-daemon )
    step "Building isle-island"
    cmake -S "$HERE" -B "$HERE/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build "$HERE/build" -j"$(nproc)"
fi
ISLED="$ROOT/target/release/isled"
ISLAND="$HERE/build/isle-island"
[ -x "$ISLED" ] || die "isled is not built: $ISLED"
[ -x "$ISLAND" ] || die "isle-island is not built: $ISLAND"

# --- stop what is running so the new binaries take over ---------------------
step "Stopping what is running"
systemctl --user stop isle-island.service 2>/dev/null || true
pkill -x isle-island 2>/dev/null || true
systemctl --user stop isled.service 2>/dev/null || true
pkill -x isled 2>/dev/null || true

# Whole or not at all: copied beside it, then renamed over it.
put() { install -Dm755 "$1" "$2.new"; mv -f "$2.new" "$2"; }
fill() { sed -e "s|@BINDIR@|$BINDIR|g" -e "s|@ICON@|isle-island|g" -e "s|@NODISPLAY@|$2|g" \
             "$HERE/data/$1" > "$3"; install -Dm644 "$3" "$4"; }

step "Installing programs into $BINDIR"
put "$ISLED" "$BINDIR/isled"
put "$ISLAND" "$BINDIR/isle-island"
install -Dm755 "$HERE/uninstall-kde.sh" "$BINDIR/isle-uninstall"

step "Installing D-Bus and systemd user files"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed "s|@BINDIR@|$BINDIR|" "$ROOT/data/isled.service" > "$TMP/isled.service"
install -Dm644 "$TMP/isled.service" "$CONFIG/systemd/user/isled.service"
sed "s|@BINDIR@|$BINDIR|" "$ROOT/data/io.github.zickrian.isle.Daemon.service" \
    > "$TMP/io.github.zickrian.isle.Daemon.service"
install -Dm644 "$TMP/io.github.zickrian.isle.Daemon.service" \
    "$DATA/dbus-1/services/io.github.zickrian.isle.Daemon.service"
sed "s|@BINDIR@|$BINDIR|" "$HERE/data/isle-island.service" > "$TMP/isle-island.service"
install -Dm644 "$TMP/isle-island.service" "$CONFIG/systemd/user/isle-island.service"

step "Installing the icon and menu entry"
install -Dm644 "$HERE/data/isle-island.svg" \
    "$DATA/icons/hicolor/scalable/apps/isle-island.svg"
fill isle-island.desktop false "$TMP/launcher.desktop" \
    "$DATA/applications/isle-island.desktop"
fill isle-island.desktop true "$TMP/autostart.desktop" \
    "$CONFIG/autostart/isle-island.desktop"

# --- start ------------------------------------------------------------------
step "Starting isled"
systemctl --user daemon-reload
systemctl --user enable isled.service >/dev/null 2>&1 || true
systemctl --user start isled.service || true
for _ in $(seq 1 20); do pgrep -x isled >/dev/null && break; sleep 0.25; done
pgrep -x isled >/dev/null || die "isled did not start: systemctl --user status isled"

step "Starting the island"
systemctl --user enable isle-island.service >/dev/null 2>&1 || true
systemctl --user start isle-island.service || true
started=0
for _ in $(seq 1 20); do
    pgrep -x isle-island >/dev/null && { started=1; break; }
    sleep 0.25
done
if [ "$started" = 0 ]; then
    # Plasma 5.27 does not always drive graphical-session.target; the
    # autostart entry always runs at login, so drop the unit and use it.
    printf 'Note: the systemd unit did not start; using the autostart entry instead.\n'
    systemctl --user disable isle-island.service >/dev/null 2>&1 || true
    rm -f "$CONFIG/systemd/user/isle-island.service"
    systemctl --user daemon-reload
    setsid "$BINDIR/isle-island" >/dev/null 2>&1 < /dev/null &
fi

step "Isle is installed"
printf '  daemon     %s\n  island     %s\n  config     %s\n' \
    "$BINDIR/isled" "$BINDIR/isle-island" "$CONFIG/isle/island.conf"
printf '  services   %s\n' "$CONFIG/systemd/user/isled.service"
printf 'Uninstall:  %s/isle-uninstall\n' "$BINDIR"
