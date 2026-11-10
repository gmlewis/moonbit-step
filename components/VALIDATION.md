# Validation Summary

Environment: macOS, MoonBit `moon 0.1.20261104 (940aa18 2026-11-04)`,
`moonc v0.10.20+65efd5b93`; OCCT `DRAWEXE` and `gmsh` present.

## Unit tests

```bash
./test-all.sh
```

Result after the correctness audit: **432 tests, 432 passed, 0 failed**
(baseline before the audit: 408/408; before the component work: 345/345).
`test-all.sh` also runs `moon fmt` and `moon info --target native`.

New regression coverage added by the audit:

- `components/collision/collision_test.mbt` — contact vs collision vs
  clearance, penetration depth, AABB false-positive rejection, OBB placement.
- `components/assemblies/extrusion_frame_test.mbt` — member count, cut
  lengths, endpoints, overall dimensions, pairwise interference, intended
  contacts, connectivity, no floating members, invalid boundaries, STEP
  round-trip, and additional frame sizes.
- `components/gears/gear_mesh_test.mbt` — external gear mesh cycle,
  non-divisible planetary phasing, and planet/ring clearance.

## STEP validation

```bash
python3 scripts/validate_step.py <file.step>
```

The validator checks ISO 10303-21 syntax, real-number grammar, reference
integrity, per-shell edge usage and orientation, `PLANE` planarity, OCCT
`checkshape`, and watertight tessellation.

Representative results:

| Artifact | Solids | Faces | Result |
|---|---:|---:|---|
| `iso4762-M4x20.step` | 3 | 62 | OK |
| `iso4762-M4x20-fully-modeled.step` | 5 | 2825 | OK |
| `iso4032-M4.step` | 1 | 56 | OK |
| `iso4032-M4-fully-modeled.step` | 2 | 590 | OK |
| `iso7089-M5.step` | 1 | 98 | OK |
| `iso4017-M5x20.step` | 2 | 11 | OK |
| `iso4014-M8x40.step` | 2 | 11 | OK |
| `din976-M8x200.step` | 1 | 3 | OK |
| `kit-M4x20-flat.step` | 5 | 216 | OK |
| `frame-2020-400x300x500.step` | 12 | 1128 | OK |
| `gear-pair-m2-20x40.step` | 2 | 2652 | OK |
| `planetary-m2-s12-p12-r36-3.step` | 5 | 2598 | OK |
| `motion-608-stack.step` | 22 | 573 | OK |
| `spring-10x1x20.step` | 1 | 4610 | OK |

All 31 flat fixtures in `components/examples/output/` pass
`validate_step.py --no-mesh`; the larger ones above were also checked with
tessellation enabled (`occt mesh: 0 open edges`).

## Assembly product structure

`components/examples/output/assembly-structure/kit-M4x20-assembly.step` is the
STEP product/occurrence representation. It passes syntax, references, shell
topology, orientation, and planarity. The repository's OCCT stage asks OCCT to
read a single named shape and reports "a is not a topological shape" for an
assembly document. See `KNOWN_ISSUES.md`; the flat kit export is the fully
validated form.

## Independent frame post-export validation

`scripts/validate_frame_geometry.py` re-imports a frame STEP with OCCT,
re-derives the member schedule in Python, and checks every solid's bounding box,
volume, and pairwise overlap. Results:

| Frame | Solids | Worst bbox error | Worst volume error | Positive-volume overlaps | Result |
|---|---:|---:|---:|---:|---|
| 400 x 300 x 500 | 12 | 1e-07 mm | 5.61e-07 | 0 | PASS |
| 600 x 300 x 400 | 12 | 1e-07 mm | 2.42e-06 | 0 | PASS |
| 45 x 45 x 45 | 12 | 1e-07 mm | 4.79e-07 | 0 | PASS |
| 400 x 300 x 500, 2040 profile | 12 | 1e-07 mm | 2.19e-06 | 0 | PASS |

The independent section area for the generic 2020 envelope is
192.345108 mm^2 (rectangle minus four tapered T-slot notches minus the 48-gon
core bore), which matches the OCCT-measured volume / cut length to the errors
above.

## Golden-reference results

External candidates were downloaded to a temporary directory, checksum-verified,
and measured with OCCT. Full provenance is in
`components/testdata/golden/manifest.json`; the policy is in
`components/GOLDEN_REFERENCES.md`.

| Fixture | Verdict | Evidence |
|---|---|---|
| ISO 4762 M3 x 10 | accepted envelope | 5.5 x 5.5 x 13.0 matches |
| ISO 4762 M4 x 20 | accepted envelope | 7.0 x 7.0 x 24.0 matches |
| ISO 4762 M5 x 10 | **rejected** | head diameter 9.2003 mm vs ISO max 8.5 |
| ISO 4032 M4 | height accepted | 3.2027 vs 3.2 mm; plan bbox not confirmable |
| ISO 7089 M4 | **rejected** | thickness 1.8 mm vs ISO 7089 h = 0.8 |
| 608ZZ bearing | accepted envelope | 22 x 22 x 7 matches |
| 2020 B-slot6 profile | envelope only | 20 x 20 x 50 matches; section not compared |
| Spur gear m2 z20 bore8 | accepted envelope | 44 x 44 x 16 matches |

Honest skips: no external file is committed (per-file license unverified), so
these comparisons run only when the fetch procedure has been executed. No
planetary assembly reference was available; planetary checks are analytic.

## Reproduce

```bash
./components/examples/generate_all.sh
```
