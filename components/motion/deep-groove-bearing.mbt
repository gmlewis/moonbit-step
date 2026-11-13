///|
/// deep_groove_bearing builds a physically plausible full-complement deep-
/// groove ball bearing: grooved outer and inner rings with retaining
/// shoulders, and a full ring of spherical balls nested in the raceways.
///
/// Axis +Z, base at z = 0. The boundary dimensions are ISO 15. The internal
/// proportions are engineering defaults, not catalogue internals: the ball
/// diameter is `0.285 x (outer - bore)`, the raceway groove radius is
/// `1.04 x` the ball radius, the shoulders overlap the ball envelope by
/// `0.35 x` the ball radius (so the balls cannot fall out axially), and the
/// default ball count is the largest full complement that leaves a small web
/// between adjacent balls. Rim and retaining-shoulder chamfers are added at
/// `Detailed` and above. The balls are single spherical faces with a seam, not
/// A cage, seals, and shields are omitted; no load or life rating is claimed.

///|
/// BALL_DIAMETER_FRACTION sets the deep-groove ball diameter as a fraction of
/// the radial boundary space (outer diameter minus bore). 0.285 reproduces the
/// common 608 / 6000 / 6204 deep-groove proportions.
const BALL_DIAMETER_FRACTION : Double = 0.285

///|
/// GROOVE_CONFORMITY is the raceway groove radius divided by the ball radius.
const GROOVE_CONFORMITY : Double = 1.04

///|
/// SHOULDER_OVERLAP_FRACTION is the radial overlap of each ring shoulder over
/// the ball envelope, as a fraction of the ball radius. It is what retains the
/// balls axially.
const SHOULDER_OVERLAP_FRACTION : Double = 0.35

///|
/// BALL_MIN_GAP_FRACTION is the minimum web between adjacent balls at the pitch
/// circle, as a fraction of the ball radius, for the default full complement.
const BALL_MIN_GAP_FRACTION : Double = 0.15

///|
/// DEEP_GROOVE_MAX_BALLS bounds the automatic full-complement search.
const DEEP_GROOVE_MAX_BALLS : Int32 = 64

///|
/// BALL_POLE_CAP_FRACTION is the height of the tiny flat polar cap, as a
/// fraction of the ball radius. The cap removes the singular pole vertex that
/// tessellates as a pinhole; the ball placement turns the caps into the
/// raceway, so the visible surface is the smooth spherical band.
const BALL_POLE_CAP_FRACTION : Double = 0.015

///|
/// DeepGrooveBearingSpec carries the derived internal geometry used to build a
/// deep-groove full-complement bearing.
pub(all) struct DeepGrooveBearingSpec {
  size : BearingSize
  ball_diameter_mm : Double
  ball_count : Int32
  pitch_radius_mm : Double
  groove_radius_mm : Double
  inner_shoulder_radius_mm : Double
  outer_shoulder_radius_mm : Double
  inner_groove_bottom_mm : Double
  outer_groove_bottom_mm : Double
  shoulder_land_mm : Double
  min_ring_wall_mm : Double
}

///|
/// deep_groove_bearing_spec derives and validates the internal geometry of a
/// full-complement deep-groove bearing. `ball_count` 0 selects the largest
/// full complement that fits; a positive value is used as given and must not
/// make adjacent balls overlap.
pub fn deep_groove_bearing_spec(
  size : BearingSize,
  ball_count~ : Int32 = 0,
) -> Result[DeepGrooveBearingSpec, @common.SpecError] {
  let d = size.bore_mm
  let outer = size.outer_mm
  let width = size.width_mm
  let bore_radius = d / 2.0
  let outer_radius = outer / 2.0
  let half_space = (outer - d) / 2.0
  if half_space <= 0.0 {
    return Err(
      @common.InvalidDimension("bearing outer diameter must exceed its bore"),
    )
  }
  let ball_diameter = BALL_DIAMETER_FRACTION * (outer - d)
  let ball_radius = ball_diameter / 2.0
  let pitch = (outer + d) / 4.0
  let groove_radius = GROOVE_CONFORMITY * ball_radius
  let shoulder_overlap = SHOULDER_OVERLAP_FRACTION * ball_radius
  let inner_shoulder = pitch - shoulder_overlap
  let outer_shoulder = pitch + shoulder_overlap
  let inner_groove = pitch - groove_radius
  let outer_groove = pitch + groove_radius
  let min_ring_wall = half_space / 2.0 - groove_radius
  if ball_diameter >= width {
    return Err(
      @common.InvalidDimension(
        "derived ball diameter does not fit the bearing width; the boundary proportions are not a plausible deep-groove bearing",
      ),
    )
  }
  if inner_groove <= bore_radius || outer_groove >= outer_radius {
    return Err(
      @common.InvalidDimension(
        "derived raceway groove does not fit inside the ring walls",
      ),
    )
  }
  let land_squared = groove_radius * groove_radius -
    shoulder_overlap * shoulder_overlap
  if land_squared <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "derived shoulder overlap is larger than the groove radius",
      ),
    )
  }
  let shoulder_land = Double::sqrt(land_squared)
  if shoulder_land >= width / 2.0 {
    return Err(
      @common.InvalidDimension(
        "derived raceway groove reaches the ring faces, so there is no retaining shoulder",
      ),
    )
  }
  let required_chord = 2.0 * ball_radius * (1.0 + BALL_MIN_GAP_FRACTION)
  let count = if ball_count > 0 {
    ball_count
  } else {
    let mut candidate = 3
    while candidate < DEEP_GROOVE_MAX_BALLS {
      let next = candidate + 1
      let chord = 2.0 * pitch * @math.sin(@math.PI / Double::from_int(next))
      if chord < required_chord {
        break
      }
      candidate = next
    }
    candidate
  }
  if count < 3 {
    return Err(
      @common.InvalidParameter("deep-groove bearing needs at least three balls"),
    )
  }
  let chord = 2.0 * pitch * @math.sin(@math.PI / Double::from_int(count))
  if chord < ball_diameter {
    return Err(
      @common.InvalidParameter(
        "deep-groove bearing ball count is too large: adjacent balls overlap",
      ),
    )
  }
  Ok({
    size,
    ball_diameter_mm: ball_diameter,
    ball_count: count,
    pitch_radius_mm: pitch,
    groove_radius_mm: groove_radius,
    inner_shoulder_radius_mm: inner_shoulder,
    outer_shoulder_radius_mm: outer_shoulder,
    inner_groove_bottom_mm: inner_groove,
    outer_groove_bottom_mm: outer_groove,
    shoulder_land_mm: shoulder_land,
    min_ring_wall_mm: min_ring_wall,
  })
}

///|
/// deep_groove_outer_ring_profile builds the outer ring cross-section: a
/// grooved raceway on the inside, flat faces, and optional OD chamfers.
fn deep_groove_outer_ring_profile(
  spec : DeepGrooveBearingSpec,
  chamfer_mm : Double,
) -> @cad.RevolvedProfile {
  let width = spec.size.width_mm
  let outer_radius = spec.size.outer_mm / 2.0
  let shoulder = spec.outer_shoulder_radius_mm
  let mid_z = width / 2.0
  let low_z = mid_z - spec.shoulder_land_mm
  let high_z = mid_z + spec.shoulder_land_mm
  let segments : Array[@cad.RevSegment] = []
  let shoulder_top_z = if chamfer_mm > 0.0 { width - chamfer_mm } else { width }
  let shoulder_bottom_z = if chamfer_mm > 0.0 { chamfer_mm } else { 0.0 }
  if chamfer_mm > 0.0 {
    segments.push(
      @cad.RevLine(
        (shoulder + chamfer_mm, 0.0),
        (outer_radius - chamfer_mm, 0.0),
      ),
    )
    segments.push(
      @cad.RevLine((outer_radius - chamfer_mm, 0.0), (outer_radius, chamfer_mm)),
    )
    segments.push(
      @cad.RevLine(
        (outer_radius, chamfer_mm),
        (outer_radius, width - chamfer_mm),
      ),
    )
    segments.push(
      @cad.RevLine(
        (outer_radius, width - chamfer_mm),
        (outer_radius - chamfer_mm, width),
      ),
    )
    segments.push(
      @cad.RevLine(
        (outer_radius - chamfer_mm, width),
        (shoulder + chamfer_mm, width),
      ),
    )
    segments.push(
      @cad.RevLine(
        (shoulder + chamfer_mm, width),
        (shoulder, width - chamfer_mm),
      ),
    )
  } else {
    segments.push(@cad.RevLine((shoulder, 0.0), (outer_radius, 0.0)))
    segments.push(@cad.RevLine((outer_radius, 0.0), (outer_radius, width)))
    segments.push(@cad.RevLine((outer_radius, width), (shoulder, width)))
  }
  segments.push(@cad.RevLine((shoulder, shoulder_top_z), (shoulder, high_z)))
  segments.push(
    @cad.RevArc(
      (shoulder, high_z),
      (shoulder, low_z),
      (spec.pitch_radius_mm, mid_z),
    ),
  )
  segments.push(@cad.RevLine((shoulder, low_z), (shoulder, shoulder_bottom_z)))
  if chamfer_mm > 0.0 {
    segments.push(
      @cad.RevLine((shoulder, shoulder_bottom_z), (shoulder + chamfer_mm, 0.0)),
    )
  }
  @cad.RevolvedProfile::new(segments)
}

///|
/// deep_groove_inner_ring_profile builds the inner ring cross-section: a
/// grooved raceway on the outside, flat faces, and optional bore chamfers.
fn deep_groove_inner_ring_profile(
  spec : DeepGrooveBearingSpec,
  chamfer_mm : Double,
) -> @cad.RevolvedProfile {
  let width = spec.size.width_mm
  let bore_radius = spec.size.bore_mm / 2.0
  let shoulder = spec.inner_shoulder_radius_mm
  let mid_z = width / 2.0
  let low_z = mid_z - spec.shoulder_land_mm
  let high_z = mid_z + spec.shoulder_land_mm
  let segments : Array[@cad.RevSegment] = []
  let shoulder_top_z = if chamfer_mm > 0.0 { width - chamfer_mm } else { width }
  let shoulder_bottom_z = if chamfer_mm > 0.0 { chamfer_mm } else { 0.0 }
  if chamfer_mm > 0.0 {
    segments.push(
      @cad.RevLine(
        (bore_radius + chamfer_mm, 0.0),
        (shoulder - chamfer_mm, 0.0),
      ),
    )
    segments.push(
      @cad.RevLine((shoulder - chamfer_mm, 0.0), (shoulder, chamfer_mm)),
    )
  } else {
    segments.push(@cad.RevLine((bore_radius, 0.0), (shoulder, 0.0)))
  }
  segments.push(@cad.RevLine((shoulder, shoulder_bottom_z), (shoulder, low_z)))
  segments.push(
    @cad.RevArc(
      (shoulder, low_z),
      (shoulder, high_z),
      (spec.pitch_radius_mm, mid_z),
    ),
  )
  segments.push(@cad.RevLine((shoulder, high_z), (shoulder, shoulder_top_z)))
  if chamfer_mm > 0.0 {
    segments.push(
      @cad.RevLine((shoulder, shoulder_top_z), (shoulder - chamfer_mm, width)),
    )
    segments.push(
      @cad.RevLine(
        (shoulder - chamfer_mm, width),
        (bore_radius + chamfer_mm, width),
      ),
    )
    segments.push(
      @cad.RevLine(
        (bore_radius + chamfer_mm, width),
        (bore_radius, width - chamfer_mm),
      ),
    )
    segments.push(
      @cad.RevLine((bore_radius, width - chamfer_mm), (bore_radius, chamfer_mm)),
    )
    segments.push(
      @cad.RevLine((bore_radius, chamfer_mm), (bore_radius + chamfer_mm, 0.0)),
    )
  } else {
    segments.push(@cad.RevLine((shoulder, width), (bore_radius, width)))
    segments.push(@cad.RevLine((bore_radius, width), (bore_radius, 0.0)))
  }
  @cad.RevolvedProfile::new(segments)
}

///|
/// deep_groove_ball_profile builds a watertight ball: a spherical band closed by
/// two tiny flat polar caps. The caps replace the singular sphere poles (which
/// some tessellators leave as pinholes); the ball placement turns them into the
/// raceway, so the visible ball surface is the smooth spherical band.
fn deep_groove_ball_profile(diameter : Double) -> @cad.RevolvedProfile {
  let radius = diameter / 2.0
  let cap_height = BALL_POLE_CAP_FRACTION * radius
  let cap_z = radius - cap_height
  let cap_radius = Double::sqrt(
    2.0 * radius * cap_height - cap_height * cap_height,
  )
  @cad.RevolvedProfile::new([
    @cad.RevLine((0.0, -cap_z), (cap_radius, -cap_z)),
    @cad.RevArc((cap_radius, -cap_z), (cap_radius, cap_z), (0.0, 0.0)),
    @cad.RevLine((cap_radius, cap_z), (0.0, cap_z)),
  ])
}

///|
/// deep_groove_bearing builds the component: two grooved rings, the full
/// complement of balls, and the bore/outer-seat/face mate connectors.
pub fn deep_groove_bearing(
  size : BearingSize,
  ball_count~ : Int32 = 0,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let spec = match deep_groove_bearing_spec(size, ball_count~) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let use_features = policy.include_small_features
  let chamfer = if use_features {
    let c = bearing_chamfer(spec.size.width_mm, spec.min_ring_wall_mm)
    let shoulder_land_length = spec.size.width_mm / 2.0 - spec.shoulder_land_mm
    if c >= spec.min_ring_wall_mm ||
      c >= spec.size.width_mm / 2.0 ||
      c >= shoulder_land_length {
      return Err(
        @common.InvalidDimension(
          "bearing ring wall, shoulder land, or width is too small for the default edge chamfer; use Simplified detail",
        ),
      )
    }
    c
  } else {
    0.0
  }
  let base_color = match color {
    Some(c) => c
    None => @cad.Rgb::purple()
  }
  let outer_profile = deep_groove_outer_ring_profile(spec, chamfer)
  let inner_profile = deep_groove_inner_ring_profile(spec, chamfer)
  let features = @common.FeatureRecord::new(
    modeled=[
      "outer-ring", "inner-ring", "raceway-groove", "retaining-shoulders", "balls",
    ],
    approximated=[
      @common.Approximation::new(
        feature="ball-size-and-count",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="ball diameter = 0.285 x (outer - bore); default count is the largest full complement with a 0.15 x ball-radius web",
      ),
      @common.Approximation::new(
        feature="raceway-conformity-and-shoulder",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="groove radius = 1.04 x ball radius; shoulder overlap = 0.35 x ball radius",
      ),
      @common.Approximation::new(
        feature="ball-polar-caps",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.03,
        control="tiny flat polar caps replace the singular sphere poles so the ball is watertight; the cap planes are turned into the raceway",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="cage",
        reason="a full complement is modelled without a cage; the shoulder-retained balls are not a caged assembly",
      ),
      @common.Omission::new(
        feature="seals-and-shields",
        reason="the bearing is open; no seal, shield, or grease is modelled",
      ),
      @common.Omission::new(
        feature="catalogue-internal-geometry",
        reason="ring proportions, ball size, and ball count are engineering defaults, not catalogue internals",
      ),
      @common.Omission::new(
        feature="load-and-life-rating",
        reason="nominal geometry only; no load, life, or material claim",
      ),
    ],
  )
  let mut component = @common.Component::new(
    name="deep-groove-bearing-\{size.designation}",
    metadata=@common.Metadata::new(
      designation="Deep groove ball bearing \{size.designation}",
      standard="ISO 15:2017 boundary dimensions (internal proportions are engineering defaults)",
      family="deep groove ball bearing (full-complement envelope)",
      size=size.designation,
      source="Boundary dimensions from ISO 15:2017; ball diameter, count, raceway conformity, and shoulder retention are parametric engineering defaults.",
    ),
    description="Full-complement deep-groove ball bearing: grooved outer and inner rings with retaining shoulders, and a full ring of watertight balls (a spherical band closed by tiny polar caps turned into the raceway). The shoulder overlap keeps the balls from falling out axially. Rim and shoulder chamfers at Detailed and above. No cage, seals, shields, load, or life rating.",
    features~,
  )
  component = component
    .add_layer(outer_profile.as_shape(), name="outer-ring", color=base_color)
    .add_layer(
      inner_profile.as_shape(),
      name="inner-ring",
      color=@cad.Rgb::blue(),
    )
  let ball = deep_groove_ball_profile(spec.ball_diameter_mm)
  let mid_z = size.width_mm / 2.0
  for i in 0..<spec.ball_count {
    let angle = 360.0 * Double::from_int(i) / Double::from_int(spec.ball_count)
    let base = @common.Placement::translation(spec.pitch_radius_mm, 0.0, mid_z)
    // Turn the tiny polar caps (local +Z) into the radial direction, where the
    // raceway hides them; the visible band is the smooth spherical surface.
    let cap_turn = @common.Placement::rotation_y(90.0)
    let placement = @common.Placement::compose(
      @common.Placement::rotation_z(angle),
      @common.Placement::compose(base, cap_turn),
    )
    component = component.add_layer(
      ball.as_shape(),
      name="ball-\{i + 1}",
      color=@cad.Rgb::orange(),
      placement~,
    )
  }
  Ok(
    with_bushing_connectors(
      component,
      size.bore_mm,
      size.outer_mm,
      size.width_mm,
    ),
  )
}
