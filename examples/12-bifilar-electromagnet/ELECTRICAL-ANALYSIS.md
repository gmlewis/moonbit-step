# Electrical / EM Analysis Guide (Example 12 – Bifilar Electromagnet)

This note captures a practical, low-cost workflow to estimate and **tune** DC + AC electrical properties of this parametric, solid-copper, bifilar electromagnet design.

## Goals and constraints

- Primary goal: **maximize capacitance** between adjacent conductors to **minimize self-resonant frequency**.
  - Target range: ideally **DC–1 kHz**, “nice” if **< 10 kHz**, likely unusable if **> 1 MHz**.
- Electrical topology clarification:
  - The "red" vs "green" naming is only for human sanity.
  - The design is intended to be **one continuous series path** (one input terminal, one output terminal).
  - The geometry is arranged so adjacent segments along the structure can sit at large voltage differences to maximize effective inter-wire capacitance.
- Material uncertainty:
  - The effective conductivity of printed copper may differ from bulk copper.
  - Treat conductivity / resistivity as an **input parameter** during analysis until a vendor process is selected.

## What you can compute cheaply (and reliably)

### DC resistance ($R_{DC}$)

If you know the total conductor length $L$ and conductor cross-section area $A$:

$$R_{DC} = \rho \frac{L}{A}$$

- $\rho$ is resistivity (\(\Omega\cdot m\)).
- For copper at ~20°C, a common starting value is $\rho_{Cu}\approx 1.7\times 10^{-8}\ \Omega\cdot m$.
- Printed copper may be worse; treat $\rho$ as a parameter.

**For this model**: the wire cross-section is square, so

- $A \approx w^2$ where $w$ is `wireWidth`.

### Quick feasibility sanity check for resonance

If you can estimate (or later extract) equivalent $L$ and $C$, the resonance estimate is:

$$f_0 \approx \frac{1}{2\pi\sqrt{LC}}$$

Rearrange to see how much capacitance you’d need:

$$C \approx \frac{1}{(2\pi f_0)^2 L}$$

This is useful early-on to calibrate expectations: getting $f_0$ down into kHz often requires *very* large effective capacitance and/or inductance.

## What is hard (and why you want solvers)

- **Inductance $L$** depends on the full 3D current path and coupling.
- **Capacitance $C$** depends on the full 3D conductor geometry, spacing, and surroundings.
- **AC resistance** adds skin + proximity effects; tight bifilar spacing increases proximity loss.
- **Very low resonance (<10 kHz)** is especially sensitive to distributed effects and the environment (air vs dielectric, nearby conductors, terminal geometry).

Hand formulas (solenoid approximations) are usually too crude for this geometry.

## Recommended lowest-cost / best-quality workflow

This is the pragmatic “fast iteration + high confidence” approach:

### 1) Add cheap, deterministic reporting to the generator

Have the parametric generator report things it can compute exactly or nearly exactly:

- helix centerline length per pair
- total helix centerline length (sum over all pairs)
- cross-sectional area
- parameter set used

This enables fast $R_{DC}$ estimates and provides inputs to external solvers.

### 2) Use PEEC / quasi-static extraction for sweeps (best value)

PEEC-style tools tend to be the best cost/quality for extracting RL and C of 3D conductors in the quasi-static regime.

Open-source / free tools to consider:

- **FastHenry2**: inductance + frequency-dependent resistance (quasi-static)
- **FastCap2**: capacitance extraction
- **Gmsh**: mesh / geometry tooling (also useful for FEM)

Why this is attractive:

- Efficient for conductor networks, good for param sweeps.
- Much less overhead than full 3D FEM for each variant.

Tradeoffs:

- Setup can be fiddly: ports/terminals, segmentation density.
- Accuracy depends on discretization.
- Eventually breaks down for frequencies where full-wave effects matter.

### 3) Validate finalists in full 3D FEM / EM

For the top few candidates, validate $L$ and $C$ with field solvers:

- **Elmer FEM**: strong open-source FEM; can do magnetostatics / AC magnetics / electrostatics.
- **GetDP** + **Gmsh**: powerful but steeper learning curve.
- **openEMS**: full-wave solver; best if you need resonance behavior including wave effects.

Typical usage:

- electrostatics → extract C (or energy) given a terminal voltage definition
- magnetostatics / AC magnetic → extract L (or energy) given a current definition
- openEMS → resonance validation for a small number of variants

## Parameter tuning strategies for lowering resonance

You’re explicitly trying to lower $f_0$ by increasing $C$ (and likely also increasing $L$). Common knobs:

- Increase adjacent conductor area / coupling:
  - decrease `wireGap`
  - increase `wireWidth` (increases area and capacitance, also reduces R)
- Increase total wire length and turns:
  - increase `vertTurns`
  - increase `numPairs`
- Bring conductors closer and parallel for longer stretches:
  - (geometry-dependent) maximize “side-by-side” length

Be aware:

- Lower `wireGap` increases capacitance but also increases proximity losses at AC.
- Very large $C$ may require extremely small gaps or dielectric loading.

## Suggested automation approach (cheap to start)

1. Use the MoonBit generator in `--report` mode to emit:
   - helix-only length (and area)
2. Use a Python script to:
   - compute $R_{DC}$ for a given resistivity
   - compute a “required C” for a target $f_0$ given an estimated/assumed $L$
3. When you’re happy with a parameter region, hook into FastHenry/FastCap or FEM.

## Notes on “series bifilar” interpretation

Even though the geometry is bifilar (two adjacent conductors), the intended wiring is a **single series path**.
That means:

- DC resistance should be computed from the total length of the full current path.
- Capacitance is “distributed” between adjacent segments at differing potentials.

A solver-based approach is strongly recommended for credible $C$ and resonance estimates.

## Next steps in this repo

- Add opt-in reporting to the example CLI to print:
  - helix centerline length (mm and m)
  - cross-section area (mm² and m²)
  - optional $R_{DC}$ estimate using a provided resistivity
- Add a small Python helper under `scripts/` for quick sweeps and early feasibility checks.

### What’s implemented now

- Example 12 supports `--report` (prints to stderr) and `--rho` (ohm*m).
- Quick analysis helper script:
  - [scripts/bfem_analyze.py](scripts/bfem_analyze.py)

Example usage:

```bash
./scripts/bfem_analyze.py --numPairs 10 --vertTurns 15 --wireWidth 1.0 --wireGap 0.2 \
  --innerDiam 6.0 --rho 1.724e-8
```

Ballpark (defaults as of 2026-01-03):

- Helix length: ~16.77 m → $R_{DC}$ (helix-only) ~0.289 Ω (assuming $\rho=1.724\times10^{-8}\ \Omega\cdot m$ and 1 mm² cross-section)
- Cage extrusions (rough): ~1.022 m total extrusion length → ~0.0047 Ω (very model-dependent; see note below)
- Exit wires (2×12 mm, 1 mm diameter, 12-gon approximation): ~0.00055 Ω

## Initial sweep findings (capacitance proxy)

This repo currently includes a sweep mode that ranks candidates by a very rough capacitance proxy:

$$C_{proxy} \propto L_{helix} \cdot \frac{wireWidth}{wireGap}$$

This is **not** a physical capacitance; it’s only a heuristic that tends to reward longer coupled length, larger facing area, and smaller separation.

Command run (12 variants total):

```bash
./scripts/bfem_analyze.py --sweep \
  --sweep-numPairs 6,10 \
  --sweep-vertTurns 10,15 \
  --sweep-wireWidth 1.0 \
  --sweep-wireGap 0.1,0.2,0.3 \
  --top 5
```

Top 5 results (ranked by higher $C_{proxy}$, then lower $R_{DC}$):

```text
sweep ranking (higher C_proxy better; lower Rdc better)
  numPairs vertTurns wireWidth wireGap | helix_m  Rdc_ohm  C_proxy | cage_Rdc exit_Rdc
  ------------------------------------------------------------------------------------
       10       15        1     0.1 | 15.924   0.2745 1.59e+05 |  0.0049  0.0006
       10       10        1     0.1 | 10.616   0.1830 1.06e+05 |  0.0041  0.0006
       10       15        1     0.2 | 16.773   0.2892 8.39e+04 |  0.0047  0.0006
        6       15        1     0.1 |  7.072   0.1219 7.07e+04 |  0.0028  0.0006
       10       15        1     0.3 | 17.623   0.3038 5.87e+04 |  0.0047  0.0006
```

Immediate takeaways from this small sweep:

- Smaller `wireGap` dominates the ranking strongly (as expected when chasing higher capacitance).
- Increasing turns/pairs raises the proxy but also raises $R_{DC}$ (longer conductor).
- In these variants the helix dominates $R_{DC}$; the cage/exits are orders of magnitude smaller in the rough model.

Notes:

- The cage/exit $R_{DC}$ estimates assume current flows along each extrusion’s axis with cross-section equal to the polygon area.
  This is a **rough** approximation, but it gives an order-of-magnitude sense of how small the connector contribution is compared to the long helices.

With a resonance target (requires an assumed L, purely for feasibility math):

```bash
./scripts/bfem_analyze.py --target-f0-hz 10000 --assumed-L-h 1e-3
```

## More robust / accurate resonant-frequency analysis

If you want a credible $f_0$ estimate (and not just “directional” tuning), you need a workflow that produces a believable equivalent **$L$ and $C$** (and ideally $R(f)$) for *your specific geometry and environment*.

For the kHz range you care about, a **quasi-static** approach is typically appropriate and cost-effective (you generally do not need full-wave solvers unless you push into MHz+ or have strong radiation/antenna-like structures).

### Step 0: Decide what environment you’re modeling

Capacitance and resonance are extremely sensitive to surroundings.

Pick at least one modeling scenario:

- air only (lower $C$)
- embedded in a dielectric (epoxy/ceramic/substrate) (higher $C$)
- near a ground plane / enclosure / nearby metal (can radically change $C$ and losses)

Also define “ports”:

- two terminals: `IN` and `OUT` of the single series path
- optional: define a reference conductor/ground if you want C-to-ground rather than purely inter-conductor coupling

### Step 1: Extract L of the full series path (FastHenry)

This repo can generate a **single-port** FastHenry deck for the full IN→OUT conductor path:

```bash
./scripts/bfem_fasthenry.py --out-inp /tmp/bfem.inp \
  --numPairs 10 --vertTurns 15 --wireWidth 1.0 --wireGap 0.2 --innerDiam 6.0
```

Run `fasthenry` on a machine that has it installed, then record the extracted inductance for the `BFEM_IN_OUT` port.

Important note: for absolute inductance accuracy you usually also model an explicit return path / reference conductor. For SRF ballparks, start with the simplest extraction and refine once you have a capacitance model.

### Step 2: Compute a lumped SRF once you have L and an effective C

Once you have (or assume) an equivalent $L$ and effective $C$, compute:

```bash
./scripts/bfem_resonance.py --L-mH 1.0 --C-nF 1.0
```

Or, if you have $L$ and want to know how much $C$ you need to hit a target:

```bash
./scripts/bfem_resonance.py --L-mH 1.0 --target-f0-hz 10000
```

### Step 3 (the hard part): Extract an effective C that matches this topology

For this design, the capacitance that drives self-resonance is **distributed** (inter-turn / inter-segment coupling at different potentials along a *single* conductor).

That means:

- A naive “one conductor vs ground” capacitance extraction is generally **not sufficient** to predict SRF.
- A credible quasi-static approach usually segments the conductor into many electrically-distinct pieces (nodes), computes a capacitance matrix between them, and then solves the resulting PEEC network.

Next work in this repo should focus on exporting a segmentation suitable for capacitance extraction (FastCap / FEM) and then building the reduced-order network to estimate SRF.

### Option A (best cost/value): PEEC / quasi-static extraction

This is usually the fastest path to usable $R$, $L$, and $C$ for complex 3D conductor networks.

Tools:

- **FastHenry2**: inductance + frequency-dependent resistance (quasi-static)
- **FastCap2**: electrostatic capacitance extraction

How this maps to this design:

- FastHenry wants a network of **wire segments/filaments** with node coordinates and cross-section.
- FastCap wants discretized **conductor surfaces/panels** for electrostatics.

Important practical note for this repo:

- The most robust way to drive these solvers is often **not** converting STEP/STL.
- Instead, export the *intent* directly from parameters:
  - a polyline (many short segments) for the centerline of each conductor path
  - cross-section (square: `wireWidth × wireWidth`)
  - terminal definition (where the series path begins/ends)

That avoids CAD-to-mesh pain for long helical wires.

What you do with the solver outputs:

1. Run FastHenry → get $R(f)$ and an inductance description (often a partial inductance matrix).
2. Run FastCap → get capacitance coefficients between conductor groups.
3. Build an equivalent circuit model:
   - simplest: one lumped $L$ and one lumped $C$ → $f_0 \approx 1/(2\pi\sqrt{LC})$
   - better: distributed ladder network (segments each with partial L/C) and find the first resonance numerically

Python can help with the last step:

- `numpy` / `scipy` to build the ladder network and sweep impedance vs frequency
- optional: `scikit-rf` if you want to work in a more RF/network-analysis style once you have multiport equivalents

### Option B (more geometry-faithful, heavier): FEM via Gmsh + Elmer or GetDP

This is a strong “ground truth” path, especially when you care about dielectric environment details.

You typically do two separate solves:

- Electrostatics (for $C$): apply 1 V between terminals, compute stored energy $W_e$, then
  $$C = 2 W_e / V^2$$
- Magnetostatics / low-frequency AC magnetics (for $L$): apply current $I$, compute magnetic energy $W_m$, then
  $$L = 2 W_m / I^2$$

Geometry/mesh pipeline:

- export STEP from the generator (you already do)
- import STEP into **Gmsh**, generate a tetrahedral mesh
- tag terminal faces / conductor regions (“physical groups”)
- run Elmer/GetDP and extract energy from the solution

This works, but helical conductors can require careful meshing to avoid huge element counts.

### Option C (later / validation only): openEMS full-wave

Use this if you eventually care about MHz+ behavior, radiation, or wave effects. For your stated goal (<10 kHz), quasi-static PEEC/FEM is usually the better starting point.

## Do you need STEP/STL conversion?

- For FEM: typically **yes** (STEP → Gmsh mesh).
- For FastHenry/FastCap: often **no** (export segments/panels directly from parameters is usually cleaner).

## Installation guidance (Linux Mint vs macOS)

### Linux Mint 22.2 (recommended for solver work)

Linux is typically the smoothest environment for building/running these toolchains.

- Install baseline tooling (packages names may vary slightly):
  - C/C++/Fortran toolchain (`gcc`, `g++`, `gfortran`, `make`)
  - Python (`python3`, `python3-venv`, `pip`)
  - Gmsh if you plan FEM (`gmsh`)

If you tell me which path you want first (FastHenry/FastCap vs FEM), I can give a copy/paste install sequence tailored to Mint.

### macOS (M2 Max)

macOS is great for:

- running the MoonBit generator and Python analysis
- installing/using Gmsh via Homebrew

But older solver build chains (especially Fortran-heavy ones) can be finicky. If build friction shows up on macOS, the fastest iteration loop is often:

- model/sweep on macOS
- run extraction on Mint

## Recommended next concrete step

To make this analysis practical and repeatable, the highest-leverage missing piece is an export of the **discretized series-path centerline** (points/segments) from the generator.

If you want, I can add an opt-in export mode (JSON or a direct FastHenry-ish text format) so Python can:

- generate a segmented conductor network from the exact parametric geometry
- run/parse extraction tools
- compute and report the lowest resonance numerically

## PEEC workflow (FastHenry2) using centerline export (implemented)

Example 12 now supports exporting discretized helix centerlines as JSON:

```bash
moon run --target native examples/12-bifilar-electromagnet -- \
  --export_centerlines /tmp/bfem_centerlines.json \
  > /dev/null
```

This JSON is designed to be a stable “intent export” for solver tooling (mm units, per-helix polylines).

To generate a **FastHenry2** input deck from that export:

```bash
./scripts/bfem_fasthenry.py --out-inp /tmp/bfem.inp \
  --numPairs 10 --vertTurns 15 --wireWidth 1.0 --wireGap 0.2 --innerDiam 6.0
```

Then run FastHenry2 (recommended on Linux):

```bash
fasthenry /tmp/bfem.inp
```

Important modeling note:

- The generated deck defines **one `.external` per helix** (between its endpoints).
- This is a good starting point for extracting per-helix $L$ and $R(f)$, but it is not automatically a physical “loop inductance” unless you model an explicit return path (a return conductor or ground plane).
