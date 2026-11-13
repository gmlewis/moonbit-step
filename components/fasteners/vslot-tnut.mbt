///|
/// SlotTNutSpec carries the boundary dimensions of a slot-6 V-Slot T-nut.
///
/// The nut body is an obround plate: `length_mm` runs along the slot,
/// `width_mm` passes through the slot neck, and `height_mm` is the insertion
/// depth. `thread_diameter_mm` is the nominal thread; the modelled bore is the
/// tap drill, because a true helical thread is not generated here.
pub(all) struct SlotTNutSpec {
  designation : String
  length_mm : Double
  width_mm : Double
  height_mm : Double
  thread_diameter_mm : Double
  tap_drill_mm : Double
}

///|
/// SlotTNutSpec::openbuilds_m5 returns the OpenBuilds drop-in T-nut boundary
/// dimensions for the 6 mm V-Slot: 10 mm long, 6 mm wide, 4.4 mm high, M5
/// thread with a Ø4.2 mm tap drill.
pub fn SlotTNutSpec::openbuilds_m5() -> SlotTNutSpec {
  {
    designation: "OpenBuilds drop-in T-nut M5 (6 mm slot)",
    length_mm: 10.0,
    width_mm: 6.0,
    height_mm: 4.4,
    thread_diameter_mm: 5.0,
    tap_drill_mm: 4.2,
  }
}

///|
/// SlotTNutSpec::validate checks the nut proportions.
fn SlotTNutSpec::validate(
  self : SlotTNutSpec,
) -> Result[Unit, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("T-nut length", self.length_mm),
    @common.require_positive("T-nut width", self.width_mm),
    @common.require_positive("T-nut height", self.height_mm),
    @common.require_positive("T-nut thread diameter", self.thread_diameter_mm),
    @common.require_positive("T-nut tap drill", self.tap_drill_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if self.length_mm <= self.width_mm {
    return Err(@common.InvalidParameter("T-nut length must exceed its width"))
  }
  if self.tap_drill_mm >= self.width_mm {
    return Err(
      @common.InvalidParameter("T-nut bore must be smaller than the body width"),
    )
  }
  Ok(())
}

///|
/// vslot_obround_loop returns a counter-clockwise obround loop with its long
/// axis along X.
///
/// The two ends are semicircular (180 degree minor arcs) and the two straight
/// sides are parallel to X.
fn vslot_obround_loop(
  length_mm : Double,
  width_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let r = width_mm / 2.0
  let lcx = -(length_mm / 2.0 - r)
  let rcx = length_mm / 2.0 - r
  [
    @cad.SegmentLine((lcx, -r), (rcx, -r)),
    @cad.SegmentArc((rcx, -r), (rcx, r), (rcx, 0.0)),
    @cad.SegmentLine((rcx, r), (lcx, r)),
    @cad.SegmentArc((lcx, r), (lcx, -r), (lcx, 0.0)),
  ]
}

///|
/// vslot_t_nut builds a slot-6 V-Slot drop-in T-nut.
///
/// Frame: the obround body spans `z = 0` to `z = height`; the long axis is X
/// (along the extrusion) and the insertion axis is +Z. The thread is a tap-drill
/// bore with a documented helical-thread omission.
///
/// The fit envelope is checked against the V-Slot slot geometry in
/// `vslot_fit_test`: the width must pass the 6.25 mm neck, the length must fit
/// the 11 mm cavity, and the height must fit below the lip.
pub fn vslot_t_nut(
  spec : SlotTNutSpec,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match spec.validate() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let _ = detail
  let r = spec.tap_drill_mm / 2.0
  let hole = vslot_circle_segments(0.0, 0.0, r)
  let body = @cad.ExtrudedArcProfile::new(
    vslot_obround_loop(spec.length_mm, spec.width_mm),
    spec.height_mm,
    holes=[hole],
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "obround-plan", "tap-drill-bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="thread",
        reason="M5 helical thread is represented by the Ø4.2 mm tap drill; thread form is not generated",
      ),
      @common.Omission::new(
        feature="retention-teeth",
        reason="the serrated teeth that bite the anodising are not modelled",
      ),
    ],
  )
  Ok(
    with_slot_t_nut_connectors(
      @common.Component::new(
        name="vslot-t-nut-\{@cad.fmt_double(spec.length_mm, None)}x\{@cad.fmt_double(spec.width_mm, None)}",
        metadata=@common.Metadata::new(
          designation=spec.designation,
          standard="OpenBuilds 6 mm V-Slot drop-in T-nut",
          family="extrusion T-nut",
          size="M\{@cad.fmt_double(spec.thread_diameter_mm, None)}",
          source="OpenBuilds published T-nut bounding dimensions 6 x 10 x 4.4 mm, M5 thread, Ø4.2 mm tap drill.",
        ),
        description="Drop-in T-nut for the 6 mm V-Slot: obround body that passes the slot neck and turns in the cavity. The M5 thread is represented by its tap drill.",
        features~,
      ).add_layer(body, name="body", color~),
      spec,
    ),
  )
}

///|
/// vslot_circle_segments returns a counter-clockwise full circle as four arcs.
fn vslot_circle_segments(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), centre),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), centre),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), centre),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), centre),
  ]
}

///|
/// with_slot_t_nut_connectors attaches the thread, seat face, and slot
/// engagement interfaces.
fn with_slot_t_nut_connectors(
  component : @common.Component,
  spec : SlotTNutSpec,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "thread",
      placement=@common.Placement::translation(0.0, 0.0, spec.height_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=spec.thread_diameter_mm,
      depth_mm=spec.height_mm,
      description="M5 threaded interface; modelled as the tap drill",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "seat-face",
      placement=@common.Placement::translation(0.0, 0.0, spec.height_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.width_mm,
      description="face that seats against the slot lip",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slot-engagement",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::ProfileSlot,
      diameter_mm=spec.width_mm,
      depth_mm=spec.height_mm,
      description="insertion envelope through the slot neck; long axis is X",
    ),
  )
}
