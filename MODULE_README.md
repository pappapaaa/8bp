# Pool debug overlay module

This module is the in-app orchestration layer for the existing simulator and live shared-memory adapter. It is intended to be added to an iOS application that owns the physics engine and its data providers.

## Components

- `ModEntry.mm` schedules startup on the main queue after launch.
- `OverlayManager` creates a transparent alert-level `UIWindow`, installs the overlay, and owns gesture controls.
- `PredictionLoop` is a callback-driven C++17 worker running at approximately 60 Hz. The host supplies `ActiveProvider` and `ShotProvider` callbacks, so the module remains decoupled from any particular view controller or data model.
- `TrajectoryOverlayView` remains the renderer and can use `LiveDataAdapter` through its `liveModeEnabled` property.
- `LiveDataAdapter` consumes the fixed binary seqlock frame defined by `SharedMemoryWriter.h`.

## Integrating into an app

Add the module `.mm` and `.cpp` files to the application target, set C++ language dialect to C++17, and use `libc++`. Add `config.plist` to the application bundle. The constructor schedules `OverlayManager` startup on the main queue; normal app lifecycle code can also call:

```objc
[[OverlayManager sharedManager] start];
```

For live mode, set `LiveData.enabled` to `true` in the plist. The overlay then reads `LiveDataAdapter` snapshots and clears after the configured stale interval.

## Starting the prediction loop

Create `PredictionLoop` from the app-owned `PhysicsSimulator` and `SharedMemoryWriter`, then supply callbacks for app-owned active state and shot parameters:

```cpp
auto loop = std::make_unique<PredictionLoop>(
    [] { return appState.isSimulationActive(); },
    [] { return appState.currentShot(); },
    simulator,
    writer);
loop->start();
```

The loop only publishes when the shot changes. It preserves the previous values and sleeps against a steady-clock deadline to avoid cumulative timing drift.

## Build

The supplied script builds a normal iOS static library; it does not alter or inject into another application:

```bash
chmod +x build_module.sh
SDK=iphonesimulator ./build_module.sh
SDK=iphoneos ./build_module.sh
```

The app target should link the resulting `libPoolDebugOverlay.a` and the iOS frameworks already used by the app (`UIKit`, `CoreGraphics`, and `QuartzCore`). For device and simulator distribution, package the two builds as an XCFramework.

## Gestures

- Double-tap toggles overlay visibility.
- Press and hold for two seconds opens the placeholder control alert.
- Gesture recognizers use `cancelsTouchesInView = NO`.

