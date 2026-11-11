///|
/// hex_nut builds an ISO 4032 hexagon regular nut.
///
/// The nut axis is +Z, its bearing face is `z = 0`, and one pair of flats is
/// normal to the X axis. The bore is a simple cylindrical hole in simplified
/// mode. At `Detailed` and above the body carries the customary chamfer on both
/// bearing faces (a parallel inset of the hexagon, built as a real ruled ring
/// stack). This chamfer is an engineering default derived from the nut size;
/// ISO 4032 does not fix its dimensions. With
/// `ThreadRepresentation::Helical` the body is bored at the major diameter and
/// a swept helical ridge fills the ISO 68-1 internal thread form inward to the
/// minor diameter; the helical body is not chamfered.
pub fn hex_nut(
  spec : @standards.ISO4032Spec,
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
  let s = dims.width_across_flats_mm
  let m = dims.height_mm
  let segments = clamp_segments(policy.circle_segments)
  let name = "ISO4032-\{dims.size.designation()}"
  let metal = match color {
    Some(c) => c
    None => @cad.Rgb::purple()
  }
  let accent = @cad.Rgb::cyan()
  let outer = hex_profile_across_flats(s)
  let bore_d = d + 2.0 * spec.clearance_mm
  // The bore is an analytic circular hole, not a sampled polygon.
  let round_bore = ((0.0, 0.0), bore_d)
  let features = nut_feature_record(
    policy, thread_rep, thread, bore_d, segments,
  )
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Hexagon regular nut with a through bore." +
      nut_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )
  if thread_rep is @common.ThreadRepresentation::Helical {
    let body = if policy.include_small_features {
      let c = nut_chamfer_mm(s, m)
      @cad.ChamferedPrism::new(
        outer,
        [(0.0, c), (c, 0.0), (m - c, 0.0), (m, c)],
        round_bore~,
      ).as_shape()
    } else {
      @cad.ChamferedPrism::new(outer, [(0.0, 0.0), (m, 0.0)], round_bore~).as_shape()
    }
    let mut component = base.add_layer(body, name="body", color=metal)
    match
      internal_thread_ridge(
        thread,
        m,
        segments_per_turn=policy.segments_per_turn,
        radial_offset_mm=spec.clearance_mm,
      ) {
      Some(shape) =>
        component = component.add_layer(
          shape,
          name="helical-thread",
          color=accent,
        )
      None => ()
    }
    component
  } else if policy.include_small_features {
    let c = nut_chamfer_mm(s, m)
    let depth = c
    let body = @cad.ChamferedPrism::new(
      outer,
      [(0.0, c), (depth, 0.0), (m - depth, 0.0), (m, c)],
      round_bore~,
    ).as_shape()
    base.add_layer(body, name="body", color=metal)
  } else {
    let body = @cad.ChamferedPrism::new(
      outer,
      [(0.0, 0.0), (m, 0.0)],
      round_bore~,
    ).as_shape()
    base.add_layer(body, name="body", color=metal)
  }
}

///|
/// nut_chamfer_mm returns the engineering-default face-chamfer inset for an
/// ISO 4032 nut. The standard does not fix the chamfer; this keeps it visible
/// and below a third of the nut height.
fn nut_chamfer_mm(s : Double, m : Double) -> Double {
  let by_width = 0.1 * s
  let by_height = m / 3.0
  if by_width < by_height {
    by_width
  } else {
    by_height
  }
}

///|
fn nut_chamfer_note(policy : @common.DetailPolicy) -> String {
  if policy.include_small_features {
    " Both bearing faces carry a 45-degree chamfer (engineering default, not a standard dimension)."
  } else {
    " Face chamfers are omitted in this detail level."
  }
}

///|
/// nut_feature_record builds the machine-readable feature record for an ISO
/// 4032 hexagon regular nut.
fn nut_feature_record(
  policy : @common.DetailPolicy,
  thread_rep : @common.ThreadRepresentation,
  thread : @standards.ThreadSpec,
  bore_d : Double,
  segments : Int32,
) -> @common.FeatureRecord {
  let _ = bore_d
  let _ = segments
  let base = @common.FeatureRecord::new(
    modeled=["hex-body", "through-bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="bore-edge-chamfer",
        reason="not modelled by this builder",
      ),
      @common.Omission::new(
        feature="thread-runout",
        reason="not modelled by this builder",
      ),
    ],
  )
  let with_chamfer = if policy.include_small_features {
    base.add_modeled("nut-face-chamfer")
  } else {
    base.add_omitted(
      @common.Omission::new(
        feature="nut-face-chamfer",
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

///|
/// iso4032_nut validates a request and builds the component.
pub fn iso4032_nut(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  clearance_mm~ : Double = 0.0,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4032_spec(size, clearance_mm~) {
    Err(e) => Err(e)
    Ok(spec) => {
      let component = match threads {
        Some(t) => hex_nut(spec, detail~, threads=t)
        None => hex_nut(spec, detail~)
      }
      Ok(component)
    }
  }
}
