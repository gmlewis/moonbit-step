///|
/// din976_rod builds a DIN 976-1 metric threaded rod.
///
/// Axis +Z, origin at one end. In simplified and detailed modes the rod is a
/// plain nominal-diameter cylinder; `FullyModeled` uses a minor-diameter core
/// plus a swept helical ridge over the full length.
pub fn din976_rod(
  spec : @standards.DIN976Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread_rep = match threads {
    Some(t) => t
    None => policy.threads
  }
  let thread = spec.thread
  let d = thread.nominal_diameter_mm
  let length = spec.length_mm
  let segments = clamp_segments(policy.circle_segments)
  let name = "DIN976-\{thread.size.designation()}x\{format_length(length)}"
  let features = din976_feature_record(policy, thread_rep, thread, segments)
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Metric threaded rod; no plain end sections are modeled." +
      din976_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )
  let lead = if policy.include_small_features {
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
    let mut component = base.add_layer(
      chamfered_cylinder_ends(d3, length, lead, lead, segments~),
      name="thread-core",
      color=@cad.Rgb::orange(),
    )
    match
      external_thread_ridge(
        thread,
        length,
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
    component
  } else {
    base.add_layer(
      chamfered_cylinder_ends(d, length, lead, lead, segments~),
      name="rod",
      color=@cad.Rgb::orange(),
    )
  }
}

///|
fn din976_chamfer_note(policy : @common.DetailPolicy) -> String {
  if policy.include_small_features {
    " Both ends carry 45-degree engineering lead-in chamfers; this is not a standards-defined thread runout."
  } else {
    " End chamfers are omitted at this detail level; the ends are square."
  }
}

///|
/// din976_feature_record builds the machine-readable feature record for a
/// DIN 976-1 threaded rod.
fn din976_feature_record(
  policy : @common.DetailPolicy,
  thread_rep : @common.ThreadRepresentation,
  thread : @standards.ThreadSpec,
  segments : Int32,
) -> @common.FeatureRecord {
  let base = @common.FeatureRecord::new(
    modeled=["rod-envelope"],
    approximated=[
      polyline_circle_approximation(
        "rod-envelope-circle",
        thread.nominal_diameter_mm / 2.0,
        segments,
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="thread-runout",
        reason="no standards-defined runout is modeled; the ends carry an engineering lead-in chamfer only",
      ),
    ],
  )
  let with_lead_in = if policy.include_small_features {
    base.add_modeled("thread-lead-in-chamfer")
  } else {
    base.add_omitted(
      @common.Omission::new(
        feature="thread-lead-in-chamfer",
        reason="omitted at Simplified detail level; the ends are square",
      ),
    )
  }
  fastener_thread_features(
    with_lead_in,
    thread_rep,
    policy,
    thread.pitch_diameter_mm() / 2.0,
  )
}

///|
/// din976 validates a request and builds the component.
pub fn din976(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din976_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) =>
      Ok(
        match threads {
          Some(t) => din976_rod(spec, detail~, threads=t)
          None => din976_rod(spec, detail~)
        },
      )
  }
}
