///|
/// with_gear_connectors attaches a bore (when present), a pitch-plane datum, and
/// two face frames to a spur gear.
fn with_gear_connectors(
  component : @common.Component,
  bore_diameter_mm : Double,
  pitch_diameter_mm : Double,
  outer_diameter_mm : Double,
  face_width_mm : Double,
  base_z_mm~ : Double = 0.0,
) -> @common.Component {
  let top_z = base_z_mm + face_width_mm
  let with_bore = if bore_diameter_mm > 0.0 {
    component.with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, base_z_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=face_width_mm,
        description="central bore, entered from the negative-Z face",
      ),
    )
  } else {
    component
  }
  with_bore
  .with_connector_unchecked(
    @common.MateConnector::new(
      "pitch-plane",
      placement=@common.Placement::translation(
        0.0,
        0.0,
        base_z_mm + face_width_mm / 2.0,
      ),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      diameter_mm=pitch_diameter_mm,
      description="pitch-circle datum at the mid-plane",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-negative",
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="face at the negative-Z end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-positive",
      placement=@common.Placement::translation(0.0, 0.0, top_z),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="face at the positive-Z end",
    ),
  )
}
