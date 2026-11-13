///|
/// with_plate_connectors attaches top and bottom face frames and one named bore
/// connector per plate hole.
///
/// The plate is centred on the XY origin with faces at `z = +/- thickness/2`,
/// matching `plate`'s documented frame.
fn with_plate_connectors(
  component : @common.Component,
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  holes : Array[PlateHole],
  slots : Array[PlateSlot],
) -> @common.Component {
  let half = thickness_mm / 2.0
  let face_size = if width_mm < height_mm { width_mm } else { height_mm }
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-top",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="top face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-bottom",
        placement=@common.Placement::translation(0.0, 0.0, -half),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="bottom face; outward normal is -Z",
      ),
    )
  for i, hole in holes {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "hole-\{i + 1}",
        placement=@common.Placement::translation(hole.x_mm, hole.y_mm, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=hole.diameter_mm,
        depth_mm=thickness_mm,
        description="through hole through the plate",
      ),
    )
  }
  for i, slot in slots {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "slot-\{i + 1}",
        placement=@common.Placement::translation(slot.x_mm, slot.y_mm, -half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=slot.width_mm,
        depth_mm=thickness_mm,
        description="obround through slot; long axis is +X",
      ),
    )
  }
  out
}

///|
/// with_angle_connectors attaches the two outer leg faces, two end datums, and
/// an inner-corner datum to an angle bar.
///
/// The outer corner is at `(0, 0, 0)`, legs run along +X and +Y, and the bar
/// runs from `z = 0` to `z = length`.
fn with_angle_connectors(
  component : @common.Component,
  section : AngleSection,
  length_mm : Double,
) -> @common.Component {
  let z_mid = length_mm / 2.0
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-outer-x",
      placement=@common.Placement::translation(
        0.0,
        section.leg_b_mm / 2.0,
        z_mid,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=section.leg_b_mm,
      description="outer face of the +Y leg; outward normal is -X",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-outer-y",
      placement=@common.Placement::translation(
        section.leg_a_mm / 2.0,
        0.0,
        z_mid,
      ),
      axis=(0.0, -1.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=section.leg_a_mm,
      description="outer face of the +X leg; outward normal is -Y",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Datum,
      description="cut end at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      description="cut end at z = length",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "inner-corner",
      placement=@common.Placement::translation(
        section.thickness_mm,
        section.thickness_mm,
        z_mid,
      ),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      description="inner corner of the two legs",
    ),
  )
}
