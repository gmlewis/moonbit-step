///|
/// oldham_coupling builds a three-piece Oldham (double-slider) coupling.
///
/// Frame: the coupling axis is +Z. Hub A runs from `z = 0` to `hub_length`,
/// the centre disc occupies `hub_length .. hub_length + disc_thickness`, and
/// hub B runs to `2 * hub_length + disc_thickness`. Both hubs are true tubes
/// with the declared bore; the centre disc is a real cross-shaped solid whose
/// tongues engage declared hub slots.
///
/// The hub slots are not modelled: they are declared by `slot-a`/`slot-b`
/// datum connectors. No torque, misalignment, or wear rating is implied.
pub fn oldham_coupling(
  bore_mm : Double,
  hub_outer_diameter_mm : Double,
  hub_length_mm : Double,
  disc_diameter_mm : Double,
  disc_thickness_mm : Double,
  tongue_width_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("Oldham coupling bore", bore_mm),
      ("Oldham hub outer diameter", hub_outer_diameter_mm),
      ("Oldham hub length", hub_length_mm),
      ("Oldham disc diameter", disc_diameter_mm),
      ("Oldham disc thickness", disc_thickness_mm),
      ("Oldham tongue width", tongue_width_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bore_mm >= hub_outer_diameter_mm {
    return Err(
      @common.InvalidDimension("Oldham hub bore does not fit the hub diameter"),
    )
  }
  let half_disc = disc_diameter_mm / 2.0
  let half_tongue = tongue_width_mm / 2.0
  if half_tongue >= half_disc {
    return Err(
      @common.InvalidDimension(
        "Oldham tongue width must be smaller than the disc diameter",
      ),
    )
  }
  let cross : Array[(Double, Double)] = [
    (half_tongue, half_disc),
    (-half_tongue, half_disc),
    (-half_tongue, half_tongue),
    (-half_disc, half_tongue),
    (-half_disc, -half_tongue),
    (-half_tongue, -half_tongue),
    (-half_tongue, -half_disc),
    (half_tongue, -half_disc),
    (half_tongue, -half_tongue),
    (half_disc, -half_tongue),
    (half_disc, half_tongue),
    (half_tongue, half_tongue),
  ]
  if @cad.polygon_area_2d(cross) <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "Oldham centre disc profile is not counter-clockwise",
      ),
    )
  }
  let disc = @cad.ExtrudedProfile::new(cross, disc_thickness_mm)
  let hub = @cad.RevolvedProfile::tube(
    hub_outer_diameter_mm, bore_mm, hub_length_mm,
  ).as_shape()
  let disc_top = hub_length_mm + disc_thickness_mm
  let total = disc_top + hub_length_mm
  let features = @common.FeatureRecord::new(
    modeled=["hub-a", "hub-b", "centre-disc", "bores", "disc-tongues"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="hub-slots",
        reason="the hub slots are declared by datum connectors and are not modelled",
      ),
      @common.Omission::new(
        feature="lubrication-and-wear",
        reason="no torque, misalignment, or wear rating is implied",
      ),
    ],
  )
  let name = "oldham-\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(disc_diameter_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Oldham coupling \{@cad.fmt_double(bore_mm, None)} bore, disc \{@cad.fmt_double(disc_diameter_mm, None)}",
        family="Oldham coupling (engineering envelope)",
        size="\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(disc_diameter_mm, None)}",
        source="Parametric three-piece Oldham coupling envelope with real bores and a cross-shaped centre disc. Hub slots are declared only.",
      ),
      description="Three-piece Oldham coupling with two bored hubs and a cross-shaped centre disc. Hub slots are connector metadata.",
      features~,
    )
    .add_layer(hub, name="hub-a", color~)
    .add_layer(
      disc,
      name="centre-disc",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(0.0, 0.0, hub_length_mm),
    )
    .add_layer(
      hub,
      name="hub-b",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, disc_top),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_mm,
        depth_mm=hub_length_mm,
        description="hub A shaft bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore-b",
        placement=@common.Placement::translation(0.0, 0.0, total),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_mm,
        depth_mm=hub_length_mm,
        description="hub B shaft bore; entered from the positive-Z face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=hub_outer_diameter_mm,
        description="hub A outer face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-b",
        placement=@common.Placement::translation(0.0, 0.0, total),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=hub_outer_diameter_mm,
        description="hub B outer face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-a",
        placement=@common.Placement::translation(0.0, 0.0, hub_length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=tongue_width_mm,
        depth_mm=disc_thickness_mm,
        description="hub A face slot, declared and not modelled",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-b",
        placement=@common.Placement::translation(0.0, 0.0, disc_top),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=tongue_width_mm,
        depth_mm=disc_thickness_mm,
        description="hub B face slot, declared and not modelled",
      ),
    ),
  )
}
