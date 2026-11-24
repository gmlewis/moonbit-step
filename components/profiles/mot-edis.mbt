///|
/// MotEdisSection describes one MotEDis I-type metric T-slot profile section.
///
/// `lip_mm` is the face-to-undercut depth, `cavity_mm` the T-slot undercut
/// width, `depth_mm` the face-to-cavity-floor depth, and `bore_mm` the core bore.
pub(all) struct MotEdisSection {
  series : String
  size_mm : Double
  slot_opening_mm : Double
  lip_mm : Double
  cavity_mm : Double
  depth_mm : Double
  bore_mm : Double
  corner_mm : Double
}

///|
/// mot_edis_section returns the MotEDis I-type section for a series token.
///
/// Sources: MotEDis datasheets (20x20 slot 5: opening 5, depth 6.35, core Ø4.3,
/// area 182 mm²; 40x40 slot 8: opening 8, depth 12.25, core Ø6.8, area 916 mm²)
/// and the FreeCAD extrusion library slot table (slot 6: opening 6.2, undercut
/// 16.3, depth 9.75, lip 3.0, core 5.0). The 20-series cavity is solved to the
/// published 182 mm² area; the 40-series cavity (16) reproduces 916 mm² within
/// about 1%.
pub fn mot_edis_section(
  series : String,
) -> Result[MotEdisSection, @common.SpecError] {
  match series.trim().to_owned() {
    "20" =>
      Ok({
        series: "20",
        size_mm: 20.0,
        slot_opening_mm: 5.0,
        lip_mm: 1.8,
        cavity_mm: 9.0,
        depth_mm: 6.35,
        bore_mm: 4.3,
        corner_mm: 2.0,
      })
    "30" =>
      Ok({
        series: "30",
        size_mm: 30.0,
        slot_opening_mm: 6.2,
        lip_mm: 3.0,
        cavity_mm: 16.3,
        depth_mm: 9.75,
        bore_mm: 5.0,
        corner_mm: 3.0,
      })
    "40" =>
      Ok({
        series: "40",
        size_mm: 40.0,
        slot_opening_mm: 8.0,
        lip_mm: 4.5,
        cavity_mm: 16.0,
        depth_mm: 12.25,
        bore_mm: 6.8,
        corner_mm: 4.0,
      })
    other =>
      Err(
        @common.InvalidSize(
          "unsupported MotEDis I-type series: \{other}; supported: 20, 30, 40",
        ),
      )
  }
}

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
/// mot_edis_tap_drill returns the ISO metric coarse tap-drill diameter for a
/// thread token, used for the modelled T-nut bore.
fn mot_edis_tap_drill(thread : String) -> Result[Double, @common.SpecError] {
  match thread.trim().to_owned().to_upper() {
    "M3" => Ok(2.5)
    "M4" => Ok(3.3)
    "M5" => Ok(4.2)
    "M6" => Ok(5.0)
    "M8" => Ok(6.8)
    other =>
      Err(
        @common.InvalidSize(
          "unsupported MotEDis T-nut thread: \{other}; supported: M3, M4, M5, M6, M8",
        ),
      )
  }
}

///|
/// mot_edis_thread_diameter returns the nominal diameter for a thread token.
fn mot_edis_thread_diameter(thread : String) -> Double {
  match thread.trim().to_owned().to_upper() {
    "M3" => 3.0
    "M4" => 4.0
    "M5" => 5.0
    "M6" => 6.0
    "M8" => 8.0
    _ => 0.0
  }
}

///|
/// mot_edis_profile_of builds a MotEDis I-type T-slot extrusion from a section.
///
/// Frame: the profile is centred on the XY origin and runs along +Z from
/// `z = 0` to `z = length`. The cross-section is the rounded square with a core
/// bore and one T-slot in each face (opening, lip, depth, and cavity from the
/// section). The four slots are a **nominal difference** — the flat STEP
/// concatenates the cutters and the CAD kernel trims them.
pub fn mot_edis_profile_of(
  section : MotEdisSection,
  length_mm~ : Double = 100.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("MotEDis profile length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let half = section.size_mm / 2.0
  let margin = 1.0
  let x_open = section.slot_opening_mm / 2.0
  let x_cav = section.cavity_mm / 2.0
  let y_lip = half - section.lip_mm
  let y_floor = half - section.depth_mm
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
    section.size_mm,
    section.size_mm,
    section.corner_mm,
  ).map(fn(p) {
    let (x, y) = p
    (x - half, y - half)
  })
  let bar = @cad.ExtrudedProfile::new(
    outer,
    length_mm,
    round_bore=((0.0, 0.0), section.bore_mm),
  ).with_name("bar")
  let body = @cad.difference(bar, cutters, name="profile")
  let size_token = "\{@cad.fmt_double(section.size_mm, None)}x\{@cad.fmt_double(section.size_mm, None)}"
  let features = @common.FeatureRecord::new(
    modeled=["rounded-square-section", "core-bore", "four-t-slots"],
    approximated=[
      @common.Approximation::new(
        feature="t-slot-cavity-width",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the published datasheets dimension the opening, lip, depth and core bore; the undercut width is an engineering value (20: solved to 182 mm2; 30: FreeCAD slot-6 table; 40: 916 mm2 within 1%)",
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
  let name = "motedis-\{size_token}-slot\{@cad.fmt_double(section.slot_opening_mm, None)}-\{@cad.fmt_double(length_mm, None)}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="MotEDis \{size_token} I-type slot \{@cad.fmt_double(section.slot_opening_mm, None)} (\{@cad.fmt_double(length_mm, None)} mm)",
      standard="MotEDis \{size_token}L I-type slot \{@cad.fmt_double(section.slot_opening_mm, None)}",
      family="metric T-slot extrusion",
      size=size_token,
      length_mm~,
      material="aluminium, anodized",
      source="https://www.motedis.com/en/aluminium-profile-prices | I-type metric T-slot | opening \{section.slot_opening_mm}, depth \{section.depth_mm}, core Ø\{section.bore_mm}, corner R\{section.corner_mm}",
    ),
    description="MotEDis I-type metric T-slot extrusion: rounded square, core bore, four T-slots (nominal difference, kernel-trimmed).",
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
        diameter_mm=section.slot_opening_mm,
        depth_mm=section.depth_mm,
        description="T-slot opening on this face",
      ),
    )
  }
  Ok(out)
}

///|
/// mot_edis_profile builds the MotEDis 40 x 40 I-type slot-8 extrusion.
pub fn mot_edis_profile(
  length_mm~ : Double = 100.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let section = match mot_edis_section("40") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  mot_edis_profile_of(section, length_mm~, color~)
}

///|
/// mot_edis_profile_20x20 builds the MotEDis 20 x 20 I-type slot-5 extrusion.
pub fn mot_edis_profile_20x20(
  length_mm~ : Double = 100.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let section = match mot_edis_section("20") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  mot_edis_profile_of(section, length_mm~, color~)
}

///|
/// mot_edis_profile_30x30 builds the MotEDis 30 x 30 I-type slot-6 extrusion.
pub fn mot_edis_profile_30x30(
  length_mm~ : Double = 100.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let section = match mot_edis_section("30") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  mot_edis_profile_of(section, length_mm~, color~)
}

///|
/// mot_edis_tnut builds a MotEDis I-type T-nut for a section.
///
/// Frame: the thread axis is +Z; the narrow neck (4.5 mm tall) sits from
/// `z = 0` and the wider flange (3 mm tall) behind it, giving the drawing's
/// 3 + 4.5 mm stack. The neck width fits the slot opening (minus 0.4 mm) and the
/// flange width fits the cavity (minus 1 mm). The central tap-drill bore is
/// real; the thread is declared by a `Threaded` connector.
///
/// Source: MotEDis T-nut I-type slot 8 (SKU `Motedis_S8IHASNM5`, €0.12/pc):
/// 16 mm long, 3 mm flange + 4.5 mm body, Ø8 boss, M5x0.8 thread.
pub fn mot_edis_tnut(
  section : MotEdisSection,
  thread~ : String = "M5",
  length_mm~ : Double = 16.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let tap = match mot_edis_tap_drill(thread) {
    Err(e) => return Err(e)
    Ok(d) => d
  }
  match @common.require_positive("MotEDis T-nut length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let neck_width = section.slot_opening_mm - 0.4
  let flange_width = section.cavity_mm - 1.0
  if neck_width <= tap || flange_width <= tap {
    return Err(
      @common.InvalidDimension("MotEDis T-nut thread does not fit the body"),
    )
  }
  let flange_height = 3.0
  let neck_height = 4.5
  let flange = @cad.ExtrudedProfile::new(
    @cad.Profile2D::centered_rect(length_mm, flange_width),
    flange_height,
    round_bore=((0.0, 0.0), tap),
  )
  let neck = @cad.ExtrudedProfile::new(
    @cad.Profile2D::centered_rect(length_mm, neck_width),
    neck_height,
    round_bore=((0.0, 0.0), tap),
  )
  let total = flange_height + neck_height
  let features = @common.FeatureRecord::new(
    modeled=["flange", "neck", "tap-drill-bore"],
    approximated=[
      @common.Approximation::new(
        feature="body-widths",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="neck and flange widths are slot opening/cavity minus a declared clearance; the drawing gives the 16 mm length, 3 mm flange, 4.5 mm body, Ø8 boss and M5 thread",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="thread-helix",
        reason="the bore is the tap drill; the thread is declared by a Threaded connector",
      ),
      @common.Omission::new(
        feature="central-boss-and-chamfers",
        reason="the Ø8 raised boss and the neck chamfers are not modelled",
      ),
    ],
  )
  let name = "motedis-tnut-slot\{@cad.fmt_double(section.slot_opening_mm, None)}-\{thread}"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="MotEDis T-nut I-type slot \{@cad.fmt_double(section.slot_opening_mm, None)} \{thread}",
        standard="MotEDis I-type T-nut",
        family="metric T-slot T-nut",
        size="slot\{@cad.fmt_double(section.slot_opening_mm, None)}-\{thread}",
        length_mm=total,
        material="galvanised steel",
        source="https://www.motedis.com/en/T-nut-I-type-slot-8-M5 | SKU Motedis_S8IHASNM5 | €0.12/pc | 16 mm long, 3 mm flange + 4.5 mm body, Ø8 boss, M5x0.8",
      ),
      description="MotEDis I-type T-nut: a 16 mm long body with a 3 mm flange and 4.5 mm neck sized to the slot, and a real central tap-drill bore (the thread is declared by a connector).",
      features~,
    )
    .add_layer(neck, name="neck", color~)
    .add_layer(
      flange,
      name="flange",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, neck_height),
    )
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=mot_edis_thread_diameter(thread),
        depth_mm=total,
        description="internal thread, entered from the neck end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "neck-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=neck_width,
        description="neck face toward the slot opening",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "flange-face",
        placement=@common.Placement::translation(0.0, 0.0, total),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=flange_width,
        description="flange face in the slot cavity",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-engagement",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=section.slot_opening_mm,
        depth_mm=section.depth_mm,
        description="slot series the T-nut engages",
      ),
    ),
  )
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
