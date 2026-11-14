///|
/// oldham_slot_sector_loop returns one half of a slotted hub face.
///
/// The loop is a C-shaped annular sector between `outer_radius` and
/// `inner_radius`, bounded by a rectangular slot of `slot_width` centred on the
/// X axis and open at the outer edge. The slot must be narrower than the bore so
/// the inner arc remains continuous.
fn oldham_slot_sector_loop(
  outer_radius_mm : Double,
  inner_radius_mm : Double,
  slot_width_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let half = slot_width_mm / 2.0
  let theta_outer = @math.asin(half / outer_radius_mm)
  let theta_inner = @math.asin(half / inner_radius_mm)
  let outer_right = (outer_radius_mm * @math.cos(theta_outer), half)
  let outer_left = (-outer_radius_mm * @math.cos(theta_outer), half)
  let inner_left = (-inner_radius_mm * @math.cos(theta_inner), half)
  let inner_right = (inner_radius_mm * @math.cos(theta_inner), half)
  [
    @cad.SegmentArc(outer_right, outer_left, (0.0, 0.0)),
    @cad.SegmentLine(outer_left, inner_left),
    @cad.SegmentArc(inner_left, inner_right, (0.0, 0.0)),
    @cad.SegmentLine(inner_right, outer_right),
  ]
}

///|
/// oldham_coupling builds a three-piece Oldham (double-slider) coupling with
/// real hub slots and disc tongues.
///
/// Frame: the coupling axis is +Z. Hub A runs from `z = 0` to `hub_length`, the
/// centre disc plate occupies `hub_length .. hub_length + disc_thickness`, and
/// hub B runs to `2 * hub_length + disc_thickness`.
///
/// Each hub is a tube plus two slotted face-sector layers; the slot is
/// `tongue_width + 2 * slot_clearance` wide, is open at the outer edge, and is
/// one `disc_thickness` deep. The centre disc is a plate with a rectangular
/// tongue on each face, the tongues at 90 degrees to each other, engaging the
/// two hub slots. The layers abut nominally; use `write_step_evaluated` for one
/// fused manifold. No torque, misalignment, or wear rating is implied.
pub fn oldham_coupling(
  bore_mm : Double,
  hub_outer_diameter_mm : Double,
  hub_length_mm : Double,
  disc_diameter_mm : Double,
  disc_thickness_mm : Double,
  tongue_width_mm : Double,
  slot_clearance_mm~ : Double = 0.1,
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
  match
    mechanism_non_negative_checks([("Oldham slot clearance", slot_clearance_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bore_mm >= hub_outer_diameter_mm {
    return Err(
      @common.InvalidDimension("Oldham hub bore does not fit the hub diameter"),
    )
  }
  let outer_radius = hub_outer_diameter_mm / 2.0
  let inner_radius = bore_mm / 2.0
  let slot_width = tongue_width_mm + 2.0 * slot_clearance_mm
  if slot_width >= bore_mm {
    return Err(
      @common.InvalidDimension(
        "Oldham slot must be narrower than the hub bore so the inner sector arc is continuous",
      ),
    )
  }
  if disc_thickness_mm >= hub_length_mm {
    return Err(
      @common.InvalidDimension(
        "Oldham disc/tongue thickness must be smaller than the hub length",
      ),
    )
  }
  let half_slot = slot_width / 2.0
  let slot_half_length = (outer_radius * outer_radius - half_slot * half_slot).sqrt()
  if disc_diameter_mm / 2.0 > slot_half_length {
    return Err(
      @common.InvalidDimension(
        "Oldham disc does not fit within the slotted hub face",
      ),
    )
  }
  let slot_depth = disc_thickness_mm
  let sector = @cad.ExtrudedArcProfile::new(
    oldham_slot_sector_loop(outer_radius, inner_radius, slot_width),
    slot_depth,
  )
  if !sector.validate() {
    return Err(
      @common.InvalidParameter(
        "Oldham hub slot sector is not a valid closed profile",
      ),
    )
  }
  let sector_shape = sector.as_shape()
  let hub_body = @cad.RevolvedProfile::tube(
    hub_outer_diameter_mm,
    bore_mm,
    hub_length_mm - slot_depth,
  ).as_shape()
  let disc_plate = @cad.RevolvedProfile::cylinder(
    disc_diameter_mm, disc_thickness_mm,
  ).as_shape()
  let half_disc = disc_diameter_mm / 2.0
  let half_tongue = tongue_width_mm / 2.0
  let tongue_bottom = @cad.ExtrudedArcProfile::new(
    rect_loop(-half_disc, -half_tongue, half_disc, half_tongue),
    slot_depth,
  ).as_shape()
  let tongue_top = @cad.ExtrudedArcProfile::new(
    rect_loop(-half_tongue, -half_disc, half_tongue, half_disc),
    slot_depth,
  ).as_shape()
  let disc_bottom = hub_length_mm
  let disc_top = hub_length_mm + disc_thickness_mm
  let total = disc_top + hub_length_mm
  let features = @common.FeatureRecord::new(
    modeled=[
      "hub-a", "hub-b", "hub-slots", "centre-disc", "disc-tongues", "bores",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="lubrication-and-wear",
        reason="no torque, misalignment, or wear rating is implied",
      ),
      @common.Omission::new(
        feature="layer-union",
        reason="the hub bodies, slotted face layers, disc plate, and tongues abut nominally",
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
        source="Parametric three-piece Oldham coupling with real slotted hub faces and disc tongues. No torque or wear rating is implied.",
      ),
      description="Three-piece Oldham coupling with real hub slots at 90 degrees and a centre disc with two perpendicular tongues. The layers abut nominally.",
      features~,
    )
    .add_layer(hub_body, name="hub-a-body", color~)
    .add_layer(
      sector_shape,
      name="hub-a-slot-a",
      color~,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        hub_length_mm - slot_depth,
      ),
    )
    .add_layer(
      sector_shape,
      name="hub-a-slot-b",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, 0.0, hub_length_mm - slot_depth),
        @common.Placement::rotation_z(180.0),
      ),
    )
    .add_layer(
      tongue_bottom,
      name="disc-tongue-bottom",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(
        0.0,
        0.0,
        hub_length_mm - slot_depth,
      ),
    )
    .add_layer(
      disc_plate,
      name="centre-disc",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(0.0, 0.0, disc_bottom),
    )
    .add_layer(
      tongue_top,
      name="disc-tongue-top",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(0.0, 0.0, disc_top),
    )
    .add_layer(
      sector_shape,
      name="hub-b-slot-a",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, 0.0, disc_top),
        @common.Placement::rotation_z(90.0),
      ),
    )
    .add_layer(
      sector_shape,
      name="hub-b-slot-b",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(0.0, 0.0, disc_top),
        @common.Placement::rotation_z(270.0),
      ),
    )
    .add_layer(
      hub_body,
      name="hub-b-body",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, disc_top + slot_depth),
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
        placement=@common.Placement::translation(
          0.0,
          0.0,
          hub_length_mm - slot_depth,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=slot_width,
        depth_mm=slot_depth,
        description="real hub A face slot along +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-b",
        placement=@common.Placement::translation(0.0, 0.0, disc_top),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=slot_width,
        depth_mm=slot_depth,
        description="real hub B face slot along +Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "disc-face-a",
        placement=@common.Placement::translation(0.0, 0.0, disc_bottom),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=disc_diameter_mm,
        description="centre disc negative-Z face (tongue side A)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "disc-face-b",
        placement=@common.Placement::translation(0.0, 0.0, disc_top),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=disc_diameter_mm,
        description="centre disc positive-Z face (tongue side B)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tongue-a",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          hub_length_mm - slot_depth,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=tongue_width_mm,
        depth_mm=slot_depth,
        description="disc tongue along +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tongue-b",
        placement=@common.Placement::translation(0.0, 0.0, disc_top),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=tongue_width_mm,
        depth_mm=slot_depth,
        description="disc tongue along +Y",
      ),
    ),
  )
}
