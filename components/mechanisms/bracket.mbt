///|
/// bracket_centered_grid returns `count` positions spaced `pitch` apart and
/// centred on `center`.
fn bracket_centered_grid(
  count : Int32,
  center : Double,
  pitch : Double,
) -> Array[Double] {
  let mid = (count - 1).to_double() / 2.0
  let out : Array[Double] = []
  for i in 0..<count {
    out.push(center + (i.to_double() - mid) * pitch)
  }
  out
}

///|
/// bracket_spaced_grid returns `count` positions from `lo + edge` to
/// `hi - edge` in `count - 1` equal steps (or the midpoint when `count = 1`).
fn bracket_spaced_grid(
  count : Int32,
  lo : Double,
  hi : Double,
  edge : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  if count <= 1 {
    out.push((lo + hi) / 2.0)
    return out
  }
  let step = (hi - lo - 2.0 * edge) / (count - 1).to_double()
  for i in 0..<count {
    out.push(lo + edge + i.to_double() * step)
  }
  out
}

///|
/// l_bracket builds an L-shaped mounting bracket with real bolt holes and an
/// optional triangular gusset.
///
/// Frame: the base leg lies on `z = 0 .. thickness` and runs along +X from the
/// outer corner at `(0, 0, 0)`; the upright leg rises along +Z for `leg_b`. Both
/// legs are `width` wide, centred on `y = 0`. Base holes pass through Z;
/// upright holes pass through X, so both are real through holes.
///
/// Hole layout. With the defaults (`holes_per_leg = 2`, `holes_across = 1`, no
/// `pitch_mm`) the builder places one or two holes on each leg's centre line at
/// `edge_distance_mm` from the ends, matching the earlier envelope. Supplying
/// `pitch_mm` (or `holes_across > 1`, or more than two holes along a leg)
/// switches to a centred rectangular grid: `holes_per_leg` rows along the leg
/// and `holes_across` columns across the width. The Maker Store
/// `PLATE-40X40L` is exactly `leg_a = leg_b = width = 40`, `thickness = 3`,
/// `hole_diameter = 5`, `holes_per_leg = 3`, `holes_across = 3`, `pitch_mm = 10`
/// (a 3 x 3 grid at 10 mm centres with 10 mm margins).
///
/// The two legs overlap nominally at the corner. This is a generic fabricated
/// bracket envelope: no standard profile, weld, or strength rating is implied.
pub fn l_bracket(
  leg_a_mm : Double,
  leg_b_mm : Double,
  width_mm : Double,
  thickness_mm : Double,
  hole_diameter_mm : Double,
  holes_per_leg~ : Int32 = 2,
  holes_per_leg_b? : Int32,
  holes_across~ : Int32 = 1,
  pitch_mm? : Double,
  edge_distance_mm? : Double,
  gusset_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("bracket leg A", leg_a_mm),
      ("bracket leg B", leg_b_mm),
      ("bracket width", width_mm),
      ("bracket thickness", thickness_mm),
      ("bracket hole diameter", hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match mechanism_non_negative_checks([("bracket gusset", gusset_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if holes_per_leg < 1 || holes_across < 1 {
    return Err(
      @common.InvalidParameter(
        "bracket needs at least one hole per leg and one across the width",
      ),
    )
  }
  let has_pitch = match pitch_mm {
    Some(_) => true
    None => false
  }
  let rows_b = match holes_per_leg_b {
    Some(n) => n
    None => holes_per_leg
  }
  if holes_per_leg < 1 || rows_b < 1 || holes_across < 1 {
    return Err(
      @common.InvalidParameter(
        "bracket needs at least one hole per leg and one across the width",
      ),
    )
  }
  let edge = match edge_distance_mm {
    Some(e) => e
    None => thickness_mm * 2.0
  }
  if !has_pitch && edge <= hole_diameter_mm / 2.0 {
    return Err(
      @common.InvalidDimension("bracket hole edge distance is too small"),
    )
  }
  if !has_pitch &&
    holes_per_leg == 2 &&
    (
      edge + hole_diameter_mm / 2.0 >= leg_a_mm / 2.0 ||
      edge + hole_diameter_mm / 2.0 >= leg_b_mm / 2.0
    ) {
    return Err(
      @common.InvalidDimension(
        "bracket holes do not fit both legs; lengthen the legs or reduce the edge distance",
      ),
    )
  }
  if hole_diameter_mm >= width_mm {
    return Err(
      @common.InvalidDimension("bracket hole is wider than the bracket"),
    )
  }
  if gusset_mm > 0.0 {
    if thickness_mm + gusset_mm > leg_a_mm ||
      thickness_mm + gusset_mm > leg_b_mm {
      return Err(
        @common.InvalidDimension("bracket gusset does not fit the inner corner"),
      )
    }
  }
  let half_width = width_mm / 2.0
  let hole_radius = hole_diameter_mm / 2.0
  let grid_mode = has_pitch ||
    holes_across > 1 ||
    holes_per_leg > 2 ||
    rows_b > 2
  let across_ys : Array[Double] = if grid_mode {
    match pitch_mm {
      Some(p) => bracket_centered_grid(holes_across, 0.0, p)
      None => bracket_spaced_grid(holes_across, -half_width, half_width, edge)
    }
  } else {
    [0.0]
  }
  let base_positions : Array[Double] = if grid_mode {
    match pitch_mm {
      Some(p) => bracket_centered_grid(holes_per_leg, leg_a_mm / 2.0, p)
      None => bracket_spaced_grid(holes_per_leg, 0.0, leg_a_mm, edge)
    }
  } else if holes_per_leg == 1 {
    [leg_a_mm / 2.0]
  } else {
    [edge, leg_a_mm - edge]
  }
  let upright_positions : Array[Double] = if grid_mode {
    match pitch_mm {
      Some(p) => bracket_centered_grid(rows_b, leg_b_mm / 2.0, p)
      None => bracket_spaced_grid(rows_b, 0.0, leg_b_mm, edge)
    }
  } else if rows_b == 1 {
    [leg_b_mm / 2.0]
  } else {
    [edge, leg_b_mm - edge]
  }
  if grid_mode {
    for x in base_positions {
      if x - hole_radius < 0.0 || x + hole_radius > leg_a_mm {
        return Err(
          @common.InvalidDimension(
            "bracket base hole grid does not fit the base leg",
          ),
        )
      }
    }
    for z in upright_positions {
      if z - hole_radius < 0.0 || z + hole_radius > leg_b_mm {
        return Err(
          @common.InvalidDimension(
            "bracket upright hole grid does not fit the upright leg",
          ),
        )
      }
    }
    for y in across_ys {
      if y - hole_radius < -half_width || y + hole_radius > half_width {
        return Err(
          @common.InvalidDimension(
            "bracket hole grid does not fit the leg width",
          ),
        )
      }
    }
  }
  let base_holes : Array[Array[@cad.ProfileSegment]] = []
  for x in base_positions {
    for y in across_ys {
      base_holes.push(circle_loop(x, y, hole_radius))
    }
  }
  let base = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, -half_width, leg_a_mm, half_width),
    thickness_mm,
    holes=base_holes,
  ).as_shape()
  let upright_holes : Array[Array[@cad.ProfileSegment]] = []
  for z in upright_positions {
    for y in across_ys {
      upright_holes.push(circle_loop(z, y, hole_radius))
    }
  }
  let upright = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, -half_width, leg_b_mm, half_width),
    thickness_mm,
    holes=upright_holes,
  ).as_shape()
  let has_gusset = gusset_mm > 0.0
  let modeled : Array[String] = [
    "base-leg", "upright-leg", "through-bolt-holes",
  ]
  if has_gusset {
    modeled.push("corner-gusset")
  }
  let features = @common.FeatureRecord::new(modeled~, approximated=[], omitted=[
    @common.Omission::new(
      feature="leg-overlap-union",
      reason="the legs overlap at the corner and are separate layers",
    ),
    @common.Omission::new(
      feature="weld-and-strength-rating",
      reason="no weld, fastener, or structural rating is implied",
    ),
  ])
  let name = "l-bracket-\{@cad.fmt_double(leg_a_mm, None)}x\{@cad.fmt_double(leg_b_mm, None)}"
  let mut component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="L bracket \{@cad.fmt_double(leg_a_mm, None)} x \{@cad.fmt_double(leg_b_mm, None)} x \{@cad.fmt_double(width_mm, None)}",
        family="L bracket (engineering envelope)",
        size="\{@cad.fmt_double(leg_a_mm, None)}x\{@cad.fmt_double(leg_b_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
        source="Parametric L-bracket envelope with real through holes and an optional gusset. No standard or strength rating is implied.",
      ),
      description="L-shaped bracket with real bolt holes through both legs and an optional triangular corner gusset. No weld or strength rating is implied.",
      features~,
    )
    .add_layer(base, name="base-leg", color~)
    .add_layer(
      upright,
      name="upright-leg",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(thickness_mm, 0.0, 0.0),
        @common.Placement::rotation_y(-90.0),
      ),
    )
  if has_gusset {
    let triangle : Array[@cad.ProfileSegment] = [
      @cad.SegmentLine((0.0, 0.0), (gusset_mm, 0.0)),
      @cad.SegmentLine((gusset_mm, 0.0), (0.0, gusset_mm)),
      @cad.SegmentLine((0.0, gusset_mm), (0.0, 0.0)),
    ]
    let gusset = @cad.ExtrudedArcProfile::new(triangle, width_mm).as_shape()
    component = component.add_layer(
      gusset,
      name="gusset",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(thickness_mm, half_width, thickness_mm),
        @common.Placement::rotation_x(90.0),
      ),
    )
  }
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(leg_a_mm / 2.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="base mounting face, outward normal -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "upright-face",
        placement=@common.Placement::translation(0.0, 0.0, leg_b_mm / 2.0),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="upright outer face, outward normal -X",
      ),
    )
  let mut base_hole_index = 0
  for x in base_positions {
    for y in across_ys {
      base_hole_index += 1
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "base-hole-\{base_hole_index}",
          placement=@common.Placement::translation(x, y, 0.0),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=hole_diameter_mm,
          depth_mm=thickness_mm,
          description="through bolt hole in the base leg",
        ),
      )
    }
  }
  let mut upright_hole_index = 0
  for z in upright_positions {
    for y in across_ys {
      upright_hole_index += 1
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "upright-hole-\{upright_hole_index}",
          placement=@common.Placement::translation(0.0, y, z),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=hole_diameter_mm,
          depth_mm=thickness_mm,
          description="through bolt hole in the upright leg",
        ),
      )
    }
  }
  if has_gusset {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "gusset-datum",
        placement=@common.Placement::translation(
          thickness_mm + gusset_mm / 2.0,
          0.0,
          thickness_mm + gusset_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=gusset_mm,
        description="corner gusset datum",
      ),
    )
  }
  Ok(out)
}

///|
/// u_bracket builds a U-channel bracket with a base plate and two side walls.
///
/// Frame: the base lies on `z = 0 .. thickness` and runs along +X from
/// `x = 0` to `base_length`; it is `width` wide, centred on `y = 0`. Two side
/// walls rise from `z = thickness` to `z = thickness + leg_height` at
/// `y = -width/2 .. -width/2 + thickness` and
/// `y = width/2 - thickness .. width/2`. Base holes pass through Z; wall holes
/// pass through Y, so all holes are real.
///
/// The base and walls abut nominally at the base top. This is a generic
/// fabricated bracket envelope: no weld or strength rating is implied.
pub fn u_bracket(
  base_length_mm : Double,
  leg_height_mm : Double,
  width_mm : Double,
  thickness_mm : Double,
  hole_diameter_mm : Double,
  holes_per_leg~ : Int32 = 2,
  edge_distance_mm? : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("U bracket base length", base_length_mm),
      ("U bracket leg height", leg_height_mm),
      ("U bracket width", width_mm),
      ("U bracket thickness", thickness_mm),
      ("U bracket hole diameter", hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if holes_per_leg < 1 || holes_per_leg > 2 {
    return Err(
      @common.InvalidParameter("U bracket supports one or two holes per leg"),
    )
  }
  if thickness_mm >= width_mm / 2.0 {
    return Err(
      @common.InvalidDimension("U bracket walls do not fit across the width"),
    )
  }
  if hole_diameter_mm >= leg_height_mm ||
    hole_diameter_mm >= width_mm - 2.0 * thickness_mm {
    return Err(
      @common.InvalidDimension("U bracket hole does not fit the wall or base"),
    )
  }
  let edge = match edge_distance_mm {
    Some(e) => e
    None => thickness_mm * 2.0
  }
  let hole_radius = hole_diameter_mm / 2.0
  if edge <= hole_radius {
    return Err(
      @common.InvalidDimension("U bracket hole edge distance is too small"),
    )
  }
  let positions : Array[Double] = if holes_per_leg == 1 {
    [base_length_mm / 2.0]
  } else {
    [edge, base_length_mm - edge]
  }
  for x in positions {
    if x - hole_radius <= 0.0 || x + hole_radius >= base_length_mm {
      return Err(
        @common.InvalidDimension(
          "U bracket holes do not fit the bracket length",
        ),
      )
    }
  }
  let half_width = width_mm / 2.0
  let base_holes = positions.map(fn(x) { circle_loop(x, 0.0, hole_radius) })
  let base = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, -half_width, base_length_mm, half_width),
    thickness_mm,
    holes=base_holes,
  ).as_shape()
  let wall_holes = positions.map(fn(x) {
    circle_loop(x, leg_height_mm / 2.0, hole_radius)
  })
  let wall = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, 0.0, base_length_mm, leg_height_mm),
    thickness_mm,
    holes=wall_holes,
  ).as_shape()
  let wall_z = thickness_mm + leg_height_mm
  let left_y = -half_width
  let right_y = half_width - thickness_mm
  let features = @common.FeatureRecord::new(
    modeled=["base-leg", "side-walls", "through-bolt-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="wall-to-base-union",
        reason="the walls abut the base nominally and are separate layers",
      ),
      @common.Omission::new(
        feature="weld-and-strength-rating",
        reason="no weld, fastener, or structural rating is implied",
      ),
    ],
  )
  let name = "u-bracket-\{@cad.fmt_double(base_length_mm, None)}x\{@cad.fmt_double(width_mm, None)}"
  let mut out = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="U bracket \{@cad.fmt_double(base_length_mm, None)} x \{@cad.fmt_double(width_mm, None)} x h\{@cad.fmt_double(leg_height_mm, None)}",
        family="U bracket (engineering envelope)",
        size="\{@cad.fmt_double(base_length_mm, None)}x\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(leg_height_mm, None)}",
        source="Parametric U-channel bracket envelope with real through holes. No standard or strength rating is implied.",
      ),
      description="U-channel bracket with a base plate and two side walls. Base holes pass through Z and wall holes through Y; the walls abut the base nominally.",
      features~,
    )
    .add_layer(base, name="base-leg", color~)
    .add_layer(
      wall,
      name="wall-left",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, left_y, wall_z),
        @common.Placement::rotation_x(-90.0),
      ),
    )
    .add_layer(
      wall,
      name="wall-right",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, right_y, wall_z),
        @common.Placement::rotation_x(-90.0),
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(base_length_mm / 2.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="base mounting face, outward normal -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "wall-face-a",
        placement=@common.Placement::translation(
          base_length_mm / 2.0,
          half_width,
          thickness_mm + leg_height_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=leg_height_mm,
        description="positive-Y wall outer face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "wall-face-b",
        placement=@common.Placement::translation(
          base_length_mm / 2.0,
          -half_width,
          thickness_mm + leg_height_mm / 2.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=leg_height_mm,
        description="negative-Y wall outer face",
      ),
    )
  for i, x in positions {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "base-hole-\{i + 1}",
        placement=@common.Placement::translation(x, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=hole_diameter_mm,
        depth_mm=thickness_mm,
        description="through bolt hole in the base",
      ),
    )
  }
  for i, x in positions {
    let z = thickness_mm + leg_height_mm / 2.0
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "wall-hole-a-\{i + 1}",
        placement=@common.Placement::translation(x, half_width, z),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=hole_diameter_mm,
        depth_mm=thickness_mm,
        description="through bolt hole in the positive-Y wall",
      ),
    )
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "wall-hole-b-\{i + 1}",
        placement=@common.Placement::translation(x, -half_width, z),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=hole_diameter_mm,
        depth_mm=thickness_mm,
        description="through bolt hole in the negative-Y wall",
      ),
    )
  }
  Ok(out)
}

///|
/// z_bracket builds a Z-shaped offset bracket with two flanges and a web.
///
/// Frame: the lower flange lies on `z = 0 .. thickness` and runs along +X from
/// `x = 0` to `lower_length`; the web occupies
/// `x = lower_length .. lower_length + thickness` and rises to `z = height`;
/// the upper flange runs from `x = lower_length` to
/// `x = lower_length + upper_length` at `z = height .. height + thickness`. All
/// parts are `width` wide, centred on `y = 0`. Flange holes pass through Z, so
/// they are real.
///
/// The flanges and web abut nominally. This is a generic fabricated bracket
/// envelope: no weld or strength rating is implied.
pub fn z_bracket(
  lower_length_mm : Double,
  upper_length_mm : Double,
  height_mm : Double,
  width_mm : Double,
  thickness_mm : Double,
  hole_diameter_mm : Double,
  holes_per_flange~ : Int32 = 2,
  edge_distance_mm? : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("Z bracket lower length", lower_length_mm),
      ("Z bracket upper length", upper_length_mm),
      ("Z bracket height", height_mm),
      ("Z bracket width", width_mm),
      ("Z bracket thickness", thickness_mm),
      ("Z bracket hole diameter", hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if holes_per_flange < 1 || holes_per_flange > 2 {
    return Err(
      @common.InvalidParameter("Z bracket supports one or two holes per flange"),
    )
  }
  if hole_diameter_mm >= width_mm {
    return Err(
      @common.InvalidDimension("Z bracket hole is wider than the bracket"),
    )
  }
  let edge = match edge_distance_mm {
    Some(e) => e
    None => thickness_mm * 2.0
  }
  let hole_radius = hole_diameter_mm / 2.0
  if edge <= hole_radius {
    return Err(
      @common.InvalidDimension("Z bracket hole edge distance is too small"),
    )
  }
  let lower_positions : Array[Double] = if holes_per_flange == 1 {
    [lower_length_mm / 2.0]
  } else {
    [edge, lower_length_mm - edge]
  }
  let upper_positions : Array[Double] = if holes_per_flange == 1 {
    [lower_length_mm + upper_length_mm / 2.0]
  } else {
    [lower_length_mm + edge, lower_length_mm + upper_length_mm - edge]
  }
  for x in lower_positions {
    if x - hole_radius <= 0.0 || x + hole_radius >= lower_length_mm {
      return Err(
        @common.InvalidDimension("Z bracket lower holes do not fit the flange"),
      )
    }
  }
  for x in upper_positions {
    if x - hole_radius <= lower_length_mm ||
      x + hole_radius >= lower_length_mm + upper_length_mm {
      return Err(
        @common.InvalidDimension("Z bracket upper holes do not fit the flange"),
      )
    }
  }
  let half_width = width_mm / 2.0
  let lower_holes = lower_positions.map(fn(x) {
    circle_loop(x, 0.0, hole_radius)
  })
  let upper_holes = upper_positions.map(fn(x) {
    circle_loop(x, 0.0, hole_radius)
  })
  let lower = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, -half_width, lower_length_mm, half_width),
    thickness_mm,
    holes=lower_holes,
  ).as_shape()
  let upper = @cad.ExtrudedArcProfile::new(
    rect_loop(
      lower_length_mm,
      -half_width,
      lower_length_mm + upper_length_mm,
      half_width,
    ),
    thickness_mm,
    holes=upper_holes,
  ).as_shape()
  let web = @cad.ExtrudedArcProfile::new(
    rect_loop(0.0, -half_width, height_mm, half_width),
    thickness_mm,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["lower-flange", "upper-flange", "web", "through-bolt-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="flange-to-web-union",
        reason="the flanges and web abut nominally and are separate layers",
      ),
      @common.Omission::new(
        feature="weld-and-strength-rating",
        reason="no weld, fastener, or structural rating is implied",
      ),
    ],
  )
  let name = "z-bracket-\{@cad.fmt_double(lower_length_mm, None)}x\{@cad.fmt_double(upper_length_mm, None)}x\{@cad.fmt_double(height_mm, None)}"
  let mut out = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Z bracket \{@cad.fmt_double(lower_length_mm, None)} / \{@cad.fmt_double(upper_length_mm, None)} x h\{@cad.fmt_double(height_mm, None)}",
        family="Z bracket (engineering envelope)",
        size="\{@cad.fmt_double(lower_length_mm, None)}x\{@cad.fmt_double(upper_length_mm, None)}x\{@cad.fmt_double(height_mm, None)}",
        source="Parametric Z-bracket envelope with real flange holes. No standard or strength rating is implied.",
      ),
      description="Z-shaped offset bracket with two flanges and a connecting web. Flange holes are real through holes; the layers abut nominally.",
      features~,
    )
    .add_layer(lower, name="lower-flange", color~)
    .add_layer(
      upper,
      name="upper-flange",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, height_mm),
    )
    .add_layer(
      web,
      name="web",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(lower_length_mm + thickness_mm, 0.0, 0.0),
        @common.Placement::rotation_y(-90.0),
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bottom-face",
        placement=@common.Placement::translation(
          lower_length_mm / 2.0,
          0.0,
          0.0,
        ),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="lower flange mounting face, outward normal -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "top-face",
        placement=@common.Placement::translation(
          lower_length_mm + upper_length_mm / 2.0,
          0.0,
          height_mm + thickness_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="upper flange face, outward normal +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "web-face-a",
        placement=@common.Placement::translation(
          lower_length_mm + thickness_mm / 2.0,
          half_width,
          height_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=height_mm,
        description="positive-Y web face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "web-face-b",
        placement=@common.Placement::translation(
          lower_length_mm + thickness_mm / 2.0,
          -half_width,
          height_mm / 2.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=height_mm,
        description="negative-Y web face",
      ),
    )
  for i, x in lower_positions {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "lower-hole-\{i + 1}",
        placement=@common.Placement::translation(x, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=hole_diameter_mm,
        depth_mm=thickness_mm,
        description="through bolt hole in the lower flange",
      ),
    )
  }
  for i, x in upper_positions {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "upper-hole-\{i + 1}",
        placement=@common.Placement::translation(x, 0.0, height_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=hole_diameter_mm,
        depth_mm=thickness_mm,
        description="through bolt hole in the upper flange",
      ),
    )
  }
  Ok(out)
}
