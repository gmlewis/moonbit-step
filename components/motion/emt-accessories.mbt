///|
/// emt_end_cap builds a spigot end cap for a cut length of EMT.
///
/// Frame: the cap's outer face is at `z = 0`, the cap disc runs from `z = 0` to
/// `z = cap_thickness_mm`, and the plug runs from `z = cap_thickness_mm` to
/// `z = cap_thickness_mm + plug_length_mm`. The cap disc is flush with the tube
/// outside diameter by default; the plug diameter is the tube inside diameter
/// minus a declared clearance, so it enters the tube.
///
/// The cap is one analytic solid of revolution: a stepped cylinder with planar
/// end faces. It is a geometric closure primitive; no seal, thread, adhesive,
/// or electrical/structural rating is claimed.
pub fn emt_end_cap(
  size : EmtSize,
  cap_thickness_mm : Double,
  plug_length_mm : Double,
  plug_clearance_mm~ : Double = 0.25,
  cap_diameter_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("EMT end cap thickness", cap_thickness_mm),
    @common.require_positive("EMT end cap plug length", plug_length_mm),
    @common.require_non_negative(
      "EMT end cap plug clearance", plug_clearance_mm,
    ),
    @common.require_non_negative("EMT end cap diameter", cap_diameter_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let tube_id = size.inside_diameter_mm()
  let plug_diameter = tube_id - plug_clearance_mm
  if plug_diameter <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "EMT end cap plug clearance leaves no plug for this tube size",
      ),
    )
  }
  let cap_diameter = if cap_diameter_mm > 0.0 {
    cap_diameter_mm
  } else {
    size.outside_diameter_mm
  }
  if cap_diameter < plug_diameter {
    return Err(
      @common.InvalidParameter(
        "EMT end cap diameter must be at least the plug diameter",
      ),
    )
  }
  let cap_r = cap_diameter / 2.0
  let plug_r = plug_diameter / 2.0
  let total_length = cap_thickness_mm + plug_length_mm
  let body = @cad.RevolvedProfile::polyline([
    (0.0, 0.0),
    (cap_r, 0.0),
    (cap_r, cap_thickness_mm),
    (plug_r, cap_thickness_mm),
    (plug_r, total_length),
    (0.0, total_length),
  ])
  let features = @common.FeatureRecord::new(
    modeled=["cap-disc", "plug", "cap-face", "shoulder"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="seal-and-retention",
        reason="no O-ring groove, adhesive, thread, or friction-fit rating is modelled",
      ),
      @common.Omission::new(
        feature="edge-chamfer",
        reason="the plug lead-in chamfer is not modelled",
      ),
    ],
  )
  let component = @common.Component::new(
    name="emt-cap-\{size.trade_size}-\{@cad.fmt_double(total_length, None)}",
    metadata=@common.Metadata::new(
      designation="EMT end cap \{size.trade_size} in x \{@cad.fmt_double(total_length, None)}",
      standard="ANSI C80.3 / UL 797 EMT boundary dimensions",
      family="EMT end cap",
      size=size.trade_size,
      length_mm=total_length,
      source="End cap sized from the EMT OD and ID: cap diameter \{@cad.fmt_double(cap_diameter, None)} mm, plug diameter \{@cad.fmt_double(plug_diameter, None)} mm (ID minus \{@cad.fmt_double(plug_clearance_mm, None)} mm clearance).",
    ),
    description="EMT spigot end cap: one analytic solid of revolution with a flush cap disc and a plug that enters the tube. No seal, thread, or retaining feature is modelled.",
    features~,
  ).add_layer(body.as_shape(), name="body", color~)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "cap-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=cap_diameter,
        description="outer cap face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "tube-face",
        placement=@common.Placement::translation(0.0, 0.0, cap_thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=cap_diameter,
        description="annular shoulder that abuts the tube end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "plug",
        placement=@common.Placement::translation(0.0, 0.0, cap_thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=plug_diameter,
        depth_mm=plug_length_mm,
        description="plug that enters the tube bore; clearance = \{@cad.fmt_double(plug_clearance_mm, None)} mm",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "plug-end",
        placement=@common.Placement::translation(0.0, 0.0, total_length),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=plug_diameter,
        description="inner end face of the plug",
      ),
    ),
  )
}

///|
/// emt_rect_loop returns a counter-clockwise rectangular profile loop.
fn emt_rect_loop(
  x0 : Double,
  z0 : Double,
  x1 : Double,
  z1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, z0), (x1, z0)),
    @cad.SegmentLine((x1, z0), (x1, z1)),
    @cad.SegmentLine((x1, z1), (x0, z1)),
    @cad.SegmentLine((x0, z1), (x0, z0)),
  ]
}

///|
/// emt_circle_loop returns a counter-clockwise circle as four arcs, which the
/// arc compiler turns into one analytic cylindrical hole.
fn emt_circle_loop(
  cx : Double,
  cz : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (cx, cz)
  [
    @cad.SegmentArc((cx + radius, cz), (cx, cz + radius), centre),
    @cad.SegmentArc((cx, cz + radius), (cx - radius, cz), centre),
    @cad.SegmentArc((cx - radius, cz), (cx, cz - radius), centre),
    @cad.SegmentArc((cx, cz - radius), (cx + radius, cz), centre),
  ]
}

///|
/// emt_split_clamp builds a generic one-bolt split clamp collar for EMT.
///
/// Frame: the tube axis is +Z and the clamp runs from `z = 0` to
/// `z = length_mm`. The ring is a C-shaped slit tube whose slot opens at +X;
/// its inside diameter is the tube OD plus `clearance_mm`, and its outside
/// diameter is the inside diameter plus twice `wall_mm`. The closure gap is
/// `gap_mm`. Two rectangular ears, one on each side of the slot, carry a single
/// cross bolt along +Y at `x = outer radius + ear_length/2`, `z = length/2`.
///
/// Construction is layered: a slit-tube ring plus two ear prisms. The ears
/// embed `ear_embed_mm` into the ring's outer slit edges so the nominal body is
/// connected; the layers therefore overlap by that small embed and the union is
/// slightly smaller than the exact layer-volume sum. The ear length, height,
/// bolt diameter, and clearance are caller-supplied. This is a generic
/// parametric form; no vendor clamp, thread, spring, or load rating is implied.
pub fn emt_split_clamp(
  size : EmtSize,
  length_mm : Double,
  wall_mm~ : Double = 3.0,
  clearance_mm~ : Double = 0.5,
  gap_mm~ : Double = 2.0,
  ear_length_mm~ : Double = 8.0,
  ear_height_mm~ : Double = 6.0,
  ear_embed_mm~ : Double = 0.5,
  bolt_diameter_mm~ : Double = 5.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("EMT split clamp length", length_mm),
    @common.require_positive("EMT split clamp wall", wall_mm),
    @common.require_non_negative("EMT split clamp clearance", clearance_mm),
    @common.require_positive("EMT split clamp gap", gap_mm),
    @common.require_positive("EMT split clamp ear length", ear_length_mm),
    @common.require_positive("EMT split clamp ear height", ear_height_mm),
    @common.require_non_negative("EMT split clamp ear embed", ear_embed_mm),
    @common.require_positive("EMT split clamp bolt diameter", bolt_diameter_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let inner_diameter = size.outside_diameter_mm + clearance_mm
  let outer_diameter = inner_diameter + 2.0 * wall_mm
  let ro = outer_diameter / 2.0
  let ri = inner_diameter / 2.0
  if gap_mm / 2.0 >= ri {
    return Err(
      @common.InvalidParameter(
        "EMT split clamp gap is too wide for the tube bore",
      ),
    )
  }
  let bolt_r = bolt_diameter_mm / 2.0
  if bolt_r >= ear_height_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "EMT split clamp bolt does not fit the ear height",
      ),
    )
  }
  if ear_length_mm <= bolt_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "EMT split clamp ear length must exceed the bolt diameter",
      ),
    )
  }
  if ear_embed_mm >= ro - ri {
    return Err(
      @common.InvalidParameter(
        "EMT split clamp ear embed is thicker than the ring wall",
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
  let ear_profile = emt_rect_loop(ear_x0, 0.0, ear_x1, length_mm)
  let ear_hole = emt_circle_loop(hole_x, length_mm / 2.0, bolt_r)
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
  let features = @common.FeatureRecord::new(
    modeled=[
      "slit-ring", "closure-gap", "bolt-ears", "bolt-hole", "inner-cylinder", "outer-cylinder",
    ],
    approximated=[
      @common.Approximation::new(
        feature="ear-attachment",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=ear_embed_mm,
        control="the ears are separate prisms embedded into the ring's slit edges; a cast or welded ear blend is not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="thread-and-fastener",
        reason="the cross bolt and any nut or thread are separate hardware and are not modelled",
      ),
      @common.Omission::new(
        feature="edge-radius",
        reason="no edge treatment is asserted",
      ),
    ],
  )
  let component = @common.Component::new(
      name="emt-split-clamp-\{size.trade_size}-\{@cad.fmt_double(length_mm, None)}",
      metadata=@common.Metadata::new(
        designation="EMT split clamp \{size.trade_size} in x \{@cad.fmt_double(length_mm, None)}",
        standard="Generic EMT split clamp (not a vendor part)",
        family="EMT split clamp",
        size=size.trade_size,
        length_mm~,
        source="Parametric one-bolt split clamp: ring ID = EMT OD + \{@cad.fmt_double(clearance_mm, None)} mm, ring wall \{@cad.fmt_double(wall_mm, None)} mm, gap \{@cad.fmt_double(gap_mm, None)} mm. Ear and bolt dimensions are caller-supplied.",
      ),
      description="EMT split clamp collar: a slit ring with a closure gap and two ears that a single cross bolt draws together. Layered slit-tube and ear prisms; the ears embed into the ring edges. No thread, fastener, or load rating is modelled.",
      features~,
    )
    .add_layer(ring.as_shape(), name="ring", color~)
    .add_layer(ear, name="ear-upper", color~, placement=upper_placement)
    .add_layer(ear, name="ear-lower", color~, placement=lower_placement)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
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
        "outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=outer_diameter,
        depth_mm=length_mm,
        description="outer cylindrical surface of the clamp ring",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=outer_diameter,
        description="negative-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=outer_diameter,
        description="positive-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "gap",
        placement=@common.Placement::translation(ro, 0.0, length_mm / 2.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        description="closure gap; the slot opens at +X",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bolt-hole",
        placement=@common.Placement::translation(hole_x, 0.0, length_mm / 2.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_diameter_mm,
        depth_mm=gap_mm + 2.0 * ear_height_mm,
        description="cross bolt hole through both ears; the bolt squeezes the closure gap",
      ),
    ),
  )
}
