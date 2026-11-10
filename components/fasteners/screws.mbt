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
  let accent = @cad.Rgb::orange()
  let thread_color = @cad.Rgb::cyan()
  let k = dims.head_height_mm
  let t = dims.socket_depth_mm
  let dk = dims.head_diameter_mm
  let segments = clamp_segments(policy.circle_segments)
  let features = screw_feature_record(policy, thread_rep, thread, dk, segments)
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Layered solid: plain shank, head floor, blind hex socket. Socket represented by a ring with a through hex hole over a floor disc." +
      head_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )

  // Shank and thread representation.
  let mut component = if thread_rep is @common.ThreadRepresentation::Helical {
    let thread_length = spec.thread_length_mm
    let plain_length = length - thread_length
    let mut c = base
    if plain_length > 0.0 {
      c = c.add_layer(
        @cad.Cylinder::new(d, plain_length),
        name="plain-shank",
        color=metal,
      )
    }
    let d3 = thread.external_minor_diameter_mm()
    let core = @cad.Cylinder::new(d3, thread_length)
    c = c.add_layer(
      core,
      name="thread-core",
      color=accent,
      placement=@common.Placement::translation(0.0, 0.0, plain_length),
    )
    let ridge = external_thread_ridge(
      thread,
      thread_length,
      segments_per_turn=policy.segments_per_turn,
    )
    match ridge {
      Some(shape) =>
        c.add_layer(
          shape,
          name="helical-thread",
          color=thread_color,
          placement=@common.Placement::translation(0.0, 0.0, plain_length),
        )
      None => c
    }
  } else {
    base.add_layer(@cad.Cylinder::new(d, length), name="shank", color=metal)
  }

  // Head: a solid floor disc plus a socket ring with a hexagonal through-hole.
  let floor_height = k - t
  component = component.add_layer(
    @cad.Cylinder::new(dk, floor_height),
    name="head-floor",
    color=metal,
    placement=@common.Placement::translation(0.0, 0.0, length),
  )
  let hex_hole = hex_hole_across_flats(dims.socket_across_flats_mm)
  let socket_ring = if policy.include_small_features {
    let c = head_chamfer_mm(dk, k, t)
    @cad.ChamferedPrism::new(
      circle_profile(dk, segments~),
      [(0.0, 0.0), (t - c, 0.0), (t, c)],
      hole=hex_hole,
    ).as_shape()
  } else {
    @cad.ExtrudedProfile::new(circle_profile(dk, segments~), t, holes=[hex_hole])
  }
  component = component.add_layer(
    socket_ring,
    name="head-socket",
    color=accent,
    placement=@common.Placement::translation(0.0, 0.0, length + floor_height),
  )
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
    " The head top edge carries a 45-degree chamfer (engineering default)."
  } else {
    " The head is sharp-edged at this detail level."
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
  let base = @common.FeatureRecord::new(
    modeled=["head-floor", "blind-hex-socket"],
    approximated=[
      @common.Approximation::new(
        feature="head-socket-band",
        kind=@common.ApproximationKind::PolygonRevolve,
        deviation_mm=@common.chord_deviation(dk / 2.0, segments),
        control="circle_segments=\{segments}",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="shank-tip-chamfer",
        reason="not modelled by this builder",
      ),
      @common.Omission::new(
        feature="under-head-radius",
        reason="not modelled by this builder",
      ),
      @common.Omission::new(
        feature="socket-lead-in-chamfer",
        reason="not modelled by this builder",
      ),
    ],
  )
  let with_chamfer = if policy.include_small_features {
    base.add_modeled("head-chamfer")
  } else {
    base.add_omitted(
      @common.Omission::new(
        feature="head-chamfer",
        reason="omitted at Simplified detail level",
      ),
    )
  }
  fastener_thread_features(
    with_chamfer,
    thread_rep,
    policy,
    thread.pitch_diameter_mm() / 2.0,
  )
}
