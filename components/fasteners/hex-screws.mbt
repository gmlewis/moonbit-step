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
  let k = dims.head_height_reference_mm
  let s = dims.width_across_flats_mm
  let head_color = @cad.Rgb::blue()
  let shank_color = @cad.Rgb::orange()
  let thread_color = @cad.Rgb::cyan()
  let segments = clamp_segments(policy.circle_segments)
  let features = hex_head_feature_record(policy, threads, thread, s)
  let base = @common.Component::new(name~, metadata~, description~, features~)
  let tip_chamfer = if policy.include_small_features {
    let raw = shank_tip_chamfer_mm(d)
    if raw < length_mm / 4.0 {
      raw
    } else {
      length_mm / 4.0
    }
  } else {
    0.0
  }
  // ISO 4014 measures the thread length b from the tip, so the thread occupies
  // z = 0 .. thread_length and any plain shank is under the head.
  let mut component = if threads is @common.ThreadRepresentation::Helical {
    let plain_length = length_mm - thread_length_mm
    let d3 = thread.external_minor_diameter_mm()
    let mut c = base
    c = c.add_layer(
      tip_chamfered_cylinder(d3, thread_length_mm, tip_chamfer, segments~),
      name="thread-core",
      color=shank_color,
    )
    match
      external_thread_ridge(
        thread,
        thread_length_mm,
        segments_per_turn=policy.segments_per_turn,
      ) {
      Some(shape) =>
        c = c.add_layer(shape, name="helical-thread", color=thread_color)
      None => ()
    }
    if plain_length > 0.0 {
      c = c.add_layer(
        @cad.Cylinder::new(d, plain_length),
        name="plain-shank",
        color=shank_color,
        placement=@common.Placement::translation(0.0, 0.0, thread_length_mm),
      )
    }
    c
  } else {
    // Without modeled threads the shank uses the ISO 68-1 basic internal
    // minor diameter D1 (the table "minor diameter"), matching the downloaded
    // hexagon-head goldens.
    base.add_layer(
      tip_chamfered_cylinder(
        thread.internal_minor_diameter_mm(),
        length_mm,
        tip_chamfer,
        segments~,
      ),
      name="shank",
      color=shank_color,
    )
  }
  // Clean chamfered hex head. The exact conical washer face and pcurve support
  // live in cad/hex-head-pcurves.mbt; SolidCraft's importer still rejects the
  // conic/pcurve associations, so the shipping build uses the ruled
  // washer-face approximation.
  let inset = hex_head_chamfer_mm(s, k)
  let depth = inset / @math.tan(75.0 * @math.PI / 180.0)
  let head = @cad.ChamferedPrism::from_chamfer(
    hex_profile_across_flats(s),
    k,
    top_chamfer=inset,
    chamfer_depth=depth,
  ).as_shape()
  component = component.add_layer(
    head,
    name="hex-head",
    color=head_color,
    placement=@common.Placement::translation(0.0, 0.0, length_mm),
  )
  // Datum: head underside at z = 0, head +Z, shank -Z.
  component.translate(z=-length_mm)
}

///|
/// hex_head_feature_record builds the machine-readable feature record for an
/// ISO 4014 / ISO 4017 hexagon head screw or bolt.
fn hex_head_feature_record(
  policy : @common.DetailPolicy,
  threads : @common.ThreadRepresentation,
  thread : @standards.ThreadSpec,
  across_flats : Double,
) -> @common.FeatureRecord {
  let base = @common.FeatureRecord::new(
    modeled=["hex-head", "hex-body"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="under-head-radius",
        reason="no verified standard value; a typed omission rather than a guessed fillet",
      ),
    ],
  )
  let with_head = base.add_modeled("hex-head-chamfer")
  let with_chamfers = if policy.include_small_features {
    with_head.add_modeled("shank-tip-chamfer")
  } else {
    with_head.add_omitted(
      @common.Omission::new(
        feature="shank-tip-chamfer",
        reason="omitted at Simplified detail level",
      ),
    )
  }
  fastener_thread_features(
    with_chamfers,
    threads,
    policy,
    thread.pitch_diameter_mm() / 2.0,
  )
}

///|
/// iso4017_screw builds a fully threaded ISO 4017 hexagon head screw.
///
/// Axis +Z, origin at the head underside (bearing face); the hexagon head
/// occupies `z = 0 .. k` and the shank `z = -length .. 0`.
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
    "Hexagon head screw; layered body and head. Without modeled threads the shank uses the ISO 68-1 basic minor diameter D1. The head carries a 75-degree conical washer face with a circular top at every detail level; the shank tip break is added at Detailed and above." +
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
///
/// Axis +Z, origin at the head underside (bearing face); the hexagon head
/// occupies `z = 0 .. k` and the shank `z = -length .. 0`.
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
    "Hexagon head bolt; layered body and head. Without modeled threads the shank uses the ISO 68-1 basic minor diameter D1. The head carries a 75-degree conical washer face with a circular top at every detail level; the shank tip break is added at Detailed and above." +
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
