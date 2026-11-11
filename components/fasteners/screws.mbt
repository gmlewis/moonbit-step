///|
/// socket_head_cap_screw builds an ISO 4762 hexagon socket head cap screw.
///
/// The screw axis is +Z with the origin at the free end of the shank. The head
/// occupies `z = length .. length + k`. This is a right-handed component and
/// is intended to be inserted along +Z.
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
    description="Single closed solid: a solid of revolution (tip break, shank, head underside, head cylinder, conical head top break) with a blind hexagonal socket cut into the head top; six planar socket walls and a planar hexagonal floor bound the pocket." +
      head_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )

  // One solid of revolution: tip, shank (or thread core plus plain shank),
  // head underside, head outside, and the conical head-top break. ISO 4762
  // measures the thread length from the tip, so the thread occupies
  // z = 0 .. thread_length and any plain shank sits under the head.
  let tip_chamfer = if policy.include_small_features {
    let raw = shank_tip_chamfer_mm(d)
    if raw < length / 4.0 {
      raw
    } else {
      length / 4.0
    }
  } else {
    0.0
  }
  let top_chamfer = if policy.include_small_features {
    head_chamfer_mm(dk, k, t)
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
  pts.push((dk / 2.0, length))
  if top_chamfer > 0.0 && top_chamfer < dk / 2.0 {
    pts.push((dk / 2.0, length + k - top_chamfer))
    pts.push((dk / 2.0 - top_chamfer, length + k))
  } else {
    pts.push((dk / 2.0, length + k))
  }
  pts.push((0.0, length + k))
  let body = @cad.RevolvedProfile::polyline(pts)
  // The blind hex socket is a real pocket in the same closed shell: the body's
  // flat top cap is replaced by an annular top face, six planar walls, and a
  // planar hexagonal floor.
  let af = dims.socket_across_flats_mm
  let floor_height = k - t
  let socket = @cad.SocketedSolid::new(body, af, length + floor_height)
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
  component
}

///|
/// iso4762_screw validates a request and builds the component.
pub fn iso4762_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4762_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => {
      let component = match threads {
        Some(t) => socket_head_cap_screw(spec, detail~, threads=t)
        None => socket_head_cap_screw(spec, detail~)
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
/// head_chamfer_mm returns the engineering-default top-edge chamfer inset for a
/// socket head cap screw. ISO 4762 does not fix the head chamfer; this keeps it
/// below a third of the head height and half the socket depth.
fn head_chamfer_mm(dk : Double, k : Double, t : Double) -> Double {
  let mut c = 0.1 * dk
  if c > k / 3.0 {
    c = k / 3.0
  }
  if c > t / 2.0 {
    c = t / 2.0
  }
  c
}

///|
fn head_chamfer_note(policy : @common.DetailPolicy) -> String {
  if policy.include_small_features {
    " The head top edge and the shank tip carry 45-degree conical chamfers (engineering defaults); the socket rim and floor are sharp and flat."
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
  let base = @common.FeatureRecord::new(
    modeled=[
      "head-outer-cylinder", "blind-hex-socket", "hex-socket-flats", "socket-floor-plane",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="under-head-radius",
        reason="ISO 4762 does not give a verified under-head radius for this builder; a typed omission rather than a guessed fillet",
      ),
      @common.Omission::new(
        feature="socket-lead-in-cone",
        reason="the golden drills a 45-degree conical countersink at the socket rim; a true trimmed cone needs hyperbola-bounded cone faces, and a ruled hex flare would misstate the shape, so the rim is sharp",
      ),
      @common.Omission::new(
        feature="socket-floor-cone",
        reason="the golden socket bottom is a shallow conical drill point; this builder emits a flat floor rather than an unverified cone",
      ),
    ],
  )
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
