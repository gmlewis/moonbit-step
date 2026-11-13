///|
/// clamp_shaft_collar builds a one-piece clamp shaft collar whose radial slit,
/// clamp-screw clearance passage, and head counterbore are real trimmed
/// geometry.
///
/// Frame: the shaft axis is +Z, from `z = 0` to `z = width`. The bore, outside,
/// clamp clearance hole, and head counterbore are true cylinders; the four rim
/// chamfers are 45 degree analytic cones. The slit is a rectangular kerf of
/// `slit_width_mm` centred on the `x = 0` plane and opening at +Y from the bore
/// through the outside surface. The clamp screw runs along the X axis at
/// `screw_offset_mm` from the shaft axis at mid-width, so tightening it closes
/// the slit. Its head counterbore opens on the +X jaw.
///
/// The flat writer cannot trim the slit or the holes, so this family's portable
/// output is `Component::write_step_evaluated` (OCCT). `Component::to_step`
/// remains nominal and is not the accepted artifact.
///
/// Defaults: `thread` M6; `drill_diameter_mm` the nominal diameter + 0.1 mm
/// (a clearance hole); `counterbore_diameter_mm` the ISO 4762 head diameter +
/// 0.2 mm; `screw_offset_mm` the wall midline radius. The head counterbore is
/// deep enough for the ISO 4762 head (`head_height_mm`) plus a small
/// `CLAMP_HEAD_SEAT_CLEARANCE_MM`. The clamp thread is declared by a connector,
/// never modelled. No holding torque, material, or strength claim is made.
pub fn clamp_shaft_collar(
  bore_mm : Double,
  outer_diameter_mm : Double,
  width_mm : Double,
  thread~ : @standards.MetricSize = @standards.MetricSize::M6,
  drill_diameter_mm? : Double,
  counterbore_diameter_mm? : Double,
  screw_offset_mm? : Double,
  slit_width_mm~ : Double = 0.8,
  chamfer_mm~ : Double = 0.2,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("clamp collar bore", bore_mm),
    @common.require_positive("clamp collar outer diameter", outer_diameter_mm),
    @common.require_positive("clamp collar width", width_mm),
    @common.require_non_negative("clamp collar chamfer", chamfer_mm),
    @common.require_positive("clamp collar slit width", slit_width_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if outer_diameter_mm <= bore_mm {
    return Err(
      @common.InvalidParameter(
        "clamp collar outer diameter must exceed its bore",
      ),
    )
  }
  let wall = (outer_diameter_mm - bore_mm) / 2.0
  if chamfer_mm >= wall || chamfer_mm >= width_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "clamp collar chamfer does not fit the collar wall",
      ),
    )
  }
  let thread_spec = @standards.ThreadSpec::coarse(thread)
  let head = match @standards.iso4762_size(thread) {
    Ok(size) => size
    Err(e) => return Err(e)
  }
  let drill_is_default = drill_diameter_mm is None
  let drill = match drill_diameter_mm {
    Some(d) => d
    None => thread_spec.nominal_diameter_mm + CLAMP_SCREW_CLEARANCE_MM
  }
  let cb_is_default = counterbore_diameter_mm is None
  let counterbore = match counterbore_diameter_mm {
    Some(d) => d
    None => head.head_diameter_mm + CLAMP_COUNTERBORE_CLEARANCE_MM
  }
  let screw_offset = match screw_offset_mm {
    Some(o) => o
    None => (bore_mm + outer_diameter_mm) / 4.0
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("clamp screw drill diameter", drill),
    @common.require_positive("clamp screw counterbore diameter", counterbore),
    @common.require_positive("clamp screw offset", screw_offset),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if counterbore <= drill {
    return Err(
      @common.InvalidParameter(
        "clamp screw counterbore must exceed its clearance hole",
      ),
    )
  }
  if drill >= width_mm || counterbore >= width_mm {
    return Err(
      @common.InvalidParameter(
        "clamp screw hole must be narrower than the collar width",
      ),
    )
  }
  let bore_radius = bore_mm / 2.0
  let outer_radius = outer_diameter_mm / 2.0
  if screw_offset >= outer_radius {
    return Err(
      @common.InvalidParameter(
        "clamp screw offset must place the clamp screw inside the collar outside diameter",
      ),
    )
  }
  if screw_offset <= counterbore / 2.0 {
    return Err(
      @common.InvalidParameter(
        "clamp screw counterbore must not reach the shaft axis",
      ),
    )
  }
  if screw_offset - drill / 2.0 <= bore_radius {
    return Err(
      @common.InvalidParameter(
        "clamp screw clearance hole must clear the collar bore",
      ),
    )
  }
  if screw_offset + drill / 2.0 >= outer_radius {
    return Err(
      @common.InvalidParameter(
        "clamp screw clearance hole must stay inside the collar outside diameter",
      ),
    )
  }
  // The outer surface along the clamp-screw axis, and the counterbore floor
  // that leaves the ISO 4762 head fully recessed behind it.
  let x_outer = Double::sqrt(
    outer_radius * outer_radius - screw_offset * screw_offset,
  )
  let head_seat_depth = head.head_height_mm + CLAMP_HEAD_SEAT_CLEARANCE_MM
  let x_floor = x_outer - head_seat_depth
  if x_floor <= slit_width_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "clamp screw head counterbore does not fit the clamp jaw (increase the outside diameter, reduce the screw offset, or use a smaller thread)",
      ),
    )
  }
  let margin = 1.0
  let base = @cad.RevolvedProfile::chamfered_tube(
    outer_diameter_mm,
    bore_mm,
    width_mm,
    outer_bottom_chamfer=chamfer_mm,
    outer_top_chamfer=chamfer_mm,
    inner_bottom_chamfer=chamfer_mm,
    inner_top_chamfer=chamfer_mm,
  ).as_shape()
  // A rectangular kerf centred on x = 0, opening at +Y from the bore to the
  // outside surface, over the full width.
  let slit = @cad.Cuboid::new(
      slit_width_mm,
      outer_radius - bore_radius + 2.0 * margin,
      width_mm + 2.0 * margin,
    )
    .with_name("clamp-slit")
    .translate(x=-slit_width_mm / 2.0, y=bore_radius - margin, z=-margin)
  // The clamp-screw clearance passage, drilled along X across the full
  // diameter at mid-width.
  let hole_length = 2.0 * (outer_radius + margin)
  let drill_cutter = @cad.Cylinder::new(drill, hole_length)
    .with_name("clamp-screw-hole")
    .rotate_y(90.0)
    .translate(x=-(outer_radius + margin), y=screw_offset, z=width_mm / 2.0)
  // The ISO 4762 head counterbore, from the head seat outward through the +X
  // jaw and outside surface.
  let counterbore_cutter = @cad.Cylinder::new(
      counterbore,
      outer_radius + margin - x_floor,
    )
    .with_name("head-counterbore")
    .rotate_y(90.0)
    .translate(x=x_floor, y=screw_offset, z=width_mm / 2.0)
  let body = @cad.difference(
    base.with_name("body"),
    [slit, drill_cutter, counterbore_cutter],
    name="body",
  )
  let features = @common.FeatureRecord::new(
    modeled=[
      "body", "outside-cylinder", "bore", "rim-chamfers", "clamp-slit", "clamp-screw-hole",
      "head-counterbore",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="clamp-screw-thread",
        reason="the tapped clamp thread is declared by the clamp-screw-thread connector but not modelled; the modelled hole is a clearance bore",
      ),
      @common.Omission::new(
        feature="clamp-screw",
        reason="the clamp screw is a separate part and is not modelled by the builder",
      ),
      @common.Omission::new(
        feature="holding-torque-and-material",
        reason="nominal geometry only; no holding torque, material, or strength claim",
      ),
    ],
  )
  Ok(
    with_clamp_shaft_collar_connectors(
      @common.Component::new(
        name="clamp-shaft-collar-\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
        metadata=@common.Metadata::new(
          designation="Clamp shaft collar \{@cad.fmt_double(bore_mm, None)} bore x \{@cad.fmt_double(outer_diameter_mm, None)} OD x \{@cad.fmt_double(width_mm, None)}, \{thread_spec.size.designation()} clamp screw",
          family="clamp shaft collar",
          size="\{@cad.fmt_double(bore_mm, None)}x\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
          source="Parametric one-piece clamp collar with a real slit, clamp-screw clearance passage, and ISO 4762 head counterbore. The free-state shape is not a standard table.",
        ),
        description="One-piece clamp shaft collar with analytic bore, outside cylinder, 45 degree rim chamfers, one radial slit, a clamp-screw clearance passage, and an ISO 4762 head counterbore. The clamp thread is declared by a connector, not modelled. Use write_step_evaluated for the trimmed solid.",
        features~,
      ).add_layer(body.shape_intent(), name="body", color~),
      bore_mm,
      outer_diameter_mm,
      width_mm,
      thread_spec,
      drill,
      counterbore,
      screw_offset,
      slit_width_mm,
      x_outer,
      x_floor,
      drill_is_default,
      cb_is_default,
    ),
  )
}

///|
/// CLAMP_SCREW_CLEARANCE_MM is the radial clearance added to the clamp-screw
/// nominal diameter for the modelled clearance hole (+0.1 mm on diameter).
const CLAMP_SCREW_CLEARANCE_MM : Double = 0.1

///|
/// CLAMP_COUNTERBORE_CLEARANCE_MM is the radial clearance added to the ISO 4762
/// head diameter for the modelled counterbore (+0.2 mm on diameter).
const CLAMP_COUNTERBORE_CLEARANCE_MM : Double = 0.2

///|
/// CLAMP_HEAD_SEAT_CLEARANCE_MM is the extra counterbore depth beyond the
/// ISO 4762 head height so the head does not bottom out on the seat.
const CLAMP_HEAD_SEAT_CLEARANCE_MM : Double = 0.4

///|
/// with_clamp_shaft_collar_connectors attaches the bore, outside seat, both
/// faces, the slit datum, the clamp-screw thread and hole, and the head seat.
fn with_clamp_shaft_collar_connectors(
  component : @common.Component,
  bore_mm : Double,
  outer_diameter_mm : Double,
  width_mm : Double,
  thread_spec : @standards.ThreadSpec,
  drill_mm : Double,
  counterbore_mm : Double,
  screw_offset_mm : Double,
  slit_width_mm : Double,
  x_outer_mm : Double,
  x_floor_mm : Double,
  drill_is_default : Bool,
  counterbore_is_default : Bool,
) -> @common.Component {
  let mid_width = width_mm / 2.0
  let hole_note = if drill_is_default {
    "ISO clearance hole (nominal + 0.1 mm)"
  } else {
    "modeled hole \{@cad.fmt_double(drill_mm, None)} mm (caller-supplied)"
  }
  let counterbore_note = if counterbore_is_default {
    "ISO 4762 head diameter + 0.2 mm"
  } else {
    "modeled counterbore \{@cad.fmt_double(counterbore_mm, None)} mm (caller-supplied)"
  }
  let far_jaw_depth = x_outer_mm - slit_width_mm / 2.0
  let clearance_passage = x_floor_mm + x_outer_mm
  with_shaft_collar_connectors(component, bore_mm, outer_diameter_mm, width_mm)
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slit-datum",
      placement=@common.Placement::translation(0.0, screw_offset_mm, mid_width),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      gender=@common.MateGender::Neutral,
      diameter_mm=outer_diameter_mm,
      description="clamp slit mid-plane x = 0; \{@cad.fmt_double(slit_width_mm, None)} mm kerf opens at +Y",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "clamp-screw-thread",
      placement=@common.Placement::translation(
        -slit_width_mm / 2.0,
        screw_offset_mm,
        mid_width,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=thread_spec.nominal_diameter_mm,
      depth_mm=far_jaw_depth,
      description="\{thread_spec.designation(external=false)} declared clamp thread in the far jaw; the modelled hole is a \{@cad.fmt_double(drill_mm, None)} mm clearance bore; thread not modelled",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "clamp-screw-hole",
      placement=@common.Placement::translation(
        x_floor_mm, screw_offset_mm, mid_width,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=drill_mm,
      depth_mm=clearance_passage,
      description="modelled clamp-screw clearance passage from the head seat to the far outside surface; \{hole_note}",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "head-seat",
      placement=@common.Placement::translation(
        x_floor_mm, screw_offset_mm, mid_width,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      gender=@common.MateGender::Neutral,
      diameter_mm=counterbore_mm,
      description="ISO 4762 head counterbore seat on the +X jaw; \{counterbore_note}",
    ),
  )
}
