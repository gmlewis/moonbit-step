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
| `motion_stack` | Shaft + two full-complement deep-groove bearings + spacer (all analytic surfaces), a rigid sleeve coupling, a flanged bearing housing, a UCP204/UCP205 pillow-block assembly, or a 5-to-8 mm helical beam coupling (`--detail envelope` for the pillow-block boundary). |
| `spring` | Simplified helical compression spring. |
| `bearing` | A deep-groove full-complement ball bearing (grooved rings with retaining shoulders, a full ring of watertight balls, rim and shoulder chamfers), the golden envelope (`--representation envelope`), or the single-solid shielded envelope. |
| `linear_bearing` | LM-series linear bushing envelope or flanged round housing. |
| `stepper_motor` | NEMA 17/23 stepper-motor envelope with mounting holes, pilot, and shaft. |
| `extrusion_hardware` | Extrusion T-nut (M3/M4/M5) or M3 heat-set insert (short/long). |
| `stock_primitive` | EN 10056-style angle section, flat/counterbored/countersunk plates, a bearing-housing plate, a tube-to-V-Slot bracket, the CC BY 4.0 SC8UU rod/bearing block (OCCT-evaluated), or an M3 x 4 heat-set insert boss. |
| `vslot` | OpenBuilds-compatible V-Slot 2020/2040 profile, V-wheel, slot T-nut, joining plate, gusseted corner bracket, and plain/eccentric wheel spacers. |
| `tubing` | EMT cut length, EMT end cap, EMT split clamp, plain shaft collar, or tube mount plate adapter. |
| `idler` | Smooth (toothless) idler with optional annular end flanges. |
| `makerbeam` | MakerBeam 10 x 10 mm extrusion (drawing article 100168), optional outer corner radius. |
| `retaining_ring` | DIN 471 type A external retaining ring, A 10 to A 34. |
| `din472_ring` | DIN 472 internal retaining ring (verified bore table 8 to 40; encoded outlines for 10, 12, 14, 16, 18, 20, 24, 28, 32, and 40 mm; the eight FreeCAD-derived sizes carry real evaluated 45° edge chamfers). |
| `set_screw_collar` | Set-screw shaft collar with a real trimmed radial hole and a DIN 916 set-screw envelope, exported as one OCCT-evaluated compound. |
| `clamp_shaft_collar` | One-piece clamp shaft collar with a real slit, clamp-screw clearance passage, and ISO 4762 head counterbore, plus an ISO 4762 clamp-screw envelope, exported as an OCCT-evaluated compound. |
| `filleted_shaft` | Single-solid stepped shaft with toroidal shoulder fillets. |
| `keyed_shaft` | Shaft with a real rectangular keyway plus the matching key. |
| `bolted_joint` | Two plates clamped by a screw, washer, and nut. |
| `mate_assembly` | A screw placed in a nut by named `MateConnector`/`MatePair` records. |
| `revolution` | Analytic solids of revolution (cylinder, cone, sphere, torus, ring, dome, frustum). |
| `rivet` | Generic solid rivet (flat cylindrical head plus straight shank). |
| `mechanism_kit` | One generic mechanism/structural envelope per `--part`: hinge, clevis, pin, linkage, rail, carriage, lead-screw, lead-nut, belt, cam, roller, oldham, extension-spring, torsion-spring, snap, o-ring, grooved-shaft, bracket, boss, or rack. |
| `mechanism_design` | Design-from-scratch linkage built with the typed `ParamSpec`/`ParamSet`/`DesignFamily` API and the `@cad` primitive DSL, with `compact`/`long` variants, a base plate, and pivot pins. |

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

## Iterating a design in SolidCraft (`--view`)

The intended loop is **author → export STEP → open in SolidCraft → resolve →
iterate**. The repository authors nominal, deterministic geometry; SolidCraft
is the engine that resolves real booleans, fillets, chamfers, and imported
vendor parts. See [`docs/boundaries.md`](../../docs/boundaries.md) for the tier
boundary.

```bash
# 1. Author and validate with the headless path (agents always use this).
./run-example.sh --headless mechanism_design --length 140 --width 24 --pivot 8 \
  -o /tmp/linkage.step
python3 scripts/validate_step.py --no-mesh /tmp/linkage.step

# 2. Open the part in SolidCraft (owner).
./run-example.sh mechanism_design --length 140 --width 24 --pivot 8 --view

# 3. Inspect connectors. The sidecar is metadata only.
STEP_CONNECTOR_SIDECAR=1 moon run components/examples/mechanism_kit -- \
  --part oldham -o /tmp/oldham.step
cat /tmp/oldham.step.connectors.tsv

# 4. Change parameters, regenerate to /tmp, and reopen. Do not edit the
#    generated STEP by hand; keep the parametric source authoritative.
./run-example.sh mechanism_design --variant compact --view
```

Inside SolidCraft:

- Apply booleans where the flat STEP preserves nominal intent. The flat writer
  concatenates faces; SolidCraft trims them.
- Add fillets and chamfers, and import licensed vendor parts, in the engine.
- Export the resolved model from SolidCraft when downstream work needs a single
  trimmed manifold.
- Connector frames appear as named `joint.origin` markers
  (`connector/<name>`). They are application features, not geometry: they never
  change the STEP, volume, bounding box, or layer count. Use `--no-connectors`
  to suppress them.

`docs/boundaries.md` also documents how imported vendor parts are referenced
through SolidCraft. This repository has no STEP importer by design.
