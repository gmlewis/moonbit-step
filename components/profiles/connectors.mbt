///|
/// with_extrusion_connectors attaches the four face-slot connectors, two end
/// datums, and a core-bore datum to a cut-to-length extrusion.
///
/// The section is centred on the XY origin and the length runs from `z = 0` to
/// `z = length`. A slot connector's axis is the outward face normal, which is
/// the insertion direction for a drop-in T-nut; sliding engagement runs along
/// the extrusion axis and is carried by `depth_mm`.
fn with_extrusion_connectors(
  component : @common.Component,
  width_mm : Double,
  height_mm : Double,
  length_mm : Double,
  slot_width_mm : Double,
  core_bore_mm : Double,
) -> @common.Component {
  let z_mid = length_mm / 2.0
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slot-x-plus",
      placement=@common.Placement::translation(width_mm / 2.0, 0.0, z_mid),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::ProfileSlot,
      diameter_mm=slot_width_mm,
      depth_mm=length_mm,
      description="slot on the +X face; axis is the outward normal",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slot-x-minus",
      placement=@common.Placement::translation(-width_mm / 2.0, 0.0, z_mid),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::ProfileSlot,
      diameter_mm=slot_width_mm,
      depth_mm=length_mm,
      description="slot on the -X face; axis is the outward normal",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slot-y-plus",
      placement=@common.Placement::translation(0.0, height_mm / 2.0, z_mid),
      axis=(0.0, 1.0, 0.0),
      kind=@common.MateKind::ProfileSlot,
      diameter_mm=slot_width_mm,
      depth_mm=length_mm,
      description="slot on the +Y face; axis is the outward normal",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slot-y-minus",
      placement=@common.Placement::translation(0.0, -height_mm / 2.0, z_mid),
      axis=(0.0, -1.0, 0.0),
      kind=@common.MateKind::ProfileSlot,
      diameter_mm=slot_width_mm,
      depth_mm=length_mm,
      description="slot on the -Y face; axis is the outward normal",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Datum,
      diameter_mm=if width_mm < height_mm { width_mm } else { height_mm },
      description="cut end at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      diameter_mm=if width_mm < height_mm { width_mm } else { height_mm },
      description="cut end at z = length",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "core-bore",
      placement=@common.Placement::translation(0.0, 0.0, z_mid),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=core_bore_mm,
      depth_mm=length_mm,
      description="central core bore; may be tapped or used for a rod",
    ),
  )
}
