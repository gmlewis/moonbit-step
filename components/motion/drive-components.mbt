///|
/// Numerical tolerance used to classify a declared diametral fit as clearance,
/// nominal, or interference.
const DRIVE_FIT_EPS : Double = 1.0e-9

///|
/// Default flange outside-diameter margin beyond the sleeve, millimetres.
const FLANGED_HOUSING_FLANGE_MARGIN_MM : Double = 18.0

///|
/// Default bolt-circle diameter margin beyond the sleeve, millimetres.
const FLANGED_HOUSING_BOLT_CIRCLE_MARGIN_MM : Double = 8.0

///|
/// rigid_coupling builds a plain rigid sleeve coupling between two equal
/// shafts.
///
/// Frame: the sleeve axis is +Z and the coupling runs from `z = 0` to
/// `z = length_mm`. The bore is a single through bore of
/// `bore_diameter_mm`; the coupling is a solid of revolution with analytic
/// outer and inner cylinders.
///
/// This is a geometric sleeve only: it has no keyway, set screw, clamp slit,
/// flexible element, or misalignment allowance, and it makes no torque or
/// load-capacity claim.
pub fn rigid_coupling(
  bore_diameter_mm : Double,
  outer_diameter_mm : Double,
  length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("rigid coupling bore", bore_diameter_mm),
    @common.require_positive(
      "rigid coupling outside diameter", outer_diameter_mm,
    ),
    @common.require_positive("rigid coupling length", length_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if bore_diameter_mm >= outer_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "rigid coupling bore must be smaller than its outside diameter",
      ),
    )
  }
  let body = @cad.RevolvedProfile::tube(
    outer_diameter_mm, bore_diameter_mm, length_mm,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["sleeve", "through-bore", "outer-cylinder"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="shaft-retention",
        reason="no keyway, set screw, clamp slit, or press-fit tolerance is modelled",
      ),
      @common.Omission::new(
        feature="flexible-element",
        reason="a rigid sleeve has no elastomer, spring, or misalignment allowance",
      ),
    ],
  )
  let component = @common.Component::new(
    name="rigid-coupling-\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Rigid sleeve coupling OD \{@cad.fmt_double(outer_diameter_mm, None)} / bore \{@cad.fmt_double(bore_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
      family="rigid coupling",
      length_mm~,
      source="Generic parametric rigid sleeve coupling: a tube with a through bore. No keyway, set screw, or torque rating is implied.",
    ),
    description="Plain rigid sleeve coupling: one analytic tube with a through bore. No keyway, set screw, clamp slit, flexible element, or torque claim.",
    features~,
  ).add_layer(body, name="body", color~)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=length_mm,
        description="through bore, entered from the z = 0 end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=length_mm,
        description="through bore, entered from the z = length end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=outer_diameter_mm,
        depth_mm=length_mm,
        description="outer cylindrical surface of the sleeve",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=outer_diameter_mm,
        description="negative-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=outer_diameter_mm,
        description="positive-Z end face",
      ),
    ),
  )
}

///|
/// declared_fit classifies a signed diametral allowance as a named fit.
///
/// A positive allowance is clearance (`Free`), a negative allowance is
/// interference (`Press`), and zero is `Nominal`. The value is recorded on the
/// connector; it never changes the nominal geometry.
fn declared_fit(allowance_mm : Double) -> @cad.Fit {
  if allowance_mm > DRIVE_FIT_EPS {
    @cad.Fit::Free
  } else if allowance_mm < -DRIVE_FIT_EPS {
    @cad.Fit::Press
  } else {
    @cad.Fit::Nominal
  }
}

///|
/// drive_circle_loop returns a counter-clockwise circle as four arcs, which the
/// arc compiler turns into one analytic cylindrical face.
fn drive_circle_loop(
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
/// flanged_bearing_housing builds a flanged round bearing housing: a sleeve with
/// a bearing seat bore and a bolt-on flange at one end.
///
/// Frame: the mounting face is `z = 0` (outward normal -Z); the flange runs from
/// `z = 0` to `z = flange_thickness_mm`; the sleeve runs from `z = 0` to
/// `z = flange_thickness_mm + bearing_width_mm`. The bearing seat is the sleeve
/// bore of diameter `bearing_outer_diameter_mm + fit_mm`; it is a through bore.
/// The flange is an annular plate around the sleeve with `bolt_count` clearance
/// holes on a bolt circle.
///
/// The declared `fit_mm` is recorded on the seat connector: positive clearance,
/// negative interference, zero nominal. The fit is a declaration; no tolerance
/// class, and no bearing life, load, or safety claim is made.
///
/// Construction is layered: the sleeve is one solid of revolution and the
/// flange is one analytic annulus with circular holes. The flange's inner
/// cylindrical face touches the sleeve's outer face over the flange thickness,
/// so the layer volumes sum exactly and the bodies do not overlap.
pub fn flanged_bearing_housing(
  bearing_outer_diameter_mm : Double,
  bearing_width_mm : Double,
  wall_mm~ : Double = 3.0,
  fit_mm~ : Double = 0.0,
  flange_diameter_mm~ : Double = 0.0,
  flange_thickness_mm~ : Double = 4.0,
  bolt_circle_diameter_mm~ : Double = 0.0,
  bolt_hole_diameter_mm~ : Double = 5.5,
  bolt_count~ : Int32 = 4,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive(
      "flanged housing bearing outside diameter", bearing_outer_diameter_mm,
    ),
    @common.require_positive("flanged housing bearing width", bearing_width_mm),
    @common.require_positive("flanged housing wall", wall_mm),
    @common.require_positive(
      "flanged housing flange thickness", flange_thickness_mm,
    ),
    @common.require_positive("flanged housing bolt hole", bolt_hole_diameter_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if bolt_count <= 0 {
    return Err(
      @common.InvalidParameter("flanged housing needs at least one bolt hole"),
    )
  }
  let seat_diameter = bearing_outer_diameter_mm + fit_mm
  if seat_diameter <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "flanged housing seat fit leaves no bearing seat",
      ),
    )
  }
  let sleeve_outer_diameter = seat_diameter + 2.0 * wall_mm
  let flange_diameter = if flange_diameter_mm > 0.0 {
    flange_diameter_mm
  } else {
    sleeve_outer_diameter + FLANGED_HOUSING_FLANGE_MARGIN_MM
  }
  if flange_diameter <= sleeve_outer_diameter {
    return Err(
      @common.InvalidParameter(
        "flanged housing flange must be larger than the sleeve",
      ),
    )
  }
  let bolt_circle = if bolt_circle_diameter_mm > 0.0 {
    bolt_circle_diameter_mm
  } else {
    sleeve_outer_diameter + FLANGED_HOUSING_BOLT_CIRCLE_MARGIN_MM
  }
  if bolt_circle <= 0.0 {
    return Err(
      @common.InvalidParameter("flanged housing bolt circle must be positive"),
    )
  }
  let sleeve_r = sleeve_outer_diameter / 2.0
  let flange_r = flange_diameter / 2.0
  let bolt_r = bolt_hole_diameter_mm / 2.0
  let circle_r = bolt_circle / 2.0
  if circle_r - bolt_r < sleeve_r {
    return Err(
      @common.InvalidParameter("flanged housing bolt holes run into the sleeve"),
    )
  }
  if circle_r + bolt_r > flange_r {
    return Err(
      @common.InvalidParameter(
        "flanged housing bolt holes run outside the flange",
      ),
    )
  }
  let chord = 2.0 *
    circle_r *
    @math.sin(@math.PI / Double::from_int(bolt_count))
  if bolt_count > 1 && chord < 2.0 * bolt_r {
    return Err(@common.InvalidParameter("flanged housing bolt holes overlap"))
  }
  let total_length = flange_thickness_mm + bearing_width_mm
  let sleeve = @cad.RevolvedProfile::tube(
    sleeve_outer_diameter, seat_diameter, total_length,
  ).as_shape()
  let bolt_loops : Array[Array[@cad.ProfileSegment]] = []
  for i in 0..<bolt_count {
    let theta = 2.0 *
      @math.PI *
      Double::from_int(i) /
      Double::from_int(bolt_count)
    bolt_loops.push(
      drive_circle_loop(
        circle_r * @math.cos(theta),
        circle_r * @math.sin(theta),
        bolt_r,
      ),
    )
  }
  let flange_holes : Array[Array[@cad.ProfileSegment]] = [
    drive_circle_loop(0.0, 0.0, sleeve_r),
  ]
  flange_holes.push_iter(bolt_loops.iter())
  let flange = @cad.ExtrudedArcProfile::new(
    drive_circle_loop(0.0, 0.0, flange_r),
    flange_thickness_mm,
    holes=flange_holes,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["sleeve", "bearing-seat", "mounting-flange", "bolt-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="bearing-internals",
        reason="the housing takes a separate bearing; rolling elements, shields, and seals are not modelled",
      ),
      @common.Omission::new(
        feature="retaining-and-lubrication-features",
        reason="no circlip groove, grease hole, or lip seal is modelled",
      ),
      @common.Omission::new(
        feature="strength-and-life",
        reason="geometry alone does not establish bearing life, load capacity, or safety",
      ),
    ],
  )
  let mut component = @common.Component::new(
      name="flanged-bearing-housing-\{@cad.fmt_double(bearing_outer_diameter_mm, None)}",
      metadata=@common.Metadata::new(
        designation="Flanged bearing housing for \{@cad.fmt_double(bearing_outer_diameter_mm, None)} mm bearing",
        family="flanged bearing housing",
        length_mm=total_length,
        source="Parametric flanged round housing: seat diameter = bearing OD + declared fit, sleeve wall \{@cad.fmt_double(wall_mm, None)} mm, flange \{@cad.fmt_double(flange_diameter, None)} mm with \{bolt_count} bolt holes. No bearing internals or rating.",
      ),
      description="Flanged round bearing housing: an analytic sleeve with a bearing-seat bore and a bolt-on flange. The declared seat fit is metadata; no bearing life or load claim is made.",
      features~,
    )
    .add_layer(sleeve, name="sleeve", color~)
    .add_layer(flange, name="flange", color~)
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bearing-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=seat_diameter,
        depth_mm=total_length,
        fit=declared_fit(fit_mm),
        description="bearing seat bore; declared fit allowance \{@cad.fmt_double(fit_mm, None)} mm",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mount-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=flange_diameter,
        description="flange mounting face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "flange-face",
        placement=@common.Placement::translation(0.0, 0.0, flange_thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=flange_diameter,
        description="inner flange face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, flange_thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=sleeve_outer_diameter,
        depth_mm=bearing_width_mm,
        description="sleeve outer cylindrical surface",
      ),
    )
  for i in 0..<bolt_count {
    let theta = 2.0 *
      @math.PI *
      Double::from_int(i) /
      Double::from_int(bolt_count)
    component = component.with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-\{i + 1}",
        placement=@common.Placement::translation(
          circle_r * @math.cos(theta),
          circle_r * @math.sin(theta),
          0.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=flange_thickness_mm,
        fit=@cad.Fit::Free,
        description="flange bolt clearance hole",
      ),
    )
  }
  Ok(component)
}
