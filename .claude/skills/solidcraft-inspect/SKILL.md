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

## Who drives SolidCraft

- **You (the agent)**: use the headless `mcp__solidcraft__*` tools. Do not open
  or raise the GUI, do not use `--view` or `open -a SolidCraft`, and never
  pretend a headless render is what the user sees in their window.
- **The user**: runs `./run-example.sh <example> --view` (or opens the STEP in
  SolidCraft) to review the part interactively. Tell them when the model is
  ready for that; they will orbit and zoom freely.

## Headless inspection recipe (agents)

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

- Crop and zoom reference photos before judging; photographs are rarely
  orthographic, so trust **counts and topology** (number of windows, holes,
  spokes, connector positions) over measured angles.
- Fix the silhouette and the largest surfaces first, then medium features
  (windows, plates), then small ones (fasteners, slots, screws).
- Keep changes parametric; do not hard-code measured pixel ratios.
- When the golden reference is itself wrong, keep the standard-correct model
  and record the deviation (see the `compare-golden` skill).

## Connector sidecars

`./run-example.sh <example> --headless` writes `<step>.connectors.tsv` next to
the STEP (name, origin, axis, secondary axis, kind, gender, diameter, depth).
The GUI shows these as named joint origins. After touching connectors, check
the sidecar: kinds are `cylindrical-shaft` (male), `cylindrical-bore` (female),
`plane-face` (neutral); axes are outward approach directions (a bore's axis
points out of the bore opening). All motors and sub-assemblies in this repo
follow that convention.

## Acceptance checklist

1. `scripts/validate_step.py <file.step>` passes (checkshape authoritative).
2. SolidCraft renders show the intended silhouette, feature counts, and colors
   from at least three angles including each functional face.
3. The user can run `./run-example.sh <example> --view` to review interactively.
4. You report which angles you inspected and what you changed — never "looks
   good" without saying how you looked.
