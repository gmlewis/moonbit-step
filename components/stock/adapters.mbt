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
