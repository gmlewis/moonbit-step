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
/// set_screw_shaft_collar builds a set-screw shaft collar whose radial
/// set-screw hole is real trimmed geometry.
///
/// Axis +Z, from `z = 0` to `z = width`. The bore, outside, and radial hole are
/// true cylinders; the four rim chamfers are 45 degree analytic cones. The hole
/// runs along +Y at mid-width and opens into the bore, so the exported solid is
/// one trimmed `MANIFOLD_SOLID_BREP`. The hole diameter defaults to the ISO
/// metric internal minor diameter (the tap drill) of `thread`; pass
/// `drill_diameter_mm` to reproduce a measured reference hole. The thread
/// itself is not modelled: a `set-screw-thread` connector declares it.
///
/// The flat writer cannot trim a radial hole, so this family's portable output
/// is `Component::write_step_evaluated` (OCCT). `Component::to_step` remains
/// nominal and is not the accepted artifact. No holding torque, material, or
/// strength claim is made.
pub fn set_screw_shaft_collar(
  bore_mm : Double,
  outer_diameter_mm : Double,
  width_mm : Double,
  thread~ : @standards.MetricSize = @standards.MetricSize::M5,
  drill_diameter_mm? : Double,
  chamfer_mm~ : Double = 0.2,
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
  let thread_spec = @standards.ThreadSpec::coarse(thread)
  let drill_is_default = drill_diameter_mm is None
  let drill = match drill_diameter_mm {
    Some(d) => d
    None => thread_spec.internal_minor_diameter_mm()
  }
  match @common.require_positive("set-screw drill diameter", drill) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if drill >= width_mm {
    return Err(
      @common.InvalidParameter(
        "set-screw hole must be narrower than the collar width",
      ),
    )
  }
  if drill >= bore_mm {
    return Err(
      @common.InvalidParameter(
        "set-screw hole must be narrower than the collar bore",
      ),
    )
  }
  if drill >= 2.0 * wall {
    return Err(
      @common.InvalidParameter(
        "set-screw hole must be narrower than the full annular wall (outer diameter minus bore)",
      ),
    )
  }
  let drill_radius = drill / 2.0
  let base = @cad.RevolvedProfile::chamfered_tube(
    outer_diameter_mm,
    bore_mm,
    width_mm,
    outer_bottom_chamfer=chamfer_mm,
    outer_top_chamfer=chamfer_mm,
    inner_bottom_chamfer=chamfer_mm,
    inner_top_chamfer=chamfer_mm,
  ).as_shape()
  // A radial drill along +Y, starting inside the bore void and running past the
  // outside surface, so the boolean opens a clean circular hole.
  let drill_length = wall + 2.0 * drill_radius
  let cutter = @cad.Cylinder::new(drill, drill_length)
    .with_name("set-screw-drill")
    .rotate_x(-90.0)
    .translate(y=bore_mm / 2.0 - drill_radius, z=width_mm / 2.0)
  let body = @cad.difference(base.with_name("body"), [cutter], name="body")
  let features = @common.FeatureRecord::new(
    modeled=[
      "body", "outside-cylinder", "bore", "rim-chamfers", "set-screw-hole",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="set-screw-thread",
        reason="the tapped thread is declared by the set-screw-thread connector but not modelled",
      ),
      @common.Omission::new(
        feature="set-screw",
        reason="the set screw is a separate part and is not modelled",
      ),
      @common.Omission::new(
        feature="holding-torque-and-material",
        reason="nominal geometry only; no holding torque, material, or strength claim",
      ),
    ],
  )
  Ok(
    with_set_screw_collar_connectors(
      @common.Component::new(
        name="set-screw-shaft-collar-\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
        metadata=@common.Metadata::new(
          designation="Set-screw shaft collar \{@cad.fmt_double(bore_mm, None)} bore x \{@cad.fmt_double(outer_diameter_mm, None)} OD x \{@cad.fmt_double(width_mm, None)}, \{thread_spec.size.designation()} set screw",
          family="shaft collar",
          size="\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
          source="Parametric collar with a real radial set-screw hole; thread data from the ISO metric table. The free-state shape is not a standard table.",
        ),
        description="Set-screw shaft collar with analytic bore, outside cylinder, 45 degree rim chamfers, and one radial set-screw hole. The ISO metric thread is declared by a connector, not modelled. Use write_step_evaluated for the trimmed solid.",
        features~,
      ).add_layer(body.shape_intent(), name="body", color~),
      bore_mm,
      outer_diameter_mm,
      width_mm,
      thread_spec,
      drill,
      wall,
      drill_is_default,
    ),
  )
}

///|
/// with_set_screw_collar_connectors attaches the bore, outside seat, both
/// faces, and the radial set-screw thread and hole frames.
fn with_set_screw_collar_connectors(
  component : @common.Component,
  bore_mm : Double,
  outer_diameter_mm : Double,
  width_mm : Double,
  thread_spec : @standards.ThreadSpec,
  drill_mm : Double,
  wall_mm : Double,
  drill_is_default : Bool,
) -> @common.Component {
  let outer_radius = outer_diameter_mm / 2.0
  let mid_width = width_mm / 2.0
  let hole_placement = @common.Placement::translation(
    0.0, outer_radius, mid_width,
  )
  let hole_note = if drill_is_default {
    "ISO tap drill \{@cad.fmt_double(drill_mm, None)} mm"
  } else {
    "modeled hole \{@cad.fmt_double(drill_mm, None)} mm (caller-supplied envelope)"
  }
  with_shaft_collar_connectors(component, bore_mm, outer_diameter_mm, width_mm)
  .with_connector_unchecked(
    @common.MateConnector::new(
      "set-screw-thread",
      placement=hole_placement,
      axis=(0.0, -1.0, 0.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=thread_spec.nominal_diameter_mm,
      depth_mm=wall_mm,
      description="\{thread_spec.designation(external=false)} declared thread; \{hole_note}; threads not modelled",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "set-screw-hole",
      placement=hole_placement,
      axis=(0.0, -1.0, 0.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=drill_mm,
      depth_mm=wall_mm,
      description="modelled radial tap-drill hole",
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
