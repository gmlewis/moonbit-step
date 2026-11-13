///|
/// shaft_collar builds a plain set-screw-style shaft collar as one analytic
/// annular solid of revolution.
///
/// Axis +Z, from `z = 0` to `z = width`. The bore and outside are true
/// cylinders. The optional 45 degree rim chamfers are analytic cones. A set
/// screw, clamp slit, or keyway is not modelled, and the collar makes no claim
/// about holding torque.
pub fn shaft_collar(
  bore_mm : Double,
  outer_diameter_mm : Double,
  width_mm : Double,
  chamfer_mm~ : Double = 0.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("collar bore", bore_mm),
    @common.require_positive("collar outer diameter", outer_diameter_mm),
    @common.require_positive("collar width", width_mm),
    @common.require_non_negative("collar chamfer", chamfer_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if outer_diameter_mm <= bore_mm {
    return Err(
      @common.InvalidParameter("collar outer diameter must exceed its bore"),
    )
  }
  let wall = (outer_diameter_mm - bore_mm) / 2.0
  if chamfer_mm >= wall || chamfer_mm >= width_mm / 2.0 {
    return Err(
      @common.InvalidParameter("collar chamfer does not fit the collar wall"),
    )
  }
  let body = @cad.RevolvedProfile::chamfered_tube(
    outer_diameter_mm,
    bore_mm,
    width_mm,
    outer_bottom_chamfer=chamfer_mm,
    outer_top_chamfer=chamfer_mm,
    inner_bottom_chamfer=chamfer_mm,
    inner_top_chamfer=chamfer_mm,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "outside-cylinder", "bore", "rim-chamfers"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="set-screw-or-clamp-slit",
        reason="the locking feature is not modelled; no holding torque is claimed",
      ),
      @common.Omission::new(
        feature="material-and-tolerances",
        reason="nominal geometry only",
      ),
    ],
  )
  Ok(
    with_shaft_collar_connectors(
      @common.Component::new(
        name="shaft-collar-\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
        metadata=@common.Metadata::new(
          designation="Shaft collar \{@cad.fmt_double(bore_mm, None)} bore x \{@cad.fmt_double(outer_diameter_mm, None)} OD x \{@cad.fmt_double(width_mm, None)}",
          family="shaft collar",
          size="\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
          source="Parametric collar; no standard table is implied. Bore and outside are exact cylinders.",
        ),
        description="Plain shaft collar with analytic bore, outside cylinder, and 45 degree rim chamfers. No set screw or clamp slit is modelled.",
        features~,
      ).add_layer(body, name="body", color~),
      bore_mm,
      outer_diameter_mm,
      width_mm,
    ),
  )
}

///|
/// with_shaft_collar_connectors attaches the bore, outside seat, and both
/// faces.
fn with_shaft_collar_connectors(
  component : @common.Component,
  bore_mm : Double,
  outer_diameter_mm : Double,
  width_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=bore_mm,
      depth_mm=width_mm,
      description="shaft bore",
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
      depth_mm=width_mm,
      description="outside cylindrical seat",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="face at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-b",
      placement=@common.Placement::translation(0.0, 0.0, width_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="face at z = width",
    ),
  )
}
