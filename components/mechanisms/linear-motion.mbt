///|
/// LinearRailProfile describes a generic profiled linear-rail cross-section.
///
/// The section is a rectangle with a shallow longitudinal groove on each side.
/// It is an engineering envelope for MGN-style rails, not a vendor section.
pub(all) struct LinearRailProfile {
  width_mm : Double
  height_mm : Double
  groove_width_mm : Double
  groove_depth_mm : Double
  groove_center_mm : Double
}

///|
/// linear_rail_profile validates a generic linear-rail cross-section.
pub fn linear_rail_profile(
  width_mm~ : Double,
  height_mm~ : Double,
  groove_width_mm~ : Double,
  groove_depth_mm~ : Double,
  groove_center_mm? : Double,
) -> Result[LinearRailProfile, @common.SpecError] {
  match
    mechanism_checks([
      ("rail width", width_mm),
      ("rail height", height_mm),
      ("rail groove width", groove_width_mm),
      ("rail groove depth", groove_depth_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let center = match groove_center_mm {
    Some(c) => c
    None => height_mm / 2.0
  }
  if groove_depth_mm >= width_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "rail groove depth must be smaller than half the width",
      ),
    )
  }
  if groove_width_mm >= height_mm {
    return Err(
      @common.InvalidDimension(
        "rail groove width must be smaller than the rail height",
      ),
    )
  }
  if center - groove_width_mm / 2.0 <= 0.0 ||
    center + groove_width_mm / 2.0 >= height_mm {
    return Err(
      @common.InvalidDimension("rail groove must lie inside the rail height"),
    )
  }
  Ok({
    width_mm,
    height_mm,
    groove_width_mm,
    groove_depth_mm,
    groove_center_mm: center,
  })
}

///|
/// RAIL_BASE_GROOVE_MARGIN_MM is the minimum material between the rail base
/// slab and the lower edge of the side grooves.
const RAIL_BASE_GROOVE_MARGIN_MM : Double = 0.5

///|
/// linear_rail_section returns the counter-clockwise side-profile loop between
/// two full-rail height coordinates.
///
/// The loop is drawn in a local plane whose X is the rail height and whose Y is
/// the rail width; the builder rotates it so the rail runs along +X.
fn linear_rail_section(
  profile : LinearRailProfile,
  bottom_mm : Double,
  top_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let hw = profile.width_mm / 2.0
  let gw = profile.groove_width_mm / 2.0
  let gd = profile.groove_depth_mm
  let c = profile.groove_center_mm
  [
    @cad.SegmentLine((bottom_mm, -hw), (c - gw, -hw)),
    @cad.SegmentLine((c - gw, -hw), (c - gw, -hw + gd)),
    @cad.SegmentLine((c - gw, -hw + gd), (c + gw, -hw + gd)),
    @cad.SegmentLine((c + gw, -hw + gd), (c + gw, -hw)),
    @cad.SegmentLine((c + gw, -hw), (top_mm, -hw)),
    @cad.SegmentLine((top_mm, -hw), (top_mm, hw)),
    @cad.SegmentLine((top_mm, hw), (c + gw, hw)),
    @cad.SegmentLine((c + gw, hw), (c + gw, hw - gd)),
    @cad.SegmentLine((c + gw, hw - gd), (c - gw, hw - gd)),
    @cad.SegmentLine((c - gw, hw - gd), (c - gw, hw)),
    @cad.SegmentLine((c - gw, hw), (bottom_mm, hw)),
    @cad.SegmentLine((bottom_mm, hw), (bottom_mm, -hw)),
  ]
}

///|
/// linear_rail builds a profiled linear rail along +X.
///
/// Frame: the rail runs from `x = 0` to `x = length_mm`, its width is centred
/// on `y = 0`, and its base and top faces are at `z = 0` and
/// `z = profile.height_mm`. The side grooves are real analytic surfaces.
///
/// Mounting holes are modelled as real through holes in the rail base slab,
/// which is a separate layer from the profiled upper body. No load, life, or
/// rail-compatibility rating is implied.
pub fn linear_rail(
  profile : LinearRailProfile,
  length_mm : Double,
  mount_hole_count~ : Int32 = 4,
  mount_hole_diameter_mm~ : Double = 4.5,
  base_thickness_mm? : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("rail length", length_mm),
      ("rail mounting-hole diameter", mount_hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if mount_hole_count < 1 {
    return Err(
      @common.InvalidParameter("rail needs at least one mounting hole"),
    )
  }
  if mount_hole_diameter_mm >= profile.width_mm / 2.0 {
    return Err(
      @common.InvalidDimension("rail mounting hole does not fit the base width"),
    )
  }
  let groove_bottom = profile.groove_center_mm - profile.groove_width_mm / 2.0
  let base_limit = groove_bottom - RAIL_BASE_GROOVE_MARGIN_MM
  let base = match base_thickness_mm {
    Some(b) => b
    None => {
      let derived = profile.height_mm * 0.35
      if derived < base_limit {
        derived
      } else {
        base_limit
      }
    }
  }
  if base <= 0.0 || base > base_limit {
    return Err(
      @common.InvalidDimension(
        "rail base thickness does not leave room for the side grooves",
      ),
    )
  }
  if base >= profile.height_mm {
    return Err(
      @common.InvalidDimension(
        "rail base thickness must be smaller than its height",
      ),
    )
  }
  let spacing = length_mm / (mount_hole_count + 1).to_double()
  if spacing <= mount_hole_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "rail mounting holes overlap; reduce the diameter or increase the length",
      ),
    )
  }
  let half_width = profile.width_mm / 2.0
  let hole_loops : Array[Array[@cad.ProfileSegment]] = []
  for i in 0..<mount_hole_count {
    hole_loops.push(
      circle_loop(
        spacing * (i + 1).to_double(),
        0.0,
        mount_hole_diameter_mm / 2.0,
      ),
    )
  }
  let base_shape = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, -half_width, length_mm, half_width),
    base,
    holes=hole_loops,
  ).as_shape()
  let upper_profile : LinearRailProfile = {
    ..profile,
    height_mm: profile.height_mm - base,
    groove_center_mm: profile.groove_center_mm - base,
  }
  let section = @cad.ExtrudedArcProfile::new(
    linear_rail_section(upper_profile, 0.0, upper_profile.height_mm),
    length_mm,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["rail-body", "side-grooves", "mounting-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="end-chamfers-and-hardened-surfaces",
        reason="no edge treatment or material claim is modelled",
      ),
      @common.Omission::new(
        feature="base-slab-union",
        reason="the base slab and profiled upper body are separate layers with a nominal abutment",
      ),
    ],
  )
  let name = "linear-rail-\{@cad.fmt_double(profile.width_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  let mut out = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Linear rail \{@cad.fmt_double(profile.width_mm, None)} wide x \{@cad.fmt_double(length_mm, None)}",
        family="linear rail (engineering envelope)",
        size="\{@cad.fmt_double(profile.width_mm, None)}x\{@cad.fmt_double(profile.height_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
        length_mm~,
        source="Parametric profiled-rail envelope with a rectangular body, side grooves, and a base slab with real mounting holes. No vendor section or load rating is implied.",
      ),
      description="Profiled linear rail with real side grooves along +X and a base slab carrying real through mounting holes. The base and upper body are separate layers with a nominal abutment.",
      features~,
    )
    .add_layer(base_shape, name="base-slab", color~)
    .add_layer(
      section,
      name="rail",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, 0.0, profile.height_mm),
        @common.Placement::rotation_y(90.0),
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-axis",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          profile.height_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=profile.width_mm,
        depth_mm=length_mm,
        description="rail running axis along +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-top",
        placement=@common.Placement::translation(
          length_mm / 2.0,
          0.0,
          profile.height_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=profile.width_mm,
        description="rail top face (running datum), outward normal +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-base",
        placement=@common.Placement::translation(length_mm / 2.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=profile.width_mm,
        description="rail mounting face, outward normal -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          profile.height_mm / 2.0,
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=profile.width_mm,
        description="rail negative-X end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(
          length_mm,
          0.0,
          profile.height_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=profile.width_mm,
        description="rail positive-X end datum",
      ),
    )
  for i in 0..<mount_hole_count {
    let x = spacing * (i + 1).to_double()
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{i + 1}",
        placement=@common.Placement::translation(x, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=mount_hole_diameter_mm,
        depth_mm=base,
        description="through mounting hole in the rail base slab",
      ),
    )
  }
  Ok(out)
}

///|
/// linear_carriage builds a U-channel carriage block that fits a rail profile.
///
/// Frame: the block is centred on the XY origin and spans `z = 0 .. block_height`.
/// Its length runs along X and its width along Y. The channel opens downward
/// (-Z) and is `rail_width + 2 * clearance` wide and `rail_height + clearance`
/// high, so a `linear_rail` slides through it along X. Two analytic bolt holes
/// pass through the top slab along +Z.
///
/// The two side walls and the top slab are separate layers; they abut nominally
/// rather than through a kernel union. No bearing balls, seals, preload, or
/// load rating is modelled.
pub fn linear_carriage(
  profile : LinearRailProfile,
  block_length_mm : Double,
  block_width_mm : Double,
  block_height_mm : Double,
  clearance_mm~ : Double = 0.03,
  bolt_hole_diameter_mm~ : Double = 5.5,
  bolt_spacing_mm? : Double,
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("carriage block length", block_length_mm),
      ("carriage block width", block_width_mm),
      ("carriage block height", block_height_mm),
      ("carriage bolt hole diameter", bolt_hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match mechanism_non_negative_checks([("carriage clearance", clearance_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let channel_half = profile.width_mm / 2.0 + clearance_mm
  let channel_top = profile.height_mm + clearance_mm
  if channel_half >= block_width_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "carriage block is not wider than the rail channel",
      ),
    )
  }
  if channel_top >= block_height_mm {
    return Err(
      @common.InvalidDimension(
        "carriage block is not taller than the rail channel",
      ),
    )
  }
  let top_thickness = block_height_mm - channel_top
  if bolt_hole_diameter_mm + 2.0 * clearance_mm > top_thickness {
    return Err(
      @common.InvalidDimension(
        "carriage top slab is too thin for the bolt hole; increase the block height",
      ),
    )
  }
  let spacing = match bolt_spacing_mm {
    Some(s) => s
    None => block_length_mm * 0.3
  }
  if spacing + bolt_hole_diameter_mm / 2.0 >= block_length_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "carriage bolt holes do not fit the block length",
      ),
    )
  }
  let half_length = block_length_mm / 2.0
  let half_width = block_width_mm / 2.0
  let wall_left = @cad.ExtrudedArcProfile::new(
    rect_loop(-half_length, -half_width, half_length, -channel_half),
    channel_top,
  ).as_shape()
  let wall_right = @cad.ExtrudedArcProfile::new(
    rect_loop(-half_length, channel_half, half_length, half_width),
    channel_top,
  ).as_shape()
  let bolt_loops = [
    circle_loop(-spacing / 2.0, 0.0, bolt_hole_diameter_mm / 2.0),
    circle_loop(spacing / 2.0, 0.0, bolt_hole_diameter_mm / 2.0),
  ]
  let top_slab = @cad.ExtrudedArcProfile::new(
    rect_loop(-half_length, -half_width, half_length, half_width),
    top_thickness,
    holes=bolt_loops,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["channel-body", "top-slab", "bolt-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="bearing-balls-and-seals",
        reason="the carriage is a channel envelope; running elements are not modelled",
      ),
      @common.Omission::new(
        feature="wall-to-slab-union",
        reason="the walls and slab are separate layers with a nominal abutment",
      ),
      @common.Omission::new(
        feature="preload-and-load-rating",
        reason="no running clearance other than the declared channel clearance is asserted",
      ),
    ],
  )
  let name = "linear-carriage-\{@cad.fmt_double(block_length_mm, None)}x\{@cad.fmt_double(block_width_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Linear carriage \{@cad.fmt_double(block_length_mm, None)} x \{@cad.fmt_double(block_width_mm, None)} x \{@cad.fmt_double(block_height_mm, None)}",
        family="linear carriage (engineering envelope)",
        size="\{@cad.fmt_double(block_length_mm, None)}x\{@cad.fmt_double(block_width_mm, None)}x\{@cad.fmt_double(block_height_mm, None)}",
        source="Parametric U-channel carriage envelope sized for a generic profiled rail. No vendor part or load rating is implied.",
      ),
      description="U-channel linear carriage block with two analytic bolt holes through the top slab. The rail channel is a declared clearance envelope.",
      features~,
    )
    .add_layer(wall_left, name="wall-left", color~)
    .add_layer(wall_right, name="wall-right", color~)
    .add_layer(
      top_slab,
      name="top-slab",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, channel_top),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "block-face",
        placement=@common.Placement::translation(0.0, 0.0, block_height_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=block_width_mm,
        description="top mounting face, outward normal +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-channel",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=profile.width_mm + 2.0 * clearance_mm,
        depth_mm=block_length_mm,
        description="rail clearance channel along +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-1",
        placement=@common.Placement::translation(
          -spacing / 2.0,
          0.0,
          channel_top,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=top_thickness,
        description="negative-X top-slab bolt hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-2",
        placement=@common.Placement::translation(
          spacing / 2.0,
          0.0,
          channel_top,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=top_thickness,
        description="positive-X top-slab bolt hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(
          -half_length,
          0.0,
          block_height_mm / 2.0,
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=block_width_mm,
        description="carriage negative-X end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(
          half_length,
          0.0,
          block_height_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=block_width_mm,
        description="carriage positive-X end datum",
      ),
    ),
  )
}

///|
/// linear_travel_mm returns the usable carriage travel on a rail.
///
/// `rail_length - block_length` in millimetres. A non-positive result means the
/// block does not fit on the rail.
pub fn linear_travel_mm(
  rail_length_mm : Double,
  block_length_mm : Double,
) -> Result[Double, @common.SpecError] {
  let travel = rail_length_mm - block_length_mm
  if travel <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "carriage block does not fit on the rail; travel is not positive",
      ),
    )
  }
  Ok(travel)
}
