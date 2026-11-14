///|
/// belt_pitch_length_mm returns the pitch length of an open belt around two
/// equal pulleys.
///
/// Formula: `2 * center_distance + pi * pitch_diameter`. Both pulleys share the
/// same pitch diameter.
pub fn belt_pitch_length_mm(
  pulley_pitch_diameter_mm : Double,
  center_distance_mm : Double,
) -> Double {
  2.0 * center_distance_mm + @math.PI * pulley_pitch_diameter_mm
}

///|
/// belt_center_distance_for_pitch_length solves the open-belt centre distance
/// for a declared pitch length.
pub fn belt_center_distance_for_pitch_length(
  pitch_length_mm : Double,
  pulley_pitch_diameter_mm : Double,
) -> Result[Double, @common.SpecError] {
  match
    mechanism_checks([
      ("belt pitch length", pitch_length_mm),
      ("belt pulley pitch diameter", pulley_pitch_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let center = (pitch_length_mm - @math.PI * pulley_pitch_diameter_mm) / 2.0
  if center <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "declared pitch length is too short for two pulleys of this diameter",
      ),
    )
  }
  Ok(center)
}

///|
/// belt_loop builds a timing-belt loop envelope around two equal pulleys.
///
/// Frame: the belt lies in the XY plane and spans `z = 0 .. belt_width`. Each
/// pulley axis is along +Z at `(+/- center_distance/2, 0)`. The inner running
/// surface is a stadium of radius `pulley_pitch_diameter / 2`; the outer surface
/// is offset by `belt_thickness`. The belt loop is one closed annular solid,
/// so the inner stadium is a real through opening. Teeth are not modelled: the
/// loop is a smooth engineering envelope.
///
/// The pitch length is `2 * center + pi * pitch_diameter` and can be checked
/// against a declared value with `belt_pitch_length_mm`.
pub fn belt_loop(
  pulley_pitch_diameter_mm : Double,
  center_distance_mm : Double,
  belt_thickness_mm : Double,
  belt_width_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::black(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("belt pulley pitch diameter", pulley_pitch_diameter_mm),
      ("belt centre distance", center_distance_mm),
      ("belt thickness", belt_thickness_mm),
      ("belt width", belt_width_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let inner_radius = pulley_pitch_diameter_mm / 2.0
  let outer_radius = inner_radius + belt_thickness_mm
  let center_offset = center_distance_mm / 2.0
  let outer_loop = stadium_loop(center_offset, outer_radius)
  let inner_loop = stadium_loop(center_offset, inner_radius)
  let body = @cad.ExtrudedArcProfile::new(outer_loop, belt_width_mm, holes=[
    inner_loop,
  ])
  if !body.validate() {
    return Err(
      @common.InvalidParameter(
        "belt loop did not produce a valid closed profile",
      ),
    )
  }
  let pitch_length = belt_pitch_length_mm(
    pulley_pitch_diameter_mm, center_distance_mm,
  )
  let _ = pitch_length
  let features = @common.FeatureRecord::new(
    modeled=["belt-loop", "inner-running-surface", "outer-surface"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="belt-teeth",
        reason="the loop is a smooth envelope; tooth form and tooth pitch are not modelled",
      ),
      @common.Omission::new(
        feature="belt-cord-and-cover",
        reason="no internal construction, splice, or tension member is modelled",
      ),
      @common.Omission::new(
        feature="pulley-and-tensioner",
        reason="the pulleys are separate parts; only their axes are declared",
      ),
    ],
  )
  let name = "belt-loop-\{@cad.fmt_double(pulley_pitch_diameter_mm, None)}x\{@cad.fmt_double(center_distance_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Timing-belt loop around 2 x \{@cad.fmt_double(pulley_pitch_diameter_mm, None)} pulleys, centres \{@cad.fmt_double(center_distance_mm, None)}",
        family="timing-belt loop (engineering envelope)",
        size="\{@cad.fmt_double(pulley_pitch_diameter_mm, None)}x\{@cad.fmt_double(center_distance_mm, None)}",
        source="Parametric open-belt loop envelope. The pitch length is 2 C + pi D; the tooth form is not modelled.",
      ),
      description="Closed smooth timing-belt loop around two equal pitch circles. The pitch length is declared analytically; belt teeth and pulley grooves are omitted.",
      features~,
    )
    .add_layer(body.as_shape(), name="belt", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pulley-a",
        placement=@common.Placement::translation(-center_offset, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="negative-X pulley axis",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pulley-b",
        placement=@common.Placement::translation(center_offset, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="positive-X pulley axis",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "running-surface",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="inner (pulley-side) running surface datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "belt-outer",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * outer_radius,
        depth_mm=belt_width_mm,
        description="outer belt surface datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, belt_width_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * outer_radius,
        description="positive-Z belt face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-bottom",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * outer_radius,
        description="negative-Z belt face",
      ),
    ),
  )
}

///|
/// belt_loop_for_pitch_length builds a belt loop from a declared pitch length.
///
/// The centre distance is solved from `pitch = 2 C + pi D`, so the closure is
/// exact. The pitch length itself is stored in the component description.
pub fn belt_loop_for_pitch_length(
  pitch_length_mm : Double,
  pulley_pitch_diameter_mm : Double,
  belt_thickness_mm : Double,
  belt_width_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::black(),
) -> Result[@common.Component, @common.SpecError] {
  match
    belt_center_distance_for_pitch_length(
      pitch_length_mm, pulley_pitch_diameter_mm,
    ) {
    Err(e) => Err(e)
    Ok(center) =>
      match
        belt_loop(
          pulley_pitch_diameter_mm,
          center,
          belt_thickness_mm,
          belt_width_mm,
          color~,
        ) {
        Err(e) => Err(e)
        Ok(component) =>
          Ok(
            component
            .with_name(
              "belt-loop-pitch-\{@cad.fmt_double(pitch_length_mm, None)}",
            )
            .with_description(
              "Closed smooth timing-belt loop with declared pitch length \{@cad.fmt_double(pitch_length_mm, None)} mm. Belt teeth are omitted.",
            ),
          )
      }
  }
}

///|
/// belt_pitch_length_mm_unequal returns the pitch length of an open belt around
/// two unequal pulleys.
///
/// With radii `r1` and `r2`, centre distance `C`, and
/// `alpha = asin((r2 - r1) / C)`, the pitch length is
/// `pi (r1 + r2) + 2 alpha (r2 - r1) + 2 sqrt(C^2 - (r2 - r1)^2)`.
/// At `r1 == r2` this reduces to `pi D + 2 C`.
pub fn belt_pitch_length_mm_unequal(
  pulley_a_pitch_diameter_mm : Double,
  pulley_b_pitch_diameter_mm : Double,
  center_distance_mm : Double,
) -> Double {
  let r1 = pulley_a_pitch_diameter_mm / 2.0
  let r2 = pulley_b_pitch_diameter_mm / 2.0
  let dr = r2 - r1
  let alpha = @math.asin(dr / center_distance_mm)
  @math.PI * (r1 + r2) +
  2.0 * alpha * dr +
  2.0 * (center_distance_mm * center_distance_mm - dr * dr).sqrt()
}

///|
/// belt_center_distance_for_pitch_length_unequal solves the open-belt centre
/// distance for two unequal pulleys and a declared pitch length.
///
/// The pitch length increases monotonically with the centre distance, so the
/// solve is a bracketed bisection on `C > |r2 - r1|`.
pub fn belt_center_distance_for_pitch_length_unequal(
  pitch_length_mm : Double,
  pulley_a_pitch_diameter_mm : Double,
  pulley_b_pitch_diameter_mm : Double,
) -> Result[Double, @common.SpecError] {
  match
    mechanism_checks([
      ("belt pitch length", pitch_length_mm),
      ("belt pulley A pitch diameter", pulley_a_pitch_diameter_mm),
      ("belt pulley B pitch diameter", pulley_b_pitch_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let r1 = pulley_a_pitch_diameter_mm / 2.0
  let r2 = pulley_b_pitch_diameter_mm / 2.0
  let min_length = 2.0 * @math.PI * (if r1 > r2 { r1 } else { r2 })
  if pitch_length_mm <= min_length {
    return Err(
      @common.InvalidDimension(
        "declared pitch length is too short for the larger pulley",
      ),
    )
  }
  let dr = (r2 - r1).abs()
  let mut lo = dr + 1.0e-9
  let mut hi = if pitch_length_mm > 4.0 * dr {
    pitch_length_mm
  } else {
    4.0 * dr + 1.0
  }
  let mut iterations = 0
  while belt_pitch_length_mm_unequal(
          pulley_a_pitch_diameter_mm, pulley_b_pitch_diameter_mm, hi,
        ) <
        pitch_length_mm &&
        iterations < 100 {
    hi = hi * 2.0
    iterations = iterations + 1
  }
  for _ in 0..<200 {
    let mid = (lo + hi) / 2.0
    let length = belt_pitch_length_mm_unequal(
      pulley_a_pitch_diameter_mm, pulley_b_pitch_diameter_mm, mid,
    )
    if length < pitch_length_mm {
      lo = mid
    } else {
      hi = mid
    }
  }
  Ok((lo + hi) / 2.0)
}

///|
/// belt_band_loop returns one counter-clockwise belt boundary loop.
///
/// `offset_mm` is added to both pulley radii: 0 gives the inner running
/// surface and `belt_thickness` gives the outer surface. Every arc is a minor
/// arc, split at the rightmost and leftmost points where necessary.
fn belt_band_loop(
  pulley_a_radius_mm : Double,
  pulley_b_radius_mm : Double,
  center_distance_mm : Double,
  offset_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let r1 = pulley_a_radius_mm + offset_mm
  let r2 = pulley_b_radius_mm + offset_mm
  let alpha = @math.asin((r2 - r1) / center_distance_mm)
  let sin_a = @math.sin(alpha)
  let cos_a = @math.cos(alpha)
  let ax = -center_distance_mm / 2.0
  let bx = center_distance_mm / 2.0
  let a_lower = (ax - r1 * sin_a, -r1 * cos_a)
  let a_upper = (ax - r1 * sin_a, r1 * cos_a)
  let a_left = (ax - r1, 0.0)
  let b_lower = (bx - r2 * sin_a, -r2 * cos_a)
  let b_upper = (bx - r2 * sin_a, r2 * cos_a)
  let b_right = (bx + r2, 0.0)
  [
    @cad.SegmentLine(a_lower, b_lower),
    @cad.SegmentArc(b_lower, b_right, (bx, 0.0)),
    @cad.SegmentArc(b_right, b_upper, (bx, 0.0)),
    @cad.SegmentLine(b_upper, a_upper),
    @cad.SegmentArc(a_upper, a_left, (ax, 0.0)),
    @cad.SegmentArc(a_left, a_lower, (ax, 0.0)),
  ]
}

///|
/// belt_loop_unequal builds a smooth timing-belt loop around two unequal
/// pulleys.
///
/// Frame: the belt lies in the XY plane and spans `z = 0 .. belt_width`. Pulley
/// A is at `(-center_distance/2, 0)` and pulley B at
/// `(+center_distance/2, 0)`, both with +Z axes. The inner boundary is the exact
/// open-belt tangent path at the two pitch radii; the outer boundary is offset
/// by `belt_thickness`. The pitch length is
/// `belt_pitch_length_mm_unequal`. Belt teeth and pulley grooves are omitted.
pub fn belt_loop_unequal(
  pulley_a_pitch_diameter_mm : Double,
  pulley_b_pitch_diameter_mm : Double,
  center_distance_mm : Double,
  belt_thickness_mm : Double,
  belt_width_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::black(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("belt pulley A pitch diameter", pulley_a_pitch_diameter_mm),
      ("belt pulley B pitch diameter", pulley_b_pitch_diameter_mm),
      ("belt centre distance", center_distance_mm),
      ("belt thickness", belt_thickness_mm),
      ("belt width", belt_width_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let r1 = pulley_a_pitch_diameter_mm / 2.0
  let r2 = pulley_b_pitch_diameter_mm / 2.0
  if (r2 - r1).abs() >= center_distance_mm {
    return Err(
      @common.InvalidDimension(
        "belt centre distance must exceed the pulley radius difference",
      ),
    )
  }
  let outer = belt_band_loop(r1, r2, center_distance_mm, belt_thickness_mm)
  let inner = belt_band_loop(r1, r2, center_distance_mm, 0.0)
  let body = @cad.ExtrudedArcProfile::new(outer, belt_width_mm, holes=[inner])
  if !body.validate() {
    return Err(
      @common.InvalidParameter(
        "belt loop did not produce a valid closed profile",
      ),
    )
  }
  let pitch_length = belt_pitch_length_mm_unequal(
    pulley_a_pitch_diameter_mm, pulley_b_pitch_diameter_mm, center_distance_mm,
  )
  let features = @common.FeatureRecord::new(
    modeled=["belt-loop", "inner-running-surface", "outer-surface"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="belt-teeth",
        reason="the loop is a smooth envelope; tooth form and tooth pitch are not modelled",
      ),
      @common.Omission::new(
        feature="belt-cord-and-cover",
        reason="no internal construction, splice, or tension member is modelled",
      ),
      @common.Omission::new(
        feature="pulley-and-tensioner",
        reason="the pulleys are separate parts; only their axes are declared",
      ),
    ],
  )
  let name = "belt-loop-\{@cad.fmt_double(pulley_a_pitch_diameter_mm, None)}-\{@cad.fmt_double(pulley_b_pitch_diameter_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Timing-belt loop around \{@cad.fmt_double(pulley_a_pitch_diameter_mm, None)} / \{@cad.fmt_double(pulley_b_pitch_diameter_mm, None)} pulleys, centres \{@cad.fmt_double(center_distance_mm, None)}",
        family="timing-belt loop (engineering envelope)",
        size="\{@cad.fmt_double(pulley_a_pitch_diameter_mm, None)}x\{@cad.fmt_double(pulley_b_pitch_diameter_mm, None)}x\{@cad.fmt_double(center_distance_mm, None)}",
        source="Parametric open-belt loop around unequal pitch circles. The pitch length is exact; the tooth form is not modelled.",
      ),
      description="Closed smooth timing-belt loop around two unequal pitch circles with exact external tangents. Pitch length \{@cad.fmt_double(pitch_length, None)} mm; belt teeth are omitted.",
      features~,
    )
    .add_layer(body.as_shape(), name="belt", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pulley-a",
        placement=@common.Placement::translation(
          -center_distance_mm / 2.0,
          0.0,
          0.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_a_pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="pulley A axis",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pulley-b",
        placement=@common.Placement::translation(
          center_distance_mm / 2.0,
          0.0,
          0.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_b_pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="pulley B axis",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "running-surface",
        placement=@common.Placement::translation(
          -center_distance_mm / 2.0,
          0.0,
          0.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_a_pitch_diameter_mm,
        depth_mm=belt_width_mm,
        description="inner running surface datum at pulley A",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "belt-outer",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=pulley_b_pitch_diameter_mm + 2.0 * belt_thickness_mm,
        depth_mm=belt_width_mm,
        description="outer belt surface datum at pulley B",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, belt_width_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=pulley_a_pitch_diameter_mm,
        description="positive-Z belt face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-bottom",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=pulley_a_pitch_diameter_mm,
        description="negative-Z belt face",
      ),
    ),
  )
}
