# Examples

This directory is a grab-bag of small-to-large example projects that demonstrate how to use this package to generate **CAD/CAM/CAE STEP files** with code.

The core idea: instead of clicking and dragging in a CAD UI (or writing one-off CAD scripts that are hard to maintain), you can model parts and assemblies using a real programming language—giving you:

- Parametric design (dimensions as variables, computed features, constraints-by-construction)
- Reusable generators (hole patterns, fastener libraries, enclosures, lattices, gears)
- “Design families” (one source → many sizes/variants)
- Programmatic text, logos, and vector artwork (engraving, embossing, stencils)
- Deterministic outputs (great for versioning, CI, and regression checks)

You can use this package as:

- A **replacement** for traditional CAD for projects where programmability and repeatability matter.
- A **helper** alongside CAD tools: generate tricky geometry (patterns, adapters, fixtures), export STEP, then import into your slicer/CAD for finishing touches.

## Working examples (01–99)

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
- [12-tube-cap-assortment](./12-tube-cap-assortment) - Endcaps for common tubes (PVC/aluminum) with configurable wall thickness and ribs.
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
- [36-bearing-seat-test-coupons](./36-bearing-seat-test-coupons) - Print small “coupons” for bearing press fits across a tolerance sweep.
- [37-gearbox-demo-assembly](./37-gearbox-demo-assembly) - A simple multi-part assembly demonstrating mating parts and alignment features.
- [38-cycloidal-reducer-model](./38-cycloidal-reducer-model) - A programmable cycloidal reducer concept model (great for parametric curves).
- [39-planetary-gearset-generator](./39-planetary-gearset-generator) - Generate sun/planet/ring proportions and clearances from a small input set.
- [40-rack-and-pinion-slider](./40-rack-and-pinion-slider) - A rack/pinion slider showing repeatable tooth patterns and assembly tolerances.
- [41-timing-pulley-parametric](./41-timing-pulley-parametric) - A pulley generator driven by belt pitch/tooth count with hub options.
- [42-bevel-gear-pair](./42-bevel-gear-pair) - A bevel gear pair concept model to explore alignment, offsets, and clearances.
- [43-chain-sprocket-profile](./43-chain-sprocket-profile) - A sprocket profile derived from parameters, with mounting patterns and lightening holes.
- [44-laser-pointer-pan-tilt](./44-laser-pointer-pan-tilt) - A small pan/tilt mechanism assembly with servo mounts and wiring guides.
- [45-small-robot-wheel](./45-small-robot-wheel) - A wheel with parametric tread, hub geometry, and bearing/axle options.
- [46-omni-wheel-rollers](./46-omni-wheel-rollers) - Omni-wheel rollers and hubs generated from a few constraints and roller counts.
- [47-rc-servo-horn-adapter](./47-rc-servo-horn-adapter) - An adapter that maps servo horn patterns to a custom linkage geometry.
- [48-servo-mount-bracket](./48-servo-mount-bracket) - A bracket generator that supports different servos and mounting styles.
- [49-stepper-motor-coupler](./49-stepper-motor-coupler) - A coupler body with configurable bore diameters, clamp slots, and screw seats.
- [50-micro-delta-robot-joints](./50-micro-delta-robot-joints) - Joint parts for a small delta mechanism, emphasizing repeatable part families.
- [51-quad-copter-motor-mount](./51-quad-copter-motor-mount) - A motor mount driven by bolt circle dimensions and arm thickness rules.
- [52-drone-frame-arm](./52-drone-frame-arm) - A frame arm generator that explores lightweighting patterns and cable channels.
- [53-gimbal-camera-cage](./53-gimbal-camera-cage) - A cage with computed clearances and flexible mounting points.
- [54-vacuum-hose-adapter](./54-vacuum-hose-adapter) - An adapter generator that maps between two measured hose diameters.
- [55-shop-vac-cyclone-flange](./55-shop-vac-cyclone-flange) - A flange and gasket seat pattern built from bolt circles and seal geometry.
- [56-dust-collection-blast-gate](./56-dust-collection-blast-gate) - A blast gate assembly with sliding geometry and configurable stop positions.
- [57-water-bottle-cage](./57-water-bottle-cage) - A cage built from arcs/splines and thickness constraints, sized to your bottle.
- [58-bike-light-mount](./58-bike-light-mount) - A mount that adapts to handlebar diameter and light body dimensions.
- [59-bicycle-clip-on-fender](./59-bicycle-clip-on-fender) - A fender concept model that’s easy to resize by wheel radius and clearance.
- [60-hydroponic-net-pot](./60-hydroponic-net-pot) - A net pot generator with configurable slot patterns and lip geometry.
- [61-drip-irrigation-manifold](./61-drip-irrigation-manifold) - A multi-outlet manifold where spacing and outlet count are computed.
- [62-plant-label-stake-text](./62-plant-label-stake-text) - Plant stakes with embossed/engraved text and optional QR-like patterns.
- [63-seed-tray-divider](./63-seed-tray-divider) - Dividers driven by tray grid dimensions and planting plan data.
- [64-cookie-cutter-svg-import](./64-cookie-cutter-svg-import) - Turn a vector outline into a cookie-cutter-style wall with thickness rules.
- [65-stencil-text-generator](./65-stencil-text-generator) - A stencil generator that automatically inserts bridges for “floating” letters.
- [66-embossed-logo-coin](./66-embossed-logo-coin) - A coin/medallion that embosses a logo and adds a procedural edge pattern.
- [67-topographic-map-relief](./67-topographic-map-relief) - A relief model generated from contour lines or a height function (concept first).
- [68-pen-plotter-toolhead](./68-pen-plotter-toolhead) - A toolhead with clamp variants and computed offsets for different pens.
- [69-mounting-hole-pattern-library](./69-mounting-hole-pattern-library) - A catalog of hole patterns (NEMA, VESA, fans) used by other examples.
- [70-slot-and-tab-enclosure-kit](./70-slot-and-tab-enclosure-kit) - Slot-and-tab panels generated from dimensions, with kerf/clearance controls.
- [71-snap-latch-box](./71-snap-latch-box) - A box with a latch feature whose spring geometry is computed from constraints.
- [72-battery-holder-aa-aaa](./72-battery-holder-aa-aaa) - Battery holders sized from cells and spring/terminal allowances.
- [73-coin-cell-holder-clip](./73-coin-cell-holder-clip) - A clip-style coin cell holder demonstrating thin flex features.
- [74-fuse-holder-panel-mount](./74-fuse-holder-panel-mount) - A panel mount body with configurable cutouts and retention features.
- [75-connector-panel-blank](./75-connector-panel-blank) - A panel system that places connector cutouts from a declarative config.
- [76-eurorack-module-panel](./76-eurorack-module-panel) - A synthesizer panel with parametric hole layouts and engraved legends.
- [77-knurled-knob-with-insert](./77-knurled-knob-with-insert) - A knob with procedural knurling and a heat-set insert boss.
- [78-hinged-lid-box](./78-hinged-lid-box) - A box with hinge barrels and pin clearance rules you can sweep.
- [79-parametric-drawer-pull](./79-parametric-drawer-pull) - Drawer pulls generated from grip ergonomics and mounting spacing.
- [80-door-stop-wedge](./80-door-stop-wedge) - A wedge whose angle, ribs, and grip texture are algorithmic.
- [81-furniture-leveling-foot](./81-furniture-leveling-foot) - A foot with configurable pads, thread insert pockets, and tilt compensation.
- [82-shelf-bracket-curved](./82-shelf-bracket-curved) - A curved bracket exploring strength ribs and aesthetic profiles.
- [83-wall-anchor-template](./83-wall-anchor-template) - A drilling template that places holes and alignment guides from measurements.
- [84-pegboard-hook-set](./84-pegboard-hook-set) - A family of pegboard hooks generated from “tool silhouettes” and rules.
- [85-modular-organizer-rails](./85-modular-organizer-rails) - Rails and clips that snap into a system, showing tolerance-aware mating parts.
- [86-toolbox-custom-insert](./86-toolbox-custom-insert) - An insert generator driven by a list of tool dimensions and packing rules.
- [87-raspberry-pi-case-with-vents](./87-raspberry-pi-case-with-vents) - A case variant that explores vent patterns, bosses, and cable cutouts.
- [88-heatset-insert-boss-kit](./88-heatset-insert-boss-kit) - A library of boss geometries for different insert sizes and wall thicknesses.
- [89-gasketed-lid-groove](./89-gasketed-lid-groove) - A lid + groove generator showing seal design and assembly constraints.
- [90-octagonal-lamp-shade-frame](./90-octagonal-lamp-shade-frame) - A frame with repeated struts and computed joint angles for fast iteration.
- [91-led-strip-diffuser-channel](./91-led-strip-diffuser-channel) - A channel profile generator with snap lids and diffuser clearances.
- [92-speaker-grille-pattern](./92-speaker-grille-pattern) - Procedural grille patterns (hex, waves) with thickness and acoustic openness controls.
- [93-fan-shroud-duct](./93-fan-shroud-duct) - A shroud/duct concept model with a programmable transition profile.
- [94-airfoil-wing-section](./94-airfoil-wing-section) - Generate an airfoil cross-section and a printable wing segment concept model.
- [95-fluid-nozzle-array](./95-fluid-nozzle-array) - An array of nozzles placed by rules (spacing, angles), ideal for code-driven layouts.
- [96-finite-element-demo-bracket](./96-finite-element-demo-bracket) - A bracket with parameter sweeps intended for later CAE-style comparisons.
- [97-lattice-infill-explorer](./97-lattice-infill-explorer) - A lattice volume generator to explore patterns, density gradients, and strength.
- [98-assembly-exploded-view-demo](./98-assembly-exploded-view-demo) - Multi-part assembly where positions are computed, enabling “exploded” layouts.
- [99-full-workshop-vise-accessory-pack](./99-full-workshop-vise-accessory-pack) - A pack of vise jaws, soft inserts, and adapters generated from your vise dimensions.
