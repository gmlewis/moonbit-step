# Component Examples

Each directory is a MoonBit executable that parses parameters and writes STEP.
All programs use millimetres and Z is up.

| Program | What it generates |
|---|---|
| `fasteners` | One metric fastener (`--standard iso4762`, `din916`, …), or the built-in M3/M4/M5 catalog. |
| `profile_extrusion` | One extrusion profile section (`2020-b-slot6-a`), P1000-style strut channel, or a generic channel nut. |
| `hardware_kit` | ISO 4762 screw + ISO 7089 washer + ISO 4032 nut. |
| `extrusion_frame` | Generic T-slot rectangular frame with optional SVG views. |
| `gear_pair` | Two involute spur gears with centre distance and phase. |
| `planetary` | Sun + equally spaced planets + exact internal involute ring, extruded as one exact line/arc solid (smooth cylindrical tooth walls). |
| `motion_stack` | Shaft + two full-complement deep-groove bearings + spacer (all analytic surfaces), a rigid sleeve coupling, or a flanged bearing housing. |
| `spring` | Simplified helical compression spring. |
| `bearing` | A deep-groove full-complement ball bearing (grooved rings with retaining shoulders, a full ring of watertight balls, rim and shoulder chamfers), the golden envelope (`--representation envelope`), or the single-solid shielded envelope. |
| `linear_bearing` | LM-series linear bushing envelope or flanged round housing. |
| `stepper_motor` | NEMA 17/23 stepper-motor envelope with mounting holes, pilot, and shaft. |
| `extrusion_hardware` | Extrusion T-nut (M3/M4/M5) or M3 heat-set insert (short/long). |
| `stock_primitive` | EN 10056-style angle section, a flat plate blank, a counterbored or countersunk plate, a bearing-housing plate, or a tube-to-V-Slot bracket. |
| `vslot` | OpenBuilds-compatible V-Slot 2020/2040 profile, V-wheel, slot T-nut, joining plate, gusseted corner bracket, and plain/eccentric wheel spacers. |
| `tubing` | EMT cut length, EMT end cap, EMT split clamp, plain shaft collar, or tube mount plate adapter. |
| `idler` | Smooth (toothless) idler with optional annular end flanges. |
| `makerbeam` | MakerBeam 10 x 10 mm extrusion (drawing article 100168), optional outer corner radius. |
| `retaining_ring` | DIN 471 type A external retaining ring, A 10 to A 34. |
| `din472_ring` | DIN 472 internal retaining ring (verified bore table 8 to 40; encoded outlines 12 and 20). |
| `set_screw_collar` | Set-screw shaft collar with a real trimmed radial hole and a DIN 916 set-screw envelope, exported as one OCCT-evaluated compound. |
| `clamp_shaft_collar` | One-piece clamp shaft collar with a real slit, clamp-screw clearance passage, and ISO 4762 head counterbore, plus an ISO 4762 clamp-screw envelope, exported as an OCCT-evaluated compound. |
| `filleted_shaft` | Single-solid stepped shaft with toroidal shoulder fillets. |
| `keyed_shaft` | Shaft with a real rectangular keyway plus the matching key. |
| `bolted_joint` | Two plates clamped by a screw, washer, and nut. |
| `mate_assembly` | A screw placed in a nut by named `MateConnector`/`MatePair` records. |
| `revolution` | Analytic solids of revolution (cylinder, cone, sphere, torus, ring, dome, frustum). |
| `rivet` | Generic solid rivet (flat cylindrical head plus straight shank). |

Run `./generate_all.sh` from this directory to regenerate every fixture in
`output/`. The `output/` directory is generated locally and Git-ignored; its
STEP, SVG, and assembly files are never committed to the repository.

## Preview in SolidCraft without leaving files in the repository

```bash
./run-example.sh 1 --view
```

`--view` writes the STEP to `/tmp/<example>.step` and opens it in SolidCraft. If
`-o` is supplied, that path is opened instead. The flag is available in the
`gmlewis/step`, `gmlewis/urdf`, and `gmlewis/cad` example launchers.
