///|
/// hinge builds a generic barrel (knuckle) hinge with two leaves, a pin, and
/// analytic pin bores.
///
/// Frame: the hinge axis is +X at `(y = 0, z = thickness / 2)`. Leaf A extends
/// along +Y and leaf B along -Y in the closed position, both spanning
/// `x = -length/2 .. length/2` and `z = 0 .. thickness`. The knuckles are tubes
/// of `knuckle_diameter` on the axis; odd knuckles belong to leaf A and even
/// knuckles to leaf B. The pin is a separate cylindrical layer that runs
/// through every knuckle with `pin_extension` beyond each leaf end.
///
/// `leaf_angle_deg` rotates leaf B about the hinge axis (positive opens the
/// leaf below the base plane, matching a right-hand rotation about +X). The
/// knuckles, pin, and leaf A do not move. This is an engineering envelope: the
/// leaves overlap the knuckle barrels nominally (the flat writer concatenates
/// the layers), screw holes are through holes, and no load, fatigue, or safety
/// rating is implied.
pub fn hinge(
  length_mm : Double,
  width_mm : Double,
  thickness_mm : Double,
  pin_diameter_mm : Double,
  knuckle_diameter_mm? : Double,
  knuckles~ : Int32 = 3,
  knuckle_gap_mm~ : Double = 0.3,
  hole_diameter_mm~ : Double = 3.4,
  hole_spacing_mm? : Double,
  pin_extension_mm~ : Double = 2.0,
  leaf_angle_deg~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let knuckle_od = match knuckle_diameter_mm {
    Some(d) => d
    None => thickness_mm
  }
  match
    mechanism_checks([
      ("hinge leaf length", length_mm),
      ("hinge leaf width", width_mm),
      ("hinge leaf thickness", thickness_mm),
      ("hinge pin diameter", pin_diameter_mm),
      ("hinge knuckle diameter", knuckle_od),
      ("hinge hole diameter", hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    mechanism_non_negative_checks([("hinge pin extension", pin_extension_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if knuckles < 2 {
    return Err(@common.InvalidParameter("hinge needs at least two knuckles"))
  }
  if pin_diameter_mm >= knuckle_od {
    return Err(
      @common.InvalidDimension(
        "hinge pin diameter must be smaller than the knuckle diameter",
      ),
    )
  }
  if knuckle_od > thickness_mm + @step.TOL_1E9 {
    return Err(
      @common.InvalidDimension(
        "hinge knuckle diameter must not exceed the leaf thickness in this envelope",
      ),
    )
  }
  if knuckle_gap_mm < 0.0 {
    return Err(@common.InvalidDimension("hinge knuckle gap must be >= 0"))
  }
  let segment = length_mm / knuckles.to_double()
  if segment - knuckle_gap_mm <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "hinge knuckle gap leaves no knuckle length; reduce the gap or the knuckle count",
      ),
    )
  }
  let spacing = match hole_spacing_mm {
    Some(s) => s
    None => length_mm * 0.6
  }
  if spacing <= hole_diameter_mm || spacing >= length_mm {
    return Err(
      @common.InvalidDimension(
        "hinge hole spacing must be larger than the hole diameter and smaller than the leaf length",
      ),
    )
  }
  let hole_radius = hole_diameter_mm / 2.0
  let hole_y = width_mm * 0.7
  if hole_y + hole_radius >= width_mm || hole_radius >= width_mm / 2.0 {
    return Err(
      @common.InvalidDimension("hinge screw holes do not fit the leaf width"),
    )
  }
  let angle = leaf_angle_deg * @math.PI / 180.0
  let cos_a = @math.cos(angle)
  let sin_a = @math.sin(angle)
  // Leaves are built centred on z = 0 and placed at the hinge mid-plane.
  let hole_loops_a = [
    circle_loop(-spacing / 2.0, hole_y, hole_radius),
    circle_loop(spacing / 2.0, hole_y, hole_radius),
  ]
  let leaf_a = @cad.ExtrudedArcProfile::new(
    rect_loop(-length_mm / 2.0, 0.0, length_mm / 2.0, width_mm),
    thickness_mm,
    holes=hole_loops_a,
  ).as_shape()
  let hole_loops_b = [
    circle_loop(-spacing / 2.0, -hole_y, hole_radius),
    circle_loop(spacing / 2.0, -hole_y, hole_radius),
  ]
  let leaf_b = @cad.ExtrudedArcProfile::new(
    rect_loop(-length_mm / 2.0, -width_mm, length_mm / 2.0, 0.0),
    thickness_mm,
    holes=hole_loops_b,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=[
      "leaf-a", "leaf-b", "knuckles", "pin", "pin-bores", "through-screw-holes",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="leaf-edge-breaks",
        reason="no edge treatment is asserted",
      ),
      @common.Omission::new(
        feature="knuckle-to-leaf-fillet",
        reason="the leaf and knuckle bodies overlap nominally; no blend is modelled",
      ),
      @common.Omission::new(
        feature="pin-retention",
        reason="no set screw, peening, or retaining feature is modelled",
      ),
    ],
  )
  let name = "hinge-\{@cad.fmt_double(length_mm, None)}x\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}"
  let mut component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Hinge L\{@cad.fmt_double(length_mm, None)} W\{@cad.fmt_double(width_mm, None)} t\{@cad.fmt_double(thickness_mm, None)}",
        family="barrel hinge (engineering envelope)",
        size="\{@cad.fmt_double(length_mm, None)}x\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
        source="Parametric knuckle hinge envelope with analytic pin bores and through screw holes. No standard or vendor part is implied.",
      ),
      description="Barrel hinge with two leaves, alternating knuckles, a separate pin, through screw holes, and analytic pin bores. The pin is an envelope cylinder; no retention feature is modelled.",
      features~,
    )
    .add_layer(leaf_a, name="leaf-a", color~)
    .add_layer(
      leaf_b,
      name="leaf-b",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, 0.0, thickness_mm / 2.0),
        @common.Placement::compose(
          @common.Placement::rotation_x(leaf_angle_deg),
          @common.Placement::translation(0.0, 0.0, -thickness_mm / 2.0),
        ),
      ),
    )
  for k in 0..<knuckles {
    let x_start = -length_mm / 2.0 +
      k.to_double() * segment +
      knuckle_gap_mm / 2.0
    let knuckle_length = segment - knuckle_gap_mm
    let knuckle = mechanism_tube_z(knuckle_od, pin_diameter_mm, knuckle_length)
    let owner = if k % 2 == 0 { "a" } else { "b" }
    component = component.add_layer(
      knuckle,
      name="knuckle-\{k + 1}-leaf-\{owner}",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(x_start, 0.0, thickness_mm / 2.0),
        @common.Placement::rotation_y(90.0),
      ),
    )
  }
  let pin = mechanism_cylinder_z(
    pin_diameter_mm,
    length_mm + 2.0 * pin_extension_mm,
  )
  component = component.add_layer(
    pin,
    name="pin",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::compose(
      @common.Placement::translation(
        -length_mm / 2.0 - pin_extension_mm,
        0.0,
        thickness_mm / 2.0,
      ),
      @common.Placement::rotation_y(90.0),
    ),
  )
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hinge-axis",
        placement=@common.Placement::translation(0.0, 0.0, thickness_mm / 2.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pin_diameter_mm,
        depth_mm=length_mm,
        description="hinge rotation axis along +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-bore",
        placement=@common.Placement::translation(
          -length_mm / 2.0,
          0.0,
          thickness_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=pin_diameter_mm,
        depth_mm=length_mm,
        description="knuckle pin bore; entered from the negative-X end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "leaf-face-a",
        placement=@common.Placement::translation(
          0.0,
          width_mm,
          thickness_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="outer face of leaf A",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "leaf-face-b",
        placement=@common.Placement::at(
          0.0,
          -width_mm * cos_a,
          -width_mm * sin_a + thickness_mm / 2.0,
          rx=leaf_angle_deg,
        ),
        axis=(0.0, -cos_a, -sin_a),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="outer face of leaf B, rotated with the leaf",
      ),
    )
  for (label, sign) in [("a", 1.0), ("b", -1.0)] {
    for i in 0..<2 {
      let x = if i == 0 { -spacing / 2.0 } else { spacing / 2.0 }
      let local_y = sign * hole_y
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "mount-hole-\{label}-\{i + 1}",
          placement=@common.Placement::at(
            x,
            local_y * cos_a,
            local_y * sin_a + thickness_mm / 2.0,
            rx=leaf_angle_deg,
          ),
          axis=(0.0, -sin_a, cos_a),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=hole_diameter_mm,
          depth_mm=thickness_mm,
          description="through screw hole in leaf \{label}",
        ),
      )
    }
  }
  Ok(out)
}
