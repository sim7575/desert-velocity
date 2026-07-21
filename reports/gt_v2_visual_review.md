# Bavarian GT-R V2 — manual visual approval gate

Status: isolated Blender and Godot visual prototype. Not integrated into gameplay.

## Verified asset data

- Body dimensions: 4.680 m long, 2.000 m wide, 1.350 m high.
- Wheelbase: 2.860 m.
- Triangles: 38,050.
- Mesh objects after material consolidation: 27, including the separate collision proxy.
- Materials: 12.
- Wheel pivots: `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`.
- Original 1024×1024 textures: base color, roughness, dirt, scratches, paint variation, carbon and livery.
- GLB has no external runtime dependency.

## V1–V2 comparison

| Area | V1 | V2 |
| --- | --- | --- |
| Silhouette | long box-like hood and disconnected greenhouse | lower technical coupe stance, shorter tail and stronger shoulder line |
| Sides | mostly flat panels | inset doors, modeled shoulders, tension line, sill and fender vents |
| Roof | flat slab | tapered roof, A/B/C pillars, roof scoop and inclined glazing |
| Front | applied rectangular lamps and loose round lights | recessed light housings, original LED signature, cooling openings and integrated lamp bridge |
| Rear | simple block volume | black graphic panel, integrated tail signatures, twin exhaust, tow hook and multi-fin diffuser |
| Wheels | road-like low-detail wheels | wide gravel tires, 28 tread blocks, ten-spoke rims, discs, hubs and calipers |
| Aero | simple wing and splitter | supported wing with endplates, deeper splitter, skirts, diffuser and fender vents |
| Materials | 10 mostly flat materials | 12 differentiated materials with textured paint and controlled roughness |
| Detail | 20,606 triangles | 38,050 triangles used on visible rally and surfacing detail |

The difference is substantial rather than marginal. V2 remains deliberately isolated pending manual approval.

## Residual limits

- The modeling language remains angular and stylized; panel curvature is improved but not photorealistic.
- The livery texture exists and the side graphic follows the shoulder, but UV treatment can be refined further.
- The Blender desert background is a review set only and does not alter the gameplay environment.
- Godot headless uses a dummy renderer on this machine, so final material appearance must also be reviewed in a graphical GL Compatibility session.

## Screenshots

Twelve neutral and five desert renders are stored in `screenshots/gt_v2/`, numbered `01` through `17`.
