# Reference inspection notes

The supplied IPA was inspected as an archive only. The bundle contains:

- `tableBase*.png/.plist` with table-hole, corner-hole, center-hole, and table-line assets.
- `tableCushions*.png/.plist` with separate top/side rebound regions.
- `ball0` through `ball15` assets plus `ball1000/1001` variants.
- Distinct sound assets for weak/strong cue collisions and cushion collisions.
- `GamePowerGauge`, spin-wheel, and cue-related UI resources.

No readable physics source implementation was present in the bundle inventory. The standalone harness therefore uses the reference asset organization as a geometry/modeling guide while keeping all simulation code independent of the app bundle. Table coordinates are normalized to the configured `width` and `height`, with ball radius, pocket radius, cushion restitution, rolling drag, collision events, spin curvature, and deterministic sampling exposed in the native simulator.

