# Generated STEP fixtures

These files are deterministic outputs of the example programs in
`components/examples/`. Regenerate them with the commands in each example's
source comments or with:

```bash
# Regenerate everything, including the audited frame sizes and SVG views:
./components/examples/generate_all.sh

# Or generate one file at a time:
moon run components/examples/fasteners -- \
  --catalog components/examples/output
moon run components/examples/hardware_kit -- \
  --size M4 --length 20 -o components/examples/output/kit-M4x20-flat.step
moon run components/examples/extrusion_frame -- \
  --width 400 --depth 300 --height 500 --series 2020 \
  -o components/examples/output/frame-2020-400x300x500.step \
  --views components/examples/output/views
moon run components/examples/gear_pair -- \
  --module 2 --teeth 20 --mateTeeth 40 \
  -o components/examples/output/gear-pair-m2-20x40.step
moon run components/examples/planetary -- \
  -o components/examples/output/planetary-m2-s12-p12-r36-3.step
moon run components/examples/motion_stack -- \
  --bearing 608 -o components/examples/output/motion-608-stack.step
```

Geometry is deterministic; the STEP header timestamp changes between runs, so
byte-for-byte equality is not expected.

Validate a file with the repository gate:

```bash
python3 scripts/validate_step.py components/examples/output/iso4762-M4x20.step
python3 scripts/validate_frame_geometry.py \
  components/examples/output/frame-2020-400x300x500.step \
  --width 400 --depth 300 --height 500 --series 2020
```

All flat-part and flat-assembly fixtures pass the full gate (syntax,
references, shell topology, orientation, planarity, OCCT `checkshape`, and
watertight tessellation). `assembly-structure/kit-M4x20-assembly.step` is the
STEP product/occurrence representation and passes everything except the OCCT
single-shape `checkshape` stage; see `components/KNOWN_ISSUES.md`.

Additional feature-session artifacts (all validated by `generate_all.sh`):

- `bearing-608-detailed.step` — single 608 bearing envelope with analytic
  spheres and ring chamfers.
- `bolted-joint-M4-2x5.step` — two plates, screw, washer, and nut (7 watertight
  solids).
- `gear-pair-m2-20x40-filleted.step` — involute pair with root fillets and tip
  chamfers.
- `frame-2020-200x200x200-rounded.step` — 2020 frame with 1.5 mm outer corner
  radii (measured post section area 190.37 mm²).

