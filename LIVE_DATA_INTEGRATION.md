# Live data adapter

The iOS overlay now supports two data sources selected by `config.plist`:

- `LiveData.enabled = false`: the existing `PhysicsEngine` drives the overlay.
- `LiveData.enabled = true`: `LiveDataAdapter` reads the shared-memory frame and the drawing layer remains unchanged.

## Shared-memory protocol

`SharedMemoryWriter.h` is the protocol definition shared by the producer and reader. The fixed frame contains:

- Magic and version fields.
- A seqlock sequence number.
- Nanosecond timestamp.
- Up to 16 balls.
- Up to 480 positions per ball in the default 64 KB frame.
- Predicted positions and on-table flags.
- Six pocket-status bytes.
- Shot-state byte.

The writer publishes an odd sequence before copying and an even sequence after copying. The reader copies only when the sequence is even and unchanged before and after the copy. This prevents the UI from observing a partially written frame without requiring a process-shared mutex.

## Producer usage

```cpp
#include "SharedMemoryWriter.h"

PoolLive::SharedMemoryWriter writer("/pool_trajectory_live");
if (writer.open()) {
    PoolLive::TrajectoryFrame frame{};
    frame.magic = PoolLive::kMagic;
    frame.version = PoolLive::kVersion;
    frame.ballCount = 1;
    frame.positionCounts[0] = 2;
    frame.positions[0][0][0] = 25.0f;
    frame.positions[0][0][1] = 25.0f;
    frame.positions[0][1][0] = 40.0f;
    frame.positions[0][1][1] = 25.0f;
    frame.predictedPositions[0][0] = 40.0f;
    frame.predictedPositions[0][1] = 25.0f;
    frame.onTable[0] = 1;
    frame.shotState = 1;
    writer.writeFrame(frame);
}
```

The iOS reader uses `shm_open` and `mmap` with the configured name. The reader retains the last valid snapshot. Before the first valid frame it returns an empty snapshot, so the overlay draws only its configured table layer and status state.

## Xcode integration

Add these files to the app target:

- `LiveDataAdapter.h/.mm`
- `SharedMemoryWriter.h/.cpp` for producer targets only
- The previously added snapshot and overlay files

Compile the Objective-C++ files as Objective-C++, use C++17 and `libc++`, and include the directory containing `PhysicsSimulator.h` and `Prediction.h`.

Set the plist section like this:

```xml
<key>LiveData</key>
<dict>
    <key>enabled</key><true/>
    <key>sharedMemoryName</key><string>/pool_trajectory_live</string>
    <key>bufferSize</key><integer>65536</integer>
</dict>
```

Set `enabled` to `false` to return to simulated mode. The overlay view's rendering code is the same in both modes.
