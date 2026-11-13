///|
/// NemaFrame carries the mounting interface of one NEMA stepper-motor frame.
///
/// The frame size, bolt spacing, mounting-hole diameter, pilot diameter, and
/// shaft diameter are the standardized interface. Body length, shaft length,
/// and pilot length are motor-specific envelope values, so callers can
/// override them.
///
/// Dimensions are millimetres. The motor origin is the rear face of the body
/// with the shaft pointing along +Z.
pub(all) struct NemaFrame {
  designation : String
  frame_mm : Double
  bolt_spacing_mm : Double
  mounting_hole_diameter_mm : Double
  pilot_diameter_mm : Double
  pilot_length_mm : Double
  shaft_diameter_mm : Double
  default_shaft_length_mm : Double
}

///|
/// nema_designations returns every frame in the built-in table.
pub fn nema_designations() -> Array[String] {
  ["NEMA17", "NEMA23"]
}

///|
/// nema_frame looks up a NEMA frame mounting interface.
///
/// The interface values come from the NEMA motor-frame convention; the pilot
/// and shaft values are the standard frame values. The step.parts reference
/// models use a smaller simplified pilot boss but the same frame, bolt
/// spacing, mounting holes, and shaft diameter (see the golden manifest).
pub fn nema_frame(designation : String) -> Result[NemaFrame, @common.SpecError] {
  let normalized = designation.trim().to_owned().to_upper()
  match normalized {
    "NEMA17" | "17" | "NEMA-17" =>
      Ok({
        designation: "NEMA17",
        frame_mm: 42.3,
        bolt_spacing_mm: 31.0,
        mounting_hole_diameter_mm: 3.384,
        pilot_diameter_mm: 22.0,
        pilot_length_mm: 3.384,
        shaft_diameter_mm: 5.0,
        default_shaft_length_mm: 11.421,
      })
    "NEMA23" | "23" | "NEMA-23" =>
      Ok({
        designation: "NEMA23",
        frame_mm: 56.4,
        bolt_spacing_mm: 47.14,
        mounting_hole_diameter_mm: 4.512,
        pilot_diameter_mm: 38.1,
        pilot_length_mm: 4.512,
        shaft_diameter_mm: 6.35,
        default_shaft_length_mm: 15.228,
      })
    other =>
      Err(
        @common.InvalidSize(
          "unsupported NEMA frame: \{other}; supported: NEMA17, NEMA23",
        ),
      )
  }
}

///|
/// validate_nema_interface checks that the frame's interface dimensions form a
/// physically possible mounting pattern.
fn validate_nema_interface(
  frame : NemaFrame,
) -> Result[Unit, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("NEMA frame size", frame.frame_mm),
    @common.require_positive("NEMA bolt spacing", frame.bolt_spacing_mm),
    @common.require_positive(
      "NEMA mounting hole diameter",
      frame.mounting_hole_diameter_mm,
    ),
    @common.require_positive("NEMA pilot diameter", frame.pilot_diameter_mm),
    @common.require_positive("NEMA pilot length", frame.pilot_length_mm),
    @common.require_positive("NEMA shaft diameter", frame.shaft_diameter_mm),
    @common.require_positive(
      "NEMA default shaft length",
      frame.default_shaft_length_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if frame.bolt_spacing_mm + frame.mounting_hole_diameter_mm >= frame.frame_mm {
    return Err(
      @common.InvalidParameter(
        "NEMA bolt spacing plus hole diameter does not fit the frame",
      ),
    )
  }
  if frame.pilot_diameter_mm >= frame.frame_mm {
    return Err(
      @common.InvalidParameter(
        "NEMA pilot diameter must be smaller than the frame",
      ),
    )
  }
  if frame.shaft_diameter_mm >= frame.pilot_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "NEMA shaft diameter must be smaller than the pilot",
      ),
    )
  }
  Ok(())
}

///|
/// nema_square_loop returns the square body outline as four counter-clockwise
/// line segments centered on the origin.
fn nema_square_loop(size_mm : Double) -> Array[@cad.ProfileSegment] {
  let h = size_mm / 2.0
  [
    @cad.SegmentLine((-h, -h), (h, -h)),
    @cad.SegmentLine((h, -h), (h, h)),
    @cad.SegmentLine((h, h), (-h, h)),
    @cad.SegmentLine((-h, h), (-h, -h)),
  ]
}

///|
/// nema_circle_loop returns one counter-clockwise circular hole as four
/// 90-degree minor arcs. The arc profile compiler turns each arc into an
/// analytic cylindrical face, so a through hole is one cylinder rather than a
/// tessellated polygon.
fn nema_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let p0 = (cx + radius, cy)
  let p90 = (cx, cy + radius)
  let p180 = (cx - radius, cy)
  let p270 = (cx, cy - radius)
  let center = (cx, cy)
  [
    @cad.SegmentArc(p0, p90, center),
    @cad.SegmentArc(p90, p180, center),
    @cad.SegmentArc(p180, p270, center),
    @cad.SegmentArc(p270, p0, center),
  ]
}

///|
/// nema_stepper_motor builds a NEMA stepper-motor envelope.
///
/// Geometry, Z-up with the rear face at `z = 0`:
/// - square body `frame_mm` by `frame_mm` by `body_length_mm`;
/// - four mounting holes at the frame bolt spacing, through the body;
/// - a front pilot boss and a plain shaft on +Z.
///
/// The body, pilot boss, and shaft are separate watertight solids because the
/// kernel-free STEP writer does not trim a union. Stator laminations, windings,
/// terminals, a rear shaft, and a shaft flat are not modelled.
///
/// `shaft_length_mm` and `shaft_diameter_mm` override the frame defaults.
pub fn nema_stepper_motor(
  frame : NemaFrame,
  body_length_mm : Double,
  shaft_length_mm? : Double,
  shaft_diameter_mm? : Double,
  pilot_diameter_mm? : Double,
  pilot_length_mm? : Double,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  match validate_nema_interface(frame) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("motor body length", body_length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let shaft_length = match shaft_length_mm {
    Some(v) => v
    None => frame.default_shaft_length_mm
  }
  let shaft_diameter = match shaft_diameter_mm {
    Some(v) => v
    None => frame.shaft_diameter_mm
  }
  let pilot_diameter = match pilot_diameter_mm {
    Some(v) => v
    None => frame.pilot_diameter_mm
  }
  let pilot_length = match pilot_length_mm {
    Some(v) => v
    None => frame.pilot_length_mm
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("motor shaft length", shaft_length),
    @common.require_positive("motor shaft diameter", shaft_diameter),
    @common.require_positive("motor pilot diameter", pilot_diameter),
    @common.require_positive("motor pilot length", pilot_length),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if shaft_diameter >= pilot_diameter {
    return Err(
      @common.InvalidParameter(
        "motor shaft diameter must be smaller than the pilot",
      ),
    )
  }
  if pilot_diameter >= frame.frame_mm {
    return Err(
      @common.InvalidParameter(
        "motor pilot diameter must be smaller than the frame",
      ),
    )
  }
  let _ = detail
  let half = frame.bolt_spacing_mm / 2.0
  let radius = frame.mounting_hole_diameter_mm / 2.0
  let holes = [
    nema_circle_loop(half, half, radius),
    nema_circle_loop(-half, half, radius),
    nema_circle_loop(-half, -half, radius),
    nema_circle_loop(half, -half, radius),
  ]
  let body = @cad.ExtrudedArcProfile::new(
    nema_square_loop(frame.frame_mm),
    body_length_mm,
    holes~,
  ).as_shape()
  let base_color = match color {
    Some(c) => c
    None => @cad.Rgb::grey()
  }
  let features = @common.FeatureRecord::new(
    modeled=["body", "mounting-hole-pattern", "pilot-boss", "shaft"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="stator-laminations",
        reason="internal motor construction is not modelled",
      ),
      @common.Omission::new(
        feature="windings-and-terminals",
        reason="electrical internals and connectors are not modelled",
      ),
      @common.Omission::new(
        feature="rear-shaft",
        reason="this builder models the single-shaft configuration",
      ),
      @common.Omission::new(
        feature="shaft-flat-or-keyway",
        reason="the shaft is a plain cylinder; motor shafts vary",
      ),
    ],
  )
  let name = "\{frame.designation}-stepper-\{@cad.fmt_double(body_length_mm, None)}"
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="\{frame.designation} stepper motor, \{@cad.fmt_double(body_length_mm, None)} mm body",
      standard="NEMA motor frame interface (frame, bolt spacing, mounting holes, pilot, shaft)",
      family="stepper motor envelope",
      size=frame.designation,
      length_mm=body_length_mm,
      source="NEMA frame interface dimensions; body and shaft lengths are envelope parameters. The step.parts reference confirms frame, bolt spacing, mounting holes, and shaft.",
    ),
    description="NEMA stepper-motor envelope: square body with four mounting holes, front pilot boss, and plain shaft. Stator, windings, terminals, rear shaft, and shaft flat are omitted.",
    features~,
  ).add_layer(body, name="body", color=base_color)
  if pilot_length > 0.0 {
    component = component.add_layer(
      @cad.Cylinder::new(pilot_diameter, pilot_length),
      name="pilot-boss",
      color=@cad.Rgb::blue(),
      placement=@common.Placement::translation(0.0, 0.0, body_length_mm),
    )
  }
  component = component.add_layer(
    @cad.Cylinder::new(shaft_diameter, shaft_length),
    name="shaft",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::translation(
      0.0,
      0.0,
      body_length_mm + pilot_length,
    ),
  )
  let front_z = body_length_mm
  let shaft_z = body_length_mm + pilot_length
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-face",
        placement=@common.Placement::translation(0.0, 0.0, front_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=frame.frame_mm,
        description="front mounting face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-pattern",
        placement=@common.Placement::translation(0.0, 0.0, front_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=frame.bolt_spacing_mm,
        description="four-hole mounting pattern datum; +X/+Y is the (+,+) hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pilot",
        placement=@common.Placement::translation(0.0, 0.0, front_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=pilot_diameter,
        depth_mm=pilot_length,
        description="pilot boss that enters the mating plate bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft",
        placement=@common.Placement::translation(0.0, 0.0, shaft_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=shaft_diameter,
        depth_mm=shaft_length,
        description="plain output shaft, pointing +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rear-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=frame.frame_mm,
        description="rear face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-1",
        placement=@common.Placement::translation(half, half, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=body_length_mm,
        description="mounting hole at (+X,+Y)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-2",
        placement=@common.Placement::translation(-half, half, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=body_length_mm,
        description="mounting hole at (-X,+Y)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-3",
        placement=@common.Placement::translation(-half, -half, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=body_length_mm,
        description="mounting hole at (-X,-Y)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-4",
        placement=@common.Placement::translation(half, -half, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=frame.mounting_hole_diameter_mm,
        depth_mm=body_length_mm,
        description="mounting hole at (+X,-Y)",
      ),
    ),
  )
}

///|
/// nema_motor_by_designation looks up a frame and builds the motor in one step.
pub fn nema_motor_by_designation(
  designation : String,
  body_length_mm : Double,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
) -> Result[@common.Component, @common.SpecError] {
  match nema_frame(designation) {
    Ok(frame) => nema_stepper_motor(frame, body_length_mm, detail~)
    Err(e) => Err(e)
  }
}
