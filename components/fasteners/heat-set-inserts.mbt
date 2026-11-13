///|
/// HeatSetInsertSpec describes a heat-set threaded insert for printed parts.
///
/// The insert is a body of revolution: a plain outer cylinder with two raised
/// knurl bands, an optional top relief, and a through bore. Knurl bands are
/// cylindrical reliefs in this envelope, not a modeled diamond knurl.
///
/// Dimensions are millimetres. The insert axis is +Z with the bottom face at
/// `z = 0`.
pub(all) struct HeatSetInsertSpec {
  thread : String
  length_mm : Double
  body_diameter_mm : Double
  knurl_diameter_mm : Double
  bore_diameter_mm : Double
}

///|
/// heat_set_insert_m3_spec returns the short or long M3 heat-set insert.
///
/// The step.parts M3 references have a 6.0 mm body, a 6.48 mm knurl diameter,
/// and a 2.25 mm through bore. The knurl bands occupy 20-32% and 68-80% of the
/// length; the short and long lengths are 6.0 and 10.5 mm.
pub fn heat_set_insert_m3_spec(
  length_kind : String,
) -> Result[HeatSetInsertSpec, @common.SpecError] {
  let token = length_kind.trim().to_owned().to_lower()
  let length = match token {
    "short" | "s" => 6.0
    "long" | "l" => 10.5
    other =>
      return Err(
        @common.InvalidParameter(
          "unknown M3 heat-set insert length '\{other}'; use short or long",
        ),
      )
  }
  let spec : HeatSetInsertSpec = {
    thread: "M3",
    length_mm: length,
    body_diameter_mm: 6.0,
    knurl_diameter_mm: 6.48,
    bore_diameter_mm: 2.25,
  }
  match validate_heat_set_insert(spec) {
    Ok(_) => Ok(spec)
    Err(e) => Err(e)
  }
}

///|
/// validate_heat_set_insert checks the radial order and knurl-band fit.
fn validate_heat_set_insert(
  spec : HeatSetInsertSpec,
) -> Result[Unit, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("heat-set insert length", spec.length_mm),
    @common.require_positive("heat-set body diameter", spec.body_diameter_mm),
    @common.require_positive("heat-set knurl diameter", spec.knurl_diameter_mm),
    @common.require_positive("heat-set bore diameter", spec.bore_diameter_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if spec.bore_diameter_mm >= spec.body_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "heat-set bore diameter must be smaller than the body diameter",
      ),
    )
  }
  if spec.knurl_diameter_mm <= spec.body_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "heat-set knurl diameter must exceed the body diameter",
      ),
    )
  }
  if spec.length_mm < 0.5 {
    return Err(
      @common.InvalidDimension(
        "heat-set insert is too short for the knurl bands",
      ),
    )
  }
  Ok(())
}

///|
/// heat_set_insert builds a heat-set threaded-insert envelope.
///
/// The profile is a solid of revolution: a plain body, two raised cylindrical
/// knurl bands, and a through bore. It is not a thread and does not claim a
/// pull-out strength.
pub fn heat_set_insert(
  spec : HeatSetInsertSpec,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match validate_heat_set_insert(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let r_bore = spec.bore_diameter_mm / 2.0
  let r_body = spec.body_diameter_mm / 2.0
  let r_knurl = spec.knurl_diameter_mm / 2.0
  let length = spec.length_mm
  let band1_start = 0.2 * length
  let band1_end = 0.32 * length
  let band2_start = 0.68 * length
  let band2_end = 0.8 * length
  let points : Array[@cad.Vec2] = [
    (r_bore, 0.0),
    (r_body, 0.0),
    (r_body, band1_start),
    (r_knurl, band1_start),
    (r_knurl, band1_end),
    (r_body, band1_end),
    (r_body, band2_start),
    (r_knurl, band2_start),
    (r_knurl, band2_end),
    (r_body, band2_end),
    (r_body, length),
    (r_bore, length),
  ]
  let body = @cad.RevolvedProfile::polyline(points.rev(), closed=true).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "through-bore", "two-knurl-bands"],
    omitted=[
      @common.Omission::new(
        feature="thread-helix",
        reason="the bore is the thread envelope, not a modeled helix",
      ),
      @common.Omission::new(
        feature="diamond-knurl",
        reason="the knurl is represented by raised cylindrical bands",
      ),
      @common.Omission::new(
        feature="installation-strength",
        reason="pull-out and torque strength require testing, not geometry",
      ),
    ],
  )
  let name = "HEATSET-\{spec.thread}-\{@cad.fmt_double(length, None)}"
  Ok(
    with_insert_connectors(
      @common.Component::new(
        name~,
        metadata=@common.Metadata::new(
          designation="Heat-set insert \{spec.thread}, \{@cad.fmt_double(length, None)} mm",
          standard="generic heat-set insert envelope (step.parts dimensions)",
          family="heat-set threaded insert",
          size=spec.thread,
          length_mm=length,
          material="brass (label only; not a strength claim)",
          source="Step.parts M3 short and long heat-set insert envelopes: 6.0 mm body, 6.48 mm knurl, 2.25 mm bore, knurl bands at 20-32% and 68-80% of length.",
        ),
        description="Heat-set threaded-insert envelope: plain body with two raised cylindrical knurl bands and a through bore. The bore is a thread envelope; diamond knurl and pull-out strength are not modeled.",
        features~,
      ).add_layer(body, name="body", color~),
      spec.thread,
      length,
      spec.body_diameter_mm,
    ),
  )
}

///|
/// heat_set_insert_m3 builds the short or long M3 insert directly.
pub fn heat_set_insert_m3(
  length_kind : String,
) -> Result[@common.Component, @common.SpecError] {
  match heat_set_insert_m3_spec(length_kind) {
    Ok(spec) => heat_set_insert(spec)
    Err(e) => Err(e)
  }
}
