///|
/// COUNTERSUNK_HEAD_TOP_INSET_MM is the detailed ISO 10642 reference's flush-top
/// inset from the sharp head radius. ISO 10642 fixes dk and the edge radius but
/// not this conical top-edge break; 0.05 mm reproduces the detailed reference.
const COUNTERSUNK_HEAD_TOP_INSET_MM : Double = 0.05

///|
/// COUNTERSUNK_TIP_BREAK_MM is the detailed ISO 10642 reference's 45-degree
/// shank-tip break (ISO 10642 does not fix it).
const COUNTERSUNK_TIP_BREAK_MM : Double = 0.2

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
  // ISO socket range is above the nominal; model the upper limit.
  let s = dims.socket_across_flats_max_mm
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
  ).add_modeled("head-edge-radius")
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Single closed solid: a solid of revolution (shank, 90-degree countersink cone with the ISO head edge radius, flush top face) with a blind hexagonal socket cut into the top; six planar socket walls and a planar hexagonal floor bound the pocket. The cone ends at the sharp head diameter dk and is rounded by r = \{format_length(dims.head_edge_radius_mm)} mm; the reference head height is \{format_length(k)} mm (a modeled thread starts the cone at the thread major diameter). Without modeled threads the shank uses the ISO 68-1 basic minor diameter D1." +
      thread_note(thread_rep),
    features~,
  )
  // A countersunk head is flush with the bearing surface, so ISO 10642
  // measures the nominal length from the top of the head to the shank tip.
  // The head is a 90-degree cone ending at the sharp head diameter dk, rounded
  // at the top edge by the ISO head edge radius r. For the unthreaded envelope
  // the head base is the reference k below the top; a modeled thread starts the
  // cone at the thread major diameter so the crest cannot protrude.
  let r_sharp = big_r
  let r_edge = dims.head_edge_radius_mm
  let root2 = Double::sqrt(2.0)
  let threaded = thread_rep is @common.ThreadRepresentation::Helical
  // The Detailed unthreaded envelope models the shank at the nominal major
  // diameter and the head as the reference's two-cone profile: a 45-degree
  // countersink from the shank up to the head edge, then a 22.5-degree conical
  // top-edge break to the flush top face. The Simplified and threaded variants
  // keep the ISO head edge radius as a true arc and the ISO 68-1 minor-diameter
  // shank, matching the simpler downloaded references.
  let detailed = policy.include_small_features && !threaded
  let head_height = if threaded { r_sharp - r_sh } else { k }
  let head_z = length - head_height
  let tip = if policy.include_small_features {
    let raw = if detailed {
      COUNTERSUNK_TIP_BREAK_MM
    } else {
      shank_tip_chamfer_mm(d)
    }
    if raw < head_z / 4.0 {
      raw
    } else {
      head_z / 4.0
    }
  } else {
    0.0
  }
  let thread_length = head_z
  let core_d = if threaded {
    thread.external_minor_diameter_mm()
  } else if detailed {
    d
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
  let body = if detailed {
    let inset = COUNTERSUNK_HEAD_TOP_INSET_MM
    let r_top = r_sharp - inset
    let t225 = @math.tan(22.5 * @math.PI / 180.0)
    let z_c = (r_top - core_r - k) / (1.0 + t225)
    let r_c = core_r + k + z_c
    pts.push((r_c, length + z_c))
    pts.push((r_top, length))
    pts.push((0.0, length))
    let segs : Array[@cad.RevSegment] = []
    for i in 0..<(pts.length() - 1) {
      segs.push(@cad.RevLine(pts[i], pts[i + 1]))
    }
    @cad.RevolvedProfile::new(segs)
  } else {
    let r_top = r_sharp - r_edge * (1.0 + root2)
    let z_t = -r_edge * (1.0 + 1.0 / root2)
    let r_t = r_sharp + z_t
    let r_base = r_sharp - head_height
    if core_r < r_base - FASTENER_EPS {
      pts.push((r_base, head_z))
    }
    let segs : Array[@cad.RevSegment] = []
    for i in 0..<(pts.length() - 1) {
      segs.push(@cad.RevLine(pts[i], pts[i + 1]))
    }
    segs.push(@cad.RevLine((r_base, head_z), (r_t, length + z_t)))
    segs.push(
      @cad.RevArc(
        (r_t, length + z_t),
        (r_top, length),
        (r_top, length - r_edge),
      ),
    )
    segs.push(@cad.RevLine((r_top, length), (0.0, length)))
    @cad.RevolvedProfile::new(segs)
  }
  let socket = if detailed {
    // The reference socket is a conical 45-degree countersink over a hexagon
    // whose corners reach the head underside, with a 70-degree drill point
    // continuing into the shank.
    let s_nom = dims.socket_across_flats_mm
    let r_corner = s_nom / Double::sqrt(3.0)
    let tan70 = @math.tan(70.0 * @math.PI / 180.0)
    let floor_apex = length - k - r_corner / tan70
    @cad.SocketedSolid::new(
      body,
      s_nom,
      floor_apex,
      conical=true,
      rim_angle_deg=45.0,
      floor_angle_deg=70.0,
      rotation_deg=0.0,
    )
  } else {
    @cad.SocketedSolid::new(body, s, length - t)
  }
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
  // Datum: flush top face at z = 0, head -Z, shank further -Z.
  component.translate(z=-length)
}

///|
/// iso7380_screw builds an ISO 7380-1 button head hexagon socket screw.
///
/// The head is the ISO 7380-1 circular-arc dome (radius `r_f`) with the
/// reference flat `d_L` and a real hexagon socket. The arc centre is off-axis,
/// so the compiler emits an analytic `TOROIDAL_SURFACE` rather than a sphere.
/// The datum is the head underside
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
    "head-dome-revolution",
    dims.head_diameter_mm,
    segments,
  )
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Single closed solid: a solid of revolution (shank, head underside, ISO circular-arc dome, flat top) with a blind hexagonal socket cut into the flat top; six planar socket walls and a planar hexagonal floor bound the pocket. The dome is the ISO 7380-1 radius r_f (upper limit) with the reference flat d_L. Without modeled threads the shank uses the ISO 68-1 basic minor diameter D1." +
      thread_note(thread_rep),
    features~,
  )
  // ISO 7380-1 defines the dome by radius r_f (M3: 3.30-3.70 mm) and a
  // reference flat diameter d_L (M3: 2.6 mm); the 2022 edition allows the arc
  // centre to be offset from the axis. Model the upper r_f limit, which is what
  // the downloaded goldens use. The centre is found from the two endpoints.
  let r_top = dims.head_flat_diameter_mm / 2.0
  let rf = dims.head_dome_radius_mm
  let chord_dr = r_top - big_r
  let chord_dz = k
  let chord = Double::sqrt(chord_dr * chord_dr + chord_dz * chord_dz)
  let half_chord = chord / 2.0
  let h2 = rf * rf - half_chord * half_chord
  let h = if h2 > 0.0 { Double::sqrt(h2) } else { 0.0 }
  let perp_r = -chord_dz / chord
  let perp_z = chord_dr / chord
  let arc_cr = (big_r + r_top) / 2.0 + h * perp_r
  let arc_cz = k / 2.0 + h * perp_z
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
    @cad.RevArc((big_r, length), (r_top, length + k), (arc_cr, length + arc_cz)),
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
