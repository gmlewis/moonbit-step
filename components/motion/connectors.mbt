///|
/// with_shaft_connectors attaches an end frame and a full-length shaft frame to
/// a cylindrical shaft whose axis is +Z.
///
/// `centered` selects ends at `+/- length/2`; otherwise the shaft runs from
/// `z = 0` to `z = length`.
fn with_shaft_connectors(
  component : @common.Component,
  diameter_mm : Double,
  length_mm : Double,
  centered~ : Bool = false,
) -> @common.Component {
  let z0 = if centered { -length_mm / 2.0 } else { 0.0 }
  let z1 = if centered { length_mm / 2.0 } else { length_mm }
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft-a",
      placement=@common.Placement::translation(0.0, 0.0, z0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="negative-Z shaft end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft-b",
      placement=@common.Placement::translation(0.0, 0.0, z1),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="positive-Z shaft end",
    ),
  )
}

///|
/// with_stepped_shaft_connectors attaches a shaft end frame at each end of a
/// stepped shaft, using the diameter that actually exists at that end.
fn with_stepped_shaft_connectors(
  component : @common.Component,
  base_diameter_mm : Double,
  top_diameter_mm : Double,
  total_length_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=base_diameter_mm,
      depth_mm=total_length_mm,
      description="base-end shaft diameter",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft-b",
      placement=@common.Placement::translation(0.0, 0.0, total_length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=top_diameter_mm,
      depth_mm=total_length_mm,
      description="top-end shaft diameter",
    ),
  )
}

///|
/// with_bushing_connectors attaches a bore, an outer seat, and two end faces to
/// a tube-like part whose axis is +Z.
///
/// `base_z_mm` is the negative-Z face. Bearings and bushings that are centred
/// on their own origin pass `base_z_mm = -width/2`; parts built from `z = 0`
/// keep the default.
fn with_bushing_connectors(
  component : @common.Component,
  inner_diameter_mm : Double,
  outer_diameter_mm : Double,
  length_mm : Double,
  base_z_mm~ : Double = 0.0,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore",
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=inner_diameter_mm,
      depth_mm=length_mm,
      description="running bore, entered from the negative-Z face",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "outer-seat",
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=outer_diameter_mm,
      depth_mm=length_mm,
      description="outer cylindrical seat for a housing bore",
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
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm + length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="face at the positive-Z end",
    ),
  )
}

///|
/// with_bore_and_faces attaches a bore and two end faces to a part whose outer
/// boundary is not cylindrical (for example a hex standoff).
fn with_bore_and_faces(
  component : @common.Component,
  inner_diameter_mm : Double,
  face_diameter_mm : Double,
  length_mm : Double,
  base_z_mm~ : Double = 0.0,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore",
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=inner_diameter_mm,
      depth_mm=length_mm,
      description="through bore, entered from the negative-Z face",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-negative",
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=face_diameter_mm,
      description="face at the negative-Z end",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-positive",
      placement=@common.Placement::translation(0.0, 0.0, base_z_mm + length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=face_diameter_mm,
      description="face at the positive-Z end",
    ),
  )
}

///|
/// with_spring_connectors attaches end datums to a compression spring that runs
/// from `z = 0` to `z = length_mm`.
fn with_spring_connectors(
  component : @common.Component,
  outer_diameter_mm : Double,
  length_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Datum,
      diameter_mm=outer_diameter_mm,
      description="negative-Z spring end datum",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      diameter_mm=outer_diameter_mm,
      description="positive-Z spring end datum",
    ),
  )
}
