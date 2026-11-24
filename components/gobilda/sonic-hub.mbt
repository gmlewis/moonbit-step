///|
/// gobilda_hex_loop returns a closed counter-clockwise regular-hexagon loop with
/// the given across-flats distance, with a horizontal flat on top and bottom.
fn gobilda_hex_loop(across_flats_mm : Double) -> Array[@cad.ProfileSegment] {
  let inradius = across_flats_mm / 2.0
  let circumradius = inradius / @math.cos(@math.PI / 6.0)
  let segs : Array[@cad.ProfileSegment] = []
  for i in 0..<6 {
    let a0 = 2.0 * @math.PI * i.to_double() / 6.0
    let a1 = 2.0 * @math.PI * ((i + 1) % 6).to_double() / 6.0
    segs.push(
      @cad.SegmentLine(
        (circumradius * @math.cos(a0), circumradius * @math.sin(a0)),
        (circumradius * @math.cos(a1), circumradius * @math.sin(a1)),
      ),
    )
  }
  segs
}

///|
/// gobilda_sonic_hub builds a goBILDA 1309 Sonic hub envelope.
///
/// Frame: the hub axis is +Z, centred on `z = 0`. The body is Ø32 x 8 mm with a
/// Ø14 x 2 mm boss on the +Z face; the through bore is a **7 mm across-flats
/// hex** (the 8 mm REX® interface); four **Ø4 mm** through holes sit on a
/// **16 mm square** pattern (at ±8, ±8 mm) through the body.
///
/// The hub's scalloped lightening cutouts, the radial clamp slit, and the
/// 14 mm clamp screw are not dimensioned in the published schematic (only the
/// outline is shown), so they are declared omissions. The hexagonal bore's
/// 0.75 mm corner rounds are also omitted. This is a mating envelope, not a
/// bit-exact vendor copy.
///
/// Source: https://www.gobilda.com/1309-series-sonic-hub-8mm-rex-bore
/// (Ø32, 8 mm body + 2 mm step, 8 mm REX bore with 7 mm flats, 16 mm M4 pattern).
pub fn gobilda_sonic_hub(
  bore_flats_mm~ : Double = 7.0,
  body_diameter_mm~ : Double = 32.0,
  body_width_mm~ : Double = 8.0,
  boss_diameter_mm~ : Double = 14.0,
  boss_height_mm~ : Double = 2.0,
  bolt_circle_mm~ : Double = 16.0,
  bolt_diameter_mm~ : Double = 4.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("Sonic hub body diameter", body_diameter_mm),
    @common.require_positive("Sonic hub body width", body_width_mm),
    @common.require_positive("Sonic hub boss diameter", boss_diameter_mm),
    @common.require_positive("Sonic hub boss height", boss_height_mm),
    @common.require_positive("Sonic hub bore flats", bore_flats_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if bore_flats_mm >= boss_diameter_mm {
    return Err(
      @common.InvalidDimension("Sonic hub bore must fit inside the boss"),
    )
  }
  let body_radius = body_diameter_mm / 2.0
  let boss_radius = boss_diameter_mm / 2.0
  let half_circle = bolt_circle_mm / 2.0
  let bolt_radius = bolt_diameter_mm / 2.0
  if (half_circle * half_circle * 2.0).sqrt() + bolt_radius > body_radius {
    return Err(
      @common.InvalidDimension("Sonic hub bolt holes do not fit the body"),
    )
  }
  let hex = gobilda_hex_loop(bore_flats_mm)
  let bolts : Array[(Double, Double)] = [
    (-half_circle, -half_circle),
    (half_circle, -half_circle),
    (half_circle, half_circle),
    (-half_circle, half_circle),
  ]
  let body_holes : Array[Array[@cad.ProfileSegment]] = [hex]
  for bolt in bolts {
    let (x, y) = bolt
    body_holes.push(@common.circle_loop(x, y, bolt_radius))
  }
  let body = @cad.ExtrudedArcProfile::new(
    @common.circle_loop(0.0, 0.0, body_radius),
    body_width_mm,
    holes=body_holes,
  ).as_shape()
  let boss = @cad.ExtrudedArcProfile::new(
    @common.circle_loop(0.0, 0.0, boss_radius),
    boss_height_mm,
    holes=[hex],
  ).as_shape()
  let total_height = body_width_mm + boss_height_mm
  let features = @common.FeatureRecord::new(
    modeled=["body", "boss", "hex-bore", "four-bolt-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="scalloped-lightening-cutouts",
        reason="the lightening scallops are not dimensioned in the published schematic; only the outline is shown",
      ),
      @common.Omission::new(
        feature="clamp-slit-and-screw",
        reason="the radial clamp slit and the 14 mm clamp screw are not modelled",
      ),
      @common.Omission::new(
        feature="hex-corner-rounds",
        reason="the REX bore's 0.75 mm corner rounds are omitted (sharp hex)",
      ),
    ],
  )
  let name = "gobilda-sonic-hub-\{@cad.fmt_double(body_diameter_mm, None)}"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="goBILDA Sonic hub Ø\{@cad.fmt_double(body_diameter_mm, None)} / \{@cad.fmt_double(bore_flats_mm, None)} mm hex (1309)",
        standard="goBILDA 8 mm pattern",
        family="goBILDA Sonic hub",
        size="\{@cad.fmt_double(body_diameter_mm, None)}",
        length_mm=total_height,
        material="aluminium, clear anodized",
        source="https://www.gobilda.com/1309-series-sonic-hub-8mm-rex-bore | SKU 1309-0016-4008 | $7.99 | Ø32 x 8 mm body, Ø14 x 2 mm boss, 7 mm flat hex bore, 4x M4 on a 16 mm pattern",
      ),
      description="goBILDA 1309 Sonic hub envelope: Ø32 x 8 mm body with a Ø14 x 2 mm boss, a 7 mm flat hex (8 mm REX) bore, and four Ø4 holes on a 16 mm square. Scalloped lightening cutouts, clamp slit, and corner rounds are omitted.",
      features~,
    )
    .add_layer(body, name="body", color~)
    .add_layer(
      boss,
      name="boss",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, body_width_mm),
    )
    .translate(z=-total_height / 2.0)
  let half = total_height / 2.0
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rex-bore",
        placement=@common.Placement::translation(0.0, 0.0, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_flats_mm,
        depth_mm=total_height,
        description="7 mm flat hex (8 mm REX) through bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=body_diameter_mm,
        depth_mm=body_width_mm,
        description="Ø32 outer boundary",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-body",
        placement=@common.Placement::translation(0.0, 0.0, -half),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=body_diameter_mm,
        description="flat body face, opposite the boss",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-boss",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=boss_diameter_mm,
        description="boss face",
      ),
    )
  let mut index = 0
  for bolt in bolts {
    let (x, y) = bolt
    index += 1
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-\{index}",
        placement=@common.Placement::translation(x, y, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_diameter_mm,
        depth_mm=body_width_mm,
        description="4 mm through hole on the 16 mm pattern",
      ),
    )
  }
  Ok(out)
}

///|
/// gobilda_sonic_hub_family exposes the Sonic hub as a validated design family.
pub fn gobilda_sonic_hub_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="boreFlats",
      default_mm=7.0,
      min_mm=4.0,
      max_mm=10.0,
      description="hex bore across flats",
    ),
    @common.ParamSpec::new(
      name="bodyDiameter",
      default_mm=32.0,
      min_mm=20.0,
      max_mm=48.0,
      description="body diameter",
    ),
    @common.ParamSpec::new(
      name="bodyWidth",
      default_mm=8.0,
      min_mm=4.0,
      max_mm=16.0,
      description="body width",
    ),
    @common.ParamSpec::new(
      name="bossDiameter",
      default_mm=14.0,
      min_mm=10.0,
      max_mm=24.0,
      description="boss diameter",
    ),
    @common.ParamSpec::new(
      name="bossHeight",
      default_mm=2.0,
      min_mm=1.0,
      max_mm=10.0,
      description="boss height",
    ),
    @common.ParamSpec::new(
      name="boltCircle",
      default_mm=16.0,
      min_mm=10.0,
      max_mm=30.0,
      description="bolt-pattern side length",
    ),
    @common.ParamSpec::new(
      name="boltDiameter",
      default_mm=4.0,
      min_mm=2.0,
      max_mm=6.0,
      description="bolt-hole diameter",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="gobilda-sonic-hub",
      specs~,
      description="goBILDA Sonic hub envelopes.",
      build=fn(parameters) {
        let bore = match parameters.get("boreFlats") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let body = match parameters.get("bodyDiameter") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let width = match parameters.get("bodyWidth") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let boss_d = match parameters.get("bossDiameter") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let boss_h = match parameters.get("bossHeight") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let circle = match parameters.get("boltCircle") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let bolt = match parameters.get("boltDiameter") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        gobilda_sonic_hub(
          bore_flats_mm=bore,
          body_diameter_mm=body,
          body_width_mm=width,
          boss_diameter_mm=boss_d,
          boss_height_mm=boss_h,
          bolt_circle_mm=circle,
          bolt_diameter_mm=bolt,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("1309-8mm-rex", [("boreFlats", 7.0)])
}
