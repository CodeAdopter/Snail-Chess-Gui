# Optimisation results, November 2026

The 3D board and board animations were made lighter in commit `4c82cdc`. These are the numbers
from `bench/bench.py` before and after, on two PCs. Each scene ran for 12 seconds in a 1000×680 window, and the first 5 seconds
of each, while the scene loads, are left out. Ultra is the Ultra preset: 8× MSAA before, 4× after.

- **Before:** the build of 9 November, before any of the changes.
- **After:** `4c82cdc`.

## Pc2: Ryzen 7 2700X, GTX 1660 Super

This is the budget gaming PC the work aimed at. It ran over ssh in a disconnected Windows session, which has no vsync, so a
moving camera draws as fast as the GPU can. That makes the frame rate a direct measure of what a frame costs.
The GPU draws 11.7 W with nothing to do.

### At rest, Ultra

The rooms animate their surroundings 30 times a second: the fire, the trees, the sky.

| Room | Before | After |
|---|---|---|
| Library (fire) | 32.0 W | **11.6 W** |
| Library, analysing | 32.8 W | **12.2 W** |
| Mars | 24.5 W | **11.9 W** |
| Park | 24.3 W | **13.9 W** |
| Bedroom | 14.2 W | **13.5 W** |

At rest, Ultra now uses about the GPU's idle power in every room.

### Camera moving, Ultra, as fast as the GPU draws

| Room | Before | After |
|---|---|---|
| Empty | 245 fps | **506 fps** |
| Library | 155 fps | **312 fps** |
| Park | 178 fps | **347 fps** |
| Mars | 181 fps | **373 fps** |

A moving frame on Ultra now costs what one on High does (High: 336 fps in the library). The view goes back to full Ultra
sharpness 180 ms after the camera stops. At a 60 Hz screen's 66 frames a second, moving the camera on Ultra uses 22-34 W.

### 2D board animations

| | Before | After |
|---|---|---|
| Animated pieces, nothing pacing the frames | 2,100-2,600 fps, 73-101 W | **66 fps, 12 W** |

Without a screen to pace it, which also happens when a graphics driver is set to ignore vsync, a 2D animation used to draw
as fast as it could. It now never starts a frame sooner than a refresh after the last one.

## This PC: i9-14900KF, RTX 5080, 164 Hz screen

The app ran on the desktop with vsync, so a moving camera is held at the screen's 164 Hz. The watts are the whole GPU's,
including about 35 W for the other programs open at the time, so the drops matter more than the totals. GPU ms per frame is
the GPU's own timing of a frame.

### At rest, Ultra

| Room | Before | After |
|---|---|---|
| Library (fire) | 47.1 W, 13.5 % busy | **38.3 W, 5.7 %** |
| Library, analysing | 59.0 W, 11.0 % | **33.8 W, 7.3 %** |
| Park | 49.5 W, 17.5 % | **36.1 W, 8.6 %** |
| Mars | 43.3 W, 15.7 % | **34.4 W, 8.4 %** |
| Bedroom | 38.5 W, 14.8 % | **35.9 W, 8.6 %** |
| Empty room, nothing to draw | 36.3 W | 35.1 W |

### Camera moving, Ultra, at 164 fps

| Room | Before | After | GPU ms a frame, before → after |
|---|---|---|---|
| Empty | 63.2 W | **44.4 W** | 0.87 → **0.37** |
| Library | 90.3 W | **54.8 W** | 1.48 → **0.73** |
| Park | 73.4 W | **51.1 W** | 1.09 → **0.55** |
| Mars | 69.2 W | **49.3 W** | 1.09 → **0.50** |

### Vsync off

| Room | Before | After |
|---|---|---|
| Empty | 65 fps | **160 fps** |
| Library | 40 fps | **159 fps** |
| Park | 50 fps | **160 fps** |
| Mars | 65 fps | **160 fps** |

With vsync off the old pacing waited a refresh after a frame was shown, then drew the next one. That held a moving camera
well under the screen's rate. The pacing now counts from the start of the last frame.

### 2D

The 2D board is unchanged: 165 fps when animating, 0.08 ms of GPU time a frame in Charcoal and 0.12 ms in Paper.

## What made the difference

- **Kept board layer.** A room's surroundings move on their own, but the board does not. On each tick, only the backdrop
  is drawn again, into the board's kept multisampled scene. The board is no longer drawn again 30 times a second. The park,
  whose tree shade drifts over the table, refreshes the kept board ten times a second.
- **Ultra at 4× MSAA.** At Ultra's 1.5× render scale, 8× and 4× MSAA look the same: screenshots differ by no more than two
  runs of the same build. 4× is about 22% faster.
- **1× while moving.** While the camera moves, the 3D view is drawn at 1× scale. It is drawn sharp again once the camera
  stops.
- **Frame pacing.** A frame never starts sooner than a refresh after the last one.
- **Frame rate limit.** Graphics > Display can cap board drawing at 15, 30, 60 or 120 fps. Screen, the default, does not cap.
- **Hidden window.** Nothing in 3D is drawn while the window is minimised or covered.

Tried and left out:

- **Shadow-map caching** saved nothing measurable.
- **2×2 shading while moving** made the board's square edges jagged.

## Running it again

```
python bench/bench.py                       # every scene, here
python bench/bench.py --host snail-2700x    # on Pc2, in its desktop session
```

Results are saved to `build/bench/`. Watts are the most reliable measure at rest, because a GPU at low clocks reads as
busier than it is.
