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
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Layered solid: plain shank, head floor, blind hex socket. Socket represented by a ring with a through hex hole over a floor disc. No head chamfer is modeled." +
      thread_note(thread_rep),
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
  let k = dims.head_height_mm
  let t = dims.socket_depth_mm
  let dk = dims.head_diameter_mm
  let floor_height = k - t
  let segments = clamp_segments(policy.circle_segments)
  component = component.add_layer(
    @cad.Cylinder::new(dk, floor_height),
    name="head-floor",
    color=metal,
    placement=@common.Placement::translation(0.0, 0.0, length),
  )
  let socket_ring = @cad.ExtrudedProfile::new(
    circle_profile(dk, segments~),
    t,
    holes=[hex_hole_across_flats(dims.socket_across_flats_mm)],
  )
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
