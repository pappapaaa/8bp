# Trajectory overlay build and protocol

## Linux

Install GLFW 3.x and OpenGL development packages, then build:

```bash
cmake -S . -B build -DPOOL_BUILD_OVERLAY=ON
cmake --build build --target trajectory_overlay -j
./build/trajectory_overlay --config overlay_config.json --pipe /tmp/trajectory_pipe
```

The endpoint is a Unix-domain stream socket. The producer sends one complete JSON object per line. The overlay reconnects automatically if the producer restarts.

## Windows

Install GLFW 3.x and an OpenGL development toolchain, then configure from a Visual Studio developer prompt:

```powershell
cmake -S . -B build -DPOOL_BUILD_OVERLAY=ON
cmake --build build --config Release --target trajectory_overlay
build\Release\trajectory_overlay.exe --config overlay_config.json --pipe "\\.\pipe\trajectory"
```

The Windows endpoint is a byte-mode named pipe. The overlay reconnects automatically when the pipe is unavailable.

## Controls

- `R`: reload `overlay_config.json`.
- `T`: toggle click-through on Windows. Linux keeps the window interactive because compositor-specific input-region APIs differ.

## Producer message

Send newline-delimited JSON matching the simulator shape. `positions` is the polyline drawn for each ball; `predictedPosition` is the displayed ball location; `shotState` controls the green/red status indicator; and `pocketStatus` controls the small indicators in the configured pockets.
