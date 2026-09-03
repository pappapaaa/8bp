# iOS integration

## Files to add to Xcode

Add these files to the application target:

- `PhysicsEngine.h/.mm`
- `ShotResultSnapshot.h/.mm`
- `TrajectoryOverlayView.h/.mm`
- `ViewController.mm`
- `config.plist`

Add the existing C++ engine sources or its static library. The wrapper currently targets this repository's public C++ types from `Prediction.h`, `Config.h`, and `PhysicsSimulator.h`.

## Xcode settings

Set:

- `Compile Sources As`: `Objective-C++` for `.mm` files.
- `C++ Language Dialect`: `C++17`.
- `C++ Standard Library`: ` libc++`.
- `Header Search Paths`: directory containing the C++ engine headers.
- `Library Search Paths`: directory containing the static library.
- `Other Linker Flags`: `-lc++` and the engine library, for example `-lPoolPhysics`.
- `Info.plist`: no special permissions are required for the in-process engine.

No bridging header is required. Objective-C++ files import the C++ headers directly, while UIKit-facing headers expose only Objective-C classes.

Ensure the static library includes the active iOS architectures (`arm64` device and the simulator architecture used by the project). If the library is a prebuilt archive, use an XCFramework when distributing across device and simulator builds.

## View controller wiring

The supplied `ViewController.mm` creates the engine, loads `config.plist` from the application bundle, configures the overlay, and adds it above the main view. It also creates angle and power sliders and sends updates through the engine's serial physics queue.

The overlay defaults to `userInteractionEnabled = NO`, so the application's controls receive touches. A double-tap toggles its visibility.

## Snapshot/threading model

`PhysicsEngine` has:

- A serial Grand Central Dispatch queue for simulations.
- A mutex protecting the simulator pointer and latest snapshot.
- Immutable `ShotResultSnapshot` objects returned to the main/UI thread.

The UI never reads C++ vectors directly. A completed simulation is converted to Foundation arrays on the physics queue and published atomically under the mutex.

## Coordinate mapping

The plist's `mapping` dictionary contains:

- `scaleFactor`: pixels per world unit; `0` automatically fits the table to the view.
- `translationX` and `translationY`: screen-space origin.

The table, pockets, trajectories, and balls all use the same world-to-screen transform.

