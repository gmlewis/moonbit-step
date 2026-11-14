///|
/// linkage_bar builds a flat linkage or lever bar with two pivot holes and an
/// optional central adjustment slot.
///
/// Frame: the bar lies in the XY plane and spans `z = 0 .. thickness`. It is a
/// stadium (fully rounded ends) with its long axis along X and overall length
/// `length_mm`; the pivot holes lie on the X axis at `+/- pivot_spacing/2`. The
/// optional slot is a through obround centred on the origin with its long axis
/// along X.
///
/// Dimensions are millimetres. This is a generic engineered linkage envelope:
/// no standard table, bearing, bushing, or strength rating is implied. Use
/// `four_bar_layout` to compute closed joint positions for a planar four-bar
/// linkage built from these bars.
pub fn linkage_bar(
  length_mm : Double,
  width_mm : Double,
  thickness_mm : Double,
  pivot_diameter_mm : Double,
  pivot_spacing_mm? : Double,
  slot_length_mm~ : Double = 0.0,
  slot_width_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("linkage length", length_mm),
      ("linkage width", width_mm),
      ("linkage thickness", thickness_mm),
      ("linkage pivot diameter", pivot_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    mechanism_non_negative_checks([
      ("linkage slot length", slot_length_mm),
      ("linkage slot width", slot_width_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if width_mm >= length_mm {
    return Err(
      @common.InvalidDimension("linkage width must be smaller than its length"),
    )
  }
  if pivot_diameter_mm >= width_mm {
    return Err(
      @common.InvalidDimension(
        "linkage pivot diameter does not fit the bar width",
      ),
    )
  }
  let spacing = match pivot_spacing_mm {
    Some(s) => s
    None => length_mm - width_mm
  }
  if spacing <= pivot_diameter_mm || spacing > length_mm - width_mm {
    return Err(
      @common.InvalidDimension(
        "linkage pivot spacing must leave a full-width straight section inside the stadium",
      ),
    )
  }
  if (slot_length_mm == 0.0) != (slot_width_mm == 0.0) {
    return Err(
      @common.InvalidParameter(
        "linkage slot length and width must both be zero or both be positive",
      ),
    )
  }
  let has_slot = slot_length_mm > 0.0
  if has_slot {
    if slot_width_mm <= 0.0 {
      return Err(@common.InvalidDimension("linkage slot width must be > 0"))
    }
    if slot_width_mm >= width_mm {
      return Err(@common.InvalidDimension("linkage slot is wider than the bar"))
    }
    if slot_length_mm < slot_width_mm {
      return Err(
        @common.InvalidParameter(
          "linkage slot length must be at least its width",
        ),
      )
    }
    let slot_right = slot_length_mm / 2.0
    let pivot_edge = spacing / 2.0 - pivot_diameter_mm / 2.0
    if slot_right > pivot_edge {
      return Err(
        @common.InvalidDimension(
          "linkage slot overlaps the pivot holes; lengthen the bar or shorten the slot",
        ),
      )
    }
  }
  let pivot_radius = pivot_diameter_mm / 2.0
  let loops : Array[Array[@cad.ProfileSegment]] = if has_slot {
    [
      circle_loop(-spacing / 2.0, 0.0, pivot_radius),
      circle_loop(spacing / 2.0, 0.0, pivot_radius),
      slot_loop(0.0, 0.0, slot_length_mm, slot_width_mm),
    ]
  } else {
    [
      circle_loop(-spacing / 2.0, 0.0, pivot_radius),
      circle_loop(spacing / 2.0, 0.0, pivot_radius),
    ]
  }
  let body = @cad.ExtrudedArcProfile::new(
    stadium_loop(length_mm / 2.0 - width_mm / 2.0, width_mm / 2.0),
    thickness_mm,
    holes=loops,
  ).as_shape()
  let modeled : Array[String] = ["stadium-body", "pivot-holes"]
  if has_slot {
    modeled.push("adjustment-slot")
  }
  let features = @common.FeatureRecord::new(modeled~, approximated=[], omitted=[
    @common.Omission::new(
      feature="bushings-and-bearings",
      reason="pivot interfaces are bare through holes; no bearing is modelled",
    ),
    @common.Omission::new(
      feature="edge-breaks",
      reason="no edge treatment is asserted",
    ),
  ])
  let name = "linkage-\{@cad.fmt_double(length_mm, None)}x\{@cad.fmt_double(width_mm, None)}"
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Linkage bar L\{@cad.fmt_double(length_mm, None)} W\{@cad.fmt_double(width_mm, None)}",
      family="linkage bar (engineering envelope)",
      size="\{@cad.fmt_double(length_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
      source="Parametric linkage envelope with analytic pivot holes and an optional obround slot. No standard or vendor part is implied.",
    ),
    description="Flat stadium-shaped linkage bar with two analytic pivot holes and an optional central adjustment slot. No bearing, bushing, or strength rating is implied.",
    features~,
  ).add_layer(body, name="body", color~)
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pivot-a",
        placement=@common.Placement::translation(-spacing / 2.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=pivot_diameter_mm,
        depth_mm=thickness_mm,
        description="negative-X pivot hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pivot-b",
        placement=@common.Placement::translation(spacing / 2.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=pivot_diameter_mm,
        depth_mm=thickness_mm,
        description="positive-X pivot hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="top face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-bottom",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="bottom face",
      ),
    )
  if has_slot {
    component = component.with_connector_unchecked(
      @common.MateConnector::new(
        "adjustment-slot",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=slot_width_mm,
        depth_mm=thickness_mm,
        description="obround through slot; long axis +X",
      ),
    )
  }
  Ok(component)
}

///|
/// linkage_bar_from_lengths is the `Length`-taking form of `linkage_bar`.
///
/// Bare `Double` dimensions in this library are millimetres; this wrapper makes
/// the unit explicit for callers that already hold `@cad.Length` values.
pub fn linkage_bar_from_lengths(
  length : @cad.Length,
  width : @cad.Length,
  thickness : @cad.Length,
  pivot_diameter : @cad.Length,
  pivot_spacing? : @cad.Length,
  slot_length~ : @cad.Length = @cad.Length::mm(0.0),
  slot_width~ : @cad.Length = @cad.Length::mm(0.0),
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let spacing = match pivot_spacing {
    Some(s) => Some(s.to_mm())
    None => None
  }
  match spacing {
    Some(s) =>
      linkage_bar(
        length.to_mm(),
        width.to_mm(),
        thickness.to_mm(),
        pivot_diameter.to_mm(),
        pivot_spacing_mm=s,
        slot_length_mm=slot_length.to_mm(),
        slot_width_mm=slot_width.to_mm(),
        color~,
      )
    None =>
      linkage_bar(
        length.to_mm(),
        width.to_mm(),
        thickness.to_mm(),
        pivot_diameter.to_mm(),
        slot_length_mm=slot_length.to_mm(),
        slot_width_mm=slot_width.to_mm(),
        color~,
      )
  }
}

///|
/// FourBarLayout is one closed pose of a planar four-bar linkage.
///
/// The fixed pivots are `crank_pivot` at `(0, 0)` and `ground_pivot` at
/// `(ground, 0)`. `crank_joint` is the moving end of the crank and
/// `rocker_joint` the moving end of the rocker; `coupler_point` is the midpoint
/// of the coupler. The `branch` sign selects the mirror pose across the line
/// between the crank joint and the ground pivot.
pub(all) struct FourBarLayout {
  ground_mm : Double
  crank_mm : Double
  coupler_mm : Double
  rocker_mm : Double
  crank_angle_deg : Double
  crank_pivot : (Double, Double)
  crank_joint : (Double, Double)
  rocker_joint : (Double, Double)
  ground_pivot : (Double, Double)
  coupler_point : (Double, Double)
  grashof : Bool
  crank_rocker : Bool
}

///|
/// four_bar_layout closes a planar four-bar linkage at a crank angle.
///
/// The rocker joint is the intersection of the coupler circle around the crank
/// joint and the rocker circle around the ground pivot. `branch = 1` selects
/// the left-hand normal of the crank-joint-to-ground-pivot line;
/// `branch = -1` selects the mirror pose. A pose that cannot close is a typed
/// error. The helper reports the Grashof condition and whether this is a
/// crank-rocker arrangement (Grashof with the crank as the shortest link).
pub fn four_bar_layout(
  ground_mm : Double,
  crank_mm : Double,
  coupler_mm : Double,
  rocker_mm : Double,
  crank_angle_deg : Double,
  branch~ : Int32 = 1,
) -> Result[FourBarLayout, @common.SpecError] {
  match
    mechanism_checks([
      ("four-bar ground link", ground_mm),
      ("four-bar crank", crank_mm),
      ("four-bar coupler", coupler_mm),
      ("four-bar rocker", rocker_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if !@common.is_finite(crank_angle_deg) {
    return Err(@common.InvalidParameter("four-bar crank angle must be finite"))
  }
  let angle = crank_angle_deg * @math.PI / 180.0
  let bx = crank_mm * @math.cos(angle)
  let by = crank_mm * @math.sin(angle)
  let ddx = ground_mm - bx
  let ddy = -by
  let d = (ddx * ddx + ddy * ddy).sqrt()
  let sum = coupler_mm + rocker_mm
  let diff = (coupler_mm - rocker_mm).abs()
  if d > sum + 1.0e-9 || d < diff - 1.0e-9 {
    return Err(
      @common.InvalidParameter(
        "four-bar linkage does not close at this crank angle",
      ),
    )
  }
  if d <= 1.0e-12 {
    return Err(
      @common.InvalidParameter(
        "four-bar crank joint coincides with the ground pivot",
      ),
    )
  }
  let a0 = (coupler_mm * coupler_mm - rocker_mm * rocker_mm + d * d) / (2.0 * d)
  let h2 = coupler_mm * coupler_mm - a0 * a0
  let h = if h2 <= 0.0 { 0.0 } else { h2.sqrt() }
  let ux = ddx / d
  let uy = ddy / d
  let px = bx + a0 * ux
  let py = by + a0 * uy
  let sign = if branch >= 0 { 1.0 } else { -1.0 }
  let cx = px + sign * h * -uy
  let cy = py + sign * h * ux
  let lengths = [ground_mm, crank_mm, coupler_mm, rocker_mm]
  let mut shortest = lengths[0]
  let mut longest = lengths[0]
  let mut total = 0.0
  for length in lengths {
    if length < shortest {
      shortest = length
    }
    if length > longest {
      longest = length
    }
    total += length
  }
  let grashof = shortest + longest <= total - shortest - longest + 1.0e-9
  let crank_rocker = grashof && crank_mm <= shortest + 1.0e-9
  Ok({
    ground_mm,
    crank_mm,
    coupler_mm,
    rocker_mm,
    crank_angle_deg,
    crank_pivot: (0.0, 0.0),
    crank_joint: (bx, by),
    rocker_joint: (cx, cy),
    ground_pivot: (ground_mm, 0.0),
    coupler_point: ((bx + cx) / 2.0, (by + cy) / 2.0),
    grashof,
    crank_rocker,
  })
}
