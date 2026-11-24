///|
/// openbuilds_rect_loop returns a counter-clockwise rectangular loop centred on
/// the origin.
fn openbuilds_rect_loop(
  half_x : Double,
  half_y : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((-half_x, -half_y), (half_x, -half_y)),
    @cad.SegmentLine((half_x, -half_y), (half_x, half_y)),
    @cad.SegmentLine((half_x, half_y), (-half_x, half_y)),
    @cad.SegmentLine((-half_x, half_y), (-half_x, -half_y)),
  ]
}

///|
/// openbuilds_cbeam_gantry_plate builds the OpenBuilds C-Beam gantry plate
/// (SKU 970).
///
/// Frame: a 77.5 x 77.5 mm plate, 6 mm thick, centred on the XY origin with
/// faces at `z = ±3`. It carries eight M5 tapped holes (modelled as Ø4.2 tap
/// drills through the 6 mm plate) at (±20, ±20) and (±10, ±30) from the centre,
/// matching the published plate drawing. The wheel recesses, countersinks, and
/// edge breaks are not modelled.
///
/// Source: OpenBuilds SKU 970 (6061-T5, 6 mm, 77.5 x 77.5 mm, 8 x M5 x 0.8
/// tapped 6 mm deep; design shared under CC BY-SA 4.0). This is a clean-room
/// reconstruction of the published dimensions, not redistributed vendor CAD.
pub fn openbuilds_cbeam_gantry_plate(
  size_mm~ : Double = 77.5,
  thickness_mm~ : Double = 6.0,
  hole_diameter_mm~ : Double = 4.2,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("C-Beam gantry plate size", size_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_positive("C-Beam gantry plate thickness", thickness_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_positive(
      "C-Beam gantry plate hole diameter", hole_diameter_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let half = size_mm / 2.0
  let hole_radius = hole_diameter_mm / 2.0
  let holes : Array[(Double, Double)] = [
    (-20.0, -20.0),
    (20.0, -20.0),
    (20.0, 20.0),
    (-20.0, 20.0),
    (-10.0, -30.0),
    (10.0, -30.0),
    (10.0, 30.0),
    (-10.0, 30.0),
  ]
  let loops : Array[Array[@cad.ProfileSegment]] = []
  for hole in holes {
    let (x, y) = hole
    if x.abs() + hole_radius > half || y.abs() + hole_radius > half {
      return Err(
        @common.InvalidDimension("C-Beam gantry plate hole does not fit"),
      )
    }
    loops.push(@common.circle_loop(x, y, hole_radius))
  }
  let body = @cad.ExtrudedArcProfile::new(
    openbuilds_rect_loop(half, half),
    thickness_mm,
    holes=loops,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "eight-tapped-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="wheel-recesses-and-countersinks",
        reason="the Mini V-wheel recesses and countersinks are not modelled",
      ),
      @common.Omission::new(
        feature="thread-helix",
        reason="the M5 tapped holes are modelled as tap-drill bores; the thread is declared by Threaded connectors",
      ),
      @common.Omission::new(
        feature="edge-breaks",
        reason="corner and edge breaks are not modelled",
      ),
    ],
  )
  let name = "openbuilds-cbeam-gantry-plate-\{@cad.fmt_double(size_mm, None)}"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="OpenBuilds C-Beam gantry plate (\{@cad.fmt_double(size_mm, None)} x \{@cad.fmt_double(thickness_mm, None)} mm)",
        standard="OpenBuilds C-Beam gantry plate (SKU 970)",
        family="OpenBuilds C-Beam gantry plate",
        size="\{@cad.fmt_double(size_mm, None)}",
        source="https://openbuildspartstore.com/c-beam-gantry-plate/ | SKU 970 | 6061-T5, 6 mm, 77.5 x 77.5 mm, 8x M5x0.8 tapped 6 mm deep at (±20,±20) and (±10,±30) | CC BY-SA 4.0 design",
      ),
      description="OpenBuilds C-Beam gantry plate: a 77.5 x 77.5 x 6 mm plate with eight M5 tapped holes. Wheel recesses, countersinks, and edge breaks are omitted; the holes are tap-drill bores with declared threads.",
      features~,
    )
    .add_layer(body, name="body", color~)
    .translate(z=-thickness_mm / 2.0)
  let half_thickness = thickness_mm / 2.0
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, half_thickness),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=size_mm,
        description="top face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-bottom",
        placement=@common.Placement::translation(0.0, 0.0, -half_thickness),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=size_mm,
        description="bottom face; outward normal is -Z",
      ),
    )
  let mut index = 0
  for hole in holes {
    let (x, y) = hole
    index += 1
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "hole-\{index}",
        placement=@common.Placement::translation(x, y, -half_thickness),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=5.0,
        depth_mm=thickness_mm,
        description="M5 tapped hole (tap-drill bore modelled)",
      ),
    )
  }
  Ok(out)
}

///|
/// openbuilds_gantry_plate_family exposes the C-Beam gantry plate as a validated
/// design family.
pub fn openbuilds_gantry_plate_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="size",
      default_mm=77.5,
      min_mm=40.0,
      max_mm=120.0,
      description="plate side length",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=6.0,
      min_mm=3.0,
      max_mm=10.0,
      description="plate thickness",
    ),
    @common.ParamSpec::new(
      name="hole",
      default_mm=4.2,
      min_mm=3.0,
      max_mm=6.0,
      description="tap-drill hole diameter",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="openbuilds-cbeam-gantry-plate",
      specs~,
      description="OpenBuilds C-Beam gantry plate (SKU 970) envelopes.",
      build=fn(parameters) {
        let size = match parameters.get("size") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let thickness = match parameters.get("thickness") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let hole = match parameters.get("hole") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        openbuilds_cbeam_gantry_plate(
          size_mm=size,
          thickness_mm=thickness,
          hole_diameter_mm=hole,
        )
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("sku-970", [
    ("size", 77.5),
    ("thickness", 6.0),
    ("hole", 4.2),
  ])
}
