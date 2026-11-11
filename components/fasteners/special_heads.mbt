///|
/// iso10642_screw builds an ISO 10642 countersunk head hexagon socket screw.
///
/// The head is an analytic revolved frustum: a 90-degree countersink cone
/// (45-degree half-angle) whose floor layer is a true `CONICAL_SURFACE`, and a
/// flat top face carrying a real hexagon socket. The upper part of the head
/// (the socket band) is built from a ring stack so the hexagonal through-hole
/// can be layered over the solid socket floor; its outer cone is a
/// high-resolution polygon with a documented deviation.
pub fn iso10642_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso10642_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => Ok(countersunk_screw(spec, detail~, threads?))
  }
}

///|
fn countersunk_screw(
  spec : @standards.ISO10642Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread_rep = match threads {
    Some(t) => t
    None => policy.threads
  }
  let dims = spec.size_dims
  let thread = dims.thread
  let d = thread.nominal_diameter_mm
  let length = spec.length_mm
  let r_sh = d / 2.0
  let big_r = dims.head_diameter_mm / 2.0
  let k = dims.head_height_mm
  let t = dims.socket_depth_mm
  let s = dims.socket_across_flats_mm
  let segments = clamp_segments(policy.circle_segments)
  let name = "ISO10642-\{dims.size.designation()}-\{format_length(length)}"
  let metal = @cad.Rgb::grey()
  let features = headed_feature_record(
    policy,
    thread_rep,
    thread,
    "head-countersink-cone",
    dims.head_diameter_mm,
    segments,
  )
  let mut component = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Countersunk head (90-degree included angle) with a hexagon socket. The socket floor is an analytic revolved head; the socket band is a high-resolution polygon with a real hex through-hole." +
      thread_note(thread_rep),
    features~,
  )
  // A countersunk head is flush with the bearing surface, so ISO 10642
  // measures the nominal length from the top of the head to the shank tip.
  // The head therefore occupies the top `k` millimetres of that length and the
  // shank runs below it.
  let head_z = length - k
  let shank_length = head_z
  component = add_plain_or_threaded_shank(
    component, thread, shank_length, thread_rep, policy, metal,
  )
  // Head geometry, local z from 0 (head base) to k (flush top face).
  let cone_axial = if big_r - r_sh < k { big_r - r_sh } else { k }
  let cyl_h = k - cone_axial
  let z_floor = k - t
  let r_of = fn(z : Double) -> Double {
    if z <= cyl_h {
      r_sh
    } else {
      let r = r_sh + (z - cyl_h)
      if r < big_r {
        r
      } else {
        big_r
      }
    }
  }
  let r_f = r_of(z_floor)
  let floor_points : Array[@cad.Vec2] = [(0.0, 0.0), (r_sh, 0.0)]
  if z_floor <= cyl_h {
    floor_points.push((r_sh, z_floor))
  } else {
    floor_points.push((r_sh, cyl_h))
    floor_points.push((r_f, z_floor))
  }
  floor_points.push((0.0, z_floor))
  let floor = @cad.RevolvedProfile::polyline(floor_points)
  component = component.add_layer(
    floor.as_shape(),
    name="head-floor",
    color=metal,
    placement=@common.Placement::translation(0.0, 0.0, head_z),
  )
  let levels : Array[(Double, Double)] = [(z_floor, big_r - r_f)]
  if z_floor < cyl_h {
    levels.push((cyl_h, big_r - r_sh))
  }
  levels.push((k, 0.0))
  let ring = if policy.include_small_features {
    let lead = socket_lead_in_chamfer_mm(s, t)
    let hole = socket_lead_in_hole(s, lead)
    let hole_levels = socket_lead_in_hole_levels(z_floor, k, lead)
    @cad.ChamferedPrism::new(
      circle_profile(dims.head_diameter_mm, segments~),
      levels,
      hole~,
      hole_levels~,
    ).as_shape()
  } else {
    @cad.ChamferedPrism::new(
      circle_profile(dims.head_diameter_mm, segments~),
      levels,
      hole=hex_hole_across_flats(s),
    ).as_shape()
  }
  component.add_layer(
    ring,
    name="head-socket",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::translation(0.0, 0.0, head_z),
  )
}

///|
/// iso7380_screw builds an ISO 7380-1 button head hexagon socket screw.
///
/// The head is a spherical-cap dome (an analytic `SPHERICAL_SURFACE`) with a
/// flat top face and a real hexagon socket. The flat-top radius and the socket
/// band are documented engineering choices; the head diameter, height, socket
/// size and depth are the standard's nominal values.
pub fn iso7380_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso7380_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => Ok(button_screw(spec, detail~, threads?))
  }
}

///|
fn button_screw(
  spec : @standards.ISO7380Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread_rep = match threads {
    Some(t) => t
    None => policy.threads
  }
  let dims = spec.size_dims
  let thread = dims.thread
  let length = spec.length_mm
  let big_r = dims.head_diameter_mm / 2.0
  let k = dims.head_height_mm
  let t = dims.socket_depth_mm
  let s = dims.socket_across_flats_mm
  let segments = clamp_segments(policy.circle_segments)
  let name = "ISO7380-\{dims.size.designation()}-\{format_length(length)}"
  let metal = @cad.Rgb::grey()
  let features = headed_feature_record(
    policy,
    thread_rep,
    thread,
    "head-dome-sphere",
    dims.head_diameter_mm,
    segments,
  )
  let mut component = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Button head with a spherical-cap dome, flat top, and hexagon socket. The dome is an analytic spherical surface; the socket band is a high-resolution polygon with a real hex through-hole." +
      thread_note(thread_rep),
    features~,
  )
  component = add_plain_or_threaded_shank(
    component, thread, length, thread_rep, policy, metal,
  )
  // Spherical cap through (big_r, 0) and (r_top, k), centred on the axis.
  let r_top = button_flat_radius(big_r, s)
  let c = (k * k + r_top * r_top - big_r * big_r) / (2.0 * k)
  let rho = Double::sqrt(big_r * big_r + c * c)
  let z_floor = k - t
  let r_of = fn(z : Double) -> Double {
    let v = rho * rho - (z - c) * (z - c)
    if v <= 0.0 {
      0.0
    } else {
      Double::sqrt(v)
    }
  }
  let r_f = r_of(z_floor)
  // Head floor: base disc, dome arc to the socket floor, flat socket floor.
  let floor = @cad.RevolvedProfile::new([
    @cad.RevLine((0.0, 0.0), (big_r, 0.0)),
    @cad.RevArc((big_r, 0.0), (r_f, z_floor), (0.0, c)),
    @cad.RevLine((r_f, z_floor), (0.0, z_floor)),
  ])
  component = component.add_layer(
    floor.as_shape(),
    name="head-floor",
    color=metal,
    placement=@common.Placement::translation(0.0, 0.0, length),
  )
  // Socket band: polygon ring stack following the dome, with a hex hole.
  let levels : Array[(Double, Double)] = []
  let steps = 4
  for i in 0..<=steps {
    let frac = Double::from_int(i) / Double::from_int(steps)
    let z = z_floor + (k - z_floor) * frac
    levels.push((z, r_f - r_of(z)))
  }
  let ring = if policy.include_small_features {
    let lead = socket_lead_in_chamfer_mm(s, t)
    let hole = socket_lead_in_hole(s, lead)
    let hole_levels = socket_lead_in_hole_levels(z_floor, k, lead)
    @cad.ChamferedPrism::new(
      circle_profile(2.0 * r_f, segments~),
      levels,
      hole~,
      hole_levels~,
    ).as_shape()
  } else {
    @cad.ChamferedPrism::new(
      circle_profile(2.0 * r_f, segments~),
      levels,
      hole=hex_hole_across_flats(s),
    ).as_shape()
  }
  component.add_layer(
    ring,
    name="head-socket",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::translation(0.0, 0.0, length),
  )
}

///|
/// button_flat_radius returns the flat-top radius of a button head. This is an
/// engineering choice (large enough for the socket, small enough to leave a
/// visible dome); it is not a standard dimension.
fn button_flat_radius(big_r : Double, s : Double) -> Double {
  let by_socket = s * 0.62
  let by_head = 0.65 * big_r
  let r = if by_socket > by_head { by_socket } else { by_head }
  if r > 0.95 * big_r {
    0.95 * big_r
  } else {
    r
  }
}

///|
/// headed_feature_record builds the feature record shared by the button and
/// countersunk head families.
fn headed_feature_record(
  policy : @common.DetailPolicy,
  thread_rep : @common.ThreadRepresentation,
  thread : @standards.ThreadSpec,
  head_feature : String,
  head_diameter_mm : Double,
  segments : Int32,
) -> @common.FeatureRecord {
  let base = @common.FeatureRecord::new(
    modeled=["blind-hex-socket", head_feature],
    approximated=[
      @common.Approximation::new(
        feature="head-socket-band",
        kind=@common.ApproximationKind::PolygonRevolve,
        deviation_mm=@common.chord_deviation(head_diameter_mm / 2.0, segments),
        control="circle_segments=\{segments}",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="under-head-radius",
        reason="no verified standard value; a typed omission rather than a guessed fillet",
      ),
    ],
  )
  let with_chamfers = if policy.include_small_features {
    base
    .add_modeled("socket-lead-in-chamfer")
    .add_modeled("shank-tip-chamfer")
    .add_approximated(
      @common.Approximation::new(
        feature="socket-lead-in-band",
        kind=@common.ApproximationKind::PolygonRevolve,
        deviation_mm=@common.chord_deviation(head_diameter_mm / 2.0, segments),
        control="hex-hole ruled lead-in, circle_segments=\{segments}",
      ),
    )
  } else {
    base
    .add_omitted(
      @common.Omission::new(
        feature="socket-lead-in-chamfer",
        reason="omitted at Simplified detail level",
      ),
    )
    .add_omitted(
      @common.Omission::new(
        feature="shank-tip-chamfer",
        reason="omitted at Simplified detail level",
      ),
    )
  }
  fastener_thread_features(
    with_chamfers,
    thread_rep,
    policy,
    thread.pitch_diameter_mm() / 2.0,
  )
}

///|
/// add_plain_or_threaded_shank adds the shank layers shared by the new head
/// families. At Detailed and above the tip carries a 45-degree engineering
/// chamfer (a real ruled cone ring stack).
fn add_plain_or_threaded_shank(
  base : @common.Component,
  thread : @standards.ThreadSpec,
  length : Double,
  thread_rep : @common.ThreadRepresentation,
  policy : @common.DetailPolicy,
  metal : @cad.Rgb,
) -> @common.Component {
  let d = thread.nominal_diameter_mm
  let segments = clamp_segments(policy.circle_segments)
  let tip = if policy.include_small_features {
    let raw = shank_tip_chamfer_mm(d)
    if raw < length / 4.0 {
      raw
    } else {
      length / 4.0
    }
  } else {
    0.0
  }
  if thread_rep is @common.ThreadRepresentation::Helical {
    let d3 = thread.external_minor_diameter_mm()
    match
      external_thread_ridge(
        thread,
        length,
        segments_per_turn=policy.segments_per_turn,
      ) {
      Some(shape) => {
        let core = base.add_layer(
          tip_chamfered_cylinder(d3, length, tip, segments~),
          name="thread-core",
          color=metal,
        )
        core.add_layer(shape, name="helical-thread", color=@cad.Rgb::cyan())
      }
      None =>
        base.add_layer(
          tip_chamfered_cylinder(d, length, tip, segments~),
          name="shank",
          color=metal,
        )
    }
  } else {
    base.add_layer(
      tip_chamfered_cylinder(d, length, tip, segments~),
      name="shank",
      color=metal,
    )
  }
}
