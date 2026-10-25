# 38 — Planetary Gearbox

This folder contains a **working example** that generates a STEP model for a
print-in-place herringbone planetary gearbox: a sun gear, three orbiting planet
gears, and an enclosing inward-facing ring gear.

It is a port of
[`go-bjk/cmd/make-planetary-gearbox`](https://github.com/gmlewis/go-bjk/tree/main/cmd/make-planetary-gearbox)
and Blackjack's `HerringboneGear` node (`herringbone_gear.lua`).

The intent is that you can run the code here to emit a STEP file, open it in a
CAD viewer, and/or import it into your slicer to 3D print and iterate.

## What this example demonstrates
- porting a mesh generator to a B-Rep model
- defining each gear's outline **once** and sweeping it through
  `numElbows + 1` twisted extrusions
- internal (ring) gear envelopes generated from a mating planet gear
- exporting a clean multi-body STEP solid you can reuse in other tools

## Why it is small
Blackjack evaluates a herringbone gear as a triangle mesh in
`(numElbows + 1) * 2 * resolution` horizontal slices. This example builds the
2D outline a single time and only instantiates the `numElbows + 1` elbow
cross-sections, so the STEP output is smaller than the equivalent STL
(about 32 MB vs 64 MB for the default parameters).

The number of cross-sections adapts to the twist: each elbow is subdivided so
that adjacent cross-sections differ by at most 24° of profile rotation. Bands
whose four corners are not coplanar are split into two planar triangles, so
every face in the STEP file is planar and the mesh tessellates watertight. The
default parameters need only the elbow boundaries; small modules with a long
gear are subdivided automatically (`--module 0.5 --gearLength 30` twists 142°
per elbow and is subdivided 6x).

## Scaling the design

Every length parameter is in millimetres. To get a uniformly scaled copy of a
model, scale `gearLength`, `outerThickness`, `tolerance` and `holeRadius` by the
same factor as `module`; angles and counts stay unchanged. For example, a 6x
smaller copy of the default gearbox:

```
./run-example.sh 38 --module 0.5 --gearLength 5 --outerThickness 1.6667 \
  --tolerance 0.041667 --holeRadius 1.6667
```

Note that `-gl` is not a flag here (the short form is `-g`); use the long
options above.

## Parameters
The parameters mirror the Go program:

| Go flag | This program | Meaning |
| --- | --- | --- |
| `-mod` | `--module` | Gear module (tooth size) |
| `-gl` | `--gearLength` | Gear length |
| `-ha` | `--helixAngle` | Helix angle (0–45°) |
| `-hr` | `--holeRadius` | Hole inradius |
| `-ht` | `--holeType` | `None`, `Squared`, `Hexagonal`, `Octagonal`, `Circular` |
| `-ne` | `--numElbows` | Number of herringbone elbows |
| `-nt` | `--numTeeth` | Sun gear teeth (default 12; must make `sun + ring` divisible by the planet count) |
| `-planets` | `--numPlanets` | Number of planet gears |
| `-planetTeeth` | `--planetTeeth` | Planet teeth (0 = same as the sun) |
| `-pa` | `--pressureAngle` | Pressure angle |
| `-ringTeeth` | `--ringTeeth` | Ring teeth (0 = sun + 2·planet) |
| `-tol` | `--tolerance` | Target flank clearance |
| `-outerThickness` | `--outerThickness` | Ring wall thickness |
| `-res` | `--resolution` | Points per curved section of the outline |
| `-o` | `--out` | Output file |

`-obj`, `-stl`, `-swapyz`, `-repo`, and `-debug` are mesh-export options and
have no STEP equivalent.

## Suggested extensions
- add a carrier plate and pin holes for an assembled gearbox
- vary the helix angle per gear stage
- add a variant generator (small/medium/large module)
