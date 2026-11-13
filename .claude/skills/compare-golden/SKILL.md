---
name: compare-golden
description: Handle "Please fix ./compare-golden.sh <indices>" by generating the numbered golden/parametric pairs, measuring and visually comparing them, and fixing the parametric geometry until they match.
---

# Fix a `compare-golden.sh` pair

## The phrase

When the user writes:

```text
Please fix ./compare-golden.sh 4
```

they mean:

1. They ran that command.
2. They saw an obvious visual difference between the generated parametric model
   and the golden model in SolidCraft.
3. They want the difference analyzed and the **parametric generator** fixed so
   the pair matches.

The indices are the sorted golden-file indices printed by
`./compare-golden.sh --list`. Never treat the phrase as a request to edit the
golden file.

## Prerequisites

- Work in the repository root
  (`/Users/glenn/src/github.com/gmlewis/moonbit-17-step`).
- The golden corpus lives in `components/testdata/golden/external/`.
- The harness is `./compare-golden.sh` (a repo-root symlink to
  `scripts/compare-golden.sh` is normal and supported).
- `moon`, `python3`, OCCT, and SolidCraft are available. The GUI caps open
  designs at 32; each pair is two tabs, so use `--batch N` for large sets.

## Workflow

1. **Map the index.**

   ```bash
   ./compare-golden.sh --list
   ```

   Record the golden basename, the generated equivalent label, and any
   `note:` the script prints (a representation choice or a golden/standard
   contradiction).

2. **Generate without opening first.**

   ```bash
   ./compare-golden.sh 4 --headless
   ```

   The parametric file is `target/golden-compare/parametric-<golden name>`.
   To see the exact command without running it:

   ```bash
   ./compare-golden.sh --commands 4
   ./compare-golden.sh --commands --all
   ```

3. **Measure both files.** Do not decide from one number.

   ```bash
   python3 scripts/measure_step_occt.py <golden.step>
   python3 scripts/measure_step_occt.py <parametric.step>
   python3 scripts/measure_step_features.py --json <golden.step>
   python3 scripts/measure_step_features.py --json <parametric.step>
   python3 scripts/validate_step.py <parametric.step>
   ```

   Compare, in this order:

   - solid count and closed-shell validity;
   - `surface_counts` (plane / cylinder / cone / sphere / torus / B-spline);
   - bbox and volume;
   - cylinder radii, cone semi-angles, torus major/minor radii, sphere radii;
   - vertex rings at feature planes;
   - section area/perimeter at feature planes (`measure_step_mesh.py`);
   - bidirectional surface deviation where the nominal shapes should match.

4. **Look at the pair.**

   ```bash
   ./compare-golden.sh 4              # opens both with `open -a SolidCraft`
   ./compare-golden.sh 4 --helper     # GUI helper, --up z, no axis dialog
   ```

   Use the headless `mcp__solidcraft__open`/`screenshot` tools for your own
   inspection without disturbing the user's tabs. A visual difference is a
   finding; the numbers are the acceptance criterion.

5. **Diagnose the difference.**

   - **Parametric defect.** The golden and the library's standard geometry are
     consistent, but our feature is wrong or missing. Fix the component or the
     kernel (revolve/cone/torus, round bore, arc extrusion, involute, thread).
     Add or tighten a red test first.
   - **Representation mismatch.** The golden is a different *representation* of
     the same part (for example `*_open_simple` bearings have only two rings and
     no rolling elements, or a `_simple` golden has no thread). Fix the mapping
     in `compare-golden.sh` (`adjust_for_golden`), not the standard geometry.
     The script should generate the golden's declared representation by default
     and still honour an explicit `--detail`.
   - **Golden contradicts the standard.** Measure both and keep the library
     standard-correct. Record the contradiction in
     `devnotes/components/GOLDEN_REFERENCES.md` and add a `GOLDEN_OVERRIDES` entry in
     `scripts/compare-golden.sh` when a closest standard envelope makes the
     manual shape comparison meaningful. Example: `bearing_6003_open_simple`
     measures 8x24x8 (628-like) although ISO 15 6003 is 17x35x10; the script
     generates a 628 envelope and prints the contradiction.

6. **Fix the smallest coherent thing.** Kernel changes belong in `cad/`, the
   component behavior in `components/<family>/`. Keep every `Shape` variant in
   every exhaustive match. Do not weaken a test or validator; the analytic
   checks (`cone_present`, `cylinder_present`, torus/sphere checks) are
   stronger than polygon-ring counts.

7. **Verify.**

   ```bash
   ./test-all.sh
   python3 scripts/golden_matrix.py
   python3 scripts/compare_golden.py
   ./compare-golden.sh 4 --headless
   python3 scripts/validate_step.py target/golden-compare/parametric-<golden>.step
   ```

   Re-measure the pair and confirm the specific difference found in step 3 is
   gone. Visual confirmation in SolidCraft is the last check, not the only one.

8. **Report.** State the golden file, the measured before/after numbers, the
   root cause (defect / representation / golden error), the files changed, and
   any remaining approximation or omission with its deviation.

## Rules

- Never modify, regenerate, or substitute a golden file.
- Never copy a golden dimension that contradicts its standard.
- Never call a layered stack a Boolean, a polygon a cylinder, or a sharp edge a
  chamfer.
- No Git state-changing commands; the owner commits.
- Keep the runtime library pure MoonBit; OCCT/CADquery/MCP are development-time
  tools.
- Update the feature record and component description to agree with the emitted
  geometry.
- A single solid can carry per-face colors: `RevolvedProfile::with_band_color`
  marks a band, and the writer emits a face-level `STYLED_ITEM`. Use that for
  features such as the black shield groove on the 608ZZ; do not split the solid
  into extra bodies just for color.
- Generated files live under `target/golden-compare/` (ignored); do not commit
  them.

## Examples

```text
Please fix ./compare-golden.sh 4
```

→ Index 004 is `bearing_6003_open_simple.step`. It measures 8x24x8, not ISO 15
6003 (17x35x10), so the library keeps 6003 standard-correct and the script pairs
it with the standard 628 envelope. The fixed pair matches at 2 solids,
4 cylinders + 4 planes, radii 4.0 / 7.6 / 8.0 / 12.0.

```text
Please fix ./compare-golden.sh 81
```

→ Index 081 is `iso4762_socket_head_cap_screw_m4x20.step`. Measure the socketed
head, compare the cone/cylinder inventory, fix the socket topology or chamfer,
and re-run the pair.
