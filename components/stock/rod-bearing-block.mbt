///|
/// Extra cutter length at each end of a through bore.
const ROD_BLOCK_CUTTER_MARGIN_MM : Double = 1.0

///|
/// rounded_block_loop returns a counter-clockwise rounded rectangle in XY.
fn rounded_block_loop(
  width_mm : Double,
  depth_mm : Double,
  radius_mm : Double,
) -> Array[@cad.ProfileSegment] {
  if radius_mm == 0.0 {
    return plate_rect_loop(width_mm, depth_mm)
  }
  let hx = width_mm / 2.0
  let hy = depth_mm / 2.0
  let r = radius_mm
  [
    @cad.SegmentLine((-hx + r, -hy), (hx - r, -hy)),
    @cad.SegmentArc((hx - r, -hy), (hx, -hy + r), (hx - r, -hy + r)),
    @cad.SegmentLine((hx, -hy + r), (hx, hy - r)),
    @cad.SegmentArc((hx, hy - r), (hx - r, hy), (hx - r, hy - r)),
    @cad.SegmentLine((hx - r, hy), (-hx + r, hy)),
    @cad.SegmentArc((-hx + r, hy), (-hx, hy - r), (-hx + r, hy - r)),
    @cad.SegmentLine((-hx, hy - r), (-hx, -hy + r)),
    @cad.SegmentArc((-hx, -hy + r), (-hx + r, -hy), (-hx + r, -hy + r)),
  ]
}

///|
/// rod_bearing_block builds a rounded rectangular block for an LM-style linear
/// bearing and its round rod. The bearing seat is a through bore along +Y,
/// centred in X and Z. Four mounting through-holes run along +Z on the stated
/// rectangular pitch. The block occupies `z = 0 .. height_mm`.
///
/// `bearing_diametral_clearance_mm` changes the nominal seat diameter; it is a
/// diametral value, not a radial value or a tolerance-class specification.
/// `bearing_fit` records design intent independently of that nominal geometry.
/// The bearing and rod are separate parts. In particular, the SC8UU preset has
/// a nominal Ø15 seat and a declared press-fit intent, with no tolerance added.
/// The Ø8 `rod-axis` connector describes the installed LM8UU interface, not an
/// additional hole cut through the block.
///
/// The corner rounds lie on the four edges parallel to the bearing axis (+Y).
/// The bearing seat is an explicit analytic profile hole. The vertical mounting
/// holes require `write_step_evaluated`; flat `to_step` output is nominal and is
/// not the accepted artifact. No load, life, retention, or joint-strength rating
/// is implied.
pub fn rod_bearing_block(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  bearing_outside_diameter_mm : Double,
  rod_diameter_mm : Double,
  mount_hole_diameter_mm : Double,
  mount_pitch_x_mm : Double,
  mount_pitch_y_mm : Double,
  corner_radius_mm~ : Double = 2.0,
  bearing_diametral_clearance_mm~ : Double = 0.0,
  bearing_fit~ : @cad.Fit = @cad.Fit::Nominal,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("bearing block width", width_mm),
    @common.require_positive("bearing block depth", depth_mm),
    @common.require_positive("bearing block height", height_mm),
    @common.require_positive(
      "bearing outside diameter", bearing_outside_diameter_mm,
    ),
    @common.require_positive("rod diameter", rod_diameter_mm),
    @common.require_positive("mounting hole diameter", mount_hole_diameter_mm),
    @common.require_positive("mounting X pitch", mount_pitch_x_mm),
    @common.require_positive("mounting Y pitch", mount_pitch_y_mm),
    @common.require_non_negative(
      "bearing block corner radius", corner_radius_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let seat_diameter = bearing_outside_diameter_mm +
    bearing_diametral_clearance_mm
  if seat_diameter <= 0.0 {
    return Err(
      @common.InvalidDimension("bearing seat diameter must remain positive"),
    )
  }
  if rod_diameter_mm >= seat_diameter {
    return Err(
      @common.InvalidDimension(
        "rod diameter must be smaller than the fitted bearing seat",
      ),
    )
  }
  if corner_radius_mm * 2.0 >= width_mm || corner_radius_mm * 2.0 >= height_mm {
    return Err(
      @common.InvalidDimension("bearing block corner radius does not fit"),
    )
  }
  let seat_radius = seat_diameter / 2.0
  if seat_radius >= width_mm / 2.0 || seat_radius >= height_mm / 2.0 {
    return Err(
      @common.InvalidDimension("bearing seat does not fit inside the block"),
    )
  }
  let mount_radius = mount_hole_diameter_mm / 2.0
  let mount_x = mount_pitch_x_mm / 2.0
  let mount_y = mount_pitch_y_mm / 2.0
  if mount_pitch_x_mm <= mount_hole_diameter_mm ||
    mount_pitch_y_mm <= mount_hole_diameter_mm {
    return Err(@common.InvalidParameter("mounting holes overlap each other"))
  }
  if mount_x - mount_radius <= seat_radius {
    return Err(
      @common.InvalidParameter("mounting holes overlap the bearing seat"),
    )
  }
  if mount_x + mount_radius >= width_mm / 2.0 ||
    mount_y + mount_radius >= depth_mm / 2.0 {
    return Err(
      @common.InvalidDimension("mounting holes do not fit inside the block"),
    )
  }
  if mount_x + mount_radius >= width_mm / 2.0 - corner_radius_mm {
    return Err(
      @common.InvalidDimension(
        "mounting holes intersect the bearing-parallel corner rounds",
      ),
    )
  }
  let mounts : Array[(Double, Double)] = [
    (-mount_x, -mount_y),
    (mount_x, -mount_y),
    (mount_x, mount_y),
    (-mount_x, mount_y),
  ]
  let base = @cad.ExtrudedArcProfile::new(
      rounded_block_loop(width_mm, height_mm, corner_radius_mm),
      depth_mm,
      holes=[plate_circle_loop(0.0, 0.0, seat_radius)],
    )
    .as_shape()
    .with_name("rounded-block-with-bearing-seat")
    .rotate_x(90.0)
    .translate(y=depth_mm / 2.0, z=height_mm / 2.0)
  let cutter_length = height_mm + 2.0 * ROD_BLOCK_CUTTER_MARGIN_MM
  let mount_cutters = mounts.map(fn(p) {
    let (x, y) = p
    @cad.Cylinder::new(mount_hole_diameter_mm, cutter_length)
    .with_name("mount-hole-cutter")
    .translate(x~, y~, z=-ROD_BLOCK_CUTTER_MARGIN_MM)
  })
  let body = @cad.difference(base, mount_cutters, name="body")
  let features = @common.FeatureRecord::new(
    modeled=[
      "rounded-block-body", "bearing-parallel-corner-rounds", "bearing-seat", "four-mounting-holes",
      "mounting-faces",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="bearing-and-rod",
        reason="the LM bearing and rod are separate parts; only their mating interfaces are declared",
      ),
      @common.Omission::new(
        feature="manufacturing-tolerances",
        reason="all geometry is nominal; fit intent does not add a tolerance or strength claim",
      ),
      @common.Omission::new(
        feature="load-life-and-retention-rating",
        reason="geometry alone does not establish bearing load, life, press-fit retention, or mounting strength",
      ),
    ],
  )
  let mut component = @common.Component::new(
    name="rod-bearing-block-\{@cad.fmt_double(bearing_outside_diameter_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Rod bearing block for bearing OD \{@cad.fmt_double(bearing_outside_diameter_mm, None)} and rod Ø\{@cad.fmt_double(rod_diameter_mm, None)}",
      family="rod-to-bearing block",
      size="\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(depth_mm, None)}x\{@cad.fmt_double(height_mm, None)}",
      source="Parametric rounded block; SC8UU preset follows Xem Studio's CC BY 4.0 dimension sheet and STEP reference (34 x 30 x 22, Ø15 seat, four Ø3.3 holes on 24 x 18 pitch).",
    ),
    description="Rounded rod/bearing block with four corner rounds parallel to the transverse bearing seat and four vertical mounting holes. Geometry is nominal; fit intent and strength are separate. Use write_step_evaluated for the real mounting bores.",
    features~,
  ).add_layer(body.shape_intent(), name="body", color~)
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bearing-seat",
        placement=@common.Placement::translation(
          0.0,
          -depth_mm / 2.0,
          height_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=seat_diameter,
        depth_mm~,
        fit=bearing_fit,
        description="bearing OD seat; diametral clearance \{@cad.fmt_double(bearing_diametral_clearance_mm, None)} mm; fit is declared intent, not a tolerance class",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rod-axis",
        placement=@common.Placement::translation(
          0.0,
          -depth_mm / 2.0,
          height_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=rod_diameter_mm,
        depth_mm~,
        description="nominal rod axis through the separately installed linear bearing",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-base",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="base mounting face; outward normal -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, height_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="top face; outward normal +Z",
      ),
    )
  for i, p in mounts {
    let (x, y) = p
    component = component.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{i + 1}",
        placement=@common.Placement::translation(x, y, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=mount_hole_diameter_mm,
        depth_mm=height_mm,
        fit=@cad.Fit::Free,
        description="vertical mounting hole; nominal geometry with no added tolerance",
      ),
    )
  }
  Ok(component)
}

///|
/// sc8uu_bearing_block builds the dimensioned Xem Studio SC8UU reference:
/// 34 x 30 x 22 mm, R2 rounds on the four edges parallel to the +Y bearing axis,
/// and four Ø3.3 mounting holes on a 24 x 18 mm pitch. The matching rod is Ø8.
pub fn sc8uu_bearing_block(
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  rod_bearing_block(
    34.0,
    30.0,
    22.0,
    15.0,
    8.0,
    3.3,
    24.0,
    18.0,
    bearing_fit=@cad.Fit::Press,
    color~,
  )
}
