///|
/// ExtrusionTNutSpec describes a generic hex-body T-nut for a T-slot
/// extrusion.
///
/// The body is a regular hexagon across flats, with a central through hole.
/// The `slot_width_mm` field records the slot series the nut is intended for;
/// it is an engagement check, not an additional body feature.
///
/// Dimensions are millimetres.
pub(all) struct ExtrusionTNutSpec {
  thread : String
  across_flats_mm : Double
  thickness_mm : Double
  hole_diameter_mm : Double
  slot_width_mm : Double
}

///|
/// extrusion_tnut_spec returns a T-nut envelope for a standard metric thread.
///
/// Body dimensions follow the step.parts extrusion-nut envelope:
/// M3 5.5 x 2.4, M4 7.0 x 3.2, M5 8.0 x 4.0 mm across flats and thickness.
/// The catalogue uses the same body for slide-in, drop-in, and hammer styles;
/// this builder therefore does not assert a style-specific retention feature.
pub fn extrusion_tnut_spec(
  thread : String,
  slot_width_mm~ : Double = 5.0,
) -> Result[ExtrusionTNutSpec, @common.SpecError] {
  let token = thread.trim().to_owned().to_upper()
  let (across_flats, thickness, hole) = match token {
    "M3" => (5.5, 2.4, 3.0)
    "M4" => (7.0, 3.2, 4.0)
    "M5" => (8.0, 4.0, 5.0)
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported extrusion T-nut thread: \{other}; supported: M3, M4, M5",
        ),
      )
  }
  let spec : ExtrusionTNutSpec = {
    thread: token,
    across_flats_mm: across_flats,
    thickness_mm: thickness,
    hole_diameter_mm: hole,
    slot_width_mm,
  }
  match validate_extrusion_tnut(spec) {
    Ok(_) => Ok(spec)
    Err(e) => Err(e)
  }
}

///|
/// validate_extrusion_tnut checks the body, hole, and slot engagement.
fn validate_extrusion_tnut(
  spec : ExtrusionTNutSpec,
) -> Result[Unit, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("T-nut across flats", spec.across_flats_mm),
    @common.require_positive("T-nut thickness", spec.thickness_mm),
    @common.require_positive("T-nut hole diameter", spec.hole_diameter_mm),
    @common.require_positive("T-nut slot width", spec.slot_width_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if spec.hole_diameter_mm >= spec.across_flats_mm {
    return Err(
      @common.InvalidDimension(
        "T-nut hole diameter must be smaller than the body",
      ),
    )
  }
  if spec.slot_width_mm >= spec.across_flats_mm {
    return Err(
      @common.InvalidParameter(
        "T-nut body across flats must exceed the slot width so it can engage the slot cavity",
      ),
    )
  }
  Ok(())
}

///|
/// extrusion_tnut builds a generic hex-body extrusion T-nut.
///
/// Geometry, axis +Z with the bearing face at `z = 0`:
/// - a regular hexagonal prism across flats;
/// - a central through hole at the nominal thread diameter.
///
/// The hole is the thread envelope, not a modeled helical thread. Spring balls,
/// style-specific retention features, and thread tolerance classes are omitted.
/// `detail` is accepted for API consistency; the envelope is identical at every
/// detail level.
pub fn extrusion_tnut(
  spec : ExtrusionTNutSpec,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match validate_extrusion_tnut(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let _ = detail
  let across_corners = spec.across_flats_mm / @math.cos(@math.PI / 6.0)
  let outer = @cad.Profile2D::polygon(6, across_corners)
  let body = @cad.ExtrudedProfile::new(
    outer,
    spec.thickness_mm,
    round_bore=((0.0, 0.0), spec.hole_diameter_mm),
  )
  let features = @common.FeatureRecord::new(
    modeled=["body", "hexagonal-prism", "through-hole"],
    omitted=[
      @common.Omission::new(
        feature="thread-helix",
        reason="the bore is the thread envelope, not a modeled helix",
      ),
      @common.Omission::new(
        feature="spring-ball",
        reason="retention hardware is not modelled",
      ),
      @common.Omission::new(
        feature="style-specific-retention",
        reason="the reference catalogue uses the same body for slide-in, drop-in, and hammer styles",
      ),
    ],
  )
  let name = "TNUT-\{spec.thread}-slot\{@cad.fmt_double(spec.slot_width_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Extrusion T-nut \{spec.thread}, slot \{@cad.fmt_double(spec.slot_width_mm, None)} mm",
        standard="generic extrusion T-nut envelope (step.parts dimensions)",
        family="extrusion T-nut",
        size=spec.thread,
        length_mm=spec.thickness_mm,
        material="steel (label only; not a structural claim)",
        source="Hex body across flats and thickness from the step.parts extrusion-nut envelope; slot width is an engagement parameter. All catalogue styles share this body.",
      ),
      description="Generic hex-body extrusion T-nut: regular hexagonal prism with a central thread-envelope hole. The reference catalogue uses the same body for slide-in, drop-in, and hammer styles, so no style-specific retention feature is claimed.",
      features~,
    ).add_layer(body, name="body", color~),
  )
}
