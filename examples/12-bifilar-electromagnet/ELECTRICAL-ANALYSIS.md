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
