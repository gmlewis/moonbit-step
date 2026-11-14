///|
/// ChainSegmentSpec describes a roller-chain segment layout envelope.
///
/// The default values reproduce the CC0 Innerscene ANSI #40 10-pitch reference:
/// pitch 12.7 mm, roller 7.92 mm, roller bore 4.06 mm, pin 3.96 mm, plate
/// thickness 1.5 mm, plate end radius 6 mm, and a 4.04 mm plate hole. The
/// reference is a layout model: both plate rows sit at the same axial offset and
/// the plates overlap like the reference, so this is not a functional chain.
pub(all) struct ChainSegmentSpec {
  pitch_mm : Double
  pitches : Int32
  roller_diameter_mm : Double
  roller_bore_mm : Double
  roller_length_mm : Double
  pin_diameter_mm : Double
  pin_length_mm : Double
  plate_thickness_mm : Double
  plate_end_radius_mm : Double
  plate_hole_diameter_mm : Double
  plate_center_z_mm : Double
}

///|
/// chain_segment_spec validates a roller-chain segment specification.
pub fn chain_segment_spec(
  pitch_mm~ : Double,
  pitches~ : Int32,
  roller_diameter_mm~ : Double = 7.92,
  roller_bore_mm~ : Double = 4.06,
  roller_length_mm~ : Double = 7.87,
  pin_diameter_mm~ : Double = 3.96,
  pin_length_mm~ : Double = 14.27,
  plate_thickness_mm~ : Double = 1.5,
  plate_end_radius_mm~ : Double = 6.0,
  plate_hole_diameter_mm~ : Double = 4.04,
  plate_center_z_mm~ : Double = 4.725,
) -> Result[ChainSegmentSpec, @common.SpecError] {
  match
    mechanism_checks([
      ("chain pitch", pitch_mm),
      ("chain roller diameter", roller_diameter_mm),
      ("chain roller bore", roller_bore_mm),
      ("chain roller length", roller_length_mm),
      ("chain pin diameter", pin_diameter_mm),
      ("chain pin length", pin_length_mm),
      ("chain plate thickness", plate_thickness_mm),
      ("chain plate end radius", plate_end_radius_mm),
      ("chain plate hole diameter", plate_hole_diameter_mm),
      ("chain plate centre offset", plate_center_z_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if pitches < 1 {
    return Err(
      @common.InvalidParameter("chain segment needs at least one pitch"),
    )
  }
  if pin_diameter_mm >= roller_bore_mm {
    return Err(
      @common.InvalidDimension("chain pin must be smaller than the roller bore"),
    )
  }
  if roller_bore_mm >= roller_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "chain roller bore must be smaller than its diameter",
      ),
    )
  }
  if plate_hole_diameter_mm <= pin_diameter_mm {
    return Err(
      @common.InvalidDimension("chain plate hole must be larger than the pin"),
    )
  }
  if plate_end_radius_mm <= roller_diameter_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "chain plate end radius must exceed the roller radius",
      ),
    )
  }
  if plate_center_z_mm <= plate_thickness_mm / 2.0 {
    return Err(
      @common.InvalidDimension("chain plate centre offset is too small"),
    )
  }
  Ok({
    pitch_mm,
    pitches,
    roller_diameter_mm,
    roller_bore_mm,
    roller_length_mm,
    pin_diameter_mm,
    pin_length_mm,
    plate_thickness_mm,
    plate_end_radius_mm,
    plate_hole_diameter_mm,
    plate_center_z_mm,
  })
}

///|
/// ansi40_chain_segment_spec returns the CC0-reference-calibrated ANSI #40 spec.
pub fn ansi40_chain_segment_spec(
  pitches : Int32,
) -> Result[ChainSegmentSpec, @common.SpecError] {
  chain_segment_spec(pitch_mm=12.7, pitches~)
}

///|
/// roller_chain_segment builds a roller-chain segment layout envelope.
///
/// Frame: the chain runs along +X; rollers and pins are coaxial along Z; the
/// two plate rows are at `+/- plate_center_z` and are `plate_thickness` thick.
/// There are `pitches + 1` pins and rollers and `pitches` plate pairs.
///
/// The reference is a layout model: the plates overlap like the reference and
/// the two rows use the same axial offset, so this is not a functional chain.
/// No tensile strength, fatigue, or wear rating is implied.
pub fn roller_chain_segment(
  spec : ChainSegmentSpec,
) -> Result[@common.Component, @common.SpecError] {
  let pitch = spec.pitch_mm
  let plate_radius = spec.plate_end_radius_mm
  let hole_radius = spec.plate_hole_diameter_mm / 2.0
  let plate_loop = stadium_loop(pitch / 2.0, plate_radius)
  let holes = [
    circle_loop(-pitch / 2.0, 0.0, hole_radius),
    circle_loop(pitch / 2.0, 0.0, hole_radius),
  ]
  let plate = @cad.ExtrudedArcProfile::new(
    plate_loop,
    spec.plate_thickness_mm,
    holes~,
  )
  if !plate.validate() {
    return Err(
      @common.InvalidParameter("chain plate did not form a valid profile"),
    )
  }
  let plate_shape = plate.as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["plates", "rollers", "pins"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="functional-chain-assembly",
        reason="the reference and this envelope are layout models; the plate rows overlap and no articulation or strength is modelled",
      ),
      @common.Omission::new(
        feature="chain-tensile-strength-and-wear",
        reason="no load, fatigue, or wear rating is implied",
      ),
    ],
  )
  let name = "chain-p\{@cad.fmt_double(pitch, None)}-\{spec.pitches}p"
  let total_pins = spec.pitches + 1
  let length = pitch * spec.pitches.to_double()
  let mut out = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Roller-chain segment p\{@cad.fmt_double(pitch, None)} \{spec.pitches} pitches",
      standard="ANSI #40 / ISO 606 (layout reference)",
      family="roller-chain segment (layout envelope)",
      size="\{spec.pitches}p",
      source="Measured CC0 Innerscene ANSI #40 10-pitch chain segment re-encoded as original parametric plates, rollers, and pins. Layout model only.",
    ),
    description="Roller-chain segment layout envelope with plates, rollers, and pins. The plate rows overlap like the reference; no articulation or strength is modelled.",
    features~,
  )
  for i in 0..<spec.pitches {
    let center_x = pitch * i.to_double() + pitch / 2.0
    out = out
      .add_layer(
        plate_shape,
        name="plate-\{i + 1}-negative",
        color=@cad.Rgb::grey(),
        placement=@common.Placement::translation(
          center_x,
          0.0,
          -spec.plate_center_z_mm - spec.plate_thickness_mm / 2.0,
        ),
      )
      .add_layer(
        plate_shape,
        name="plate-\{i + 1}-positive",
        color=@cad.Rgb::grey(),
        placement=@common.Placement::translation(
          center_x,
          0.0,
          spec.plate_center_z_mm - spec.plate_thickness_mm / 2.0,
        ),
      )
  }
  for i in 0..<total_pins {
    let x = pitch * i.to_double()
    out = out
      .add_layer(
        mechanism_tube_z(
          spec.roller_diameter_mm,
          spec.roller_bore_mm,
          spec.roller_length_mm,
        ),
        name="roller-\{i + 1}",
        color=@cad.Rgb::orange(),
        placement=@common.Placement::translation(
          x,
          0.0,
          -spec.roller_length_mm / 2.0,
        ),
      )
      .add_layer(
        mechanism_cylinder_z(spec.pin_diameter_mm, spec.pin_length_mm),
        name="pin-\{i + 1}",
        color=@cad.Rgb::grey(),
        placement=@common.Placement::translation(
          x,
          0.0,
          -spec.pin_length_mm / 2.0,
        ),
      )
  }
  out = out
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=spec.pin_diameter_mm,
        depth_mm=spec.pin_length_mm,
        description="first pin axis along +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-b",
        placement=@common.Placement::translation(length, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=spec.pin_diameter_mm,
        depth_mm=spec.pin_length_mm,
        description="last pin axis along +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pitch-line",
        placement=@common.Placement::translation(length / 2.0, 0.0, 0.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=spec.roller_diameter_mm,
        depth_mm=length,
        description="chain pitch line along +X",
      ),
    )
  Ok(out)
}

///|
/// ansi40_chain_segment builds an ANSI #40 chain segment with the reference
/// layout parameters.
pub fn ansi40_chain_segment(
  pitches : Int32,
) -> Result[@common.Component, @common.SpecError] {
  match ansi40_chain_segment_spec(pitches) {
    Err(e) => Err(e)
    Ok(spec) => roller_chain_segment(spec)
  }
}
