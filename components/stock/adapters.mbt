///|
/// Minimum material between a fastener hole edge and the adapter plate edge.
const ADAPTER_EDGE_MARGIN_MM : Double = 3.0

///|
/// tube_mount_plate builds a flat adapter plate that takes a round tube through
/// its centre and bolts down through two clearance holes.
///
/// This is a printed-to-metal (or metal-to-metal) interface primitive: the
/// central bore is the tube pass-through and the two side holes are the fastener
/// clearance holes. It does not model a clamp split, a saddle, or a thread, and
/// it makes no claim about joint strength.
///
/// Frame: the plate is centred on the XY origin with faces at
/// `z = +/- thickness/2`; the tube axis is +Z and the two bolt holes lie on the
/// X axis at `+/- bolt_spacing/2`.
pub fn tube_mount_plate(
  tube_outside_diameter_mm : Double,
  clearance_mm : Double,
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  bolt_hole_diameter_mm : Double,
  bolt_spacing_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("tube outside diameter", tube_outside_diameter_mm),
    @common.require_non_negative("tube clearance", clearance_mm),
    @common.require_positive("adapter width", width_mm),
    @common.require_positive("adapter height", height_mm),
    @common.require_positive("adapter thickness", thickness_mm),
    @common.require_positive("bolt hole diameter", bolt_hole_diameter_mm),
    @common.require_positive("bolt spacing", bolt_spacing_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let tube_bore = tube_outside_diameter_mm + clearance_mm
  if tube_bore >= width_mm || tube_bore >= height_mm {
    return Err(
      @common.InvalidParameter("tube bore does not fit the adapter plate"),
    )
  }
  let holes : Array[PlateHole] = [
    { x_mm: 0.0, y_mm: 0.0, diameter_mm: tube_bore, },
    {
      x_mm: -bolt_spacing_mm / 2.0,
      y_mm: 0.0,
      diameter_mm: bolt_hole_diameter_mm,
    },
    {
      x_mm: bolt_spacing_mm / 2.0,
      y_mm: 0.0,
      diameter_mm: bolt_hole_diameter_mm,
    },
  ]
  match @common.require_positive("tube bore", tube_bore) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let base = match
    plate_impl(width_mm, height_mm, thickness_mm, holes, [], color) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let features = @common.FeatureRecord::new(
    modeled=[
      "body", "tube-through-bore", "bolt-clearance-holes", "mounting-faces",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="clamp-split-or-saddle",
        reason="the plate is a flat pass-through adapter, not a clamp",
      ),
      @common.Omission::new(
        feature="joint-strength",
        reason="geometry alone does not establish the strength of a bolted or printed joint",
      ),
    ],
  )
  let component = base
    .with_features(features)
    .with_metadata(
      @common.Metadata::new(
        designation="Tube mount plate \{@cad.fmt_double(tube_bore, None)} bore",
        family="tube-to-plate adapter",
        size="tube \{@cad.fmt_double(tube_outside_diameter_mm, None)}",
        source="Parametric adapter plate. Tube bore = tube OD + declared clearance; bolt clearance is explicit.",
      ),
    )
    .with_description(
      "Flat adapter plate with a central tube pass-through bore and two bolt clearance holes. No clamp split, thread, or strength claim.",
    )
    .with_name(
      "tube-mount-plate-\{@cad.fmt_double(tube_outside_diameter_mm, None)}",
    )
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tube-bore",
        placement=@common.Placement::translation(0.0, 0.0, -thickness_mm / 2.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=tube_bore,
        depth_mm=thickness_mm,
        description="tube pass-through bore; clearance = \{@cad.fmt_double(clearance_mm, None)} mm",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-1",
        placement=@common.Placement::translation(
          -bolt_spacing_mm / 2.0,
          0.0,
          -thickness_mm / 2.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=thickness_mm,
        description="fastener clearance hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole-2",
        placement=@common.Placement::translation(
          bolt_spacing_mm / 2.0,
          0.0,
          -thickness_mm / 2.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_diameter_mm,
        depth_mm=thickness_mm,
        description="fastener clearance hole",
      ),
    ),
  )
}

///|
/// tube_to_vslot_bracket builds an adapter bracket that carries a round tube
/// through its centre and has two obround slots for V-Slot 20-series T-nuts.
///
/// This is the tube-to-extrusion interface primitive: the central bore is the
/// tube pass-through (tube OD plus a declared clearance) and the two obround
/// slots take M5 T-nuts in a V-Slot rail. It is a flat plate, not a clamp; it
/// does not model a split, a saddle, a T-nut, or a thread, and it makes no
/// claim about joint strength.
///
/// Frame: the plate is centred on the XY origin with faces at
/// `z = +/- thickness/2`; the tube axis is +Z, and the two slots lie on the X
/// axis at `+/- slot_pitch/2` with their long axis along X.
pub fn tube_to_vslot_bracket(
  tube_outside_diameter_mm : Double,
  clearance_mm : Double,
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  slot_pitch_mm : Double,
  slot_length_mm : Double,
  slot_width_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive(
      "bracket tube outside diameter", tube_outside_diameter_mm,
    ),
    @common.require_non_negative("bracket tube clearance", clearance_mm),
    @common.require_positive("bracket width", width_mm),
    @common.require_positive("bracket height", height_mm),
    @common.require_positive("bracket thickness", thickness_mm),
    @common.require_positive("bracket slot pitch", slot_pitch_mm),
    @common.require_positive("bracket slot length", slot_length_mm),
    @common.require_positive("bracket slot width", slot_width_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let tube_bore = tube_outside_diameter_mm + clearance_mm
  let holes : Array[PlateHole] = [
    { x_mm: 0.0, y_mm: 0.0, diameter_mm: tube_bore, },
  ]
  let slots : Array[PlateSlot] = [
    {
      x_mm: -slot_pitch_mm / 2.0,
      y_mm: 0.0,
      length_mm: slot_length_mm,
      width_mm: slot_width_mm,
    },
    {
      x_mm: slot_pitch_mm / 2.0,
      y_mm: 0.0,
      length_mm: slot_length_mm,
      width_mm: slot_width_mm,
    },
  ]
  let base = match
    plate_impl(width_mm, height_mm, thickness_mm, holes, slots, color) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let component = with_plate_connectors(
      base,
      width_mm,
      height_mm,
      thickness_mm,
      [],
      slots,
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tube-bore",
        placement=@common.Placement::translation(0.0, 0.0, -thickness_mm / 2.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=tube_bore,
        depth_mm=thickness_mm,
        description="tube pass-through bore; clearance = \{@cad.fmt_double(clearance_mm, None)} mm",
      ),
    )
    .with_name(
      "tube-vslot-bracket-\{@cad.fmt_double(tube_outside_diameter_mm, None)}",
    )
    .with_metadata(
      @common.Metadata::new(
        designation="Tube-to-V-Slot bracket \{@cad.fmt_double(tube_bore, None)} bore",
        standard="Generic V-Slot 20-series bracket (not a vendor part)",
        family="tube-to-extrusion adapter",
        size="tube \{@cad.fmt_double(tube_outside_diameter_mm, None)}",
        source="Parametric flat bracket: tube bore = tube OD + declared clearance; two obround M5-clearance slots at the caller's pitch. No T-nut, clamp split, thread, or strength claim.",
      ),
    )
    .with_description(
      "Flat tube-to-V-Slot bracket with a central tube pass-through bore and two obround T-nut slots. No clamp split, thread, T-nut, or strength claim.",
    )
    .with_features(
      @common.FeatureRecord::new(
        modeled=["body", "tube-through-bore", "t-nut-slots", "mounting-faces"],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="t-nut-and-clamp",
            reason="the bracket takes separate V-Slot T-nuts; it is not a clamp and no T-nut is modelled",
          ),
          @common.Omission::new(
            feature="joint-strength",
            reason="geometry alone does not establish the strength of a bolted or printed joint",
          ),
        ],
      ),
    )
  Ok(component)
}

///|
/// vslot_joining_plate builds a generic 20-series V-Slot joining plate: a flat
/// plate with two obround slots, one per joined extrusion end.
///
/// This is a caller-configurable plate, not a vendor part. The default
/// 60 x 20 x 3 mm plate has two Ø5.5 x 10 mm slots at `+/- slot_pitch/2`, which
/// matches the M5 clearance used by OpenBuilds-style T-nuts. It does not model
/// a locating tongue, counterbore, or gusset.
pub fn vslot_joining_plate(
  length_mm : Double,
  width_mm : Double,
  thickness_mm : Double,
  slot_pitch_mm : Double,
  slot_length_mm : Double,
  slot_width_mm : Double,
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("joining plate length", length_mm),
    @common.require_positive("joining plate width", width_mm),
    @common.require_positive("joining plate thickness", thickness_mm),
    @common.require_positive("joining plate slot pitch", slot_pitch_mm),
    @common.require_positive("joining plate slot length", slot_length_mm),
    @common.require_positive("joining plate slot width", slot_width_mm),
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
        "joining plate slot length must be at least its width",
      ),
    )
  }
  let slots : Array[PlateSlot] = [
    {
      x_mm: -slot_pitch_mm / 2.0,
      y_mm: 0.0,
      length_mm: slot_length_mm,
      width_mm: slot_width_mm,
    },
    {
      x_mm: slot_pitch_mm / 2.0,
      y_mm: 0.0,
      length_mm: slot_length_mm,
      width_mm: slot_width_mm,
    },
  ]
  match plate(length_mm, width_mm, thickness_mm, slots~) {
    Err(e) => return Err(e)
    Ok(base) =>
      Ok(
        base
        .with_name("vslot-joining-plate-\{@cad.fmt_double(length_mm, None)}")
        .with_metadata(
          @common.Metadata::new(
            designation="V-Slot joining plate \{@cad.fmt_double(length_mm, None)} x \{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
            standard="Generic 20-series joining plate (not a vendor part)",
            family="joining plate",
            size="\{@cad.fmt_double(length_mm, None)}x\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
            source="Parametric flat plate with two obround M5-clearance slots; no locating tongue or gusset.",
          ),
        )
        .with_description(
          "Flat 20-series joining plate with two obround slots. No locating tongue, counterbore, gusset, or strength claim.",
        )
        .with_features(
          @common.FeatureRecord::new(
            modeled=["body", "through-slots", "mounting-faces"],
            approximated=[],
            omitted=[
              @common.Omission::new(
                feature="locating-tongue-or-gusset",
                reason="a flat joining plate is modelled; no vendor gusset is claimed",
              ),
              @common.Omission::new(
                feature="joint-strength",
                reason="geometry alone does not establish joint strength",
              ),
            ],
          ),
        ),
      )
  }
}

///|
/// channel_to_extrusion_adapter builds a flat plate that joins a P1000-style
/// strut-channel back wall to a 20-series extrusion slot.
///
/// Frame: the plate is centred on the XY origin with faces at
/// `z = +/- thickness/2`. The channel face is -Z; its two bolt holes lie on X
/// at `+/- channel_hole_pitch/2` and use the channel's back-wall hole diameter.
/// The extrusion face is +Z; its two T-nut clearance holes lie on Y at
/// `+/- extrusion_pitch/2`.
///
/// This is a generic engineering adapter built from the published P1000 channel
/// and 20-series slot interfaces. It is not a vendor part; it models no channel
/// nut, spring, slot adjustment, or strength.
pub fn channel_to_extrusion_adapter(
  channel_width_mm : Double,
  channel_hole_pitch_mm : Double,
  channel_hole_diameter_mm : Double,
  extrusion_pitch_mm : Double,
  plate_width_mm : Double,
  plate_height_mm : Double,
  thickness_mm : Double,
  extrusion_hole_diameter_mm~ : Double = 5.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("channel adapter channel width", channel_width_mm),
    @common.require_positive(
      "channel adapter channel hole pitch", channel_hole_pitch_mm,
    ),
    @common.require_positive(
      "channel adapter channel hole diameter", channel_hole_diameter_mm,
    ),
    @common.require_positive(
      "channel adapter extrusion pitch", extrusion_pitch_mm,
    ),
    @common.require_positive("channel adapter plate width", plate_width_mm),
    @common.require_positive("channel adapter plate height", plate_height_mm),
    @common.require_positive("channel adapter plate thickness", thickness_mm),
    @common.require_positive(
      "channel adapter extrusion hole diameter", extrusion_hole_diameter_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let margin = ADAPTER_EDGE_MARGIN_MM
  if plate_width_mm <
    channel_hole_pitch_mm + channel_hole_diameter_mm + 2.0 * margin {
    return Err(
      @common.InvalidDimension(
        "channel adapter plate is too narrow for the channel hole pattern",
      ),
    )
  }
  if plate_height_mm < channel_width_mm + 2.0 * margin {
    return Err(
      @common.InvalidDimension(
        "channel adapter plate is too short across the channel width",
      ),
    )
  }
  if plate_height_mm <
    extrusion_pitch_mm + extrusion_hole_diameter_mm + 2.0 * margin {
    return Err(
      @common.InvalidDimension(
        "channel adapter plate is too short for the extrusion hole pattern",
      ),
    )
  }
  let half_ch = channel_hole_pitch_mm / 2.0
  let half_ext = extrusion_pitch_mm / 2.0
  let dx = half_ch
  let dy = half_ext
  let hole_gap = (dx * dx + dy * dy).sqrt()
  if hole_gap <
    (channel_hole_diameter_mm + extrusion_hole_diameter_mm) / 2.0 + margin {
    return Err(
      @common.InvalidDimension(
        "channel and extrusion holes intersect each other",
      ),
    )
  }
  let holes : Array[PlateHole] = [
    { x_mm: -half_ch, y_mm: 0.0, diameter_mm: channel_hole_diameter_mm, },
    { x_mm: half_ch, y_mm: 0.0, diameter_mm: channel_hole_diameter_mm, },
    { x_mm: 0.0, y_mm: -half_ext, diameter_mm: extrusion_hole_diameter_mm, },
    { x_mm: 0.0, y_mm: half_ext, diameter_mm: extrusion_hole_diameter_mm, },
  ]
  let base = match
    plate_impl(plate_width_mm, plate_height_mm, thickness_mm, holes, [], color) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let bottom = -thickness_mm / 2.0
  let top = thickness_mm / 2.0
  let face_size = if plate_width_mm < plate_height_mm {
    plate_width_mm
  } else {
    plate_height_mm
  }
  let component = base
    .with_name(
      "channel-to-extrusion-adapter-\{@cad.fmt_double(plate_width_mm, None)}x\{@cad.fmt_double(plate_height_mm, None)}",
    )
    .with_metadata(
      @common.Metadata::new(
        designation="Channel-to-extrusion adapter \{@cad.fmt_double(plate_width_mm, None)} x \{@cad.fmt_double(plate_height_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
        standard="Generic P1000-style strut channel plus 20-series extrusion slot (not a vendor part)",
        family="channel-to-extrusion adapter",
        size="\{@cad.fmt_double(plate_width_mm, None)}x\{@cad.fmt_double(plate_height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
        length_mm=thickness_mm,
        source="Channel hole pitch and diameter from the published P1000 back-wall pattern; extrusion holes use the caller's 20-series slot pitch. Generic engineering adapter; no channel nut, spring, or strength rating.",
      ),
    )
    .with_description(
      "Flat channel-to-extrusion adapter: two channel back-wall bolt holes on -Z and two 20-series T-nut clearance holes on +Z. Circular holes only; no channel nut, slot adjustment, edge treatment, or strength claim.",
    )
    .with_features(
      @common.FeatureRecord::new(
        modeled=[
          "plate", "channel-bolt-holes", "extrusion-mounting-holes", "through-holes",
        ],
        omitted=[
          @common.Omission::new(
            feature="channel-nut-and-spring",
            reason="the adapter takes separate channel hardware; no nut or spring is modelled",
          ),
          @common.Omission::new(
            feature="mounting-slots",
            reason="all holes are circular; slot adjustment is not modelled",
          ),
          @common.Omission::new(
            feature="joint-strength",
            reason="geometry only; no joint strength or load rating is claimed",
          ),
        ],
      ),
    )
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "channel-face",
        placement=@common.Placement::translation(0.0, 0.0, bottom),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="face against the strut-channel back wall; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "extrusion-face",
        placement=@common.Placement::translation(0.0, 0.0, top),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="face against the 20-series extrusion; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "channel-hole-1",
        placement=@common.Placement::translation(-half_ch, 0.0, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=channel_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="channel back-wall bolt clearance at -X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "channel-hole-2",
        placement=@common.Placement::translation(half_ch, 0.0, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=channel_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="channel back-wall bolt clearance at +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "extrusion-hole-1",
        placement=@common.Placement::translation(0.0, -half_ext, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=extrusion_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="T-nut clearance in the 20-series slot at -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "extrusion-hole-2",
        placement=@common.Placement::translation(0.0, half_ext, bottom),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=extrusion_hole_diameter_mm,
        depth_mm=thickness_mm,
        fit=@cad.Fit::Free,
        description="T-nut clearance in the 20-series slot at +Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "extrusion-slot",
        placement=@common.Placement::translation(0.0, 0.0, top),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=extrusion_pitch_mm,
        description="20-series slot centreline along Y; the two T-nut holes lie on it",
      ),
    ),
  )
}

///|
/// adapter_rect_loop returns a counter-clockwise rectangle in the profile plane.
fn adapter_rect_loop(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, y0), (x1, y0)),
    @cad.SegmentLine((x1, y0), (x1, y1)),
    @cad.SegmentLine((x1, y1), (x0, y1)),
    @cad.SegmentLine((x0, y1), (x0, y0)),
  ]
}

///|
/// adapter_circle_loop returns a counter-clockwise circle as four arcs.
fn adapter_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), (cx, cy)),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), (cx, cy)),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), (cx, cy)),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), (cx, cy)),
  ]
}

///|
/// extrusion_to_tube_clamp builds a one-piece tube clamp with a split ring, a
/// pair of closure ears, and a base plate that bolts to a 20-series extrusion.
///
/// Frame: the tube axis is +Z and the ring is centred on the origin. The split
/// opens at +X; the two ears bridge the gap and take one cross bolt. The base
/// plate is below the ring (-Y), with its top edge embedded `embed_mm` into the
/// ring wall. Two clearance holes on X at `+/- extrusion_pitch/2` pass through
/// the base along Y for T-nuts in a 20-series slot; the extrusion face is the
/// base bottom.
///
/// The ring, ears, and base are layered solids; the accepted artifact is the
/// OCCT-evaluated union (`write_step_evaluated`). This is a generic engineering
/// clamp built from the tube OD and the 20-series slot interface; it models no
/// thread, fastener, strap, or strength.
pub fn extrusion_to_tube_clamp(
  tube_outside_diameter_mm : Double,
  length_mm : Double,
  clearance_mm~ : Double = 0.5,
  wall_mm~ : Double = 3.0,
  gap_mm~ : Double = 4.0,
  ear_length_mm~ : Double = 8.0,
  ear_height_mm~ : Double = 6.0,
  ear_embed_mm~ : Double = 0.5,
  clamp_bolt_diameter_mm~ : Double = 5.5,
  base_width_mm~ : Double = 40.0,
  base_thickness_mm~ : Double = 6.0,
  extrusion_pitch_mm~ : Double = 25.0,
  bolt_diameter_mm~ : Double = 5.5,
  embed_mm~ : Double = 0.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive(
      "tube clamp outside diameter", tube_outside_diameter_mm,
    ),
    @common.require_positive("tube clamp length", length_mm),
    @common.require_non_negative("tube clamp clearance", clearance_mm),
    @common.require_positive("tube clamp wall", wall_mm),
    @common.require_positive("tube clamp gap", gap_mm),
    @common.require_positive("tube clamp ear length", ear_length_mm),
    @common.require_positive("tube clamp ear height", ear_height_mm),
    @common.require_non_negative("tube clamp ear embed", ear_embed_mm),
    @common.require_positive(
      "tube clamp cross bolt diameter", clamp_bolt_diameter_mm,
    ),
    @common.require_positive("tube clamp base width", base_width_mm),
    @common.require_positive("tube clamp base thickness", base_thickness_mm),
    @common.require_positive("tube clamp extrusion pitch", extrusion_pitch_mm),
    @common.require_positive(
      "tube clamp mounting bolt diameter", bolt_diameter_mm,
    ),
    @common.require_non_negative("tube clamp base embed", embed_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let inner_diameter = tube_outside_diameter_mm + clearance_mm
  let ri = inner_diameter / 2.0
  let ro = ri + wall_mm
  let outer_diameter = 2.0 * ro
  if gap_mm / 2.0 >= ri {
    return Err(
      @common.InvalidParameter("tube clamp gap is too wide for the tube bore"),
    )
  }
  if embed_mm >= wall_mm || embed_mm >= base_thickness_mm {
    return Err(
      @common.InvalidParameter(
        "tube clamp base embed must be less than the ring wall and base thickness",
      ),
    )
  }
  if ear_embed_mm >= wall_mm {
    return Err(
      @common.InvalidParameter(
        "tube clamp ear embed is thicker than the ring wall",
      ),
    )
  }
  let clamp_bolt_r = clamp_bolt_diameter_mm / 2.0
  if clamp_bolt_r >= ear_height_mm / 2.0 || clamp_bolt_r >= ear_length_mm / 2.0 {
    return Err(
      @common.InvalidParameter("tube clamp cross bolt does not fit the ears"),
    )
  }
  let margin = ADAPTER_EDGE_MARGIN_MM
  if base_width_mm < extrusion_pitch_mm + bolt_diameter_mm + 2.0 * margin {
    return Err(
      @common.InvalidDimension(
        "tube clamp base is too narrow for the extrusion mounting holes",
      ),
    )
  }
  if base_width_mm < outer_diameter {
    return Err(
      @common.InvalidDimension(
        "tube clamp base is narrower than the clamp ring",
      ),
    )
  }
  if length_mm < bolt_diameter_mm + 2.0 * margin {
    return Err(
      @common.InvalidDimension(
        "tube clamp length is too short for the base mounting holes",
      ),
    )
  }
  let ring = @cad.SlitTube::new(
    outer_diameter_mm=outer_diameter,
    inner_diameter_mm=inner_diameter,
    length_mm~,
    slot_width_mm=gap_mm,
  )
  let ear_x0 = ro - ear_embed_mm
  let ear_x1 = ro + ear_length_mm
  let hole_x = ro + ear_length_mm / 2.0
  let ear_profile = adapter_rect_loop(ear_x0, 0.0, ear_x1, length_mm)
  let ear_hole = adapter_circle_loop(hole_x, length_mm / 2.0, clamp_bolt_r)
  let ear = @cad.ExtrudedArcProfile::new(ear_profile, ear_height_mm, holes=[
    ear_hole,
  ]).as_shape()
  let ear_rotation = @common.Placement::rotation_deg(90.0, 0.0, 0.0)
  let upper_placement = @common.Placement::translation(
    0.0,
    gap_mm / 2.0 + ear_height_mm,
    0.0,
  ).compose(ear_rotation)
  let lower_placement = @common.Placement::translation(0.0, -gap_mm / 2.0, 0.0).compose(
    ear_rotation,
  )
  let base_top_y = -ro + embed_mm
  let base_center_y = base_top_y - base_thickness_mm / 2.0
  let base_bottom_y = base_top_y - base_thickness_mm
  let base_holes : Array[PlateHole] = [
    {
      x_mm: -extrusion_pitch_mm / 2.0,
      y_mm: 0.0,
      diameter_mm: bolt_diameter_mm,
    },
    {
      x_mm: extrusion_pitch_mm / 2.0,
      y_mm: 0.0,
      diameter_mm: bolt_diameter_mm,
    },
  ]
  let base = match
    plate_impl(
      base_width_mm,
      length_mm,
      base_thickness_mm,
      base_holes,
      [],
      color,
    ) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  // The plate shape is built from z = 0..thickness, so the placement's Y is the
  // base top and the plate extends downward by base_thickness.
  let base_placement = @common.Placement::translation(
    0.0,
    base_top_y,
    length_mm / 2.0,
  ).compose(@common.Placement::rotation_deg(90.0, 0.0, 0.0))
  let features = @common.FeatureRecord::new(
    modeled=[
      "slit-ring", "tube-bore", "closure-gap", "clamp-ears", "cross-bolt-hole", "base-plate",
      "mounting-holes",
    ],
    approximated=[
      @common.Approximation::new(
        feature="ear-and-base-attachment",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=embed_mm + ear_embed_mm,
        control="the ears and base plate embed into the ring wall; the layered union is evaluated with OCCT, not a cast or welded blend",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="thread-and-fasteners",
        reason="the cross bolt, T-nuts, and any thread are separate hardware and are not modelled",
      ),
      @common.Omission::new(
        feature="edge-treatment",
        reason="no chamfer, fillet, or deburr is asserted",
      ),
      @common.Omission::new(
        feature="clamping-force-and-strength",
        reason="geometry alone does not establish grip, clamp force, or load capacity",
      ),
    ],
  )
  let component = @common.Component::new(
      name="extrusion-to-tube-clamp-\{@cad.fmt_double(tube_outside_diameter_mm, None)}",
      metadata=@common.Metadata::new(
        designation="Tube-to-extrusion clamp for Ø\{@cad.fmt_double(tube_outside_diameter_mm, None)} tube",
        standard="Generic split tube clamp plus 20-series extrusion base (not a vendor part)",
        family="extrusion-to-tube clamp",
        size="tube \{@cad.fmt_double(tube_outside_diameter_mm, None)}",
        length_mm~,
        source="Parametric one-bolt split clamp: ring ID = tube OD + \{@cad.fmt_double(clearance_mm, None)} mm, wall \{@cad.fmt_double(wall_mm, None)} mm, cross bolt \{@cad.fmt_double(clamp_bolt_diameter_mm, None)} mm, base T-nut pitch \{@cad.fmt_double(extrusion_pitch_mm, None)} mm. Generic engineering clamp; no vendor part or strength rating.",
      ),
      description="One-piece split tube clamp with two closure ears, a cross-bolt hole, and a base plate with two 20-series T-nut holes. Layered ring, ears, and base; the accepted artifact is the OCCT-evaluated union. No thread, fastener, grip, or strength claim.",
      features~,
    )
    .add_layer(ring.as_shape(), name="ring", color~)
    .add_layer(ear, name="ear-upper", color~, placement=upper_placement)
    .add_layer(ear, name="ear-lower", color~, placement=lower_placement)
    .add_layer(
      base.layers()[0].shape,
      name="base",
      color~,
      placement=base_placement,
    )
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tube-bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=inner_diameter,
        depth_mm=length_mm,
        description="tube bore; the clamp slides over the tube OD plus clearance",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slit",
        placement=@common.Placement::translation(ro, 0.0, length_mm / 2.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        description="closure gap; the slot opens at +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "clamp-bolt",
        placement=@common.Placement::translation(hole_x, 0.0, length_mm / 2.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=clamp_bolt_diameter_mm,
        depth_mm=gap_mm + 2.0 * ear_height_mm,
        description="cross bolt through both ears; draws the closure gap shut",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(
          0.0,
          base_bottom_y,
          length_mm / 2.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=base_width_mm,
        description="base mounting face against the 20-series extrusion; outward normal is -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-hole-1",
        placement=@common.Placement::translation(
          -extrusion_pitch_mm / 2.0,
          base_center_y,
          length_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_diameter_mm,
        depth_mm=base_thickness_mm,
        fit=@cad.Fit::Free,
        description="T-nut clearance through the base at -X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-hole-2",
        placement=@common.Placement::translation(
          extrusion_pitch_mm / 2.0,
          base_center_y,
          length_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_diameter_mm,
        depth_mm=base_thickness_mm,
        fit=@cad.Fit::Free,
        description="T-nut clearance through the base at +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "extrusion-slot",
        placement=@common.Placement::translation(
          0.0,
          base_bottom_y,
          length_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=extrusion_pitch_mm,
        description="20-series slot centreline along X; the two base holes lie on it",
      ),
    ),
  )
}
