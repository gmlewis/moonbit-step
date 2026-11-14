///|
/// mechanism_helix_body builds the swept helical wire used by the spring
/// builders. The path is inset by one wire radius at each end so the finished
/// spring spans exactly `z = 0 .. free_length`.
fn mechanism_helix_body(
  radius_mm : Double,
  wire_radius_mm : Double,
  free_length_mm : Double,
  active_coils : Int32,
  segments_per_turn : Int32,
) -> Result[@cad.Shape, @common.SpecError] {
  let path_length = free_length_mm - 2.0 * wire_radius_mm
  if path_length <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "spring free length must exceed the wire diameter so the path has positive length",
      ),
    )
  }
  let pitch = path_length / active_coils.to_double()
  if pitch < 2.0 * wire_radius_mm {
    return Err(
      @common.InvalidParameter(
        "spring pitch is smaller than the wire diameter; reduce coils or lengthen the spring",
      ),
    )
  }
  let segments = if segments_per_turn < 8 { 8 } else { segments_per_turn }
  let path = @cad.helix_path(
    pos=(0.0, 0.0, wire_radius_mm),
    size_per_turn=(radius_mm, radius_mm, pitch),
    num_turns=active_coils.to_double(),
    num_segs_per_turn=segments,
    start_angle=0.0,
    clockwise=false,
  )
  let wire_profile : Array[@cad.Vec3] = []
  let wire_segments = 12
  for i in 0..<wire_segments {
    let angle = 2.0 * @math.PI * i.to_double() / wire_segments.to_double()
    wire_profile.push(
      (
        wire_radius_mm * @math.cos(angle),
        0.0,
        wire_radius_mm * @math.sin(angle),
      ),
    )
  }
  let profile = @cad.SweepProfile::new(
    wire_profile,
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  Ok(@cad.SweptProfile::new(path~, profile~, straight_outline=false))
}

///|
/// extension_spring builds a helical extension spring with straight end legs.
///
/// Frame: the coil axis is +Z from `z = 0` to `z = free_length`. Each end carries
/// a straight radial wire leg: the negative-Z leg runs along +X from the coil
/// and the positive-Z leg along -X. Closed hook loops are not modelled; the
/// straight legs are an open-hook substitute and are declared by
/// `hook-leg-a`/`hook-leg-b`.
///
/// No spring rate, initial tension, or fatigue rating is implied.
pub fn extension_spring(
  mean_diameter_mm : Double,
  wire_diameter_mm : Double,
  free_length_mm : Double,
  active_coils : Int32,
  leg_length_mm~ : Double = 10.0,
  segments_per_turn~ : Int32 = 24,
  color~ : @cad.Rgb = @cad.Rgb::cyan(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("extension spring mean diameter", mean_diameter_mm),
      ("extension spring wire diameter", wire_diameter_mm),
      ("extension spring free length", free_length_mm),
      ("extension spring leg length", leg_length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if active_coils < 1 {
    return Err(
      @common.InvalidParameter(
        "extension spring needs at least one active coil",
      ),
    )
  }
  let radius = mean_diameter_mm / 2.0
  let wire_radius = wire_diameter_mm / 2.0
  if radius <= wire_radius {
    return Err(
      @common.InvalidDimension("spring mean radius must exceed the wire radius"),
    )
  }
  let body = match
    mechanism_helix_body(
      radius, wire_radius, free_length_mm, active_coils, segments_per_turn,
    ) {
    Err(e) => return Err(e)
    Ok(shape) => shape
  }
  let bottom_z = wire_radius
  let top_z = free_length_mm - wire_radius
  let features = @common.FeatureRecord::new(
    modeled=["helix-body", "end-legs"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="closed-hook-loops",
        reason="straight end legs replace the hook loops; hook geometry is not modelled",
      ),
      @common.Omission::new(
        feature="spring-rate-and-initial-tension",
        reason="geometry only; no spring rate or initial tension is implied",
      ),
      @common.Omission::new(
        feature="ground-or-closed-ends",
        reason="the coil ends are open and not ground",
      ),
    ],
  )
  let name = "extension-spring-\{@cad.fmt_double(mean_diameter_mm, None)}x\{@cad.fmt_double(free_length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Extension spring mean dia \{@cad.fmt_double(mean_diameter_mm, None)} / wire \{@cad.fmt_double(wire_diameter_mm, None)} x \{@cad.fmt_double(free_length_mm, None)}",
        family="extension spring (simplified)",
        size="\{@cad.fmt_double(mean_diameter_mm, None)}x\{@cad.fmt_double(wire_diameter_mm, None)}x\{@cad.fmt_double(free_length_mm, None)}",
        length_mm=free_length_mm,
        source="Parametric helical sweep with straight end legs. No spring rate or hook-loop model is asserted.",
      ),
      description="Open helical extension spring with straight radial end legs. Closed hook loops are omitted.",
      features~,
    )
    .add_layer(body, name="body", color~)
    .add_layer(
      mechanism_cylinder_z(wire_diameter_mm, leg_length_mm),
      name="leg-a",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(radius, 0.0, bottom_z),
        @common.Placement::rotation_y(90.0),
      ),
    )
    .add_layer(
      mechanism_cylinder_z(wire_diameter_mm, leg_length_mm),
      name="leg-b",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(radius, 0.0, top_z),
        @common.Placement::rotation_y(-90.0),
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=mean_diameter_mm + wire_diameter_mm,
        description="negative-Z spring end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, free_length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=mean_diameter_mm + wire_diameter_mm,
        description="positive-Z spring end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hook-leg-a",
        placement=@common.Placement::translation(
          radius + leg_length_mm,
          0.0,
          bottom_z,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=wire_diameter_mm,
        depth_mm=leg_length_mm,
        description="negative-Z straight hook leg along +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hook-leg-b",
        placement=@common.Placement::translation(
          radius - leg_length_mm,
          0.0,
          top_z,
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=wire_diameter_mm,
        depth_mm=leg_length_mm,
        description="positive-Z straight hook leg along -X",
      ),
    ),
  )
}

///|
/// torsion_spring builds a helical torsion spring with two straight end legs.
///
/// Frame: the coil axis is +Z from `z = 0` to `z = free_length`. The negative-Z
/// leg runs along +Y and the positive-Z leg along -Y, so the legs form an
/// opposed tangential pair. The legs are real cylindrical wire; no leg bend
/// radius, torque, rate, or fatigue rating is modelled.
pub fn torsion_spring(
  mean_diameter_mm : Double,
  wire_diameter_mm : Double,
  free_length_mm : Double,
  active_coils : Int32,
  leg_length_mm~ : Double = 10.0,
  segments_per_turn~ : Int32 = 24,
  color~ : @cad.Rgb = @cad.Rgb::cyan(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("torsion spring mean diameter", mean_diameter_mm),
      ("torsion spring wire diameter", wire_diameter_mm),
      ("torsion spring free length", free_length_mm),
      ("torsion spring leg length", leg_length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if active_coils < 1 {
    return Err(
      @common.InvalidParameter("torsion spring needs at least one active coil"),
    )
  }
  let radius = mean_diameter_mm / 2.0
  let wire_radius = wire_diameter_mm / 2.0
  if radius <= wire_radius {
    return Err(
      @common.InvalidDimension("spring mean radius must exceed the wire radius"),
    )
  }
  let body = match
    mechanism_helix_body(
      radius, wire_radius, free_length_mm, active_coils, segments_per_turn,
    ) {
    Err(e) => return Err(e)
    Ok(shape) => shape
  }
  let bottom_z = wire_radius
  let top_z = free_length_mm - wire_radius
  let features = @common.FeatureRecord::new(
    modeled=["helix-body", "end-legs"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="leg-bend-radius",
        reason="the legs meet the coil at a sharp corner; no bend radius is modelled",
      ),
      @common.Omission::new(
        feature="spring-rate-and-torque",
        reason="geometry only; no rate, torque, or fatigue rating is implied",
      ),
    ],
  )
  let name = "torsion-spring-\{@cad.fmt_double(mean_diameter_mm, None)}x\{@cad.fmt_double(free_length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Torsion spring mean dia \{@cad.fmt_double(mean_diameter_mm, None)} / wire \{@cad.fmt_double(wire_diameter_mm, None)} x \{@cad.fmt_double(free_length_mm, None)}",
        family="torsion spring (simplified)",
        size="\{@cad.fmt_double(mean_diameter_mm, None)}x\{@cad.fmt_double(wire_diameter_mm, None)}x\{@cad.fmt_double(free_length_mm, None)}",
        length_mm=free_length_mm,
        source="Parametric helical sweep with two opposed straight legs. No spring rate or torque model is asserted.",
      ),
      description="Open helical torsion spring with two opposed straight tangential legs. Leg bend radii are omitted.",
      features~,
    )
    .add_layer(body, name="body", color~)
    .add_layer(
      mechanism_cylinder_z(wire_diameter_mm, leg_length_mm),
      name="leg-a",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(radius, 0.0, bottom_z),
        @common.Placement::rotation_x(-90.0),
      ),
    )
    .add_layer(
      mechanism_cylinder_z(wire_diameter_mm, leg_length_mm),
      name="leg-b",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(radius, 0.0, top_z),
        @common.Placement::rotation_x(90.0),
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=mean_diameter_mm + wire_diameter_mm,
        description="negative-Z spring end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, free_length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=mean_diameter_mm + wire_diameter_mm,
        description="positive-Z spring end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "leg-a",
        placement=@common.Placement::translation(
          radius, leg_length_mm, bottom_z,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=wire_diameter_mm,
        depth_mm=leg_length_mm,
        description="negative-Z straight leg along +Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "leg-b",
        placement=@common.Placement::translation(radius, -leg_length_mm, top_z),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=wire_diameter_mm,
        depth_mm=leg_length_mm,
        description="positive-Z straight leg along -Y",
      ),
    ),
  )
}
