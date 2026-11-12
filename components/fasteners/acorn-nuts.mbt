///|
/// DIN 1587 dimension ratios recorded from the reference family. DIN 1587
/// fixes s, e, dk, h and m but not the cap's spherical radius or its wall; the
/// builder uses a spherical cap fitted to dk and h with a uniform 1.0 mm wall,
/// and the reference's 75-degree washer faces on both ends.
const ACORN_NUT_WALL_MM : Double = 1.0

///|
const ACORN_NUT_FACE_ANGLE_DEG : Double = 75.0

///|
/// din1587_acorn_nut builds a DIN 1587 hexagon domed cap nut.
///
/// The nut axis is +Z with the bearing face at `z = 0`. The hexagon body
/// carries a conical washer face on each end; the cap is a spherical dome whose
/// base circle is `dk` at the body top and whose apex reaches the standard
/// overall height `h`. Inside the cap a concentric spherical cavity leaves a
/// uniform `ACORN_NUT_WALL_MM` wall above the through bore.
pub fn din1587_acorn_nut(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Detailed,
  clearance_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @standards.din1587_spec(size, clearance_mm~) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let d = dims.thread.nominal_diameter_mm
      let bore_d = d + 2.0 * spec.clearance_mm
      let body = @cad.AcornNut::new(
        across_flats_mm=dims.width_across_flats_mm,
        body_height_mm=dims.body_height_mm,
        bore_diameter_mm=bore_d,
        total_height_mm=dims.overall_height_mm,
        dome_diameter_mm=dims.dome_diameter_mm,
        wall_mm=ACORN_NUT_WALL_MM,
        face_angle_deg=ACORN_NUT_FACE_ANGLE_DEG,
      ).as_shape()
      let features = @common.FeatureRecord::new(
        modeled=[
          "hexagon-body", "conical-washer-faces", "through-bore", "spherical-cap",
          "spherical-cavity",
        ],
        approximated=[
          @common.Approximation::new(
            feature="cap-radius",
            kind=@common.ApproximationKind::EngineeringDefault,
            deviation_mm=0.0,
            control="spherical cap fitted to dk at the body top and h at the apex; DIN 1587 does not fix the cap radius",
          ),
          @common.Approximation::new(
            feature="cap-wall",
            kind=@common.ApproximationKind::EngineeringDefault,
            deviation_mm=0.0,
            control="uniform 1.0 mm cap wall, taken from the reference family; DIN 1587 does not fix it",
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
        @common.Component::new(
          name="DIN1587-\{size.designation()}",
          metadata=@common.Metadata::new(
            designation=spec.designation(),
            standard=@standards.DIN1587Spec::standard(),
            family="hexagon domed cap nut",
            size=size.designation(),
            source=@standards.DIN1587Spec::source(),
          ),
          description="Hexagon domed cap nut: one closed solid with a hexagon body, a 75-degree conical washer face on each end, a circular through bore, and a spherical cap over a concentric spherical cavity.",
          features~,
        ).add_layer(body, name="body", color~),
      )
    }
  }
}
