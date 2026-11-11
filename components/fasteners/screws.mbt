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
    description="Layered solid: plain shank and an analytic revolved head (cylindrical outside, conical top break, circular socket bore) plus a buried hexagon ring forming the six socket flats; the blind socket floor is the cup floor." +
      head_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )

  // Shank and thread representation. ISO 4762 measures the thread length from
  // the tip, so the thread occupies z = 0 .. thread_length and any plain shank
  // sits under the head. (An earlier build put the plain shank at the tip,
  // which left the nut of a bolted joint on an unthreaded length.)
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
  let mut component = if thread_rep is @common.ThreadRepresentation::Helical {
    let thread_length = spec.thread_length_mm
    let plain_length = length - thread_length
    let d3 = thread.external_minor_diameter_mm()
    let mut c = base
    c = c.add_layer(
      tip_chamfered_cylinder(d3, thread_length, tip_chamfer, segments~),
      name="thread-core",
      color=accent,
    )
    let ridge = external_thread_ridge(
      thread,
      thread_length,
      segments_per_turn=policy.segments_per_turn,
    )
    match ridge {
      Some(shape) =>
        c = c.add_layer(shape, name="helical-thread", color=thread_color)
      None => ()
    }
    if plain_length > 0.0 {
      c = c.add_layer(
        @cad.Cylinder::new(d, plain_length),
        name="plain-shank",
        color=metal,
        placement=@common.Placement::translation(0.0, 0.0, thread_length),
      )
    }
    c
  } else {
    base.add_layer(
      tip_chamfered_cylinder(d, length, tip_chamfer, segments~),
      name="shank",
      color=metal,
    )
  }

  // Head: one analytic revolved shell (cylindrical outside, conical top rim,
  // circular socket bore, planar base/annulus/floor) plus a hexagonal ring that
  // turns the circular bore into the hex socket. The outer head surface is
  // therefore a real CYLINDRICAL_SURFACE and its top break a real
  // CONICAL_SURFACE, never a 64-gon prism.
  let _ = segments
  let floor_height = k - t
  let af = dims.socket_across_flats_mm
  let socket_radius = af / Double::sqrt(3.0)
  let top_chamfer = if policy.include_small_features {
    head_chamfer_mm(dk, k, t)
  } else {
    0.0
  }
  let lead = if policy.include_small_features {
    socket_lead_in_chamfer_mm(af, t)
  } else {
    0.0
  }
  let head_shell = @cad.RevolvedProfile::cup(
    dk,
    k,
    socket_radius * 2.0,
    floor_height,
    top_chamfer~,
    bore_lead_in=lead,
  ).as_shape()
  component = component.add_layer(
    head_shell,
    name="head-shell",
    color=metal,
    placement=@common.Placement::translation(0.0, 0.0, length),
  )
  // The hex ring's outer hexagon is buried inside the head shell; only its
  // six inner flats are visible. Its outer circumradius is kept inside the
  // shell so no planar facet ever replaces the head cylinder.
  let outer_radius = if dk / 2.0 - top_chamfer - 0.1 > socket_radius + 0.05 {
    let target = socket_radius + 0.5 * af
    let cap = dk / 2.0 - top_chamfer - 0.1
    if target < cap {
      target
    } else {
      cap
    }
  } else {
    socket_radius + 0.05
  }
  let outer_af = outer_radius * Double::sqrt(3.0)
  let socket_ring = if lead > 0.0 {
    let hole = socket_lead_in_hole(af, lead)
    let hole_levels = socket_lead_in_hole_levels(0.0, t, lead)
    @cad.ChamferedPrism::new(
      hex_profile_across_flats(outer_af),
      [(0.0, 0.0), (t, 0.0)],
      hole~,
      hole_levels~,
    ).as_shape()
  } else {
    @cad.ExtrudedProfile::new(hex_profile_across_flats(outer_af), t, holes=[
      hex_hole_across_flats(af),
    ])
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
    " The head top edge, the socket rim, and the shank tip carry 45-degree chamfers (engineering defaults)."
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
      "head-outer-cylinder", "head-socket-bore-cylinder", "blind-hex-socket", "hex-socket-flats",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="under-head-radius",
        reason="ISO 4762 does not give a verified under-head radius for this builder; a typed omission rather than a guessed fillet",
      ),
    ],
  )
  let with_chamfers = if policy.include_small_features {
    base
    .add_modeled("head-chamfer")
    .add_modeled("socket-lead-in-chamfer")
    .add_modeled("shank-tip-chamfer")
    .add_approximated(
      @common.Approximation::new(
        feature="socket-lead-in-hex-facets",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the socket lead-in on the hex flats is a ruled hex taper; the circular bore lead-in is an analytic cone",
      ),
    )
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
