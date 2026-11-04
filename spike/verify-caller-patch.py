#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Spike check: a process holding io.github.zickrian.isle.Island may call
# isled's guarded methods, and a process without the name may not.

import sys

from gi.repository import Gio, GLib

BUS = "io.github.zickrian.isle.Daemon"
PATH = "/io/github/zickrian/isle/Daemon"
CLIPBOARD = "io.github.zickrian.isle.Clipboard1"
ISLAND = "io.github.zickrian.isle.Island"


def call_get_text(bus):
    return bus.call_sync(
        BUS, PATH, CLIPBOARD, "Search",
        GLib.Variant("(s)", ("",)),
        None, Gio.DBusCallFlags.NONE, 5000, None)


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    # Without the Island name: must be refused.
    try:
        call_get_text(bus)
        print("FAIL: guarded call passed without the Island name")
        return 1
    except GLib.Error as e:
        if "AccessDenied" not in e.message and "denied" not in e.message.lower():
            print(f"FAIL: expected AccessDenied, got: {e.message}")
            return 1
        print("ok: refused without the Island name")

    # With it: must pass.
    loop = GLib.MainLoop()
    result = {}

    def on_name(bus, name):
        try:
            call_get_text(bus)
            result["ok"] = True
        except GLib.Error as e:
            result["error"] = e.message
        loop.quit()

    def on_lost(bus, name):
        result["error"] = f"could not own {name} (another holder?)"
        loop.quit()

    Gio.bus_own_name_on_connection(
        bus, ISLAND, Gio.BusNameOwnerFlags.NONE, on_name, on_lost)
    GLib.timeout_add_seconds(5, loop.quit)
    loop.run()

    if result.get("ok"):
        print("ok: accepted while holding the Island name")
        return 0
    print(f"FAIL: {result.get('error', 'timed out')}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
