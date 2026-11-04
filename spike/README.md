# Isle KDE port — feasibility spike

Throwaway code. It proves (or disproves) the layer-shell notch architecture
before the real port starts. Nothing here ships.

Built for Qt5 + Plasma 5.27 (what this machine runs). The real port targets
Qt6/KF6 with a Qt5 fallback while distros still ship Plasma 5.

## Build

```bash
sudo apt install liblayershellqtinterface-dev qtbase5-dev qtdeclarative5-dev \
    qml-module-qtquick2 qml-module-qtquick-window2 cmake g++

cd spike
cmake -B build && cmake --build build -j
```

## Run

isled must be running first for criterion 5 (`cargo build --release -p
isle-daemon`, then run `target/release/isled`), and some MPRIS player
(Spotify, a YouTube tab...) must be playing.

```bash
./build/isle-spike
```

On Wayland it uses layer-shell; on X11 it falls back to an unmanaged
always-on-top window. The QML shows which path is active.

## Pass criteria

| # | Test | Pass when | Status |
|---|------|-----------|--------|
| 1 | Stacking | The notch shows **above the Plasma panel**, top centre, not clipped | ☐ |
| 2 | Click-through | Clicks 2 px outside the notch reach the panel/app underneath | ☐ |
| 3 | Hover + spring | Pointer in/out opens/closes with the spring, no flicker at the edge | ☐ |
| 4 | Glass | The translucent notch reads as glass over any wallpaper, no KWin blur | ☐ |
| 5 | D-Bus | The open notch shows `Media1.NowPlaying` and ▶❙❙ toggles playback | ☐ |

Also note: panel at top vs bottom, multi-monitor, fractional scaling.

## Verdict

Fill in after testing on a real Plasma Wayland session:

- Result: _pending_
- Decision: _pending_ (layer-shell architecture / plasmoid fallback)
