///|
/// HEX_HEAD_WASHER_FACE_INSET_MM and HEIGHT are the detailed ISO 4017 reference
/// under-head washer face: diameter `s - inset`, height 0.15 mm. ISO 4017 does
/// not fix these in the table used here; they reproduce the detailed reference.
const HEX_HEAD_WASHER_FACE_INSET_MM : Double = 1.12

///|
const HEX_HEAD_WASHER_FACE_HEIGHT_MM : Double = 0.15

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
  unified~ : Bool = false,
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
  let features = hex_head_feature_record(policy, threads, thread)
  let base = @common.Component::new(name~, metadata~, description~, features~)
  if unified && !(threads is @common.ThreadRepresentation::Helical) {
    // Reference representation: one closed solid combining the shank, the
    // under-head washer face, and the conical-washer-face hexagon head. The
    // detailed reference family uses a 65-degree face, a raised washer face,
    // the nominal shank diameter and a d/6 tip break; the simplified variant
    // uses the 75-degree face, no washer face, the ISO 68-1 minor-diameter
    // shank and a sharp tip.
    let detailed = policy.include_small_features
    let face_angle = if detailed { 65.0 } else { 75.0 }
    let washer_d = if detailed {
      s - HEX_HEAD_WASHER_FACE_INSET_MM
    } else {
      0.0
    }
    let washer_h = if detailed { HEX_HEAD_WASHER_FACE_HEIGHT_MM } else { 0.0 }
    let shank_d = if detailed { d } else { thread.internal_minor_diameter_mm() }
    let tip = if detailed { d / 6.0 } else { 0.0 }
    // The detailed reference uses the nominal head height, not the upper
    // standard limit the simple references use.
    let head_h = if detailed { dims.head_height_mm } else { k }
    let head = @cad.HexHeadWasherFace::new(
      across_flats_mm=s,
      head_height_mm=head_h,
      face_angle_deg=face_angle,
      shank_diameter_mm=shank_d,
      shank_length_mm=length_mm,
      washer_face_diameter_mm=washer_d,
      washer_face_height_mm=washer_h,
      tip_chamfer_mm=tip,
    ).as_shape()
    let unified_base = @common.Component::new(
      name~,
      metadata~,
      description="Single closed solid: a shank with a 45-degree tip break, an under-head washer face, and a hexagon head with a \{if detailed { "65" } else { "75" }}-degree conical washer face. The head, washer face and shank are one shell, not a layer stack." +
        thread_note(threads),
      features~,
    )
    return unified_base.add_layer(head, name="screw", color=head_color)
  }
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
  // Exact conical washer-face head with SURFACE_CURVE/pcurve associations.
  let head = @cad.HexHeadWasherFace::new(across_flats_mm=s, head_height_mm=k).as_shape()
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
  unified~ : Bool = false,
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
    unified~,
  )
}

///|
/// iso4017 validates a request and builds the component.
pub fn iso4017(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  unified~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4017_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) =>
      Ok(
        match threads {
          Some(t) => iso4017_screw(spec, detail~, threads=t, unified~)
          None => iso4017_screw(spec, detail~, unified~)
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
  unified~ : Bool = false,
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
    unified~,
  )
}

///|
/// iso4014 validates a request and builds the component.
pub fn iso4014(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  unified~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4014_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) =>
      Ok(
        match threads {
          Some(t) => iso4014_bolt(spec, detail~, threads=t, unified~)
          None => iso4014_bolt(spec, detail~, unified~)
        },
      )
  }
}
