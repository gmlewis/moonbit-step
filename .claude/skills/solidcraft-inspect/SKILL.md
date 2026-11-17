---
name: solidcraft-inspect
description: Inspect generated CAD geometry in SolidCraft instead of trusting OCCT/DrawEXE four-view PNGs. Use whenever you need to judge how a part actually looks, when fixing models to match photos or drawings, or before telling the user to run ./run-example.sh <example> --view.
---

# Inspect geometry in SolidCraft, not in four-pane OCCT renders

## The rule

`scripts/render_step.py` and `./run-example.sh <example> --png` produce a
four-view PNG from OCCT `DRAWEXE`. It is a smoke test ("did it render at all?"),
**never** acceptance evidence and never a basis for visual judgments. It has no
real shading, hides small features, and misrepresents curved/silhouette detail.
When you need to judge whether geometry looks right — silhouette, window and
slot shapes, feature scale, connector placement, color intent — inspect it in
SolidCraft, which renders lit, shaded views from any angle.

If the user asks you to "look at" or "fix how it looks", they mean SolidCraft.
Never justify keeping a wrong-looking model because "the 4-pane looks fine".

## No single-view acceptance

An isometric view is for **orientation only**. It hides gaps, half-size
offsets, detached layers, and interpenetration, and it is the worst possible
basis for a "looks right" judgment. A four-quadrant OCCT render is even worse:
treat it as worthless for geometry.

Never accept, report, or hand off a model after one iso render. The minimum
inspection set for any changed part is:

- **Six orthographic views**: front, back, left, right, top, bottom (or the
  functional equivalents for the part). These expose silhouette, symmetry,
  hole spacing, and gaps.
- **One 3/4 view from each functional side**, for context.
- **Close-ups** of every feature you changed or that carries the function.
- **A numeric layer-connection check**: use `measure` / `body_topology` and
  confirm that adjacent layer bounding boxes actually overlap. A rendered gap
  is a real gap; do not argue it away.
- For flat plates, straps, and webs: remember that the repo's `@cad.Cuboid` is
  **corner-anchored at the local origin**, not centered. A placement at the
  desired center shifts the body by half its size. Verify bboxes after every
  cuboid placement.

If you cannot name the views you inspected, you have not inspected the model.

## Who drives SolidCraft

- **You (the agent)**: use the headless `mcp__solidcraft__*` tools **or**
  `solidcraft-cli snapshot` / `solidcraft-cli eval` directly. Do not open or
  raise the GUI, do not use `--view` or `open -a SolidCraft`, and never pretend
  a headless render is what the user sees in their window.
- **The user**: runs `./run-example.sh <example> --view` (or opens the STEP in
  SolidCraft) to review the part interactively. Tell them when the model is
  ready for that; they will orbit and zoom freely.

## Headless inspection recipe (agents)

### Option A — via `mcp__solidcraft__*`

1. Generate the STEP under an allowed root. The headless server refuses other
   paths: use the repo's ignored scratch space (`target/`, or
   `components/examples/output/` in moonbit-17-step). `/tmp` is not allowed.
2. `mcp__solidcraft__open` with `up: "z"` (STEP written by this toolchain is
   Z-up). This **replaces** the in-memory design; check `errors` in the reply
   and note `content_sha256`.
3. `mcp__solidcraft__screenshot` with `source: "model"` and an explicit
   `camera` (`{target, yaw, pitch, distance}`, radians/mm) or a named `view`
   (`iso`, `front`, `top`, ...). Set `grid: false, axes: false` for clean
   images. Pass `path` to keep the PNG under an allowed root.
4. Take several angles, not one: an isometric 3/4 view, straight-on shots of
   every functional face (e.g. prop side and mount side of a motor), and
   close-ups of the changed features. `mcp__solidcraft__screenshot` accepts
   `view` or `camera`; there is no "default good angle", so iterate.
5. Iterate: edit the generator → regenerate → `open` again (the in-memory
   design is replaced) → re-screenshot. A render from a stale open shows the old
   model.
6. Cross-check facts with `inspect_design` / `measure` (bodies, joints) and
   `scripts/validate_step.py` for validity. The render is for looks; the
   validators are the acceptance criteria.

### Option B — via `solidcraft-cli` (when MCP tools are not wired in)

`solidcraft-cli` renders shaded PNGs and inspects geometry headlessly without
opening a window or requiring MCP bindings:

```bash
solidcraft-cli snapshot --in target/part.step --out target/left.png \
  --view left --no-grid --no-axes --width 1024 --height 1024
solidcraft-cli snapshot --in target/part.step --out target/right.png \
  --view right --no-grid --no-axes --width 1024 --height 1024
solidcraft-cli snapshot --in target/part.step --out target/front.png \
  --view front --no-grid --no-axes --width 1024 --height 1024
solidcraft-cli snapshot --in target/part.step --out target/rotor_iso.png \
  --camera '{"target":[12,0,0],"yaw":-2.3,"pitch":0.4,"distance":175}' \
  --no-grid --no-axes --width 1024 --height 1024
solidcraft-cli eval --in target/part.step
```

Always inspect **both** opposite functional faces (e.g., `left` and `right`
along ±X), the side silhouette (`front`), and at least one 3/4 view per side
using `read_file` on the PNGs, then delete scratch PNGs/STEPs when done.

Notes:

- The GUI app and the headless server are separate processes. Your headless
  screenshots never appear on the user's screen; `source: "window"` only works
  against a connected app and shows *their* tab, so prefer `model` renders.
- The GUI caps open designs (~32); irrelevant headless, but do not open tabs on
  the user's behalf.
- STEP import may warn "imported as an open body"; that is often benign —
  confirm with `scripts/validate_step.py` (OCCT `checkshape` is the authority).
  The validator's optional tessellation watertight check is known to be noisy
  on these parts and may fail on a good model.
- Connector axes/genders are invisible in a render; verify them in the emitted
  sidecar (below) and tests, not by eye.

## Comparing against photos or a golden part

- **Calibrate and overlay before editing.** Never eyeball feature counts, spoke
  widths, or window radii from raw photos alone:
  1. Crop and zoom every reference photo (front, rear, side, and oblique views).
  2. Anchor pixel scale (`px/mm`) on a straight-on photo or an un-foreshortened
     axis using known physical datums (outer OD, standard bearing OD such as
     `6901Z` = 12 × 24 × 6 mm, or known bolt-circle diameters).
  3. Draw concentric millimeter rings, angular protractors, and candidate
     window/slot contours onto a scratch copy of the photo (in `target/` or
     `/tmp/`) and view the overlay image to verify radii and angles to ~0.5 mm /
     ~1° before writing CAD code.
- **Verify pattern symmetry, alternation, and nested rings.** Do not assume all
  spokes or slots are identical or single-ring: check whether spokes alternate
  (e.g., 3 solid + 3 forked/slotted spokes on a 6-spoke rotor bell) and look for
  concentric inner hub slots inside raised bosses in addition to outer cooling
  windows.
- **Check what is visible through air gaps and at perimeters.** Verify that
  windings sit inside pole-shoe tips so stator teeth remain visible, bearing
  rings match standard ODs and metallic finishes, insulator rings sit on the
  correct axial side, and side silhouettes capture stepped mount flanges.
- **Separate open mounting holes from screw-filled holes.** Only open
  user-facing mounting holes expose `MateConnector`s. Holes already occupied by
  retaining screws (such as prop-adapter cap screws) should visibly contain the
  fastener solids and must **not** emit mate connectors.
- **Check spoke-hole clearance in 2D, not 1D.** When mounting holes lie on the
  spokes between cooling windows, they are separated *angularly* from the
  windows. Never enforce a 1D radial inequality (`hole_outer_r < win_inner_r`)
  that forces windows artificially outward and makes spokes overly wide; check
  2D hole-to-sector clearance instead so air gaps can reach inward alongside the
  spokes.
- Fix the silhouette and the largest surfaces first, then medium features
  (windows, plates), then small ones (fasteners, slots, screws).
- Keep changes parametric; derive secondary features (such as spoke fork-slot
  radial bounds) from the spec so scaled-down presets remain valid.
- When the golden reference is itself wrong, keep the standard-correct model
  and record the deviation (see the `compare-golden` skill).

## Connector sidecars

`./run-example.sh <example> --headless` writes `<step>.connectors.tsv` next to
the STEP (name, origin, axis, secondary axis, kind, gender, diameter, depth).
The GUI shows these as named joint origins. After touching connectors, check
the sidecar alongside the straight-on SolidCraft renders: kinds are
`cylindrical-shaft` (male), `cylindrical-bore` (female), `plane-face`
(neutral); axes are outward approach directions (a bore's axis points out of
the bore opening). Verify that hole connectors sit solidly on open mounting
holes or spokes — never inside air gaps or screw-filled counterbores. All
motors and sub-assemblies in this repo follow that convention.

## Acceptance checklist

1. `scripts/validate_step.py <file.step>` passes (checkshape authoritative).
2. SolidCraft renders show the intended silhouette, feature counts, and colors
   from the full orthographic set (front/back/left/right/top/bottom or the
   functional equivalents), a 3/4 view from each functional side, and close-ups
   of every changed feature. A single iso render is **not** acceptance evidence.
3. `measure` / `body_topology` confirms adjacent layers overlap; no detached
   webs, straps, bosses, or sockets.
4. The user can run `./run-example.sh <example> --view` to review interactively.
5. You report which views you inspected and what you changed — never "looks
   good" without saying how you looked.
