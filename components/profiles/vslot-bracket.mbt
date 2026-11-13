///|
/// bracket_rect_loop returns a counter-clockwise rectangular profile loop.
fn bracket_rect_loop(
  u0 : Double,
  v0 : Double,
  u1 : Double,
  v1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((u0, v0), (u1, v0)),
    @cad.SegmentLine((u1, v0), (u1, v1)),
    @cad.SegmentLine((u1, v1), (u0, v1)),
    @cad.SegmentLine((u0, v1), (u0, v0)),
  ]
}

///|
/// bracket_slot_loop returns a counter-clockwise obround loop whose long axis
/// is the local V axis.
fn bracket_slot_loop(
  cu : Double,
  cv : Double,
  length_mm : Double,
  width_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let r = width_mm / 2.0
  let v0 = cv - (length_mm / 2.0 - r)
  let v1 = cv + (length_mm / 2.0 - r)
  [
    @cad.SegmentArc((cu - r, v0), (cu + r, v0), (cu, v0)),
    @cad.SegmentLine((cu + r, v0), (cu + r, v1)),
    @cad.SegmentArc((cu + r, v1), (cu - r, v1), (cu, v1)),
    @cad.SegmentLine((cu - r, v1), (cu - r, v0)),
  ]
}

///|
/// vslot_corner_bracket builds a gusseted 20-series V-Slot corner bracket.
///
/// Frame: the bracket is centred on the X axis (`x = -width/2 .. +width/2`),
/// its base lies on `z = 0`, and its two legs occupy `y = -leg/2 .. +leg/2`
/// and `z = 0 .. leg`. The horizontal leg is `thickness` thick in Z and the
/// vertical leg is `thickness` thick in Y. Two 45-degree side gussets, each
/// `gusset_thickness` thick, fill the inside corner. Each leg carries one
/// M5-clearance obround slot; the slot centres are shifted `slot_shift` toward
/// the free end of each leg. The default 1 mm is the Xem Studio reference's
/// measured placement: each 10 mm slot leaves a 4 mm land at the leg's free end,
/// so its centre is 1 mm off the bracket mid-plane. For an M5 (Ø5.5) screw in
/// that slot the mid-plane screw position has 3.25 mm of travel toward the free
/// end and 1.25 mm toward the corner. Set `slot_shift = 0` for symmetric
/// +/-2.25 mm travel, or `(slot_length - slot_width) / 2` to put the mid-plane
/// screw at the corner end of the slot.
///
/// Construction is layered: two slotted analytic extrusions plus two
/// triangular prisms. The four bodies touch face-to-face but do not overlap, so
/// the component volume is the exact sum of the parts. Casting draft, edge
/// rounds, and the vendor's locating tabs are not modelled.
///
/// The default 20 x 20 x 20 bracket with 3 mm legs, 3 mm gussets, and two
/// 5.5 x 10 mm slots reproduces the Xem Studio `corner-bracket-20` reference
/// geometry (CC BY 4.0); it is a generic parametric form, not a vendor part.
pub fn vslot_corner_bracket(
  leg_mm~ : Double = 20.0,
  width_mm~ : Double = 20.0,
  thickness_mm~ : Double = 3.0,
  gusset_thickness_mm~ : Double = 3.0,
  slot_width_mm~ : Double = 5.5,
  slot_length_mm~ : Double = 10.0,
  slot_shift_mm~ : Double = 1.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("corner bracket leg", leg_mm),
    @common.require_positive("corner bracket width", width_mm),
    @common.require_positive("corner bracket thickness", thickness_mm),
    @common.require_positive(
      "corner bracket gusset thickness", gusset_thickness_mm,
    ),
    @common.require_positive("corner bracket slot width", slot_width_mm),
    @common.require_positive("corner bracket slot length", slot_length_mm),
    @common.require_non_negative("corner bracket slot shift", slot_shift_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if slot_length_mm < slot_width_mm {
    return Err(
      @common.InvalidParameter(
        "corner bracket slot length must be at least its width",
      ),
    )
  }
  if 2.0 * thickness_mm >= leg_mm {
    return Err(
      @common.InvalidParameter(
        "corner bracket legs are too thick for the leg length",
      ),
    )
  }
  if 2.0 * gusset_thickness_mm > width_mm {
    return Err(
      @common.InvalidParameter(
        "corner bracket gussets are too thick for the bracket width",
      ),
    )
  }
  let half_leg = leg_mm / 2.0
  let half_width = width_mm / 2.0
  let half_slot = slot_length_mm / 2.0
  // The base slot must lie inside the horizontal leg.
  if half_slot > half_leg - slot_shift_mm ||
    half_slot > half_leg - thickness_mm + slot_shift_mm {
    return Err(
      @common.InvalidParameter(
        "corner bracket base slot does not fit the horizontal leg",
      ),
    )
  }
  // The side slot must lie inside the vertical leg: it is centred at
  // half_leg + shift and must end at or before the top face.
  if half_slot > half_leg - slot_shift_mm {
    return Err(
      @common.InvalidParameter(
        "corner bracket side slot does not fit the vertical leg",
      ),
    )
  }
  if slot_width_mm / 2.0 >= half_width - gusset_thickness_mm {
    return Err(
      @common.InvalidParameter("corner bracket slot runs into the side gusset"),
    )
  }
  // Base leg: profile in XY, extruded along +Z.
  let base_outer = bracket_rect_loop(
    -half_width,
    -half_leg,
    half_width,
    half_leg - thickness_mm,
  )
  let base_slot = bracket_slot_loop(
    0.0,
    -slot_shift_mm,
    slot_length_mm,
    slot_width_mm,
  )
  let base_body = @cad.ExtrudedArcProfile::new(base_outer, thickness_mm, holes=[
    base_slot,
  ]).as_shape()
  // Vertical leg: profile in XZ, extruded along -Y then shifted to +Y.
  let vertical_outer = bracket_rect_loop(-half_width, 0.0, half_width, leg_mm)
  let side_slot = bracket_slot_loop(
    0.0,
    half_leg + slot_shift_mm,
    slot_length_mm,
    slot_width_mm,
  )
  let vertical_body = @cad.ExtrudedArcProfile::new(
    vertical_outer,
    thickness_mm,
    holes=[side_slot],
  ).as_shape()
  let vertical_placement = @common.Placement::translation(0.0, half_leg, 0.0).compose(
    @common.Placement::rotation_deg(90.0, 0.0, 0.0),
  )
  // Gussets: right-triangle profile in YZ, extruded along +X. The 45-degree
  // hypotenuse runs from the inner corner out to the free ends.
  let gusset_points : Array[(Double, Double)] = [
    (-(half_leg - thickness_mm), thickness_mm),
    (half_leg - thickness_mm, thickness_mm),
    (half_leg - thickness_mm, leg_mm - thickness_mm),
  ]
  let gusset_body = @cad.ExtrudedProfile::new(
    gusset_points, gusset_thickness_mm,
  )
  let gusset_rotation = @common.Placement::rotation_deg(90.0, 0.0, 90.0)
  let left_gusset_placement = @common.Placement::translation(
    -half_width,
    0.0,
    0.0,
  ).compose(gusset_rotation)
  let right_gusset_placement = @common.Placement::translation(
    half_width - gusset_thickness_mm,
    0.0,
    0.0,
  ).compose(gusset_rotation)
  let features = @common.FeatureRecord::new(
    modeled=["base-leg", "side-leg", "through-slots", "side-gussets"],
    approximated=[
      @common.Approximation::new(
        feature="gusset-profile",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="flat 45-degree triangular gusset; the cast reference has draft and a rounded web",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="casting-draft",
        reason="the parametric form keeps prismatic faces",
      ),
      @common.Omission::new(
        feature="edge-fillets",
        reason="no edge treatment is asserted",
      ),
      @common.Omission::new(
        feature="locating-tabs",
        reason="the vendor cast bracket's 4 mm slot tabs are not modelled",
      ),
    ],
  )
  let name = "vslot-corner-bracket-\{@cad.fmt_double(leg_mm, None)}"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="V-Slot corner bracket \{@cad.fmt_double(leg_mm, None)} x \{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
        standard="Generic 20-series V-Slot corner bracket",
        family="V-Slot corner bracket",
        size="\{@cad.fmt_double(leg_mm, None)}x\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
        source="Parametric gusseted corner bracket: two slotted legs plus two 45-degree side gussets. The default dimensions reproduce the Xem Studio corner-bracket-20 reference (CC BY 4.0); no vendor part is claimed.",
      ),
      description="Layered V-Slot corner bracket with one M5-clearance obround slot in each leg and two side gussets. Faces touch but do not overlap. No casting draft, edge fillets, or locating tabs are modelled.",
      features~,
    )
    .add_layer(base_body, name="base-leg", color~)
    .add_layer(
      vertical_body,
      name="side-leg",
      color~,
      placement=vertical_placement,
    )
    .add_layer(
      gusset_body,
      name="gusset-left",
      color~,
      placement=left_gusset_placement,
    )
    .add_layer(
      gusset_body,
      name="gusset-right",
      color~,
      placement=right_gusset_placement,
    )
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=if width_mm < leg_mm { width_mm } else { leg_mm },
        description="outer face of the horizontal leg; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "side-face",
        placement=@common.Placement::translation(0.0, half_leg, half_leg),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=width_mm,
        description="outer face of the vertical leg; outward normal is +Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-slot",
        placement=@common.Placement::translation(0.0, -slot_shift_mm, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=slot_width_mm,
        depth_mm=thickness_mm,
        description="M5-clearance slot through the horizontal leg; long axis is Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "side-slot",
        placement=@common.Placement::translation(
          0.0,
          half_leg,
          half_leg + slot_shift_mm,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=slot_width_mm,
        depth_mm=thickness_mm,
        description="M5-clearance slot through the vertical leg; long axis is Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "inner-corner",
        placement=@common.Placement::translation(
          0.0,
          half_leg - thickness_mm,
          thickness_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        description="inside corner of the two legs; the corner line runs along X",
      ),
    ),
  )
}
