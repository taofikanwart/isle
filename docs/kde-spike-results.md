# Isle KDE port — feasibility spike results

*The throwaway spike under `spike/` was deleted after these results; `kde-island/` replaced it.*

The spike was a throwaway Qt5 + LayerShellQt app that proved the layer-shell
notch architecture before real work started. It was deleted once the answers
were in; `kde-island/` replaced it.

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

| # | Test | Pass when | X11 | Wayland |
|---|------|-----------|-----|---------|
| 1 | Stacking | The notch shows **above the Plasma panel**, top centre, not clipped | ✅ | ☐ |
| 2 | Click-through | Clicks 2 px outside the notch reach the panel/app underneath | ✅ | ☐ |
| 3 | Hover + spring | Pointer in/out opens/closes with the spring, no flicker at the edge | ✅ | ☐ |
| 4 | Glass | The translucent notch reads as glass over any wallpaper, no KWin blur | ✅* | ☐ |
| 5 | D-Bus | The open notch shows `Media1.NowPlaying` and ▶❙❙ toggles playback | ✅** | ☐ |

\* Renders fine; the spike's look is a placeholder, the real design comes in
phase 2 from `gnome-extension/src/{island,glass,shader}.js`.
\*\* Contract proven over `busctl` and `verify-caller-patch.py`; the in-UI
play/pause test still needs an MPRIS player running.

Also note: panel at top vs bottom, multi-monitor, fractional scaling.

## Verdict

- X11 (Plasma 5.27, 2026-11-04): criteria 1–3 pass on the fallback path
  (`Qt::X11BypassWindowManagerHint` + input mask). Hover and spring feel
  right; clicks outside the notch pass through.
- Wayland: _pending_ — needs a login into a Plasma Wayland session, then
  `./build/isle-spike` again. This is the test that decides the
  architecture (layer-shell vs plasmoid fallback).
- Decision: _pending Wayland result_
