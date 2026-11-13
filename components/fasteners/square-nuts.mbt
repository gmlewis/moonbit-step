///|
/// DIN 557 dimension ratios recorded from the reference family: the washer
/// face on the chamfered bearing face is a 75-degree cone. DIN 557 does not
/// fix the chamfer angle or its depth; both are engineering defaults.
const SQUARE_NUT_FACE_ANGLE_DEG : Double = 75.0

///|
/// din557_square_nut builds a DIN 557 square nut.
///
/// The nut axis is +Z with the flat bearing face at `z = 0`. The top face
/// carries the DIN 557 single conical washer face, trimmed by the four flats;
/// the bottom face stays flat, as the standard chamfers one face only.
pub fn din557_square_nut(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Detailed,
  clearance_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @standards.din557_spec(size, clearance_mm~) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let d = dims.thread.nominal_diameter_mm
      let bore_d = d + 2.0 * spec.clearance_mm
      let body = @cad.SquareNut::new(
        across_flats_mm=dims.width_across_flats_mm,
        height_mm=dims.height_mm,
        bore_diameter_mm=bore_d,
        face_angle_deg=SQUARE_NUT_FACE_ANGLE_DEG,
      ).as_shape()
      let features = @common.FeatureRecord::new(
        modeled=[
          "square-body", "conical-washer-face", "through-bore", "flat-bearing-face",
        ],
        approximated=[
          @common.Approximation::new(
            feature="washer-face-angle",
            kind=@common.ApproximationKind::EngineeringDefault,
            deviation_mm=0.0,
            control="75-degree conical washer face on the top bearing face, taken from the reference family; DIN 557 does not fix it",
          ),
        ],
        omitted=[
          @common.Omission::new(
            feature="thread",
            reason="the bore is the nominal thread envelope; the internal thread form is not modeled",
          ),
        ],
      )
      Ok(
        with_nut_connectors(
          @common.Component::new(
            name="DIN557-\{size.designation()}",
            metadata=@common.Metadata::new(
              designation=spec.designation(),
              standard=@standards.DIN557Spec::standard(),
              family="square nut",
              size=size.designation(),
              source=@standards.DIN557Spec::source(),
            ),
            description="Square nut: one closed solid with a square prism body, a 75-degree conical washer face on the top bearing face trimmed by the four flats, a flat bottom bearing face, and a circular through bore.",
            features~,
          ).add_layer(body, name="body", color~),
          d,
          dims.height_mm,
          dims.width_across_flats_mm,
        ),
      )
    }
  }
}
