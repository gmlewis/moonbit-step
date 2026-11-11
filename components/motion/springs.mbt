///|
/// compression_spring builds a simplified helical compression spring.
///
/// The spring is an open helix of circular wire with flat end caps. Closed end
/// coils, grinding, and end-condition variations are not modeled. Axis +Z, from
/// z = 0 to z = length.
pub fn compression_spring(
  mean_diameter_mm : Double,
  wire_diameter_mm : Double,
  length_mm : Double,
  active_coils : Int32,
  segments_per_turn~ : Int32 = 24,
  color~ : @cad.Rgb = @cad.Rgb::cyan(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("spring mean diameter", mean_diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("spring wire diameter", wire_diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("spring length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if active_coils < 1 {
    return Err(
      @common.InvalidParameter("spring active coils must be at least 1"),
    )
  }
  let radius = mean_diameter_mm / 2.0
  let wire_radius = wire_diameter_mm / 2.0
  if radius <= wire_radius {
    return Err(
      @common.InvalidDimension("spring mean radius must exceed the wire radius"),
    )
  }
  // The wire is swept about the path centreline, so it extends one wire radius
  // beyond the first and last path points. Inset the path by that radius at
  // each end so the finished spring still spans exactly z = 0 .. length_mm.
  let path_length = length_mm - 2.0 * wire_radius
  if path_length <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "spring length must exceed the wire diameter so the path has positive length",
      ),
    )
  }
  let pitch = path_length / active_coils.to_double()
  if pitch < wire_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "spring pitch is smaller than the wire diameter; reduce active coils or lengthen the spring",
      ),
    )
  }
  let segments = if segments_per_turn < 8 { 8 } else { segments_per_turn }
  let path = @cad.helix_path(
    pos=(0.0, 0.0, wire_radius),
    size_per_turn=(radius, radius, pitch),
    num_turns=active_coils.to_double(),
    num_segs_per_turn=segments,
    start_angle=0.0,
    clockwise=false,
  )
  let wire_profile : Array[@cad.Vec3] = []
  let wire_segments = 12
  for i in 0..<wire_segments {
    let angle = 2.0 * @math.PI * i.to_double() / wire_segments.to_double()
    wire_profile.push(
      (wire_radius * @math.cos(angle), 0.0, wire_radius * @math.sin(angle)),
    )
  }
  let profile = @cad.SweepProfile::new(
    wire_profile,
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let body = @cad.SweptProfile::new(path~, profile~, straight_outline=false)
  let name = "spring-\{@cad.fmt_double(mean_diameter_mm, None)}x\{@cad.fmt_double(wire_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Compression spring mean dia \{@cad.fmt_double(mean_diameter_mm, None)} / wire \{@cad.fmt_double(wire_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
        family="compression spring (simplified)",
        length_mm~,
        source="Parametric helical sweep; no spring rate, end-coil, or grinding model.",
      ),
      description="Open helical spring with circular wire and flat swept end caps. The wire section is swept in the radial-axial plane and is a 12-gon; the helix tangent used by the sweep has no axial component, so the section normal to the true helix is slightly elliptical. Closed/ground ends and preload are not modeled.",
      features=@common.FeatureRecord::new(
        modeled=["helix-body"],
        approximated=[
          @common.Approximation::new(
            feature="helical-wire",
            kind=@common.ApproximationKind::SweptSpline,
            deviation_mm=@common.chord_deviation(radius, segments),
            control="segments_per_turn=\{segments}",
          ),
          @common.Approximation::new(
            feature="wire-section",
            kind=@common.ApproximationKind::PolylineArc,
            deviation_mm=@common.chord_deviation(wire_radius, wire_segments),
            control="wire_segments=12",
          ),
        ],
        omitted=[
          @common.Omission::new(
            feature="closed-end-coils",
            reason="not modelled by this builder",
          ),
          @common.Omission::new(
            feature="ground-ends",
            reason="not modelled by this builder",
          ),
          @common.Omission::new(
            feature="spring-rate",
            reason="geometry only; no spring rate or preload model",
          ),
        ],
      ),
    ).add_layer(body, name="body", color~),
  )
}

///|
/// standoff builds a hex standoff with a through bore.
///
/// Axis +Z, base at z = 0; one pair of flats is normal to X.
pub fn standoff(
  across_flats_mm : Double,
  length_mm : Double,
  bore_diameter_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("standoff across flats", across_flats_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("standoff length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bore_diameter_mm <= 0.0 || bore_diameter_mm >= across_flats_mm {
    return Err(
      @common.InvalidDimension(
        "standoff bore must be > 0 and smaller than the across-flats size",
      ),
    )
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let segments = if policy.circle_segments < 32 {
    32
  } else {
    policy.circle_segments
  }
  let across_corners = across_flats_mm / @math.cos(@math.PI / 6.0)
  let outer = @cad.Profile2D::polygon(6, across_corners, rotation=30.0)
  let hole = @cad.Profile2D::circle(bore_diameter_mm, segments~).rev()
  let body = @cad.ExtrudedProfile::new(outer, length_mm, holes=[hole])
  let name = "standoff-\{@cad.fmt_double(across_flats_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Hex standoff AF \{@cad.fmt_double(across_flats_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
        family="hex standoff",
        length_mm~,
        source="Parametric hex tube; threads and chamfers are not modeled.",
      ),
      description="Hexagonal standoff with a plain through bore. Threads and chamfers are not modeled.",
      features=@common.FeatureRecord::new(
        modeled=["hex-body"],
        approximated=[
          @common.Approximation::new(
            feature="through-bore",
            kind=@common.ApproximationKind::PolylineArc,
            deviation_mm=@common.chord_deviation(
              bore_diameter_mm / 2.0,
              segments,
            ),
            control="circle_segments=\{segments}",
          ),
        ],
        omitted=[
          @common.Omission::new(
            feature="thread",
            reason="no thread geometry in this builder",
          ),
          @common.Omission::new(
            feature="edge-chamfer",
            reason="not modelled by this builder",
          ),
        ],
      ),
    ).add_layer(body, name="body", color=@cad.Rgb::green()),
  )
}

///|
/// dowel_pin builds a plain cylindrical dowel pin.
pub fn dowel_pin(
  diameter_mm : Double,
  length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  match shaft(diameter_mm, length_mm, color~) {
    Err(e) => Err(e)
    Ok(c) =>
      Ok(
        c
        .with_name(
          "dowel-pin-\{@cad.fmt_double(diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
        )
        .with_metadata(
          @common.Metadata::new(
            designation="Dowel pin \{@cad.fmt_double(diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
            family="dowel pin",
            length_mm~,
            source="Plain cylindrical pin; chamfers and tolerance class are not modeled.",
          ),
        )
        .with_features(
          @common.FeatureRecord::new(modeled=["body"], omitted=[
            @common.Omission::new(
              feature="pin-chamfer",
              reason="not modelled by this builder",
            ),
            @common.Omission::new(
              feature="tolerance-class",
              reason="nominal geometry only; no h/g tolerance class",
            ),
          ]),
        ),
      )
  }
}
