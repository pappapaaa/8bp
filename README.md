# Pool Physics Sandbox

Standalone C++17 harness for deterministic pool-shot simulation. It has no game-client, process-memory, or platform-specific dependencies.

## Build

```powershell
cmake -S . -B build
cmake --build build --config Release
```

Headless single shot:

```powershell
build\Release\pool_sandbox.exe --config config.json --headless --output result.json
```

Batch run:

```powershell
build\Release\pool_sandbox.exe --config config.json --random 1000 --output batch.json
```

The batch seed is fixed to `12345` for reproducibility. The simulator uses a fixed integration step, elastic equal-mass ball collisions, cushion restitution, rolling drag, spin-induced lateral curvature, and pocket capture.

For the optional SFML window, install SFML 2.5+ and configure with `-DPOOL_ENABLE_SFML=ON`. Left-click on the table to aim from the cue ball; click distance controls power. Without SFML, `--ui` prints a compact trajectory preview.
