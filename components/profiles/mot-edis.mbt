///|
/// MotEDis 40 x 40 I-type slot-8 metric T-slot profile dimensions.
///
/// Source: MotEDis "Profile 40x40L I-Type slot 8" (8 mm groove, 12 mm depth,
/// M8 core) and the CommunityCAD drawing (slot opening 8, lip 4.5, slot depth
/// 12.25, core bore Ø6.8, corner radius 4, area 916 mm²).
let mot_edis_size_mm : Double = 40.0

///|
/// The MotEDis 40-series slot-8 corner radius, in millimetres.
let mot_edis_corner_radius_mm : Double = 4.0

///|
/// The MotEDis slot-8 opening width, in millimetres.
let mot_edis_slot_opening_mm : Double = 8.0

///|
/// The MotEDis slot-8 lip depth (face to the undercut), in millimetres.
let mot_edis_lip_depth_mm : Double = 4.5

///|
/// The MotEDis slot-8 total slot depth (face to the cavity floor), in
/// millimetres.
let mot_edis_slot_depth_mm : Double = 12.25

///|
/// The nominal MotEDis slot-8 cavity width (the T-slot undercut), in
/// millimetres. The published drawing gives the slot depth and lip; the cavity
/// width is the standard 16 mm that gives the published 916 mm² profile area
/// within about 1%.
let mot_edis_cavity_width_mm : Double = 16.0

///|
/// The MotEDis 40-series core bore diameter, in millimetres.
let mot_edis_core_bore_mm : Double = 6.8

///|
/// mot_edis_rotate rotates a 2D point by `quarter` x 90 degrees counter-clockwise.
fn mot_edis_rotate(quarter : Int32, x : Double, y : Double) -> (Double, Double) {
  match quarter % 4 {
    0 => (x, y)
    1 => (-y, x)
    2 => (-x, -y)
    _ => (y, -x)
  }
}

///|
/// mot_edis_profile builds a MotEDis 40 x 40 I-type slot-8 metric T-slot
/// extrusion of the given length.
///
/// Frame: the profile is centred on the XY origin and runs along +Z from
/// `z = 0` to `z = length`. The cross-section is the 40 x 40 mm rounded square
/// (R4) with a Ø6.8 mm core bore and one T-slot in each face (8 mm opening,
/// 4.5 mm lip, 12.25 mm depth, nominal 16 mm cavity). The four slots are a
/// **nominal difference** — the flat STEP concatenates the cutters and the CAD
/// kernel trims them, then the extrusion length is the part's length.
///
/// The cavity width is an engineering value chosen to reproduce the published
/// 916 mm² profile area (the drawing dimensions the opening, lip, and depth but
/// not the undercut width). The exact anodising, edge breaks, and end machining
/// are not modelled.
pub fn mot_edis_profile(
  length_mm~ : Double = 100.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("MotEDis profile length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let half = mot_edis_size_mm / 2.0
  let margin = 1.0
  let x_open = mot_edis_slot_opening_mm / 2.0
  let x_cav = mot_edis_cavity_width_mm / 2.0
  let y_lip = half - mot_edis_lip_depth_mm
  let y_floor = half - mot_edis_slot_depth_mm
  let top : Array[@cad.Vec2] = [
    (-x_open, half + margin),
    (-x_open, y_lip),
    (-x_cav, y_lip),
    (-x_cav, y_floor),
    (x_cav, y_floor),
    (x_cav, y_lip),
    (x_open, y_lip),
    (x_open, half + margin),
  ]
  let cutters : Array[@cad.SceneNode] = []
  for quarter in 0..<4 {
    let rotated : Array[@cad.Vec2] = top.map(fn(p) {
      let (x, y) = p
      mot_edis_rotate(quarter, x, y)
    })
    cutters.push(
      @cad.ExtrudedProfile::new(rotated, length_mm + 2.0 * margin)
      .with_name("slot-cutter")
      .translate(z=-margin),
    )
  }
  let outer = @cad.Profile2D::rounded_rect(
    mot_edis_size_mm, mot_edis_size_mm, mot_edis_corner_radius_mm,
  ).map(fn(p) {
    let (x, y) = p
    (x - half, y - half)
  })
  let bar = @cad.ExtrudedProfile::new(
    outer,
    length_mm,
    round_bore=((0.0, 0.0), mot_edis_core_bore_mm),
  ).with_name("bar")
  let body = @cad.difference(bar, cutters, name="profile")
  let features = @common.FeatureRecord::new(
    modeled=["rounded-square-section", "core-bore", "four-t-slots"],
    approximated=[
      @common.Approximation::new(
        feature="t-slot-cavity-width",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the drawing dimensions the opening (8), lip (4.5) and depth (12.25) but not the undercut; the nominal 16 mm cavity reproduces the published 916 mm2 area within about 1%",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="slot-trim",
        reason="the four slots are a nominal difference: the flat writer concatenates cutter faces and SolidCraft or the evaluated export performs the trim",
      ),
      @common.Omission::new(
        feature="anodising-and-edge-breaks",
        reason="surface finish and edge breaks are not modelled",
      ),
    ],
  )
  let name = "motedis-40x40-slot8-\{@cad.fmt_double(length_mm, None)}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="MotEDis 40x40 I-type slot 8 (\{@cad.fmt_double(length_mm, None)} mm)",
      standard="MotEDis 40 x 40L I-type slot 8",
      family="metric T-slot extrusion",
      size="40x40",
      length_mm~,
      material="aluminium, anodized",
      source="https://www.motedis.com/en/Profile-40x40L-I-Type-slot-8 | 40x40, 8 mm groove, 12 mm depth, M8 core, €14-16/m | CommunityCAD: slot 8, lip 4.5, depth 12.25, core Ø6.8, R4, area 916 mm2",
    ),
    description="MotEDis 40 x 40 I-type slot-8 extrusion: R4 rounded square, Ø6.8 core bore, four 8 mm T-slots (4.5 mm lip, 12.25 mm deep). The slots are a nominal difference resolved by the CAD kernel.",
    features~,
  ).add_layer(body.shape_intent(), name="body", color~)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Datum,
        description="cut end at z = 0",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        description="cut end at z = length",
      ),
    )
  let faces : Array[
    (String, (Double, Double, Double), (Double, Double, Double)),
  ] = [
    ("slot-top", (0.0, half, 0.0), (0.0, 1.0, 0.0)),
    ("slot-bottom", (0.0, -half, 0.0), (0.0, -1.0, 0.0)),
    ("slot-left", (-half, 0.0, 0.0), (-1.0, 0.0, 0.0)),
    ("slot-right", (half, 0.0, 0.0), (1.0, 0.0, 0.0)),
  ]
  for entry in faces {
    let (face_name, position, axis) = entry
    let (x, y, z) = position
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        face_name,
        placement=@common.Placement::translation(x, y, z),
        axis~,
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=mot_edis_slot_opening_mm,
        depth_mm=mot_edis_slot_depth_mm,
        description="T-slot opening on this face",
      ),
    )
  }
  Ok(out)
}

///|
/// mot_edis_profile_family exposes the MotEDis 40 x 40 slot-8 profile as a
/// validated design family with common cut-length presets.
pub fn mot_edis_profile_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=100.0,
      min_mm=50.0,
      max_mm=1980.0,
      description="extrusion length",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="motedis-40x40-slot8",
      specs~,
      description="MotEDis 40 x 40 I-type slot-8 metric T-slot extrusion.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        mot_edis_profile(length_mm=length)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for length in [100.0, 250.0, 500.0, 1000.0, 1500.0, 1980.0] {
    let name = "len-\{@cad.fmt_double(length, None)}"
    out = match out.with_variant(name, [("length", length)]) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
