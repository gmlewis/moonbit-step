///|
/// o_ring_volume_mm3 returns the exact torus volume for an O-ring.
///
/// With mean radius `R = inner/2 + cross/2` and minor radius `r = cross/2`,
/// the volume is `2 * pi^2 * R * r^2`.
pub fn o_ring_volume_mm3(
  inner_diameter_mm : Double,
  cross_section_mm : Double,
) -> Double {
  let r = cross_section_mm / 2.0
  let mean = inner_diameter_mm / 2.0 + r
  2.0 * @math.PI * @math.PI * mean * r * r
}

///|
/// o_ring builds a toroidal O-ring envelope.
///
/// Frame: the ring axis is +Z and the torus is centred on the origin, spanning
/// `z = -cross/2 .. cross/2`. The inner diameter is the torus bore, so the
/// outside diameter is `inner + 2 * cross`. The torus is a real analytic
/// surface of revolution (four minor arcs).
///
/// This is a seal envelope: no squeeze, groove fill, material, pressure, or
/// temperature rating is implied.
pub fn o_ring(
  inner_diameter_mm : Double,
  cross_section_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::black(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("O-ring inner diameter", inner_diameter_mm),
      ("O-ring cross-section", cross_section_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let r = cross_section_mm / 2.0
  let mean = inner_diameter_mm / 2.0 + r
  let profile = @cad.RevolvedProfile::new([
    @cad.RevArc((mean + r, 0.0), (mean, r), (mean, 0.0)),
    @cad.RevArc((mean, r), (mean - r, 0.0), (mean, 0.0)),
    @cad.RevArc((mean - r, 0.0), (mean, -r), (mean, 0.0)),
    @cad.RevArc((mean, -r), (mean + r, 0.0), (mean, 0.0)),
  ])
  let features = @common.FeatureRecord::new(
    modeled=["torus-body"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="squeeze-and-groove-fill",
        reason="the seal envelope carries no squeeze, groove, or pressure rating",
      ),
      @common.Omission::new(
        feature="material-and-temperature-rating",
        reason="no material, hardness, or temperature rating is implied",
      ),
    ],
  )
  let name = "o-ring-\{@cad.fmt_double(inner_diameter_mm, None)}x\{@cad.fmt_double(cross_section_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="O-ring ID \{@cad.fmt_double(inner_diameter_mm, None)} CS \{@cad.fmt_double(cross_section_mm, None)}",
        family="O-ring (envelope)",
        size="\{@cad.fmt_double(inner_diameter_mm, None)}x\{@cad.fmt_double(cross_section_mm, None)}",
        source="Parametric torus envelope. No seal standard table, squeeze, or material rating is implied.",
      ),
      description="Toroidal O-ring envelope with an exact analytic surface of revolution. No squeeze or pressure rating is claimed.",
      features~,
    )
    .add_layer(profile.as_shape(), name="torus", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "torus-axis",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=inner_diameter_mm + 2.0 * cross_section_mm,
        depth_mm=cross_section_mm,
        description="O-ring axis and outside-diameter datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "inner-datum",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=inner_diameter_mm,
        depth_mm=cross_section_mm,
        description="inner-diameter datum (not a machined bore)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "seal-plane",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=inner_diameter_mm + 2.0 * cross_section_mm,
        description="mid-plane of the seal",
      ),
    ),
  )
}

///|
/// o_ring_squeeze_mm returns the diametral squeeze of an O-ring in a groove.
///
/// `cross_section - groove_depth`. A non-positive result means the O-ring does
/// not fill the groove.
pub fn o_ring_squeeze_mm(
  cross_section_mm : Double,
  groove_depth_mm : Double,
) -> Result[Double, @common.SpecError] {
  let squeeze = cross_section_mm - groove_depth_mm
  if squeeze <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "O-ring cross-section does not exceed the groove depth; there is no squeeze",
      ),
    )
  }
  Ok(squeeze)
}

///|
/// grooved_shaft builds a shaft with one real rectangular seal groove.
///
/// Frame: the shaft axis is +Z from `z = 0` to `z = length`; the groove is a
/// rectangular annular relief centred at `groove_center_z` with width
/// `groove_width` and radial depth `groove_depth`. The shaft and groove are one
/// closed revolved solid, so the groove is real geometry.
///
/// The groove does not model a seal, groove fill, or pressure rating.
pub fn grooved_shaft(
  shaft_diameter_mm : Double,
  length_mm : Double,
  groove_width_mm : Double,
  groove_depth_mm : Double,
  groove_center_z_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("grooved shaft diameter", shaft_diameter_mm),
      ("grooved shaft length", length_mm),
      ("groove width", groove_width_mm),
      ("groove depth", groove_depth_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let radius = shaft_diameter_mm / 2.0
  if groove_depth_mm >= radius {
    return Err(
      @common.InvalidDimension(
        "groove depth must be smaller than the shaft radius",
      ),
    )
  }
  let z0 = groove_center_z_mm - groove_width_mm / 2.0
  let z1 = groove_center_z_mm + groove_width_mm / 2.0
  if z0 <= 0.0 || z1 >= length_mm {
    return Err(
      @common.InvalidDimension("groove must lie fully inside the shaft length"),
    )
  }
  let inner_radius = radius - groove_depth_mm
  let profile = @cad.RevolvedProfile::new([
    @cad.RevLine((0.0, 0.0), (radius, 0.0)),
    @cad.RevLine((radius, 0.0), (radius, z0)),
    @cad.RevLine((radius, z0), (inner_radius, z0)),
    @cad.RevLine((inner_radius, z0), (inner_radius, z1)),
    @cad.RevLine((inner_radius, z1), (radius, z1)),
    @cad.RevLine((radius, z1), (radius, length_mm)),
    @cad.RevLine((radius, length_mm), (0.0, length_mm)),
  ])
  let features = @common.FeatureRecord::new(
    modeled=["shaft-body", "rectangular-groove"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="seal-and-groove-fill",
        reason="the groove is geometry only; no seal, fill ratio, or pressure rating is modelled",
      ),
      @common.Omission::new(
        feature="groove-edge-breaks",
        reason="no edge treatment is asserted",
      ),
    ],
  )
  let name = "grooved-shaft-\{@cad.fmt_double(shaft_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Grooved shaft \{@cad.fmt_double(shaft_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
        family="grooved shaft (engineering envelope)",
        size="\{@cad.fmt_double(shaft_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
        length_mm~,
        source="Parametric shaft with one rectangular seal groove. No seal or pressure rating is implied.",
      ),
      description="Plain shaft with one real rectangular annular seal groove. No seal or groove-fill model is included.",
      features~,
    )
    .add_layer(profile.as_shape(), name="shaft", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "groove-seat",
        placement=@common.Placement::translation(0.0, 0.0, groove_center_z_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * inner_radius,
        depth_mm=groove_width_mm,
        description="groove root diameter datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "groove-face-a",
        placement=@common.Placement::translation(0.0, 0.0, z0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=shaft_diameter_mm,
        description="negative-Z groove wall",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "groove-face-b",
        placement=@common.Placement::translation(0.0, 0.0, z1),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=shaft_diameter_mm,
        description="positive-Z groove wall",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=shaft_diameter_mm,
        depth_mm=length_mm,
        description="negative-Z shaft end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=shaft_diameter_mm,
        depth_mm=length_mm,
        description="positive-Z shaft end",
      ),
    ),
  )
}
