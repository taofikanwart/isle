#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 zickrian
# Removes Isle for KDE Plasma from this user's home folder.
#   isle-uninstall            keep your settings (~/.config/isle)
#   isle-uninstall --purge    remove them too
set -euo pipefail

BINDIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

printf '\033[1m==> Stopping Isle\033[0m\n'
systemctl --user stop isle-island.service 2>/dev/null || true
systemctl --user stop isled.service 2>/dev/null || true
pkill -x isle-island 2>/dev/null || true
pkill -x isled 2>/dev/null || true

printf '\033[1m==> Removing files\033[0m\n'
systemctl --user disable isle-island.service 2>/dev/null || true
systemctl --user disable isled.service 2>/dev/null || true
rm -f "$CONFIG/systemd/user/isle-island.service" "$CONFIG/systemd/user/isled.service"
systemctl --user daemon-reload 2>/dev/null || true

rm -f "$BINDIR/isled" "$BINDIR/isle-island"
rm -f "$DATA/dbus-1/services/io.github.zickrian.isle.Daemon.service"
rm -f "$DATA/applications/isle-island.desktop"
rm -f "$CONFIG/autostart/isle-island.desktop"
rm -f "$DATA/icons/hicolor/scalable/apps/isle-island.svg"
rm -f "$BINDIR/isle-uninstall"

if [ "$PURGE" = 1 ]; then
    rm -rf "$CONFIG/isle"
    printf 'Settings removed (%s/isle).\n' "$CONFIG"
else
    printf 'Settings kept in %s/isle (use --purge to remove them).\n' "$CONFIG"
fi
printf 'Isle is uninstalled.\n'
