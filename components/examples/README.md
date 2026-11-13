# Component Examples

Each directory is a MoonBit executable that parses parameters and writes STEP.
All programs use millimetres and Z is up.

| Program | What it generates |
|---|---|
| `fasteners` | One metric fastener (`--standard iso4762`, `din916`, …), or the built-in M3/M4/M5 catalog. |
| `profile_extrusion` | One extrusion profile section (`2020-b-slot6-a`). |
| `hardware_kit` | ISO 4762 screw + ISO 7089 washer + ISO 4032 nut. |
| `extrusion_frame` | Generic T-slot rectangular frame with optional SVG views. |
| `gear_pair` | Two involute spur gears with centre distance and phase. |
| `planetary` | Sun + equally spaced planets + exact internal involute ring. |
| `motion_stack` | Shaft + two simplified bearings + spacer. |
| `spring` | Simplified helical compression spring. |
| `bearing` | One detailed bearing envelope. |
| `linear_bearing` | LM-series linear bushing envelope or flanged round housing. |
| `stepper_motor` | NEMA 17/23 stepper-motor envelope with mounting holes, pilot, and shaft. |
| `extrusion_hardware` | Extrusion T-nut (M3/M4/M5) or M3 heat-set insert (short/long). |
| `stock_primitive` | EN 10056-style angle section or a flat plate blank. |
| `filleted_shaft` | Single-solid stepped shaft with toroidal shoulder fillets. |
| `keyed_shaft` | Shaft with a real rectangular keyway plus the matching key. |
| `bolted_joint` | Two plates clamped by a screw, washer, and nut. |
| `mate_assembly` | A screw placed in a nut by named `MateConnector`/`MatePair` records. |
| `revolution` | Analytic solids of revolution (cylinder, cone, sphere, torus, ring, dome, frustum). |

Run `./generate_all.sh` from this directory to regenerate every fixture in
`output/`.
