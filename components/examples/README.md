# Component Examples

Each directory is a MoonBit executable that parses parameters and writes STEP.
All programs use millimetres and Z is up.

| Program | What it generates |
|---|---|
| `fasteners` | One metric fastener (`--standard iso4762`, `din916`, …), or the built-in M3/M4/M5 catalog. |
| `profile_extrusion` | One extrusion profile section (`2020-b-slot6-a`), P1000-style strut channel, or a generic channel nut. |
| `hardware_kit` | ISO 4762 screw + ISO 7089 washer + ISO 4032 nut. |
| `extrusion_frame` | Generic T-slot rectangular frame with optional SVG views. |
| `gear_pair` | Two involute spur gears with centre distance and phase; smooth arc-run extrusions by default, `--detailed` for the faceted involute pair. |
| `bevel_gear` | External straight bevel gear from a mate tooth count and shaft angle (or an explicit pitch angle): Tredgold back-cone tooth sector with standard back-cone tooth ends (`--endFace backCone`, default; `flat` for the larger flat-back variant), optional analytic bore, optional back-cone root fillet (`--rootFillet`, flat end only), optional tip chamfer (`--tipChamfer`, both end faces), and an optional backing/hub (`--hubDiameter`/`--hubLength`). `--pair` writes the driver and mate in the meshing pose. Static geometry; the exact octoid/spherical involute is not modelled. |
| `planetary` | Sun + equally spaced planets + exact internal involute ring, extruded as one exact line/arc solid (smooth cylindrical tooth walls). |
| `motion_stack` | Shaft + two full-complement deep-groove bearings + spacer (all analytic surfaces), a rigid sleeve coupling, a flanged bearing housing, a UCP204/UCP205 pillow-block assembly, a 5-to-8 mm helical beam coupling (`--detail envelope` for the pillow-block boundary), or a smooth flanged idler (`--part idler`). |
| `spring` | Simplified helical compression spring; smooth B-spline side surfaces and a 36-segment wire by default, `--detailed` for the faceted 12-gon sweep. |
| `bearing` | A deep-groove full-complement ball bearing (grooved rings with retaining shoulders, a full ring of watertight balls, rim and shoulder chamfers), the golden envelope (`--representation envelope`), or the single-solid shielded envelope. |
| `linear_bearing` | LM-series linear bushing envelope or flanged round housing. |
| `stepper_motor` | NEMA 17/23 stepper-motor envelope with mounting holes, pilot, and shaft. |
| `brushless_motor` | Parameterized outrunner brushless-motor envelope with a conical 5-spoke bell, windows, rim and lip, stator hub, prop and mount holes, and a through shaft; defaults measured from the owner-authored 360KV model. |
| `a12_motor` | Parameterized XAIRCRAFT A12 8318 outrunner motor envelope: 6-spoke bell with 3 alternating forked spokes and 4 inner hub slots, 42 curved rotor magnets, machined prop adapter, 36-slot stator with pole shoes and copper frames, stepped 8-window mount plate with interleaved M3/M4 circles on the spokes, 6901Z bearing tube, insulator ring, and through shaft; defaults measured from the motor (91 mm bell, 33 mm height, 23/30/32 mm bolt circles, 83 x 18 mm stator). |
| `tire` | Parameterized wheel/tire envelope with a smooth tire ring, hub tube and bore, 2 mm inset back plate, and straight radial ribs (6 by default); defaults measured from the owner-authored reference. |
| `tire_mount` | Parameterized tire mounting flange with a solid front plate, three bolt holes, rear ring, hub tube and bore, and six 2 mm radial slots; defaults measured from the owner-authored reference. |
| `extrusion_hardware` | Extrusion T-nut (M3/M4/M5) or M3 heat-set insert (short/long). |
| `stock_primitive` | EN 10056-style angle section, flat/counterbored/countersunk plates, a bearing-housing plate, a tube-to-V-Slot bracket, the CC BY 4.0 SC8UU rod/bearing block (OCCT-evaluated), or an M3 x 4 heat-set insert boss. |
| `vslot` | OpenBuilds-compatible V-Slot 2020/2040 profile, V-wheel, slot T-nut, joining plate, gusseted corner bracket, C-Beam gantry plate (`--part gantry-plate`), and plain/eccentric wheel spacers. |
| `makerstore_l_plate` | Maker Store 20-series L plate / bracket with a centred hole grid on both legs: `l40x40` (`PLATE-40X40L`, 3×3 Ø5 on 10 mm centres) or `l40x80` (`PLATE-40X80L`). |
| `makerstore_hardware` | One Maker Store USA part per `--part`: metric aluminum spacer (`SHIM-SPAC`, OD 10 / ID 5), thrust bearing (`BEAR-F`), 20-series hex T-nut (`HARD-TNUT-SLIDING`), 40-series sliding block T-nut (`HARD-40S-TNUT-STEEL-SLID-18`), or gusseted V-Slot corner bracket (`BRAC-90CAST` / `BRAC-40S`). |
| `gobilda_kit` | goBILDA® parts: a grid plate (`--cols` × `--rows`), the 1120-series U-channel (`--part channel --holes`), the 1106-series square beam (`--part beam --beamHoles`), or the 1309 Sonic hub (`--part hub`). |
| `mot_edis` | MotEDis I-type metric T-slot: a profile (`--series 20/30/40 --length`) or a T-nut (`--part tnut --series 40 --thread M5`). The profile's four T-slots are a nominal difference (kernel-trimmed). |
| `tubing` | EMT cut length, EMT end cap, EMT split clamp, plain shaft collar, or tube mount plate adapter. |
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
| `mechanism_kit` | One generic mechanism/structural envelope per `--part`: hinge, clevis, pin, rod-end, linkage, rail, carriage, lead-screw, lead-nut, belt, belt-unequal, cam, roller, oldham, extension-spring, torsion-spring, snap, o-ring, grooved-shaft, bracket, u-bracket, z-bracket, boss, rack, sprocket, or chain-segment. `--evaluated` fuses layers into one OCCT-trimmed manifold. |
| `mechanism_design` | Design-from-scratch linkage built with the typed `ParamSpec`/`ParamSet`/`DesignFamily` API and the `@cad` primitive DSL, with `compact`/`long` variants, a base plate, and pivot pins. |
| `mechanism_assembly` | Clevis + rod end + pin assembled by a named `MatePair` between `eye-seat` and `eye-bore`; checks connectivity and writes either the flat STEP or the product/occurrence structure. |
| `belt_drive` | Two approximate GT2 pulleys plus a smooth belt envelope built from an exact declared pitch length; flat or product-structure output. |
| `rack_pinion` | Basic rack plus an involute spur pinion as one smooth arc-run extrusion at the layout pitch-plane centre distance; static envelope, flat or product-structure output. |
| `four_bar` | Planar four-bar linkage from `four_bar_layout` and the linkage bars, with lower/upper link planes and four dowel pins; flat or product-structure output. |
| `adapters` | Motor-to-extrusion and channel-to-extrusion adapters, plus NEMA mounting plates. |
| `makerpipe_frame` | MakerPipe-based rectangular frame built from named mate connectors. |
| `makerpipe_kit` | Assorted MakerPipe fittings and accessories. |
| `pvc` | PVC pipe, fittings, and frame envelopes. |

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
./run-example.sh mechanism_assembly --view   # clevis + rod end + pin

# 3. Inspect connectors. The sidecar is metadata only.
STEP_CONNECTOR_SIDECAR=1 moon run components/examples/mechanism_kit -- \
  --part oldham -o /tmp/oldham.step
cat /tmp/oldham.step.connectors.tsv

# 4. Change parameters, regenerate to /tmp, and reopen. Do not edit the
#    generated STEP by hand; keep the parametric source authoritative.
./run-example.sh mechanism_design --variant compact --view

# 5. When one trimmed manifold is needed, use the evaluated path.
moon run components/examples/mechanism_kit -- \
  --part hinge --evaluated -o /tmp/hinge-evaluated.step
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
