# Known Issues and Deferred Features

## Geometry limitations

1. **Nominal STEP booleans.** `@cad.difference()` and `@cad.union_all()` are
   nominal in the STEP backend. The component library avoids using them for
   real features, but components that are naturally layered export as several
   closed bodies. This is documented per family; do not expect one fused
   manifold from a layered screw.
2. **No head chamfers or fillets.** Screw and bolt heads are sharp-edged
   cylinders/hex prisms. The kernel has no general chamfer/fillet shape, and a
   nominal boolean would not produce a true chamfer.
3. **No screw tip chamfer or thread runout.** The shank ends are square.
4. **No socket counterbore/lead-in.** The hexagonal socket is a straight
   through-hole in the socket ring over a solid floor disc.
5. **Helical thread ridge is an approximation.** It uses the ISO 68-1 basic
   profile and standard pitch, but does not model tolerance classes, root
   radius, flank grind, or runout. It is a real swept helix, not a cosmetic
   texture.
6. **Gear root fillet omitted.** Tooth flanks are involute; tip and root arcs
   are polygonal. Root fillets, tip chamfers, profile shift, and helix are not
   modeled.
7. **Gear pair is a static layout.** It uses the standard centre distance plus
   an offset and a half-pitch phase. It is not a kinematic solver and does not
   verify tooth contact.
8. **Internal ring gear tooth form is approximate.** The planetary set uses a
   trapezoidal internal tooth profile. It is visually and kinematically laid
   out but is not an exact internal involute envelope. The existing
   `examples/38-planetary-gearbox` herringbone generator is preserved.
9. **Bearing balls are not spheres.** Each rolling element is a cylinder with
   diameter and length equal to the radial gap. Rings are plain tubes; seals,
   cages, chamfers, and exact internal proportions are omitted.
10. **Stepped shafts are separate cylinders.** Sharp shoulders, no fillets or
    undercuts. A true one-body stepped extrusion is not available in the
    current shape set.
11. **Springs are simplified.** Open helix with flat end caps; closed/ground
    ends, spring rate, and preload are not modeled.
12. **Standoffs, pins, and keys have no thread/tolerance model.** They are
    parametric shapes with explicit dimensions, not standard part numbers.
13. **T-slot profiles are generic envelopes.** Slot, neck, cavity, wall, and
    bore dimensions are engineering assumptions. They are not manufacturer
    compatible without verification. Section corners are sharp; end taps and
    machining are not modeled.
14. **Extrusion frame rails overlap posts.** The frame is a display/assembly
    envelope; brackets, cut-to-fit joints, and fasteners are not modeled.

## API / packaging

1. **No separate `iso4762` package.** Functions live in
   `components/standards` and `components/fasteners` to avoid one trivial
   package per standard. The public functions are named `iso4762_spec`,
   `iso4762_screw`, etc.
2. **Optional thread override forwarding.** MoonBit optional named arguments
   cannot be forwarded as an option directly; wrapper functions use a `match`
   on `Some`/`None`. This is a readability cost only.
3. **Color defaults.** Components default to bright colors (blue/orange/green/
   purple/cyan) to keep previews readable. Pass `color=` where a neutral or
   material-specific color is required.

## Validation issues

1. **Assembly STEP product structure and the OCCT single-shape gate.**
   `Assembly::to_assembly_step()` writes a valid product/occurrence structure
   with `NEXT_ASSEMBLY_USAGE_OCCURRENCE` and
   `ITEM_DEFINED_TRANSFORMATION`. The repository validator checks syntax,
   references, shells, topology, orientation, and planarity successfully, but
   its OCCT stage calls `testreadstep <file> a` and reports "a is not a
   topological shape" for an assembly document. Use a CAD assembly importer or
   the flat export (`Assembly::to_step()`) when the OCCT gate is required.
2. **Fully modeled files are large.** An M4x20 fully modeled screw is roughly
   4 MB at 48 segments per turn. Simplified/detailed files are ~60 KB. Reduce
   `segments_per_turn` or use `Detailed` for catalog-wide generation when size
   matters.
3. **Bounding boxes of swept profiles are conservative.** `@cad`'s
   `SweptProfile` bounding box expands path points by 5 mm; unit tests inspect
   analytic layers instead of trusting the swept envelope.

## Deferred standards/components

- ISO 7380 button head screws (domed head; needs verified table and a dome
  representation).
- ISO 10642 countersunk head screws (conical head; needs a true cone or a
  documented stepped approximation).
- ISO 4762 additional lengths and preferred-length series outside the tested
  range.
- Fine-thread fasteners beyond the first-choice fine pitch per size.
- Threaded inserts, retaining rings, pins, standoffs, and springs.
- Exact internal involute ring gears.
- Helical gears, bevel gears, worm gears, timing belts/pulleys, sprockets.
- T-nuts, corner brackets, joining plates, end caps.
- Motor envelopes and mounting patterns.
- Machine-readable catalog query API.
