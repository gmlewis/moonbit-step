///|
/// The measured flange thickness of the goBILDA 1309 Sonic hub, in millimetres.
let sonic_hub_flange_mm : Double = 8.0

///|
/// The measured boss height of the goBILDA 1309 Sonic hub, in millimetres.
let sonic_hub_boss_mm : Double = 2.0

///|
/// The published 8 mm REX hex bore, across flats, in millimetres.
let sonic_hub_bore_flats_mm : Double = 7.0

///|
/// The published 16 mm bolt-square half-span (holes at +/-8 mm), in
/// millimetres.
let sonic_hub_bolt_span_mm : Double = 8.0

///|
/// The M4 x 0.7 tap drill used for the four mounting holes, in millimetres.
let sonic_hub_bolt_drill_mm : Double = gobilda_m4_tap_drill_mm

///|
/// The measured perpendicular offset of each tangential clamp screw from the
/// hub axis, in millimetres.
let sonic_hub_screw_offset_mm : Double = 6.409

///|
/// The clamp screw thread size (M4), in millimetres.
let sonic_hub_screw_mm : Double = 4.0

///|
/// The measured socket-head counterbore at each clamp-screw entry, in
/// millimetres.
let sonic_hub_screw_cbore_mm : Double = 7.2

///|
/// The measured length of each clamp-screw counterbore, in millimetres.
let sonic_hub_screw_cbore_len_mm : Double = 10.0

///|
/// The measured axial distance from the hub centre to each clamp-screw entry,
/// in millimetres.
let sonic_hub_screw_entry_mm : Double = 15.06

///|
/// gobilda_sonic_hub builds a goBILDA 1309 Sonic hub as a measured B-rep.
///
/// Frame: the hub axis is +Z, the flange sits on `z = 0` and the two raised boss
/// halves end at `z = 10`. The flange outline, the central flexure void (a 7 mm
/// across-flats hex bore with 0.75 mm corner rounds that opens into two
/// crescent slots), and the two boss halves are the exact measured profiles of
/// the vendor solid (`1309-0016-4008`); the section areas are 618.422,
/// 107.414, 52.432 and 52.434 mm2 respectively.
///
/// The four M4 x 0.7 mounting holes on the 16 mm square are modelled as 3.3 mm
/// tap drills with `Threaded` connectors. The two tangential clamp screws have
/// a measured perpendicular offset of 6.409 mm, a 4 mm shank bore and a 7.2 mm
/// socket-head counterbore, 10 mm long, at the entry end. The thread helices
/// themselves are not modelled.
///
/// Source: https://www.gobilda.com/1309-series-sonic-hub-8mm-rex-bore
/// (vendor STEP `1309-0016-4008` measured clean-room; 48 x 48 x 2.5 mm channel
/// system, Ø32 x 10 mm hub, 8 mm REX bore with 7 mm flats).
pub fn gobilda_sonic_hub(
  bore_flats_mm~ : Double = sonic_hub_bore_flats_mm,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if (bore_flats_mm - sonic_hub_bore_flats_mm).abs() > 1.0e-9 {
    return Err(
      @common.InvalidDimension(
        "the measured 1309 Sonic hub profile has a 7 mm across-flats bore",
      ),
    )
  }
  // Flange holes: the measured central flexure void plus four M4 tap drills.
  let holes : Array[Array[@cad.ProfileSegment]] = [
    hub_loop(gobilda_sonic_hub_void()),
  ]
  for x in [-sonic_hub_bolt_span_mm, sonic_hub_bolt_span_mm] {
    for y in [-sonic_hub_bolt_span_mm, sonic_hub_bolt_span_mm] {
      holes.push(@common.circle_loop(x, y, sonic_hub_bolt_drill_mm / 2.0))
    }
  }
  let flange = @cad.ExtrudedArcProfile::new(
      hub_loop(gobilda_sonic_hub_outer()),
      sonic_hub_flange_mm,
      holes~,
    )
    .as_shape()
    .with_name("flange")
  // Two tangential clamp screws, symmetric under 180 degrees.
  let u = 1.0 / 2.0.sqrt()
  let entry_mm = sonic_hub_screw_entry_mm
  let screw_cutters : Array[@cad.SceneNode] = []
  for offset in [-sonic_hub_screw_offset_mm, sonic_hub_screw_offset_mm] {
    let px = -offset * u
    let py = offset * u
    let entry_sign = if offset < 0.0 { 1.0 } else { -1.0 }
    let entry_s = entry_sign * entry_mm
    let bore = @cad.Cylinder::new(sonic_hub_screw_mm, 2.0 * entry_mm + 4.0)
      .with_name("clamp-bore")
      .rotate_y(90.0)
      .rotate_z(45.0)
      .translate(x=px, y=py, z=sonic_hub_flange_mm / 2.0)
    let cb_s = entry_s - entry_sign * sonic_hub_screw_cbore_len_mm / 2.0
    let counterbore = @cad.Cylinder::new(
        sonic_hub_screw_cbore_mm, sonic_hub_screw_cbore_len_mm,
      )
      .with_name("clamp-counterbore")
      .rotate_y(90.0)
      .rotate_z(45.0)
      .translate(x=px + cb_s * u, y=py + cb_s * u, z=sonic_hub_flange_mm / 2.0)
    screw_cutters.push(bore)
    screw_cutters.push(counterbore)
  }
  let flange_body = @cad.difference(flange, screw_cutters, name="flange-body")
  let boss_a = @cad.ExtrudedArcProfile::new(
    hub_loop(gobilda_sonic_hub_boss_a()),
    sonic_hub_boss_mm,
  ).as_shape()
  let boss_b = @cad.ExtrudedArcProfile::new(
    hub_loop(gobilda_sonic_hub_boss_b()),
    sonic_hub_boss_mm,
  ).as_shape()
  let boss_placement = @common.Placement::translation(
    0.0, 0.0, sonic_hub_flange_mm,
  )
  let features = @common.FeatureRecord::new(
    modeled=[
      "measured-flange-outline", "measured-flexure-void-and-hex-bore", "measured-boss-halves",
      "m4-tap-drills", "tangential-clamp-screws",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="thread-helices",
        reason="the M4 x 0.7 mounting and clamp threads are declared by Threaded connectors; their 3.3 mm tap drills and the 4 mm clamp bores are modelled",
      ),
    ],
  )
  let name = "gobilda-sonic-hub-1309"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="goBILDA 1309 Sonic hub (8 mm REX bore)",
        standard="goBILDA 8 mm pattern",
        family="goBILDA Sonic hub",
        size="1309",
        material="aluminium, clear anodized",
        source="https://www.gobilda.com/1309-series-sonic-hub-8mm-rex-bore | Ø32 x 10 mm hub, 7 mm across-flats hex bore with 0.75 mm rounds, 4 x M4 on a 16 mm square, two tangential M4 clamp screws | measured from vendor STEP 1309-0016-4008",
      ),
      description="goBILDA 1309 Sonic hub: measured Ø32 flange with the flexure void and hex bore, two boss halves, four M4 mounting holes on a 16 mm square, and two tangential clamp screws with 7.2 mm socket-head counterbores.",
      features~,
    )
    .add_layer(flange_body.shape_intent(), name="flange", color~)
    .add_layer(boss_a, name="boss-a", color~, placement=boss_placement)
    .add_layer(boss_b, name="boss-b", color~, placement=boss_placement)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "flange-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * sonic_hub_bore_flats_mm,
        description="flange mounting face on -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "boss-face",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          sonic_hub_flange_mm + sonic_hub_boss_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * sonic_hub_bore_flats_mm,
        description="raised boss face on +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rex-bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=sonic_hub_bore_flats_mm,
        depth_mm=sonic_hub_flange_mm + sonic_hub_boss_mm,
        description="7 mm across-flats hex bore for an 8 mm REX shaft",
      ),
    )
  let mut bolt_index = 0
  for x in [-sonic_hub_bolt_span_mm, sonic_hub_bolt_span_mm] {
    for y in [-sonic_hub_bolt_span_mm, sonic_hub_bolt_span_mm] {
      bolt_index += 1
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "bolt-hole-\{bolt_index}",
          placement=@common.Placement::translation(x, y, 0.0),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Threaded,
          gender=@common.MateGender::Female,
          diameter_mm=sonic_hub_screw_mm,
          depth_mm=sonic_hub_flange_mm,
          description="M4 x 0.7 tapped mounting hole on the 16 mm square",
        ),
      )
    }
  }
  let mut screw_index = 0
  for offset in [-sonic_hub_screw_offset_mm, sonic_hub_screw_offset_mm] {
    screw_index += 1
    let px = -offset * u
    let py = offset * u
    let entry_sign = if offset < 0.0 { 1.0 } else { -1.0 }
    let entry_s = entry_sign * entry_mm
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "clamp-screw-\{screw_index}",
        placement=@common.Placement::translation(
          px + entry_s * u,
          py + entry_s * u,
          sonic_hub_flange_mm / 2.0,
        ),
        axis=(entry_sign * u, entry_sign * u, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=sonic_hub_screw_mm,
        depth_mm=sonic_hub_screw_cbore_len_mm,
        description="M4 x 0.7 tangential clamp screw, entered through a 7.2 mm counterbore",
      ),
    )
  }
  Ok(out)
}

///|
/// gobilda_sonic_hub_family exposes the measured 1309 Sonic hub as a validated
/// design family.
pub fn gobilda_sonic_hub_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="boreFlats",
      default_mm=sonic_hub_bore_flats_mm,
      min_mm=sonic_hub_bore_flats_mm,
      max_mm=sonic_hub_bore_flats_mm,
      description="hex bore across flats (fixed by the measured 1309 profile)",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="gobilda-sonic-hub",
      specs~,
      description="goBILDA 1309 Sonic hub (8 mm REX bore) with the measured flexure profile.",
      build=fn(parameters) {
        let flats = match parameters.get("boreFlats") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        gobilda_sonic_hub(bore_flats_mm=flats)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  match family.with_variant("1309-8mm-rex", []) {
    Ok(next) => Ok(next)
    Err(e) => Err(e)
  }
}
