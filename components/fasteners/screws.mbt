///|
/// Detailed socket-head reference defaults. ISO 4762 fixes the head diameter,
/// height, socket across-flats, socket depth and thread; it does not fix the
/// head breaks or drill-point clearance, so these are engineering defaults
/// taken from the detailed reference family and recorded, never claimed as
/// standard dimensions.
const SOCKET_HEAD_BREAK_MM : Double = 0.1

///|
const SOCKET_TIP_BREAK_MIN_MM : Double = 0.4

///|
const SOCKET_DRILL_CLEARANCE_MM : Double = 0.3

///|
/// socket_head_cap_screw builds an ISO 4762 hexagon socket head cap screw.
///
/// The screw axis is +Z with the origin at the centre of the head underside
/// (the bearing face). The head occupies `z = 0 .. k` and the shank
/// `z = -length .. 0`, so the flat bearing face rests on the `z = 0` plane.
/// This is a right-handed component and is intended to be inserted along -Z.
///
/// Construction is layered rather than boolean-trimmed: the head is a solid
/// floor disc plus a socket ring with a hexagonal through-hole, so the socket
/// is blind and each exported body is a closed shell. With
/// `ThreadRepresentation::Helical` the threaded length is a minor-diameter core
/// plus a swept helical ridge; without it the shank is a plain nominal-diameter
/// cylinder and no thread is claimed.
pub fn socket_head_cap_screw(
  spec : @standards.ISO4762Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  color? : @cad.Rgb,
  reference~ : Bool = false,
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
  let name = "ISO4762-\{dims.size.designation()}-\{format_length(length)}"
  let metal = match color {
    Some(c) => c
    None => @cad.Rgb::blue()
  }
  let thread_color = @cad.Rgb::cyan()
  let k = dims.head_height_mm
  let t = dims.socket_depth_mm
  let dk = dims.head_diameter_mm
  let segments = clamp_segments(policy.circle_segments)
  let features = screw_feature_record(policy, thread_rep, thread, dk, segments)
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Single closed solid: a solid of revolution (tip break, shank, head underside, head cylinder, conical head breaks) with a blind hexagonal socket cut into the head top; six planar socket walls are trimmed by a 45-degree conical countersink at the mouth and a 70-degree conical drill point at the floor." +
      head_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )
  if reference && !(thread_rep is @common.ThreadRepresentation::Helical) {
    // The simple step.parts reference representation: nominal shank with a
    // pitch-sized 45-degree tip break and a 0.001 mm under-head relief, a head
    // with a 0.0277 mm rounded top edge, and a sharp blind hex socket whose
    // across flats is the ISO nominal + 0.06 mm and whose flat floor is that
    // same distance below the top.
    let r = d / 2.0
    let dk_r = dk / 2.0
    let c = thread.pitch_mm
    let af = dims.socket_across_flats_mm + 0.06
    let edge_r = 0.0277
    let relief = 0.001
    let segs : Array[@cad.RevSegment] = [
      @cad.RevLine((0.0, 0.0), (r - c, 0.0)),
      @cad.RevLine((r - c, 0.0), (r, c)),
      @cad.RevLine((r, c), (r, length - 0.2)),
      @cad.RevLine((r, length - 0.2), (r - relief, length)),
      @cad.RevLine((r - relief, length), (dk_r, length)),
      @cad.RevLine((dk_r, length), (dk_r, length + k - edge_r)),
      @cad.RevArc(
        (dk_r, length + k - edge_r),
        (dk_r - edge_r, length + k),
        (dk_r - edge_r, length + k - edge_r),
      ),
      @cad.RevLine((dk_r - edge_r, length + k), (0.0, length + k)),
    ]
    let body = @cad.RevolvedProfile::new(segs)
    let floor_local = length + k - af
    let socket = @cad.SocketedSolid::new(body, af, floor_local)
    let ref_features = fastener_thread_features(
      @common.FeatureRecord::new(
        modeled=[
          "head-outer-cylinder", "blind-hex-socket", "hex-socket-flats", "socket-floor-plane",
          "shank-tip-chamfer", "under-head-relief", "head-top-edge-radius",
        ],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="socket-rim-chamfer",
            reason="the simple reference socket rim is sharp; only the detailed reference countersinks it",
          ),
        ],
      ),
      thread_rep,
      policy,
      thread.pitch_diameter_mm() / 2.0,
    )
    let ref_base = @common.Component::new(
      name~,
      metadata=spec.metadata(),
      description="Single closed solid in the simple reference representation: shank at the nominal diameter with a pitch-sized 45-degree tip break and a 0.001 mm under-head relief, a head with a 0.0277 mm rounded top edge, and a blind hexagonal socket (across flats = ISO nominal + 0.06 mm) with a flat floor." +
        thread_note(thread_rep),
      features=ref_features,
    )
    return ref_base
      .add_layer(socket.as_shape(), name="body", color=metal)
      .translate(z=-length)
  }

  // One solid of revolution: tip, shank (or thread core plus plain shank),
  // head underside, head outside, and the conical head-top break. ISO 4762
  // measures the thread length from the tip, so the thread occupies
  // z = 0 .. thread_length and any plain shank sits under the head.
  // The detailed reference profile uses a 0.4 mm minimum tip break and a
  // 0.1 mm head break; both are engineering defaults (ISO 4762 does not fix
  // them) and are recorded as such.
  let tip_chamfer = if policy.include_small_features {
    let raw = if 0.1 * d > SOCKET_TIP_BREAK_MIN_MM {
      0.1 * d
    } else {
      SOCKET_TIP_BREAK_MIN_MM
    }
    if raw < length / 4.0 {
      raw
    } else {
      length / 4.0
    }
  } else {
    0.0
  }
  let head_break = if policy.include_small_features {
    SOCKET_HEAD_BREAK_MM
  } else {
    0.0
  }
  let threaded = thread_rep is @common.ThreadRepresentation::Helical
  let thread_length = spec.thread_length_mm
  let core_d = if threaded { thread.external_minor_diameter_mm() } else { d }
  let core_r = core_d / 2.0
  let pts : Array[@cad.Vec2] = [(0.0, 0.0)]
  if tip_chamfer > 0.0 && tip_chamfer < core_r {
    pts.push((core_r - tip_chamfer, 0.0))
    pts.push((core_r, tip_chamfer))
  } else {
    pts.push((core_r, 0.0))
  }
  if threaded && thread_length < length - FASTENER_EPS {
    pts.push((core_r, thread_length))
    pts.push((d / 2.0, thread_length))
    pts.push((d / 2.0, length))
  } else {
    pts.push((core_r, length))
  }
  if head_break > 0.0 && head_break < dk / 2.0 {
    pts.push((dk / 2.0 - head_break, length))
    pts.push((dk / 2.0, length + head_break))
    pts.push((dk / 2.0, length + k - head_break))
    pts.push((dk / 2.0 - head_break, length + k))
  } else {
    pts.push((dk / 2.0, length))
    pts.push((dk / 2.0, length + k))
  }
  pts.push((0.0, length + k))
  let body = @cad.RevolvedProfile::polyline(pts)
  // The blind hex socket is a real pocket in the same closed shell. At Detailed
  // and above it is bounded by a 45-degree conical countersink and a 70-degree
  // conical drill point (hyperbola-trimmed hex walls), matching the detailed
  // ISO 4762 references. At Simplified detail the socket is the shallow flat
  // floor with the ISO upper-limit across-flats, so a standard hex key fits.
  let socket = if policy.include_small_features {
    @cad.SocketedSolid::new(
      body,
      dims.socket_across_flats_mm,
      length + SOCKET_DRILL_CLEARANCE_MM,
      conical=true,
      rim_angle_deg=45.0,
      floor_angle_deg=70.0,
    )
  } else {
    let af = dims.socket_across_flats_max_mm
    let floor_height = k - t
    @cad.SocketedSolid::new(body, af, length + floor_height)
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
          color=thread_color,
        )
      None => ()
    }
  }
  // Datum: head underside at z = 0, head +Z, shank -Z.
  component.translate(z=-length)
}

///|
/// iso4762_screw validates a request and builds the component.
pub fn iso4762_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  reference~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4762_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => {
      let component = match threads {
        Some(t) => socket_head_cap_screw(spec, detail~, threads=t, reference~)
        None => socket_head_cap_screw(spec, detail~, reference~)
      }
      Ok(component)
    }
  }
}

///|
/// socket_head_cap_screw_assembly_name returns the conventional instance stem
/// used by catalog assemblies.
pub fn socket_head_cap_screw_assembly_name(
  spec : @standards.ISO4762Spec,
) -> String {
  "screw-\{spec.size_dims.size.designation()}-\{format_length(spec.length_mm)}"
}

///|
fn head_chamfer_note(policy : @common.DetailPolicy) -> String {
  if policy.include_small_features {
    " The head top and bottom edges and the shank tip carry 45-degree conical breaks (engineering defaults); the socket mouth is a 45-degree countersink and the floor a 70-degree drill point trimmed by the six flats."
  } else {
    " The head, socket, and shank edges are sharp at this detail level."
  }
}

///|
/// screw_feature_record builds the machine-readable feature record for an
/// ISO 4762 socket head cap screw.
fn screw_feature_record(
  policy : @common.DetailPolicy,
  thread_rep : @common.ThreadRepresentation,
  thread : @standards.ThreadSpec,
  dk : Double,
  segments : Int32,
) -> @common.FeatureRecord {
  let _ = segments
  let _ = dk
  let under_head = @common.Omission::new(
    feature="under-head-radius",
    reason="ISO 4762 does not give a verified under-head radius for this builder; a typed omission rather than a guessed fillet",
  )
  let base = if policy.include_small_features {
    @common.FeatureRecord::new(
      modeled=[
        "head-outer-cylinder", "blind-hex-socket", "hex-socket-flats", "socket-lead-in-cone",
        "socket-floor-cone",
      ],
      approximated=[],
      omitted=[under_head],
    )
  } else {
    @common.FeatureRecord::new(
      modeled=[
        "head-outer-cylinder", "blind-hex-socket", "hex-socket-flats", "socket-floor-plane",
      ],
      approximated=[],
      omitted=[
        under_head,
        @common.Omission::new(
          feature="socket-lead-in-cone",
          reason="omitted at Simplified detail level; the rim is sharp",
        ),
        @common.Omission::new(
          feature="socket-floor-cone",
          reason="omitted at Simplified detail level; the floor is flat",
        ),
      ],
    )
  }
  let with_chamfers = if policy.include_small_features {
    base.add_modeled("head-chamfer").add_modeled("shank-tip-chamfer")
  } else {
    base
    .add_omitted(
      @common.Omission::new(
        feature="head-chamfer",
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
