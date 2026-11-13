///|
/// with_vslot_connectors attaches the V-Slot mating interfaces:
///
/// - one `slot-*` connector per open slot, with its axis on the outward face
///   normal (the insertion direction for a drop-in T-nut);
/// - `end-a` and `end-b` cut-end datums;
/// - one `core-bore-*` connector per 4.2 mm core bore;
/// - `center-channel` for the central channel of a two-cell section.
///
/// The section is centred on the XY origin and runs from `z = 0` to
/// `z = length`. Adding these connectors never changes the exported geometry.
fn with_vslot_connectors(
  component : @common.Component,
  profile : VSlotProfile,
  length_mm : Double,
) -> @common.Component {
  let hw = profile.width_mm / 2.0
  let hh = profile.height_mm / 2.0
  let z_mid = length_mm / 2.0
  let side_centres = profile.cell_centres()
  let mut out = component
  // End face slots.
  out = out
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-y-plus",
        placement=@common.Placement::translation(0.0, hh, z_mid),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=profile.slot_neck_mm,
        depth_mm=length_mm,
        description="slot on the +Y end face; axis is the outward normal",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-y-minus",
        placement=@common.Placement::translation(0.0, -hh, z_mid),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=profile.slot_neck_mm,
        depth_mm=length_mm,
        description="slot on the -Y end face; axis is the outward normal",
      ),
    )
  // Long-face slots: one per cell on each side.
  let multi = side_centres.length() > 1
  for i, y in side_centres {
    let suffix = if multi { "-\{i + 1}" } else { "" }
    out = out
      .with_connector_unchecked(
        @common.MateConnector::new(
          "slot-x-plus\{suffix}",
          placement=@common.Placement::translation(hw, y, z_mid),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::ProfileSlot,
          diameter_mm=profile.slot_neck_mm,
          depth_mm=length_mm,
          description="slot on the +X long face; axis is the outward normal",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "slot-x-minus\{suffix}",
          placement=@common.Placement::translation(-hw, y, z_mid),
          axis=(-1.0, 0.0, 0.0),
          kind=@common.MateKind::ProfileSlot,
          diameter_mm=profile.slot_neck_mm,
          depth_mm=length_mm,
          description="slot on the -X long face; axis is the outward normal",
        ),
      )
  }
  out = out
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=profile.width_mm,
        description="cut end at z = 0",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=profile.width_mm,
        description="cut end at z = length",
      ),
    )
  let bores = profile.cell_centres()
  for i, y in bores {
    let name = if bores.length() > 1 {
      "core-bore-\{i + 1}"
    } else {
      "core-bore"
    }
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        name,
        placement=@common.Placement::translation(0.0, y, z_mid),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=profile.core_bore_diameter_mm,
        depth_mm=length_mm,
        description="core bore; nominal M5 tap drill, threading is not modelled",
      ),
    )
  }
  if profile.cells >= 2 {
    let x_wall = hw - profile.lip_thickness_mm
    let y_wall = profile.floor_depth()
    let short = if x_wall < y_wall { x_wall } else { y_wall }
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "center-channel",
        placement=@common.Placement::translation(0.0, 0.0, z_mid),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * short,
        description="central through-channel of the two-cell section",
      ),
    )
  }
  out
}
