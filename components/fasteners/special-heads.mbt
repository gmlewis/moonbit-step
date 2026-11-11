///|
/// iso10642_screw builds an ISO 10642 countersunk head hexagon socket screw.
///
/// The head is a 90-degree included-angle countersink cone with a flush top
/// face carrying a real hexagon socket. The datum is the centre of the flush
/// top face: the head occupies `z = -k .. 0`, the shank `z = -length .. -k`,
/// and the socket opens at `z = 0`.
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
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Single closed solid: a solid of revolution (shank, 90-degree countersink cone, flush top face) with a blind hexagonal socket cut into the top; six planar socket walls and a planar hexagonal floor bound the pocket. Without modeled threads the shank uses the ISO 68-1 basic minor diameter D1." +
      thread_note(thread_rep),
    features~,
  )
  // A countersunk head is flush with the bearing surface, so ISO 10642
  // measures the nominal length from the top of the head to the shank tip.
  // The head therefore occupies the top `k` millimetres of that length and the
  // shank runs below it.
  let head_z = length - k
  let cone_axial = if big_r - r_sh < k { big_r - r_sh } else { k }
  let cyl_h = k - cone_axial
  let tip = if policy.include_small_features {
    let raw = shank_tip_chamfer_mm(d)
    if raw < head_z / 4.0 {
      raw
    } else {
      head_z / 4.0
    }
  } else {
    0.0
  }
  let threaded = thread_rep is @common.ThreadRepresentation::Helical
  let thread_length = head_z
  // Without modeled threads the shank uses the ISO 68-1 basic internal minor
  // diameter D1, matching the downloaded countersunk goldens.
  let core_d = if threaded {
    thread.external_minor_diameter_mm()
  } else {
    thread.internal_minor_diameter_mm()
  }
  let core_r = core_d / 2.0
  let pts : Array[@cad.Vec2] = [(0.0, 0.0)]
  if tip > 0.0 && tip < core_r {
    pts.push((core_r - tip, 0.0))
    pts.push((core_r, tip))
  } else {
    pts.push((core_r, 0.0))
  }
  pts.push((core_r, head_z))
  if core_r < r_sh - FASTENER_EPS {
    pts.push((r_sh, head_z))
  }
  if cyl_h > FASTENER_EPS {
    pts.push((r_sh, head_z + cyl_h))
  }
  pts.push((big_r, length))
  pts.push((0.0, length))
  let body = @cad.RevolvedProfile::polyline(pts)
  let z_floor = k - t
  let socket = @cad.SocketedSolid::new(body, s, length - t)
  let mut component = base.add_layer(
    socket.as_shape(),
    name="body",
    color=metal,
  )
  if threaded {
    match
      external_thread_ridge(
        thread,
        thread_length,
        segments_per_turn=policy.segments_per_turn,
      ) {
      Some(shape) =>
        component = component.add_layer(
          shape,
          name="helical-thread",
          color=@cad.Rgb::cyan(),
        )
      None => ()
    }
  }
  let _ = z_floor
  let _ = segments
  // Datum: flush top face at z = 0, head -Z, shank further -Z.
  component.translate(z=-length)
}

///|
/// iso7380_screw builds an ISO 7380-1 button head hexagon socket screw.
///
/// The head is a spherical-cap dome (an analytic `SPHERICAL_SURFACE`) with a
/// flat top face and a real hexagon socket. The datum is the head underside
/// (bearing face): the head occupies `z = 0 .. k` and the shank
/// `z = -length .. 0`. The socket is modelled at the ISO upper limit of the
/// across-flats range (for example 2.080 mm for M3, whose range is
/// 2.020–2.080 mm) so a standard hex key fits; the downloaded button-head
/// goldens use the same limit. The flat-top radius and socket band are
/// documented engineering choices; the head diameter, height and socket depth
/// are the standard's values.
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
  let d = thread.nominal_diameter_mm
  let length = spec.length_mm
  let big_r = dims.head_diameter_mm / 2.0
  let k = dims.head_height_mm
  let t = dims.socket_depth_mm
  // ISO gives the socket as 2.02-2.08 mm for M3 (nominal 2.0). Model the
  // upper limit so a standard hex key fits; the downloaded goldens use it too.
  let s = dims.socket_across_flats_max_mm
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
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Single closed solid: a solid of revolution (shank, head underside, spherical-cap dome, flat top) with a blind hexagonal socket cut into the flat top; six planar socket walls and a planar hexagonal floor bound the pocket. Without modeled threads the shank uses the ISO 68-1 basic minor diameter D1." +
      thread_note(thread_rep),
    features~,
  )
  // Spherical cap through (big_r, 0) and (r_top, k), centred on the axis.
  let r_top = button_flat_radius(big_r, s, d)
  let c = (k * k + r_top * r_top - big_r * big_r) / (2.0 * k)
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
  let threaded = thread_rep is @common.ThreadRepresentation::Helical
  let thread_length = length
  // ISO 7380 threads run to the head. Without modeled threads the envelope is
  // the ISO 68-1 basic internal minor diameter D1 (the table "minor diameter"),
  // which is the shank the downloaded button-head goldens use. With threads the
  // core is the external root d3 and the swept ridge reaches the major diameter.
  let core_d = if threaded {
    thread.external_minor_diameter_mm()
  } else {
    thread.internal_minor_diameter_mm()
  }
  let core_r = core_d / 2.0
  let pts : Array[@cad.Vec2] = [(0.0, 0.0)]
  if tip > 0.0 && tip < core_r {
    pts.push((core_r - tip, 0.0))
    pts.push((core_r, tip))
  } else {
    pts.push((core_r, 0.0))
  }
  pts.push((core_r, length))
  if core_r < big_r - FASTENER_EPS {
    pts.push((big_r, length))
  }
  let segs : Array[@cad.RevSegment] = []
  for i in 0..<(pts.length() - 1) {
    segs.push(@cad.RevLine(pts[i], pts[i + 1]))
  }
  segs.push(
    @cad.RevArc((big_r, length), (r_top, length + k), (0.0, length + c)),
  )
  segs.push(@cad.RevLine((r_top, length + k), (0.0, length + k)))
  let body = @cad.RevolvedProfile::new(segs)
  let z_floor = k - t
  let socket = @cad.SocketedSolid::new(body, s, length + z_floor)
  let mut component = base.add_layer(
    socket.as_shape(),
    name="body",
    color=metal,
  )
  if threaded {
    match
      external_thread_ridge(
        thread,
        thread_length,
        segments_per_turn=policy.segments_per_turn,
      ) {
      Some(shape) =>
        component = component.add_layer(
          shape,
          name="helical-thread",
          color=@cad.Rgb::cyan(),
        )
      None => ()
    }
  }
  let _ = segments
  // Datum: head underside at z = 0, head +Z, shank -Z.
  component.translate(z=-length)
}

///|
/// button_flat_radius returns the flat-top radius of a button head. This is an
/// engineering choice (large enough for the socket, small enough to leave a
/// visible dome); it is not a standard dimension. The default
/// `r = 0.6 d - 0.5` reproduces the downloaded M3/M4/M5 button-head goldens
/// (1.3, 1.9, 2.5 mm); it is clamped clear of the socket and inside the head.
fn button_flat_radius(big_r : Double, s : Double, d : Double) -> Double {
  let socket_circumradius = s / Double::sqrt(3.0)
  let mut r = 0.6 * d - 0.5
  let clear_of_socket = socket_circumradius + 0.05
  if r < clear_of_socket {
    r = clear_of_socket
  }
  let inside_head = 0.95 * big_r
  if r > inside_head {
    r = inside_head
  }
  r
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
  let _ = head_diameter_mm
  let _ = segments
  let base = @common.FeatureRecord::new(
    modeled=[
      "blind-hex-socket", "hex-socket-flats", "socket-floor-plane", head_feature,
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="under-head-radius",
        reason="no verified standard value; a typed omission rather than a guessed fillet",
      ),
      @common.Omission::new(
        feature="socket-lead-in-cone",
        reason="the golden rim is a conical countersink; a true trimmed cone needs hyperbola-bounded cone faces, and a ruled hex flare would misstate the shape, so the rim is sharp",
      ),
      @common.Omission::new(
        feature="socket-floor-cone",
        reason="the golden socket bottom is a shallow conical drill point; this builder emits a flat floor rather than an unverified cone",
      ),
    ],
  )
  let with_chamfers = if policy.include_small_features {
    base.add_modeled("shank-tip-chamfer")
  } else {
    base.add_omitted(
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
