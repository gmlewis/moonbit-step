///|
/// ISO 8752 dimension ratios, measured from the reference family's radial
/// geometry: outside diameter d, inside diameter 0.68 d (wall 0.16 d), and a
/// parallel-sided slot of width 0.18 d. ISO 8752 fixes d and the length; the
/// wall and slot depend on the rolled strip and are recorded engineering
/// defaults.
const SPRING_PIN_INNER_RATIO : Double = 0.68

///|
const SPRING_PIN_SLOT_RATIO : Double = 0.18

///|
/// iso8752_spring_pin builds an ISO 8752 slotted spring pin: a straight tube
/// with a full-length parallel-sided slot. The pin is centred on the origin
/// along Z.
pub fn iso8752_spring_pin(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let d = size.nominal_diameter_mm()
  if length_mm < 2.0 || length_mm > 200.0 {
    return Err(
      @common.SpecError::UnsupportedLength(
        "ISO 8752 \{size.designation()}: length \{length_mm} is outside 2..200 mm",
      ),
    )
  }
  let tube = @cad.SlitTube::new(
    outer_diameter_mm=d,
    inner_diameter_mm=SPRING_PIN_INNER_RATIO * d,
    length_mm~,
    slot_width_mm=SPRING_PIN_SLOT_RATIO * d,
  )
  let features = @common.FeatureRecord::new(
    modeled=[
      "slit-tube", "outer-cylinder", "inner-cylinder", "longitudinal-slot", "flat-ends",
    ],
    approximated=[
      @common.Approximation::new(
        feature="slot-width",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="parallel-sided slot of width 0.18 d, measured from the reference family; ISO 8752 does not fix it",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="end-chamfer",
        reason="ISO 8752 pins normally carry a chamfered end; a chamfer on the C-shaped slit section is not modeled yet, so the ends are square",
      ),
    ],
  )
  Ok(
    with_pin_connectors(
      @common.Component::new(
        name="ISO8752-\{size.designation()}x\{length_mm}",
        metadata=@common.Metadata::new(
          designation="ISO8752-\{size.designation()}x\{length_mm}",
          standard="ISO 8752:2009",
          family="slotted spring pin, heavy duty",
          size=size.designation(),
          length_mm~,
          source="ISO 8752:2009 d and length; internal diameter 0.68 d and slot 0.18 d measured from the reference family (engineering defaults)",
        ),
        description="Slotted spring pin: one closed solid, a straight tube with a full-length parallel-sided slot (outer and inner analytic cylinders, two slot-wall planes and two C-shaped end planes). The ends are square; the customary end chamfer is a typed omission.",
        features~,
      )
      .add_layer(tube.as_shape(), name="body", color~)
      .translate(z=-length_mm / 2.0),
      d,
      length_mm,
    ),
  )
}
