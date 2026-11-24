///|
/// gobilda_channel_clearance_mm is the gap kept between a hole and a bearing hole
/// so the modelled grid never intersects a bearing seat.
let gobilda_channel_clearance_mm : Double = 0.5

///|
/// gobilda_rect_loop_xy returns a counter-clockwise rectangular loop.
fn gobilda_rect_loop_xy(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, y0), (x1, y0)),
    @cad.SegmentLine((x1, y0), (x1, y1)),
    @cad.SegmentLine((x1, y1), (x0, y1)),
    @cad.SegmentLine((x0, y1), (x0, y0)),
  ]
}

///|
/// gobilda_u_channel builds a goBILDA 1120-series U-channel.
///
/// Frame: the channel opens along +Z. The base spans `x = -24 .. 24`,
/// `y = -length/2 .. length/2`, `z = 0 .. 2.5`; the two legs rise from `z = 2.5`
/// to `z = 48`, giving the published **48 x 48 mm** outside, **43 mm** inside,
/// and **2.5 mm** wall. The length follows the part numbering
/// `1120-00NN-LLLL`: `holes` bearing holes at a 24 mm pitch give a length of
/// `(holes + 1) * 24` mm (8 holes = 216 mm) unless `length_mm` is supplied.
///
/// The base carries the modelled mounting pattern: 4 mm holes on the 8 mm grid
/// in four columns at `x = -16, -8, +8, +16`, plus one **14 mm** bearing hole on
/// the centre line every 24 mm; a grid hole that would intersect a bearing hole
/// is omitted. The two legs are modelled as plain plates. The clocked 45-degree
/// slots, the 16 mm retainer bolt patterns, the 24 mm bearing circles, the leg
/// hole patterns, and the bent-sheet radius are declared omissions — this is a
/// structural envelope, not a bit-exact vendor copy.
///
/// Source: https://www.gobilda.com/1120-series-u-channel (48 x 48 x 2.5 mm,
/// 4 mm holes on an 8 mm grid, 14 mm bearing holes on a 24 mm pitch).
pub fn gobilda_u_channel(
  holes~ : Int32 = 8,
  length_mm? : Double,
  thickness_mm~ : Double = gobilda_sheet_thickness_mm,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if holes < 1 {
    return Err(
      @common.InvalidParameter(
        "goBILDA U-channel needs at least one bearing hole",
      ),
    )
  }
  match @common.require_positive("goBILDA U-channel thickness", thickness_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let length = match length_mm {
    Some(value) =>
      match @common.require_positive("goBILDA U-channel length", value) {
        Err(e) => return Err(e)
        Ok(_) => value
      }
    None => (holes.to_double() + 1.0) * gobilda_bearing_pitch_mm
  }
  if length < 2.0 * gobilda_bearing_pitch_mm {
    return Err(
      @common.InvalidDimension(
        "goBILDA U-channel is too short for its bearing holes",
      ),
    )
  }
  let half_len = length / 2.0
  let width = 48.0
  let half_width = width / 2.0
  let height = 48.0
  let inner_half = half_width - thickness_mm
  // Bearing-hole centres down the base.
  let bearing_ys : Array[Double] = []
  for j in 0..<holes {
    bearing_ys.push(
      -half_len +
      gobilda_bearing_pitch_mm +
      j.to_double() * gobilda_bearing_pitch_mm,
    )
  }
  // 4 mm grid rows along the length, one pitch in from each end.
  let rows : Array[Double] = []
  let row_count = (length / gobilda_grid_mm).to_int() - 1
  for i in 0..<row_count {
    rows.push(-half_len + gobilda_grid_mm + i.to_double() * gobilda_grid_mm)
  }
  // 4 mm grid columns across the width (centre column reserved for bearings).
  let columns : Array[Double] = [
    -2.0 * gobilda_grid_mm,
    -gobilda_grid_mm,
    gobilda_grid_mm,
    2.0 * gobilda_grid_mm,
  ]
  let hole_radius = gobilda_hole_diameter_mm / 2.0
  let bearing_radius = gobilda_bearing_hole_mm / 2.0
  let keep_distance = bearing_radius +
    hole_radius +
    gobilda_channel_clearance_mm
  let holes_profile : Array[Array[@cad.ProfileSegment]] = []
  // Base mounting grid, minus holes that would intersect a bearing seat.
  for x in columns {
    for y in rows {
      let mut too_close = false
      for by in bearing_ys {
        let dx = x
        let dy = y - by
        if (dx * dx + dy * dy).sqrt() < keep_distance {
          too_close = true
        }
      }
      if !too_close {
        holes_profile.push(@common.circle_loop(x, y, hole_radius))
      }
    }
  }
  // 14 mm bearing holes.
  for by in bearing_ys {
    holes_profile.push(@common.circle_loop(0.0, by, bearing_radius))
  }
  let base = @cad.ExtrudedArcProfile::new(
    gobilda_rect_loop_xy(-half_width, -half_len, half_width, half_len),
    thickness_mm,
    holes=holes_profile,
  ).as_shape()
  let leg_height = height - thickness_mm
  let leg = @cad.Cuboid::new(thickness_mm, length, leg_height)
  let features = @common.FeatureRecord::new(
    modeled=["u-section", "base-4mm-grid", "14mm-bearing-holes", "two-legs"],
    approximated=[
      @common.Approximation::new(
        feature="base-hole-pattern",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the goBILDA base pattern is a four-column 8 mm grid; holes that meet a bearing seat are omitted and the clocked slots are not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="leg-hole-pattern",
        reason="the two legs are plain plates; their goBILDA hole pattern is not modelled",
      ),
      @common.Omission::new(
        feature="clocked-slots",
        reason="the 45-degree adjustment slots and 16 mm retainer bolt patterns are not modelled",
      ),
      @common.Omission::new(
        feature="bend-radius",
        reason="the bent-sheet corner radius is not modelled",
      ),
    ],
  )
  let name = "gobilda-u-channel-\{holes}-hole"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="goBILDA U-channel \{holes} hole (\{@cad.fmt_double(length, None)} mm)",
        standard="goBILDA 8 mm pattern",
        family="goBILDA U-channel",
        size="\{holes}-hole",
        length_mm=length,
        material="aluminium, clear anodized",
        source="https://www.gobilda.com/1120-series-u-channel | 48 x 48 x 2.5 mm U-section (43 mm inside) | 4 mm holes on an 8 mm grid, 14 mm bearing holes on a 24 mm pitch | length (holes+1)x24 mm",
      ),
      description="goBILDA 1120-series U-channel envelope: exact 48 x 48 x 2.5 mm U-section with the base 4 mm mounting grid and 14 mm bearing seats. The leg hole pattern, clocked slots, retainer patterns, and bend radius are omitted.",
      features~,
    )
    .add_layer(base, name="base", color~)
    .add_layer(
      leg,
      name="leg-left",
      color~,
      placement=@common.Placement::translation(
        -half_width,
        -half_len,
        thickness_mm,
      ),
    )
    .add_layer(
      leg,
      name="leg-right",
      color~,
      placement=@common.Placement::translation(
        inner_half,
        -half_len,
        thickness_mm,
      ),
    )
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-outer",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width,
        description="base outer face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-inner",
        placement=@common.Placement::translation(0.0, 0.0, thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * inner_half,
        description="base inner face; outward normal is +Z",
      ),
    )
  let mut index = 0
  for by in bearing_ys {
    index += 1
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "bearing-hole-\{index}",
        placement=@common.Placement::translation(0.0, by, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=gobilda_bearing_hole_mm,
        depth_mm=thickness_mm,
        description="14 mm bearing seat through the base",
      ),
    )
  }
  Ok(out)
}

///|
/// gobilda_u_channel_family exposes the goBILDA U-channel as a validated design
/// family with one preset per published bearing-hole count.
pub fn gobilda_u_channel_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="holes",
      default_mm=8.0,
      min_mm=1.0,
      max_mm=24.0,
      unit="count",
      description="bearing-hole count (length = (holes+1) x 24 mm)",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=gobilda_sheet_thickness_mm,
      min_mm=1.0,
      max_mm=6.0,
      description="wall thickness",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="gobilda-u-channel",
      specs~,
      description="goBILDA 1120-series U-channel envelopes.",
      build=fn(parameters) {
        let holes = match parameters.get("holes") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let thickness = match parameters.get("thickness") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        gobilda_u_channel(holes=holes.to_int(), thickness_mm=thickness)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for count in [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 13] {
    let name = "\{count}-hole"
    out = match out.with_variant(name, [("holes", count.to_double())]) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
