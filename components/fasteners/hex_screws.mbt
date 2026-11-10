///|
fn hex_head_shape(
  dims : @standards.HexHeadSize,
  length_mm : Double,
  thread_length_mm : Double,
  detail : @common.DetailLevel,
  threads : @common.ThreadRepresentation,
  name : String,
  metadata : @common.Metadata,
  description : String,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread = dims.thread
  let d = thread.nominal_diameter_mm
  let k = dims.head_height_mm
  let s = dims.width_across_flats_mm
  let head_color = @cad.Rgb::blue()
  let shank_color = @cad.Rgb::orange()
  let thread_color = @cad.Rgb::cyan()
  let base = @common.Component::new(name~, metadata~, description~)
  let mut component = if threads is @common.ThreadRepresentation::Helical {
    let plain_length = length_mm - thread_length_mm
    let mut c = base
    if plain_length > 0.0 {
      c = c.add_layer(
        @cad.Cylinder::new(d, plain_length),
        name="plain-shank",
        color=shank_color,
      )
    }
    let d3 = thread.external_minor_diameter_mm()
    c = c.add_layer(
      @cad.Cylinder::new(d3, thread_length_mm),
      name="thread-core",
      color=shank_color,
      placement=@common.Placement::translation(0.0, 0.0, plain_length),
    )
    match
      external_thread_ridge(
        thread,
        thread_length_mm,
        segments_per_turn=policy.segments_per_turn,
      ) {
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
    base.add_layer(
      @cad.Cylinder::new(d, length_mm),
      name="shank",
      color=shank_color,
    )
  }
  let head = @cad.ExtrudedProfile::new(hex_profile_across_flats(s), k)
  component = component.add_layer(
    head,
    name="hex-head",
    color=head_color,
    placement=@common.Placement::translation(0.0, 0.0, length_mm),
  )
  component
}

///|
/// iso4017_screw builds a fully threaded ISO 4017 hexagon head screw.
///
/// Axis +Z, origin at the free end of the shank; the hexagon head occupies
/// `z = length .. length + k`.
pub fn iso4017_screw(
  spec : @standards.ISO4017Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread_rep = match threads {
    Some(t) => t
    None => policy.threads
  }
  let dims = spec.size_dims
  let name = "ISO4017-\{dims.size.designation()}-\{format_length(spec.length_mm)}"
  hex_head_shape(
    dims,
    spec.length_mm,
    spec.length_mm,
    detail,
    thread_rep,
    name,
    spec.metadata(),
    "Hexagon head screw; layered body and head. Head edges are not chamfered." +
    thread_note(thread_rep),
  )
}

///|
/// iso4017 validates a request and builds the component.
pub fn iso4017(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4017_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) =>
      Ok(
        match threads {
          Some(t) => iso4017_screw(spec, detail~, threads=t)
          None => iso4017_screw(spec, detail~)
        },
      )
  }
}

///|
/// iso4014_bolt builds a partially threaded ISO 4014 hexagon head bolt.
pub fn iso4014_bolt(
  spec : @standards.ISO4014Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread_rep = match threads {
    Some(t) => t
    None => policy.threads
  }
  let dims = spec.size_dims
  let name = "ISO4014-\{dims.size.designation()}-\{format_length(spec.length_mm)}"
  hex_head_shape(
    dims,
    spec.length_mm,
    spec.thread_length_mm,
    detail,
    thread_rep,
    name,
    spec.metadata(),
    "Hexagon head bolt; layered body and head. Head edges are not chamfered." +
    thread_note(thread_rep),
  )
}

///|
/// iso4014 validates a request and builds the component.
pub fn iso4014(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4014_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) =>
      Ok(
        match threads {
          Some(t) => iso4014_bolt(spec, detail~, threads=t)
          None => iso4014_bolt(spec, detail~)
        },
      )
  }
}
