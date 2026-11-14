///|
/// clevis builds a generic clevis fork with two pin-bored prongs and an
/// optional threaded shank.
///
/// Frame: the pin axis is +Z. The base is a rectangular block centred on the XY
/// origin with its bottom face at `z = 0`; the lower prong sits directly on the
/// base and the upper prong is separated by `gap_mm`. Both prongs carry an
/// analytic through bore of `pin_diameter_mm`, so a pin enters along +Z. A
/// positive `shank_diameter_mm` adds a cylindrical shank below `z = 0` with a
/// declared (never modelled) thread.
///
/// The part is an engineering envelope: prong edges are square, the pin is not
/// included (use `clevis_pin`), and no thread, clamp force, or strength rating
/// is implied.
pub fn clevis(
  base_width_mm : Double,
  base_depth_mm : Double,
  base_thickness_mm : Double,
  prong_thickness_mm : Double,
  gap_mm : Double,
  pin_diameter_mm : Double,
  shank_diameter_mm~ : Double = 0.0,
  shank_length_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("clevis base width", base_width_mm),
      ("clevis base depth", base_depth_mm),
      ("clevis base thickness", base_thickness_mm),
      ("clevis prong thickness", prong_thickness_mm),
      ("clevis pin diameter", pin_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    mechanism_non_negative_checks([
      ("clevis gap", gap_mm),
      ("clevis shank diameter", shank_diameter_mm),
      ("clevis shank length", shank_length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if gap_mm <= 0.0 {
    return Err(@common.InvalidDimension("clevis gap must be > 0"))
  }
  if pin_diameter_mm >= base_width_mm || pin_diameter_mm >= base_depth_mm {
    return Err(
      @common.InvalidDimension(
        "clevis pin bore does not fit the prong footprint",
      ),
    )
  }
  if (shank_diameter_mm == 0.0) != (shank_length_mm == 0.0) {
    return Err(
      @common.InvalidParameter(
        "clevis shank diameter and length must both be zero or both be positive",
      ),
    )
  }
  if shank_diameter_mm > 0.0 && shank_diameter_mm > base_width_mm {
    return Err(
      @common.InvalidDimension("clevis shank does not fit the base width"),
    )
  }
  let radius = if base_width_mm < base_depth_mm {
    base_width_mm * 0.1
  } else {
    base_depth_mm * 0.1
  }
  let footprint = rounded_rect_loop(
    -base_width_mm / 2.0,
    -base_depth_mm / 2.0,
    base_width_mm / 2.0,
    base_depth_mm / 2.0,
    radius,
  )
  let bore = circle_loop(0.0, 0.0, pin_diameter_mm / 2.0)
  let prong = @cad.ExtrudedArcProfile::new(footprint, prong_thickness_mm, holes=[
    bore,
  ]).as_shape()
  let lower_z = base_thickness_mm
  let upper_z = base_thickness_mm + prong_thickness_mm + gap_mm
  let features = @common.FeatureRecord::new(
    modeled=["base", "prongs", "pin-bores"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="pin-and-retention",
        reason="the pin is a separate part; no retaining feature is modelled",
      ),
      @common.Omission::new(
        feature="thread",
        reason="the shank thread is declared by a connector and never modelled",
      ),
      @common.Omission::new(
        feature="prong-edge-breaks",
        reason="no edge treatment is asserted",
      ),
    ],
  )
  let name = "clevis-\{@cad.fmt_double(base_width_mm, None)}x\{@cad.fmt_double(base_depth_mm, None)}"
  let mut component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Clevis \{@cad.fmt_double(pin_diameter_mm, None)} bore",
        family="clevis fork (engineering envelope)",
        size="\{@cad.fmt_double(pin_diameter_mm, None)}",
        source="Parametric clevis envelope with analytic pin bores. No standard or vendor part is implied.",
      ),
      description="Clevis fork with a base block, two pin-bored prongs, and an optional threaded shank envelope. The pin and thread are separate or declared.",
      features~,
    )
    .add_layer(
      @cad.Cuboid::new(base_width_mm, base_depth_mm, base_thickness_mm),
      name="base",
      color~,
      placement=@common.Placement::translation(
        -base_width_mm / 2.0,
        -base_depth_mm / 2.0,
        0.0,
      ),
    )
    .add_layer(
      prong,
      name="prong-lower",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, lower_z),
    )
    .add_layer(
      prong,
      name="prong-upper",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, upper_z),
    )
  if shank_diameter_mm > 0.0 {
    component = component.add_layer(
      mechanism_cylinder_z(shank_diameter_mm, shank_length_mm),
      name="shank",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, -shank_length_mm),
    )
  }
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-bore-a",
        placement=@common.Placement::translation(0.0, 0.0, lower_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=pin_diameter_mm,
        depth_mm=prong_thickness_mm,
        description="lower prong pin bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-bore-b",
        placement=@common.Placement::translation(0.0, 0.0, upper_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=pin_diameter_mm,
        depth_mm=prong_thickness_mm,
        description="upper prong pin bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "fork-slot",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          lower_z + prong_thickness_mm,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=base_depth_mm,
        depth_mm=gap_mm,
        description="rod-eye space between the prongs; entered from -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "fork-face",
        placement=@common.Placement::translation(0.0, 0.0, upper_z),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=base_width_mm,
        description="inner face of the upper prong (rod-eye roof)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=base_width_mm,
        description="base bottom face",
      ),
    )
  if shank_diameter_mm > 0.0 {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "rod-thread",
        placement=@common.Placement::translation(0.0, 0.0, -shank_length_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Male,
        diameter_mm=shank_diameter_mm,
        depth_mm=shank_length_mm,
        description="declared shank thread; the thread form is not modelled",
      ),
    )
  }
  Ok(out)
}

///|
/// clevis_pin builds a headed clevis pin.
///
/// Frame: the shank runs along +Z from `z = 0` to `z = length_mm`; the head is
/// a larger coaxial cylinder at `z = 0 .. head_thickness_mm` and overlaps the
/// shank nominally. The head diameter is not a strength rating.
pub fn clevis_pin(
  diameter_mm : Double,
  length_mm : Double,
  head_diameter_mm : Double,
  head_thickness_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("pin diameter", diameter_mm),
      ("pin length", length_mm),
      ("pin head diameter", head_diameter_mm),
      ("pin head thickness", head_thickness_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if head_diameter_mm <= diameter_mm {
    return Err(
      @common.InvalidDimension(
        "pin head diameter must exceed the shank diameter",
      ),
    )
  }
  if head_thickness_mm >= length_mm {
    return Err(
      @common.InvalidDimension(
        "pin head thickness must be smaller than the length",
      ),
    )
  }
  let features = @common.FeatureRecord::new(
    modeled=["shank", "head"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="head-edge-breaks",
        reason="no edge treatment is asserted",
      ),
      @common.Omission::new(
        feature="retaining-feature",
        reason="no cotter hole, groove, or clip is modelled",
      ),
    ],
  )
  let name = "clevis-pin-\{@cad.fmt_double(diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Clevis pin \{@cad.fmt_double(diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
        family="clevis pin (engineering envelope)",
        size="\{@cad.fmt_double(diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
        source="Parametric headed pin envelope. No standard table is implied.",
      ),
      description="Headed clevis pin with a plain shank and a larger coaxial head. No retaining feature is modelled.",
      features~,
    )
    .add_layer(
      mechanism_cylinder_z(diameter_mm, length_mm),
      name="shank",
      color~,
    )
    .add_layer(
      mechanism_cylinder_z(head_diameter_mm, head_thickness_mm),
      name="head",
      color=@cad.Rgb::grey(),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft-end",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm~,
        depth_mm=length_mm,
        description="shank; entered from the positive-Z tip",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "head-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=head_diameter_mm,
        description="underside of the pin head",
      ),
    ),
  )
}

///|
/// rod_end builds an eye-and-shank rod end for a pivot interface.
///
/// Frame: the eye is an annulus with its axis along +Z, centred on the origin
/// and spanning `z = -eye_width/2 .. eye_width/2`. The shank is a coaxial
/// cylinder along +Y from `y = 0` to `y = shank_length` at `z = 0` and overlaps
/// the eye nominally. The eye bore is a real through hole; the shank thread is
/// declared by the `rod-thread` connector and is never modelled.
///
/// The rod end is an engineering envelope: no thread, bend radius, or strength
/// rating is implied.
pub fn rod_end(
  eye_outer_diameter_mm : Double,
  eye_bore_diameter_mm : Double,
  eye_width_mm : Double,
  shank_diameter_mm : Double,
  shank_length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("rod-end eye outer diameter", eye_outer_diameter_mm),
      ("rod-end eye bore diameter", eye_bore_diameter_mm),
      ("rod-end eye width", eye_width_mm),
      ("rod-end shank diameter", shank_diameter_mm),
      ("rod-end shank length", shank_length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if eye_bore_diameter_mm >= eye_outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "rod-end eye bore must be smaller than the eye outer diameter",
      ),
    )
  }
  if shank_diameter_mm >= eye_outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "rod-end shank must be smaller than the eye outer diameter",
      ),
    )
  }
  let eye = mechanism_tube_z(
    eye_outer_diameter_mm, eye_bore_diameter_mm, eye_width_mm,
  )
  let shank = mechanism_cylinder_z(shank_diameter_mm, shank_length_mm)
  let features = @common.FeatureRecord::new(
    modeled=["eye", "eye-bore", "shank"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="thread",
        reason="the shank thread is declared by the `rod-thread` connector and never modelled",
      ),
      @common.Omission::new(
        feature="eye-to-shank-fillet",
        reason="the eye and shank overlap nominally; no blend is modelled",
      ),
      @common.Omission::new(
        feature="edge-breaks-and-bend-radius",
        reason="no edge treatment or formed bend is modelled",
      ),
    ],
  )
  let name = "rod-end-\{@cad.fmt_double(eye_bore_diameter_mm, None)}x\{@cad.fmt_double(shank_length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Rod end eye \{@cad.fmt_double(eye_bore_diameter_mm, None)}, shank \{@cad.fmt_double(shank_diameter_mm, None)} x \{@cad.fmt_double(shank_length_mm, None)}",
        family="rod end (engineering envelope)",
        size="\{@cad.fmt_double(eye_bore_diameter_mm, None)}x\{@cad.fmt_double(shank_diameter_mm, None)}",
        length_mm=shank_length_mm,
        source="Parametric eye-and-shank envelope with a real eye bore. The shank thread is declared, not modelled.",
      ),
      description="Rod-end eye with a real through bore and a cylindrical shank. The shank thread and any formed bend are omitted.",
      features~,
    )
    .add_layer(
      eye,
      name="eye",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, -eye_width_mm / 2.0),
    )
    .add_layer(
      shank,
      name="shank",
      color~,
      placement=@common.Placement::rotation_x(-90.0),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "eye-bore",
        placement=@common.Placement::translation(0.0, 0.0, -eye_width_mm / 2.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=eye_bore_diameter_mm,
        depth_mm=eye_width_mm,
        description="eye pivot bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shank",
        placement=@common.Placement::translation(0.0, shank_length_mm, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=shank_diameter_mm,
        depth_mm=shank_length_mm,
        description="shank; entered from the +Y end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rod-thread",
        placement=@common.Placement::translation(0.0, shank_length_mm, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Male,
        diameter_mm=shank_diameter_mm,
        depth_mm=shank_length_mm,
        description="declared shank thread; not modelled",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "eye-face-a",
        placement=@common.Placement::translation(0.0, 0.0, -eye_width_mm / 2.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=eye_outer_diameter_mm,
        description="negative-Z eye face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "eye-face-b",
        placement=@common.Placement::translation(0.0, 0.0, eye_width_mm / 2.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=eye_outer_diameter_mm,
        description="positive-Z eye face",
      ),
    ),
  )
}
