///|
/// gobilda_square_beam builds a goBILDA 1106-series square beam.
///
/// Frame: an 8 x 8 mm solid bar along Y (`x = -4 .. 4`, `y = -length/2 ..
/// length/2`, `z = -4 .. 4`). The length follows the part numbering
/// `1106-00NN-LLLL`: `holes * 8` mm (4-hole = 32 mm). Each hole station carries
/// a 4 mm through hole through Z (a real analytic hole) and a crossing 4 mm
/// through hole through X, which is a **nominal difference**: the flat STEP
/// writer concatenates the cutter faces and marks the file nominal, and the
/// external CAD kernel (SolidCraft / OCCT) performs the trim. The M4 x 0.7 end
/// threads are declared by `Threaded` connectors, not modelled.
///
/// Source: https://www.gobilda.com/1106-series-square-beam-4-hole-32mm-length
/// (8 x 8 mm, 4 mm holes on an 8 mm grid, M4 x 0.7 tapped ends 10 mm deep).
pub fn gobilda_square_beam(
  holes~ : Int32 = 4,
  length_mm? : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if holes < 1 {
    return Err(
      @common.InvalidParameter("goBILDA square beam needs at least one hole"),
    )
  }
  let length = match length_mm {
    Some(value) =>
      match @common.require_positive("goBILDA square beam length", value) {
        Err(e) => return Err(e)
        Ok(_) => value
      }
    None => holes.to_double() * gobilda_grid_mm
  }
  let half_len = length / 2.0
  let half = gobilda_grid_mm / 2.0
  let hole_radius = gobilda_hole_diameter_mm / 2.0
  // Hole stations: one hole per 8 mm, 4 mm in from each end.
  let stations : Array[Double] = []
  for i in 0..<holes {
    stations.push(
      -half_len + gobilda_grid_mm / 2.0 + i.to_double() * gobilda_grid_mm,
    )
  }
  // Real 4 mm holes through Z in the base prism.
  let z_holes : Array[Array[@cad.ProfileSegment]] = []
  for y in stations {
    z_holes.push(@common.circle_loop(0.0, y, hole_radius))
  }
  let beam = @cad.ExtrudedArcProfile::new(
      gobilda_rect_loop_xy(-half, -half_len, half, half_len),
      gobilda_grid_mm,
      holes=z_holes,
    )
    .as_shape()
    .with_name("beam")
    .translate(z=-half)
  // Crossing 4 mm holes through X plus the M4 end tap drills are a nominal
  // difference; the evaluated export trims them into one solid.
  let margin = 1.0
  let cross_cutters : Array[@cad.SceneNode] = stations.map(fn(y) {
    @cad.Cylinder::new(gobilda_hole_diameter_mm, gobilda_grid_mm + 2.0 * margin)
    .with_name("cross-hole-cutter")
    .rotate_y(90.0)
    .translate(x=-(half + margin), y~, z=0.0)
  })
  let tap_length = gobilda_end_tap_depth_mm + margin
  let tap_centre = gobilda_end_tap_depth_mm / 2.0 - margin / 2.0
  let tap_a = @cad.Cylinder::new(gobilda_m4_tap_drill_mm, tap_length)
    .with_name("end-tap-cutter")
    .rotate_x(-90.0)
    .translate(y=-half_len + tap_centre)
  let tap_b = @cad.Cylinder::new(gobilda_m4_tap_drill_mm, tap_length)
    .with_name("end-tap-cutter")
    .rotate_x(-90.0)
    .translate(y=half_len - tap_centre)
  let cutters = cross_cutters.copy()
  cutters.push(tap_a)
  cutters.push(tap_b)
  let body = @cad.difference(beam, cutters, name="body")
  let features = @common.FeatureRecord::new(
    modeled=["body", "z-through-holes", "crossing-x-holes", "end-tap-drills"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="cross-hole-trim",
        reason="the crossing X holes and end tap drills are a nominal difference: the flat writer concatenates the cutter faces and SolidCraft or the evaluated export performs the trim",
      ),
      @common.Omission::new(
        feature="end-thread-helix",
        reason="the M4 x 0.7 end threads are declared by Threaded connectors; the 3.3 mm tap drill that the thread cuts is modelled",
      ),
    ],
  )
  let name = "gobilda-square-beam-\{holes}-hole"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="goBILDA square beam \{holes} hole (\{@cad.fmt_double(length, None)} mm)",
      standard="goBILDA 8 mm pattern",
      family="goBILDA square beam",
      size="\{holes}-hole",
      length_mm=length,
      material="aluminium, clear anodized",
      source="https://www.gobilda.com/1106-series-square-beam-4-hole-32mm-length | 8 x 8 mm bar, 4 mm holes on an 8 mm grid, M4 x 0.7 tapped ends 10 mm deep | length = holes x 8 mm",
    ),
    description="goBILDA 1106-series square beam: an 8 x 8 mm bar with a 4 mm through hole and a crossing 4 mm hole per 8 mm station, plus a 3.3 mm M4 tap drill 10 mm deep at each end. The boolean trimming is resolved by the evaluated export; the threads themselves are declared by connectors.",
    features~,
  ).add_layer(body.shape_intent(), name="body", color~)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-thread-a",
        placement=@common.Placement::translation(0.0, -half_len, 0.0),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=gobilda_hole_diameter_mm,
        depth_mm=10.0,
        description="M4 x 0.7 end thread, 10 mm deep",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-thread-b",
        placement=@common.Placement::translation(0.0, half_len, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=gobilda_hole_diameter_mm,
        depth_mm=10.0,
        description="M4 x 0.7 end thread, 10 mm deep",
      ),
    )
  let mut index = 0
  for y in stations {
    index += 1
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "hole-\{index}",
        placement=@common.Placement::translation(0.0, y, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=gobilda_hole_diameter_mm,
        depth_mm=gobilda_grid_mm,
        description="4 mm through hole on the goBILDA 8 mm pattern",
      ),
    )
  }
  Ok(out)
}

///|
/// gobilda_square_beam_family exposes the goBILDA square beam as a validated
/// design family with one preset per published hole count.
pub fn gobilda_square_beam_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="holes",
      default_mm=4.0,
      min_mm=1.0,
      max_mm=24.0,
      unit="count",
      description="hole count (length = holes x 8 mm)",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="gobilda-square-beam",
      specs~,
      description="goBILDA 1106-series square beam envelopes.",
      build=fn(parameters) {
        let holes = match parameters.get("holes") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        gobilda_square_beam(holes=holes.to_int())
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for count in [2, 3, 4, 6, 8, 12, 16] {
    let name = "\{count}-hole"
    out = match out.with_variant(name, [("holes", count.to_double())]) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
