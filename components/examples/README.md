# Component Examples

Each directory is a MoonBit executable that parses parameters and writes STEP.

| Program | What it generates |
|---|---|
| `fasteners` | One metric fastener, or the built-in M3/M4/M5 catalog. |
| `hardware_kit` | ISO 4762 screw + ISO 7089 washer + ISO 4032 nut. |
| `extrusion_frame` | Generic T-slot rectangular frame, optional SVG views, and the three audited frame sizes. |
| `gear_pair` | Two involute spur gears with centre distance and phase. |
| `planetary` | Sun + equally spaced planets + approximate internal ring. |
| `motion_stack` | Shaft + two simplified bearings + spacer. |
| `spring` | Simplified helical compression spring. |

Run `./generate_all.sh` from this directory to regenerate every fixture in
`output/` and validate the flat exports with the repository gate.

All programs use millimetres and the Z-up component conventions documented in
`../GEOMETRY.md`.
