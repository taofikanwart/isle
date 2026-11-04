# isle-island — the KDE frontend

The island for KDE: a notch at the top of the screen that shows the time and
what is playing, and opens on hover into the pages. It talks to `isled` (the
Rust daemon in this repository) over D-Bus, so all the work — MPRIS, lyrics,
timers, reminders, calendar, clipboard — is the same code the GNOME extension
uses.

Early work in progress. It draws the closed notch and the media page; the
other pages come next.

## Build

```bash
sudo apt install qtbase5-dev qtdeclarative5-dev liblayershellqtinterface-dev \
    qml-module-qtquick2 qml-module-qtquick-window2

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Qt 6 is picked up automatically where it is the default; the code builds
against both.

## Run

`isled` must be running first (it is the daemon in the root of this
repository):

```bash
cargo build --release -p isle-daemon
./target/release/isled &

cd kde-island
./build/isle-island
```

Environment:

| Variable | Default | Meaning |
|---|---|---|
| `ISLE_THEME` | `black` | `black` or `glass` (theme.js: Isle's own black, or glass over what is behind it) |
| `ISLE_IN_BAR` | `1` | `1`: the closed island sits inside the top bar like a notch. `0`: it hangs below the bar (notch-depth 30) |

## What is ported

| Piece | Source | State |
|---|---|---|
| Damped springs | `gnome-extension/src/spring.js` | C++ (`src/spring.*`), same constants |
| Theme, glass tint | `gnome-extension/src/theme.js` | `qml/Theme.js` |
| Notch outline | `gnome-extension/src/glass.js` (ShapeMask), `island.js` `_box` | `qml/NotchShape.qml` (Canvas) |
| Sizes, radii | `controller.js` (COMPACT_*, EXPANDED_*), `compact.js` (SIZES, PILL_HEIGHT) | `qml/Island.qml` |
| Media state | `Media1` D-Bus interface | `src/daemonclient.*` |
| Inter typeface | `data/fonts/InterVariable.ttf` | built into the binary |

Not ported yet: the real glass blur (needs KWin or a backdrop capture), the
other pages, notifications, and the panel-aware positioning for a panel that
is not at the top.

## Window placement

- **Wayland**: a layer-shell surface on the top layer, anchored to the top
  edge, exclusive zone 0, no keyboard interactivity, when `LayerShellQt` is
  available.
- **X11**: a frameless, always-on-top, unmanaged window centred at the top.

Either way the window is as big as the expanded island and everything outside
the notch is masked away with `QWindow::setMask`, so clicks pass through to
whatever is underneath. The mask follows the springs every frame.

## Talking to isled

The daemon used to answer only `org.gnome.Shell` for its guarded methods
(clipboard, assistant, agents). `island` now claims `io.github.zickrian.isle.Island`
on the session bus; `crates/isle-daemon/src/caller.rs` accepts whoever holds
it, first claim wins — the same trust model as the shell's well-known name.
