# Bavarian GT-R V1 — visual review gate

Status: isolated Blender/Godot visual prototype. It is not referenced by `VehicleFactory` and is not integrated into gameplay.

## Asset metrics

- Overall dimensions: 4.620 m long, 1.960 m wide, 1.360 m high.
- Wheelbase: 2.850 m.
- Rendered triangles: 20,606.
- Materials: 10 shared materials.
- Animated pivots retained: `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`.
- Simplified non-rendering collision proxy is separate, but no gameplay collision was changed.
- External dependencies: none.

The triangle count is below the indicative 25,000–40,000 target. This is accepted only for the V1 review gate and must not be presented as final quality.

## Visual assessment

The V1 establishes the requested compact modern GT proportions, low roof, advanced cabin, wide arches, splitter, diffuser, wing, mudflaps, auxiliary lights and roll bar. The Blender renders are reproducible with `render_bavarian_gt_v1.py`.

Before gameplay integration, a V2 should improve side surfacing, roof/windshield transitions, lamp housings, air intakes, rear volume, wheel detail and material variation. The current desert set in the ambient screenshots is a review backdrop, not the environment V2 requested for gameplay.

## Review images

- `screenshots/gt_v1/gt_neutral_front.png`
- `screenshots/gt_v1/gt_neutral_rear.png`
- `screenshots/gt_v1/gt_ambient_front.png`
- `screenshots/gt_v1/gt_ambient_wide.png`

## Manual gate

Do not connect `bavarian_gt_r_v1.glb` to `VehicleFactory` until explicit visual approval. Open `VisualPrototypeGT.tscn` in a graphical Godot session for the engine-side material/import check; the automated headless renderer exposes no viewport texture on this system.
