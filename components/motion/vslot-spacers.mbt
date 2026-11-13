///|
/// spacer_circle_loop returns a counter-clockwise full circle as four arcs so
/// `ExtrudedArcProfile` merges it into one analytic cylindrical face.
fn spacer_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), centre),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), centre),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), centre),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), centre),
  ]
}

///|
/// spacer_polygon_loop converts a counter-clockwise point loop into lines.
fn spacer_polygon_loop(
  points : Array[(Double, Double)],
) -> Array[@cad.ProfileSegment] {
  let n = points.length()
  Array::makei(n, fn(i) {
    let a = points[i]
    let b = points[(i + 1) % n]
    @cad.SegmentLine(a, b)
  })
}

///|
/// vslot_spacer builds the OpenBuilds-style plain wheel spacer.
///
/// Axis +Z, from `z = 0` to `z = length`. The default 10 mm outside diameter,
/// 5 mm bore, and 6 mm length are the published OpenBuilds aluminum spacer
/// boundary dimensions. The bore is the nominal M5 clearance diameter quoted by
/// the vendor; verify the running fit against the screw before use. The part is
/// a plain tube and makes no holding or strength claim.
pub fn vslot_spacer(
  outer_diameter_mm~ : Double = 10.0,
  bore_diameter_mm~ : Double = 5.0,
  length_mm~ : Double = 6.0,
  color~ : @cad.Rgb = @cad.Rgb::green(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("V-Slot spacer outer diameter", outer_diameter_mm),
    @common.require_positive("V-Slot spacer bore", bore_diameter_mm),
    @common.require_positive("V-Slot spacer length", length_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if bore_diameter_mm >= outer_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "V-Slot spacer bore must be smaller than the outer diameter",
      ),
    )
  }
  let body = @cad.ExtrudedArcProfile::new(
    spacer_circle_loop(0.0, 0.0, outer_diameter_mm / 2.0),
    length_mm,
    holes=[spacer_circle_loop(0.0, 0.0, bore_diameter_mm / 2.0)],
  ).as_shape()
  let component = @common.Component::new(
    name="vslot-spacer-\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
    metadata=@common.Metadata::new(
      designation="V-Slot wheel spacer OD \{@cad.fmt_double(outer_diameter_mm, None)} / bore \{@cad.fmt_double(bore_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
      standard="OpenBuilds aluminum wheel spacer (boundary dimensions)",
      family="V-Slot wheel spacer",
      length_mm~,
      source="Plain aluminum spacer: 10 mm OD, 5 mm nominal M5 bore, 6 mm length as listed by OpenBuilds resellers. The bore is nominal; no tolerance class is asserted.",
    ),
    description="Plain V-Slot wheel spacer: one analytic annular solid (true outer and inner cylinders). Bore is the nominal M5 clearance quoted by the vendor; no thread, slit, or strength claim.",
    features=@common.FeatureRecord::new(
      modeled=["outer-cylinder", "inner-cylinder", "flat-ends"],
      omitted=[
        @common.Omission::new(
          feature="bore-tolerance",
          reason="the vendor quotes a nominal 5 mm bore; no tolerance class is asserted",
        ),
      ],
    ),
  ).add_layer(body, name="body", color~)
  Ok(
    with_bushing_connectors(
      component, bore_diameter_mm, outer_diameter_mm, length_mm,
    ),
  )
}

///|
/// vslot_eccentric_spacer builds the OpenBuilds-style eccentric wheel spacer.
///
/// Frame: the hex seating shoulder is at `z = 0`, the hex body runs from
/// `z = -hex_height` to `z = 0`, and the cylindrical pilot runs from `z = 0` to
/// `z = +pilot_length`. The hex is centred on the pilot axis; the bore is
/// offset `eccentricity_mm` along +X. This follows the published reference
/// frame of the OpenBuilds 6 mm eccentric spacer (pilot axis at x = y = 0,
/// seating shoulder z = 0, hex on -z, pilot on +z, bore at x = +0.79).
///
/// Defaults: 10 mm hex across flats, 6 mm hex height, 7.11 mm pilot x 2.5 mm,
/// 0.79 mm eccentricity, 5 mm bore. The pilot fits the 7.12 mm wheel hole quoted
/// by the vendor. The overall axial stack is `hex_height + pilot_length`;
/// some vendor listings quote 6 mm as the overall height and give the pilot
/// length separately, so the seating shoulder is the unambiguous datum.
/// No divot marker, spanner flats finish, or tolerance class is modelled.
pub fn vslot_eccentric_spacer(
  across_flats_mm~ : Double = 10.0,
  hex_height_mm~ : Double = 6.0,
  pilot_diameter_mm~ : Double = 7.11,
  pilot_length_mm~ : Double = 2.5,
  bore_diameter_mm~ : Double = 5.0,
  eccentricity_mm~ : Double = 0.79,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("eccentric spacer across flats", across_flats_mm),
    @common.require_positive("eccentric spacer hex height", hex_height_mm),
    @common.require_positive(
      "eccentric spacer pilot diameter", pilot_diameter_mm,
    ),
    @common.require_positive("eccentric spacer pilot length", pilot_length_mm),
    @common.require_positive("eccentric spacer bore", bore_diameter_mm),
    @common.require_non_negative("eccentric spacer offset", eccentricity_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if pilot_diameter_mm >= across_flats_mm {
    return Err(
      @common.InvalidParameter(
        "eccentric spacer pilot diameter must be smaller than the hex across flats",
      ),
    )
  }
  if eccentricity_mm + bore_diameter_mm / 2.0 >= pilot_diameter_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "eccentric spacer bore breaks through the pilot wall",
      ),
    )
  }
  if eccentricity_mm + bore_diameter_mm / 2.0 >= across_flats_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "eccentric spacer bore breaks through the hex flats",
      ),
    )
  }
  let across_corners = across_flats_mm / @math.cos(@math.PI / 6.0)
  let hex_points = @cad.Profile2D::polygon(6, across_corners, rotation=30.0)
  let hex_loop = spacer_polygon_loop(hex_points)
  let hex_bore = spacer_circle_loop(
    eccentricity_mm,
    0.0,
    bore_diameter_mm / 2.0,
  )
  let hex_body = @cad.ExtrudedArcProfile::new(hex_loop, hex_height_mm, holes=[
    hex_bore,
  ]).as_shape()
  let pilot_outer = spacer_circle_loop(0.0, 0.0, pilot_diameter_mm / 2.0)
  let pilot_bore = spacer_circle_loop(
    eccentricity_mm,
    0.0,
    bore_diameter_mm / 2.0,
  )
  let pilot_body = @cad.ExtrudedArcProfile::new(pilot_outer, pilot_length_mm, holes=[
    pilot_bore,
  ]).as_shape()
  let hex_placement = @common.Placement::translation(0.0, 0.0, -hex_height_mm)
  let total_depth = hex_height_mm + pilot_length_mm
  let features = @common.FeatureRecord::new(
    modeled=["hex-body", "offset-bore", "cylindrical-pilot"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="divot-marker",
        reason="the vendor marks the small side of the cam with a divot; it is a visual marker, not a mating feature",
      ),
      @common.Omission::new(
        feature="across-flats-finish",
        reason="no wrench-flat finish or tolerance class is asserted",
      ),
    ],
  )
  let component = @common.Component::new(
      name="vslot-eccentric-spacer-\{@cad.fmt_double(across_flats_mm, None)}",
      metadata=@common.Metadata::new(
        designation="V-Slot eccentric spacer AF \{@cad.fmt_double(across_flats_mm, None)} x \{@cad.fmt_double(hex_height_mm, None)}, pilot \{@cad.fmt_double(pilot_diameter_mm, None)} x \{@cad.fmt_double(pilot_length_mm, None)}",
        standard="OpenBuilds eccentric wheel spacer (boundary dimensions)",
        family="V-Slot eccentric spacer",
        length_mm=total_depth,
        source="Hex body across flats 10 mm, hex height 6 mm, pilot 7.11 mm x 2.5 mm, 5 mm bore, 0.79 mm eccentricity, as listed by OpenBuilds resellers and the ink.parts reference frame. Overall axial stack = hex height + pilot length.",
      ),
      description="Hex eccentric spacer with an offset 5 mm bore and a 7.11 mm pilot that fits the 7.12 mm wheel hole. The seating shoulder is z = 0, the hex is on -Z, and the pilot is on +Z. No divot, finish, or tolerance class is modelled.",
      features~,
    )
    .add_layer(pilot_body, name="pilot", color~)
    .add_layer(hex_body, name="hex-body", color~, placement=hex_placement)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(
          eccentricity_mm,
          0.0,
          -hex_height_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=total_depth,
        description="offset 5 mm bore through the hex and pilot; the offset is what makes the spacer eccentric",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pilot",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=pilot_diameter_mm,
        depth_mm=pilot_length_mm,
        description="pilot spigot that fits the 7.12 mm wheel hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "seat-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=across_flats_mm,
        description="hex seating shoulder at z = 0; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hex-face",
        placement=@common.Placement::translation(0.0, 0.0, -hex_height_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=across_flats_mm,
        description="outer hex end face at z = -hex_height",
      ),
    ),
  )
}
