///|
/// BearingSize carries the boundary dimensions of a standard radial ball
/// bearing: bore `d`, outside diameter `D`, and width `B`.
///
/// The table covers common ISO 15 / catalogue sizes. It is boundary data only;
/// internal ring and ball geometry is parametric and simplified.
pub(all) struct BearingSize {
  designation : String
  bore_mm : Double
  outer_mm : Double
  width_mm : Double
}

///|
/// bearing_size looks up a bearing by its catalogue designation.
pub fn bearing_size(
  designation : String,
) -> Result[BearingSize, @common.SpecError] {
  let (d, outer, width) = match designation {
    "608" => (8.0, 22.0, 7.0)
    "623" => (3.0, 10.0, 4.0)
    "624" => (4.0, 13.0, 5.0)
    "625" => (5.0, 16.0, 5.0)
    "626" => (6.0, 19.0, 6.0)
    "628" => (8.0, 24.0, 8.0)
    "688" => (8.0, 16.0, 5.0)
    "6000" => (10.0, 26.0, 8.0)
    "6001" => (12.0, 28.0, 8.0)
    "6002" => (15.0, 32.0, 9.0)
    "6003" => (17.0, 35.0, 10.0)
    "6004" => (20.0, 42.0, 12.0)
    "6005" => (25.0, 47.0, 12.0)
    "6006" => (30.0, 55.0, 13.0)
    "6200" => (10.0, 30.0, 9.0)
    "6201" => (12.0, 32.0, 10.0)
    "6202" => (15.0, 35.0, 11.0)
    "6203" => (17.0, 40.0, 12.0)
    "6204" => (20.0, 47.0, 14.0)
    "6205" => (25.0, 52.0, 15.0)
    "6206" => (30.0, 62.0, 16.0)
    "6300" => (10.0, 35.0, 11.0)
    "6301" => (12.0, 37.0, 12.0)
    "6302" => (15.0, 42.0, 13.0)
    "6303" => (17.0, 47.0, 14.0)
    "6304" => (20.0, 52.0, 15.0)
    "6305" => (25.0, 62.0, 17.0)
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported bearing designation: \{other}; supported: 608, 623-626, 628, 688, 6000-6006, 6200-6206, 6300-6305",
        ),
      )
  }
  Ok({ designation, bore_mm: d, outer_mm: outer, width_mm: width, })
}

///|
/// bearing_designations returns every supported bearing designation.
pub fn bearing_designations() -> Array[String] {
  [
    "608", "623", "624", "625", "626", "628", "688", "6000", "6001", "6002", "6003",
    "6004", "6005", "6006", "6200", "6201", "6202", "6203", "6204", "6205", "6206",
    "6300", "6301", "6302", "6303", "6304", "6305",
  ]
}

///|
/// bearing builds a simplified radial bearing envelope.
///
/// Geometry: an outer ring, an inner ring, and a set of **spherical balls**
/// between them (an analytic `SPHERICAL_SURFACE` per ball). At `Detailed` and
/// above the rings also carry a small engineering-default edge chamfer and the
/// balls are placed at the radial mid-plane. The envelope is not exact
/// catalogue geometry: ring proportions and ball diameter come from the
/// boundary dimensions, and seals/cages are omitted.
///
/// Axis +Z, base at z = 0.
pub fn bearing(
  size : BearingSize,
  ring_thickness_mm? : Double,
  roller_count~ : Int32 = 8,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let d = size.bore_mm
  let outer = size.outer_mm
  let width = size.width_mm
  let space = (outer - d) / 2.0
  // A rings-only envelope (roller_count = 0) uses the golden references' ring
  // proportions: the outer ring reaches the pitch radius and a narrow
  // engineering gap separates it from the slightly thinner inner ring. With
  // rolling elements, keep the symmetric rings and the wider ball gap.
  let ring_outer = match ring_thickness_mm {
    Some(v) => v
    None => if roller_count == 0 { space / 2.0 } else { (outer - d) / 5.0 }
  }
  let ring_inner = match ring_thickness_mm {
    Some(v) => v
    None =>
      if roller_count == 0 {
        space / 2.0 - 0.05 * space
      } else {
        (outer - d) / 5.0
      }
  }
  match @common.require_positive("bearing ring thickness", ring_outer) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("bearing inner ring thickness", ring_inner) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let radial_gap = space - ring_outer - ring_inner
  if radial_gap <= 0.0 {
    return Err(
      @common.InvalidDimension("bearing ring thickness leaves no radial gap"),
    )
  }
  // A zero roller count is a rings-only envelope: it matches the simplified
  // golden references, which contain the two rings and no rolling elements.
  if roller_count < 0 {
    return Err(
      @common.InvalidParameter("bearing roller count must be non-negative"),
    )
  }
  let mid_radius = (outer + d) / 4.0
  // Adjacent ball centres are a chord of the pitch circle. Too many rollers
  // makes the balls overlap even though the count itself is positive.
  if roller_count > 0 {
    let ball_span = 2.0 *
      mid_radius *
      @math.sin(@math.PI / roller_count.to_double())
    if ball_span < radial_gap {
      return Err(
        @common.InvalidParameter(
          "bearing roller count is too large: adjacent balls overlap (spacing \{ball_span} mm < ball diameter \{radial_gap} mm)",
        ),
      )
    }
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let segments = if policy.circle_segments < 32 {
    32
  } else {
    policy.circle_segments
  }
  let base_color = match color {
    Some(c) => c
    None => @cad.Rgb::purple()
  }
  let use_features = policy.include_small_features
  let name = "bearing-\{size.designation}"
  let features = bearing_feature_record(
    policy, outer, d, segments, roller_count,
  )
  let description = if roller_count > 0 {
    "Outer and inner rings plus spherical balls (analytic sphere surfaces). Rings are plain tubes at Simplified detail and carry an engineering-default edge chamfer at Detailed and above. Seals and cages are omitted."
  } else {
    "Outer and inner rings only (a rings-only envelope with no rolling elements, matching the simplified golden references). Rings are plain tubes at Simplified detail and carry an engineering-default edge chamfer at Detailed and above. Seals, cages, and rolling elements are omitted."
  }
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Bearing \{size.designation}",
      standard="ISO 15 boundary dimensions; simplified internal geometry",
      family="radial ball bearing (simplified envelope)",
      size=size.designation,
      source="Boundary dimensions from common ISO 15 / catalogue tables; internal rings, balls, and chamfers are parametric, not catalogue geometry. See components/DATA_SOURCES.md.",
    ),
    description~,
    features~,
  )
  let outer_hole = outer - 2.0 * ring_outer
  let inner_outer = d + 2.0 * ring_inner
  if use_features {
    let c = bearing_chamfer(width, ring_inner)
    if c >= ring_inner || c >= width / 2.0 {
      return Err(
        @common.InvalidDimension(
          "bearing ring thickness or width is too small for the default edge chamfer; use Simplified detail or thicker rings",
        ),
      )
    }
    component = component.add_layer(
      @cad.RevolvedProfile::chamfered_tube(
        outer,
        outer_hole,
        width,
        outer_bottom_chamfer=c,
        outer_top_chamfer=c,
      ).as_shape(),
      name="outer-ring",
      color=base_color,
    )
    component = component.add_layer(
      @cad.RevolvedProfile::chamfered_tube(
        inner_outer,
        d,
        width,
        outer_bottom_chamfer=c,
        outer_top_chamfer=c,
      ).as_shape(),
      name="inner-ring",
      color=@cad.Rgb::blue(),
    )
  } else {
    component = component.add_layer(
      @cad.RevolvedProfile::tube(outer, outer_hole, width).as_shape(),
      name="outer-ring",
      color=base_color,
    )
    component = component.add_layer(
      @cad.RevolvedProfile::tube(inner_outer, d, width).as_shape(),
      name="inner-ring",
      color=@cad.Rgb::blue(),
    )
  }
  let ball = @cad.RevolvedProfile::sphere(radial_gap)
  for i in 0..<roller_count {
    let angle = 360.0 * Double::from_int(i) / Double::from_int(roller_count)
    let base = @common.Placement::translation(mid_radius, 0.0, width / 2.0)
    let placement = @common.Placement::compose(
      @common.Placement::rotation_z(angle),
      base,
    )
    component = component.add_layer(
      ball.as_shape(),
      name="ball-\{i + 1}",
      color=@cad.Rgb::orange(),
      placement~,
    )
  }
  Ok(component)
}

///|
/// shielded_bearing builds a single-solid shielded bearing envelope.
///
/// The cross-section is a thin-walled annulus with a recessed 45-degree groove
/// on each face. The groove is the shield seat: the model has no rolling
/// elements, no cage, and no separate shield plate; the groove floor is the
/// shield face. The solid is centred on z = 0, matching the common catalogue
/// reference frame.
///
/// The defaults reproduce the downloaded 608-ZZ envelope: shield depth
/// `width / 28`, outer-ring thickness `2/7 * (outer - bore) / 2`, and
/// inner-ring thickness `11/28 * (outer - bore) / 2`. The optional arguments
/// override them. The result is one `RevolvedProfile` solid with two
/// cylinders, six 45-degree cones, and six planes.
pub fn shielded_bearing(
  size : BearingSize,
  shield_depth_mm? : Double,
  outer_ring_thickness_mm? : Double,
  inner_ring_thickness_mm? : Double,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let d = size.bore_mm
  let outer = size.outer_mm
  let width = size.width_mm
  let rb = d / 2.0
  let ro = outer / 2.0
  let space = (outer - d) / 2.0
  let g = match shield_depth_mm {
    Some(v) => v
    None => width / 28.0
  }
  let outer_t = match outer_ring_thickness_mm {
    Some(v) => v
    None => 2.0 / 7.0 * space
  }
  let inner_t = match inner_ring_thickness_mm {
    Some(v) => v
    None => 11.0 / 28.0 * space
  }
  match @common.require_positive("shield depth", g) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("outer ring thickness", outer_t) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("inner ring thickness", inner_t) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let zf = width / 2.0
  let zfl = zf - g
  let r_inner_floor = rb + inner_t
  let r_outer_floor = ro - outer_t
  let r_inner_face = r_inner_floor - g
  let r_outer_face = r_outer_floor + g
  if zfl <= 0.0 ||
    r_inner_face <= rb ||
    r_outer_face >= ro - g ||
    r_inner_face >= r_outer_floor {
    return Err(
      @common.InvalidDimension(
        "shielded bearing dimensions do not fit the boundary envelope",
      ),
    )
  }
  let points : Array[@cad.Vec2] = [
    (rb, -zf),
    (r_inner_face, -zf),
    (r_inner_floor, -zfl),
    (r_outer_floor, -zfl),
    (r_outer_face, -zf),
    (ro - g, -zf),
    (ro, -zfl),
    (ro, zfl),
    (ro - g, zf),
    (r_outer_face, zf),
    (r_outer_floor, zfl),
    (r_inner_floor, zfl),
    (r_inner_face, zf),
    (rb, zf),
  ]
  // The reference colors only the flat shield faces black; the 45-degree
  // groove walls and the rings stay light metal. Bands 2 and 10 are the bottom
  // and top groove floors in the profile point order above.
  let mut profile = @cad.RevolvedProfile::polyline(points, closed=true)
  for band in [2, 10] {
    profile = profile.with_band_color(band, @cad.Rgb::black())
  }
  let body = profile.as_shape()
  let name = "bearing-\{size.designation}-shielded"
  let metal = match color {
    Some(c) => c
    // The reference's outer ring is light grey; a light body lets the recessed
    // shield groove read as a darker ring under shading.
    None => @cad.Rgb::new(0.75, 0.75, 0.75)
  }
  let features = shielded_bearing_feature_record()
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Shielded bearing \{size.designation}",
        standard="ISO 15 boundary dimensions; simplified shielded envelope",
        family="shielded radial ball bearing (simplified envelope)",
        size=size.designation,
        source="Boundary dimensions from common ISO 15 / catalogue tables; the shield groove and ring proportions are parametric envelope geometry, not catalogue internals. See components/DATA_SOURCES.md.",
      ),
      description="Single-solid shielded bearing envelope: outer and inner rings joined by a recessed 45-degree shield groove on each face. The flat shield faces are styled black to match the reference; the 45-degree groove walls and the rings stay light metal. No rolling elements, cage, or separate shield plate; the groove floor is the shield seat. Centered on z = 0.",
      features~,
    ).add_layer(body, name="body", color=metal),
  )
}

///|
/// shielded_bearing_feature_record builds the feature record for the
/// single-solid shielded envelope.
fn shielded_bearing_feature_record() -> @common.FeatureRecord {
  @common.FeatureRecord::new(
    modeled=[
      "outer-ring", "inner-ring", "shield-groove", "shield-face-black", "single-solid-envelope",
    ],
    omitted=[
      @common.Omission::new(
        feature="rolling-elements",
        reason="the shielded reference contains no balls; the shields close the bearing",
      ),
      @common.Omission::new(
        feature="cage",
        reason="rolling-element cages are not modelled",
      ),
      @common.Omission::new(
        feature="separate-shield-plate",
        reason="the shield is represented by the recessed face groove, not a separate plate",
      ),
    ],
  )
}

///|
/// bearing_chamfer returns the engineering-default ring edge chamfer. Bearing
/// catalogue drawings specify their own chamfers; this keeps the value small
/// relative to the ring and width.
fn bearing_chamfer(width : Double, ring_t : Double) -> Double {
  let by_width = 0.15 * width
  let by_ring = 0.4 * ring_t
  let c = if by_width < by_ring { by_width } else { by_ring }
  if c < 0.2 {
    0.2
  } else {
    c
  }
}

///|
/// bearing_by_designation looks up a bearing by name and builds it.
pub fn bearing_by_designation(
  designation : String,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  match bearing_size(designation) {
    Err(e) => Err(e)
    Ok(size) => bearing(size, detail~)
  }
}

///|
/// bearing_feature_record builds the machine-readable feature record for a
/// simplified bearing envelope.
fn bearing_feature_record(
  policy : @common.DetailPolicy,
  outer : Double,
  bore : Double,
  segments : Int32,
  roller_count : Int32,
) -> @common.FeatureRecord {
  let _ = outer
  let _ = bore
  let _ = segments
  let modeled : Array[String] = ["outer-ring", "inner-ring"]
  if roller_count > 0 {
    modeled.push("ball-sphere")
  }
  let omitted : Array[@common.Omission] = [
    @common.Omission::new(
      feature="seal",
      reason="seals are not modelled in this envelope",
    ),
    @common.Omission::new(
      feature="cage",
      reason="rolling-element cages are not modelled",
    ),
    @common.Omission::new(
      feature="race-groove",
      reason="rolling-element race grooves are not modelled",
    ),
    @common.Omission::new(
      feature="bore-chamfer",
      reason="the bore and outer edges are not chamfered at Simplified detail",
    ),
  ]
  if roller_count == 0 {
    omitted.push(
      @common.Omission::new(
        feature="rolling-elements",
        reason="rings-only envelope: the simplified golden reference contains no balls",
      ),
    )
  }
  let base = @common.FeatureRecord::new(modeled~, approximated=[], omitted~)
  if policy.include_small_features {
    base.add_modeled("ring-edge-chamfer")
  } else {
    base.add_omitted(
      @common.Omission::new(
        feature="ring-edge-chamfer",
        reason="omitted at Simplified detail level",
      ),
    )
  }
}
