///|
/// hex_nut builds an ISO 4032 hexagon regular nut.
///
/// The nut axis is +Z, its bearing face is `z = 0`, and one pair of flats is
/// normal to the X axis. The bore is a simple cylindrical hole in simplified
/// and detailed modes. With `ThreadRepresentation::Helical` the body is bored
/// at the major diameter and a swept helical ridge fills the ISO 68-1 internal
/// thread form inward to the minor diameter.
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
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Hexagon regular nut with a through bore. No washer-face chamfer is modeled." +
      thread_note(thread_rep),
  )
  if thread_rep is @common.ThreadRepresentation::Helical {
    let bore_d = d + 2.0 * spec.clearance_mm
    let body = @cad.ExtrudedProfile::new(outer, m, holes=[
      hole_profile(bore_d, segments~),
    ])
    let mut component = base.add_layer(body, name="body", color=metal)
    match
      internal_thread_ridge(
        thread,
        m,
        segments_per_turn=policy.segments_per_turn,
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
  } else {
    let bore_d = d + 2.0 * spec.clearance_mm
    let body = @cad.ExtrudedProfile::new(outer, m, holes=[
      hole_profile(bore_d, segments~),
    ])
    base.add_layer(body, name="body", color=metal)
  }
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
