# Validation Summary

Environment: macOS, MoonBit `moon 0.1.20261104 (940aa18 2026-11-04)`,
`moonc v0.10.20+65efd5b93`; OCCT `DRAWEXE` and `gmsh` present.

## Unit tests

```bash
./test-all.sh
```

Result: **408 tests, 408 passed, 0 failed** (baseline before component work:
345/345). `test-all.sh` also runs `moon fmt` and `moon info --target native`.

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
| `frame-2020-400x300x500.step` | 12 | 1032 | OK |
| `gear-pair-m2-20x40.step` | 2 | 2652 | OK |
| `planetary-m2-s12-p12-r36-3.step` | 5 | 2598 | OK |
| `motion-608-stack.step` | 22 | 573 | OK |
| `spring-10x1x20.step` | 1 | 4610 | OK |

All 29 flat fixtures in `components/examples/output/` pass
`validate_step.py --no-mesh`; the larger ones above were also checked with
tessellation enabled (`occt mesh: 0 open edges`).

## Assembly product structure

`components/examples/output/assembly-structure/kit-M4x20-assembly.step` is the
STEP product/occurrence representation. It passes syntax, references, shell
topology, orientation, and planarity. The repository's OCCT stage asks OCCT to
read a single named shape and reports "a is not a topological shape" for an
assembly document. See `KNOWN_ISSUES.md`; the flat kit export is the fully
validated form.

## Reproduce

```bash
./components/examples/generate_all.sh
```
