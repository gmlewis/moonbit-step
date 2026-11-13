///|
/// B-slot6 2020 profile constants. The section is the step.parts
/// "Profile-20x20-B-Slot6_A" reference: a 20 x 20 square with 1 mm outer
/// corner radii, four T-slots with a 6 mm neck and a 6.8 mm mouth, four
/// diagonal corner webs, and a lobed central 5.5 mm bore.
///
/// All coordinates are millimetres in the local XY plane, centred on the
/// origin. The loops are line/arc chains: every arc is a counter-clockwise
/// minor arc, so the extrusion compiles to analytic `CYLINDRICAL_SURFACE`
/// faces.

///|
/// b_slot6_2020_outer returns the outer section loop (76 segments).
fn b_slot6_2020_outer() -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((10.0, 3.4), (10.0, 9.0)),
    @cad.SegmentArc((10.0, 9.0), (9.0, 10.0), (9.0, 9.0)),
    @cad.SegmentLine((9.0, 10.0), (3.4, 10.0)),
    @cad.SegmentLine((3.4, 10.0), (3.4, 9.6)),
    @cad.SegmentLine((3.4, 9.6), (3.0, 9.6)),
    @cad.SegmentLine((3.0, 9.6), (3.0, 8.5)),
    @cad.SegmentLine((3.0, 8.5), (6.0, 8.5)),
    @cad.SegmentLine((6.0, 8.5), (6.0, 7.0)),
    @cad.SegmentLine((6.0, 7.0), (3.35, 4.7)),
    @cad.SegmentLine((3.35, 4.7), (0.65, 4.7)),
    @cad.SegmentLine((0.65, 4.7), (0.0, 4.3)),
    @cad.SegmentLine((0.0, 4.3), (-0.65, 4.7)),
    @cad.SegmentLine((-0.65, 4.7), (-3.35, 4.7)),
    @cad.SegmentLine((-3.35, 4.7), (-6.0, 7.0)),
    @cad.SegmentLine((-6.0, 7.0), (-6.0, 8.5)),
    @cad.SegmentLine((-6.0, 8.5), (-3.0, 8.5)),
    @cad.SegmentLine((-3.0, 8.5), (-3.0, 9.6)),
    @cad.SegmentLine((-3.0, 9.6), (-3.4, 9.6)),
    @cad.SegmentLine((-3.4, 9.6), (-3.4, 10.0)),
    @cad.SegmentLine((-3.4, 10.0), (-9.0, 10.0)),
    @cad.SegmentArc((-9.0, 10.0), (-10.0, 9.0), (-9.0, 9.0)),
    @cad.SegmentLine((-10.0, 9.0), (-10.0, 3.4)),
    @cad.SegmentLine((-10.0, 3.4), (-9.6, 3.4)),
    @cad.SegmentLine((-9.6, 3.4), (-9.6, 3.0)),
    @cad.SegmentLine((-9.6, 3.0), (-8.5, 3.0)),
    @cad.SegmentLine((-8.5, 3.0), (-8.5, 6.0)),
    @cad.SegmentLine((-8.5, 6.0), (-7.0, 6.0)),
    @cad.SegmentLine((-7.0, 6.0), (-4.7, 3.35)),
    @cad.SegmentLine((-4.7, 3.35), (-4.7, 0.65)),
    @cad.SegmentLine((-4.7, 0.65), (-4.3, 0.0)),
    @cad.SegmentLine((-4.3, 0.0), (-4.7, -0.65)),
    @cad.SegmentLine((-4.7, -0.65), (-4.7, -3.35)),
    @cad.SegmentLine((-4.7, -3.35), (-7.0, -6.0)),
    @cad.SegmentLine((-7.0, -6.0), (-8.5, -6.0)),
    @cad.SegmentLine((-8.5, -6.0), (-8.5, -3.0)),
    @cad.SegmentLine((-8.5, -3.0), (-9.6, -3.0)),
    @cad.SegmentLine((-9.6, -3.0), (-9.6, -3.4)),
    @cad.SegmentLine((-9.6, -3.4), (-10.0, -3.4)),
    @cad.SegmentLine((-10.0, -3.4), (-10.0, -9.0)),
    @cad.SegmentArc((-10.0, -9.0), (-9.0, -10.0), (-9.0, -9.0)),
    @cad.SegmentLine((-9.0, -10.0), (-3.4, -10.0)),
    @cad.SegmentLine((-3.4, -10.0), (-3.4, -9.6)),
    @cad.SegmentLine((-3.4, -9.6), (-3.0, -9.6)),
    @cad.SegmentLine((-3.0, -9.6), (-3.0, -8.5)),
    @cad.SegmentLine((-3.0, -8.5), (-6.0, -8.5)),
    @cad.SegmentLine((-6.0, -8.5), (-6.0, -7.0)),
    @cad.SegmentLine((-6.0, -7.0), (-3.35, -4.7)),
    @cad.SegmentLine((-3.35, -4.7), (-0.65, -4.7)),
    @cad.SegmentLine((-0.65, -4.7), (0.0, -4.3)),
    @cad.SegmentLine((0.0, -4.3), (0.65, -4.7)),
    @cad.SegmentLine((0.65, -4.7), (3.35, -4.7)),
    @cad.SegmentLine((3.35, -4.7), (6.0, -7.0)),
    @cad.SegmentLine((6.0, -7.0), (6.0, -8.5)),
    @cad.SegmentLine((6.0, -8.5), (3.0, -8.5)),
    @cad.SegmentLine((3.0, -8.5), (3.0, -9.6)),
    @cad.SegmentLine((3.0, -9.6), (3.4, -9.6)),
    @cad.SegmentLine((3.4, -9.6), (3.4, -10.0)),
    @cad.SegmentLine((3.4, -10.0), (9.0, -10.0)),
    @cad.SegmentArc((9.0, -10.0), (10.0, -9.0), (9.0, -9.0)),
    @cad.SegmentLine((10.0, -9.0), (10.0, -3.4)),
    @cad.SegmentLine((10.0, -3.4), (9.6, -3.4)),
    @cad.SegmentLine((9.6, -3.4), (9.6, -3.0)),
    @cad.SegmentLine((9.6, -3.0), (8.5, -3.0)),
    @cad.SegmentLine((8.5, -3.0), (8.5, -6.0)),
    @cad.SegmentLine((8.5, -6.0), (7.0, -6.0)),
    @cad.SegmentLine((7.0, -6.0), (4.7, -3.35)),
    @cad.SegmentLine((4.7, -3.35), (4.7, -0.65)),
    @cad.SegmentLine((4.7, -0.65), (4.3, 0.0)),
    @cad.SegmentLine((4.3, 0.0), (4.7, 0.65)),
    @cad.SegmentLine((4.7, 0.65), (4.7, 3.35)),
    @cad.SegmentLine((4.7, 3.35), (7.0, 6.0)),
    @cad.SegmentLine((7.0, 6.0), (8.5, 6.0)),
    @cad.SegmentLine((8.5, 6.0), (8.5, 3.0)),
    @cad.SegmentLine((8.5, 3.0), (9.6, 3.0)),
    @cad.SegmentLine((9.6, 3.0), (9.6, 3.4)),
    @cad.SegmentLine((9.6, 3.4), (10.0, 3.4)),
  ]
}

///|
/// b_slot6_2020_bore returns the lobed central bore loop (20 segments): a
/// 2.75 mm-radius circle with four 1.5 mm-wide, 3.5 mm-radius notches along the
/// diagonals where the corner webs meet the core.
fn b_slot6_2020_bore() -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentArc((2.75, 0.0), (2.40115877928, 1.3404986075), (0.0, 0.0)),
    @cad.SegmentLine(
      (2.40115877928, 1.3404986075),
      (3.00520382004, 1.94454364826),
    ),
    @cad.SegmentLine(
      (3.00520382004, 1.94454364826),
      (1.94454364826, 3.00520382004),
    ),
    @cad.SegmentLine(
      (1.94454364826, 3.00520382004),
      (1.3404986075, 2.40115877928),
    ),
    @cad.SegmentArc((1.3404986075, 2.40115877928), (0.0, 2.75), (0.0, 0.0)),
    @cad.SegmentArc((0.0, 2.75), (-1.3404986075, 2.40115877928), (0.0, 0.0)),
    @cad.SegmentLine(
      (-1.3404986075, 2.40115877928),
      (-1.94454364826, 3.00520382004),
    ),
    @cad.SegmentLine(
      (-1.94454364826, 3.00520382004),
      (-3.00520382004, 1.94454364826),
    ),
    @cad.SegmentLine(
      (-3.00520382004, 1.94454364826),
      (-2.40115877928, 1.3404986075),
    ),
    @cad.SegmentArc((-2.40115877928, 1.3404986075), (-2.75, 0.0), (0.0, 0.0)),
    @cad.SegmentArc((-2.75, 0.0), (-2.40115877928, -1.3404986075), (0.0, 0.0)),
    @cad.SegmentLine(
      (-2.40115877928, -1.3404986075),
      (-3.00520382004, -1.94454364826),
    ),
    @cad.SegmentLine(
      (-3.00520382004, -1.94454364826),
      (-1.94454364826, -3.00520382004),
    ),
    @cad.SegmentLine(
      (-1.94454364826, -3.00520382004),
      (-1.3404986075, -2.40115877928),
    ),
    @cad.SegmentArc((-1.3404986075, -2.40115877928), (0.0, -2.75), (0.0, 0.0)),
    @cad.SegmentArc((0.0, -2.75), (1.3404986075, -2.40115877928), (0.0, 0.0)),
    @cad.SegmentLine(
      (1.3404986075, -2.40115877928),
      (1.94454364826, -3.00520382004),
    ),
    @cad.SegmentLine(
      (1.94454364826, -3.00520382004),
      (3.00520382004, -1.94454364826),
    ),
    @cad.SegmentLine(
      (3.00520382004, -1.94454364826),
      (2.40115877928, -1.3404986075),
    ),
    @cad.SegmentArc((2.40115877928, -1.3404986075), (2.75, 0.0), (0.0, 0.0)),
  ]
}

///|
/// b_slot6_2020_extrusion builds the 20 x 20 B-slot6 A profile as one closed
/// solid. It sweeps along +Z from `z = 0`; pass `orient_to_reference=true` to
/// lie along -Y with the section in the XZ plane, matching the reference file's
/// axis convention.
pub fn b_slot6_2020_extrusion(
  length_mm : Double,
  detail~ : @common.DetailLevel = Detailed,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @common.require_positive("extrusion length", length_mm) {
    Err(e) => Err(e)
    Ok(_) => {
      let body = @cad.ExtrudedArcProfile::new(b_slot6_2020_outer(), length_mm, holes=[
        b_slot6_2020_bore(),
      ]).as_shape()
      let features = @common.FeatureRecord::new(
        modeled=[
          "body", "four-t-slot-cavities", "slot-neck-chamfers", "diagonal-webs",
          "outer-corner-radii", "lobed-central-bore",
        ],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="end-caps",
            reason="end caps and end machining are not modelled",
          ),
        ],
      )
      let component = @common.Component::new(
        name="BSLOT6-2020-L\{@cad.fmt_double(length_mm, None)}",
        metadata=@common.Metadata::new(
          designation="2020 B-slot6 A extrusion",
          standard="vendor profile (step.parts Profile-20x20-B-Slot6_A)",
          family="extrusion profile",
          size="2020",
          source="step.parts Profile-20x20-B-Slot6_A section; analytic lines and arcs",
        ),
        description="20 x 20 aluminium T-slot extrusion (B-slot6 A): four 6 mm-neck slots with 6.8 mm mouths, 1 mm rounded outer corners, four diagonal corner webs, and a lobed central bore. No end machining.",
        features~,
      ).add_layer(body, name="body", color~)
      if orient_to_reference {
        Ok(component.rotate_x(90.0))
      } else {
        Ok(component)
      }
    }
  }
}
