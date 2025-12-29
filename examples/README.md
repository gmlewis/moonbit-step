# Examples

This directory is a collection of example projects that demonstrate how to use this package to generate **CAD/CAM/CAE STEP files** with code.

The core idea: you can model parts and assemblies using a real programming language — giving you:

- Parametric design (dimensions as variables, computed features, constraints-by-construction)
- Reusable generators (hole patterns, fastener libraries, enclosures, lattices, gears)
- “Design families” (one source → many sizes/variants)
- Programmatic text, logos, and vector artwork (engraving, embossing, stencils)
- Deterministic outputs (great for versioning, CI, and regression checks)

You can use this package as:

- A **replacement** for traditional CAD for projects where programmability and repeatability matter.
- A **helper** alongside CAD tools: generate tricky geometry (patterns, adapters, fixtures), export STEP, then import into your slicer/CAD tool for finishing touches.

## Working examples

Each entry below links to a subfolder containing a **working example**: code that generates a STEP model you can open in a CAD viewer or import into a slicer for 3D printing, plus notes on what to tweak and why.

- [01-hello-cube](./01-hello-cube) - The smallest “hello world”: a parameterized cube with a few named dimensions.
- [02-calibration-chamfer-block](./02-calibration-chamfer-block) - A print-tuning block that sweeps chamfers/fillets to see what your printer handles.
- [03-engraved-name-tag](./03-engraved-name-tag) - A keychain tag with programmable text placement, kerning, and border styles.
- [04-parametric-washer-kit](./04-parametric-washer-kit) - Generate a family of washers from a table of inner/outer diameters and thicknesses.
- [05-gridfinity-compatible-bin](./05-gridfinity-compatible-bin) - A maker-friendly storage bin generator with configurable compartments and labels.
- [06-stackable-spacer-tower](./06-stackable-spacer-tower) - A set of stackable spacers with “click-together” features for fast height changes.
- [07-cable-label-clip](./07-cable-label-clip) - A snap-on cable label that embeds text and fits multiple cable diameters.
- [08-snap-fit-test-strip](./08-snap-fit-test-strip) - A strip of snap-fit geometries with varying interference to measure your tolerances.
- [09-dovetail-slider-jig](./09-dovetail-slider-jig) - A dovetail track and mating slider, generated with adjustable clearances.
- [10-polygon-knob](./10-polygon-knob) - A knob whose profile is driven by a polygon/spline function and grip parameters.
- [11-hex-bit-holder](./11-hex-bit-holder) - A customizable bit organizer that arrays pockets from a CSV list of sizes.
- [12-bifilar-electromagnet](./12-bifilar-electromagnet) - An electromagnet with interesting inductance and capacitance properties.
- [13-o-ring-groove-gauge](./13-o-ring-groove-gauge) - A gauge block that prints different O-ring groove dimensions for fit testing.
- [14-bolt-length-gauge](./14-bolt-length-gauge) - A physical “ruler” for bolts that includes embossed size markings.
- [15-metric-threaded-rod-nut](./15-metric-threaded-rod-nut) - A nut-like coupler body with correct clearances (thread modeling optional later).
- [16-press-fit-pin-gauge](./16-press-fit-pin-gauge) - Pins and holes that step through interference values to calibrate press fits.
- [17-living-hinge-sample](./17-living-hinge-sample) - A set of hinge patterns whose thickness and slot geometry are computed.
- [18-vented-electronics-enclosure](./18-vented-electronics-enclosure) - A vented box generator: walls, lid, screw bosses, and parametric vent patterns.
- [19-raspberry-pi-mount-plate](./19-raspberry-pi-mount-plate) - A mounting plate with programmable hole patterns and cable strain-relief geometry.
- [20-arduino-shield-standoff-frame](./20-arduino-shield-standoff-frame) - A standoff frame that supports stacked boards with computed clearances.
- [21-breadboard-rail-clips](./21-breadboard-rail-clips) - Clips that hold breadboards to rails, generated for multiple breadboard sizes.
- [22-zip-tie-anchor-panel](./22-zip-tie-anchor-panel) - A panel of zip-tie anchors with different slot geometries and strengths.
- [23-cable-grommet-ring](./23-cable-grommet-ring) - A parametric grommet for cable pass-throughs with lip and retention features.
- [24-angled-drill-guide-block](./24-angled-drill-guide-block) - A drill guide with configurable angles and bushing seat geometry.
- [25-miter-saw-angle-template](./25-miter-saw-angle-template) - Printable angle templates computed from desired joint geometry.
- [26-router-circle-cutting-jig](./26-router-circle-cutting-jig) - A circle-cutting jig where radius, mounting, and handle are all variables.
- [27-camera-tripod-adapter](./27-camera-tripod-adapter) - Adapter geometry driven by measured dimensions and thread insert allowances.
- [28-phone-stand-parametric](./28-phone-stand-parametric) - A phone stand generator tuned by device size, viewing angle, and cable notch.
- [29-headphone-hook](./29-headphone-hook) - A wall/desk hook with computed fillets and a strength-focused profile.
- [30-desk-cable-tray](./30-desk-cable-tray) - A cable tray with pattern-generated ribs and mounting options.
- [31-magnetic-tool-holder-strip](./31-magnetic-tool-holder-strip) - A strip with magnet pockets, spacing rules, and configurable retention lips.
- [32-spool-holder-bracket](./32-spool-holder-bracket) - A bracket that adapts to multiple spool widths and axle diameters.
- [33-filament-runout-sensor-housing](./33-filament-runout-sensor-housing) - A housing generator with controlled clearances for switches and fasteners.
- [34-belt-tensioner-block](./34-belt-tensioner-block) - A tensioner block with computed belt path and bolt slot geometry.
- [35-linear-rail-endcap](./35-linear-rail-endcap) - Endcaps that fit common rail profiles, with optional wipers and covers.
- [36-chronos-gear-flower](./36-chronos-gear-flower) - A parametric design with colors and complex symmetry.
- [37-tube-cap-assortment](./37-tube-cap-assortment) - Endcaps for common tubes (PVC/aluminum) with configurable wall thickness and ribs.
