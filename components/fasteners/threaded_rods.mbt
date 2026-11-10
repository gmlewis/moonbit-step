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
  let name = "DIN976-\{thread.size.designation()}x\{format_length(length)}"
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Metric threaded rod; no plain end sections are modeled." +
      thread_note(thread_rep),
  )
  if thread_rep is @common.ThreadRepresentation::Helical {
    let d3 = thread.external_minor_diameter_mm()
    let mut component = base.add_layer(
      @cad.Cylinder::new(d3, length),
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
      @cad.Cylinder::new(d, length),
      name="rod",
      color=@cad.Rgb::orange(),
    )
  }
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
