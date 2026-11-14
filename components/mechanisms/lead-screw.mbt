///|
/// lead_screw builds a plain lead-screw shaft with a declared thread.
///
/// Frame: the screw runs along +Z from `z = 0` to `z = length_mm`. The body is a
/// true cylinder of `nominal_diameter_mm`; the thread is declared by the
/// `thread` connector and is never modelled. `lead_mm` records the axial travel
/// per revolution as metadata. No tolerance class, strength, or life rating is
/// implied.
pub fn lead_screw(
  nominal_diameter_mm : Double,
  length_mm : Double,
  lead_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("lead screw diameter", nominal_diameter_mm),
      ("lead screw length", length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match mechanism_non_negative_checks([("lead screw lead", lead_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let features = @common.FeatureRecord::new(
    modeled=["screw-body"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="thread",
        reason="the thread form is declared by the `thread` connector and is never modelled",
      ),
      @common.Omission::new(
        feature="end-journals-and-bearings",
        reason="plain cylinder ends; no journal, bearing, or support feature is modelled",
      ),
    ],
  )
  let name = "lead-screw-\{@cad.fmt_double(nominal_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Lead screw \{@cad.fmt_double(nominal_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
        family="lead screw (envelope)",
        size="\{@cad.fmt_double(nominal_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}",
        length_mm~,
        source="Plain cylindrical lead-screw envelope. The thread and lead are declared, not modelled.",
      ),
      description="Plain cylindrical lead-screw body. The thread is connector metadata; no thread form, tolerance class, or load rating is modelled.",
      features~,
    )
    .add_layer(
      mechanism_cylinder_z(nominal_diameter_mm, length_mm),
      name="body",
      color~,
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Male,
        diameter_mm=nominal_diameter_mm,
        depth_mm=length_mm,
        description="declared lead-screw thread; not modelled",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=nominal_diameter_mm,
        depth_mm=length_mm,
        description="negative-Z shaft end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=nominal_diameter_mm,
        depth_mm=length_mm,
        description="positive-Z shaft end",
      ),
    ),
  )
}

///|
/// lead_screw_nut builds a flanged lead-screw nut with a real bore and a
/// declared internal thread.
///
/// Frame: the nut runs along +Z from `z = 0` to `z = length_mm`; the flange is at
/// the negative-Z end. The modelled bore is the ISO metric internal minor
/// diameter `d - 1.082532 * P` of the declared thread, so the thread itself is
/// not modelled. The `thread` connector carries the nominal diameter and pitch.
///
/// No tolerance class, backlash, load, or life rating is implied.
pub fn lead_screw_nut(
  outer_diameter_mm : Double,
  length_mm : Double,
  flange_diameter_mm : Double,
  flange_thickness_mm : Double,
  nominal_thread_diameter_mm : Double,
  thread_pitch_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("lead-screw nut outer diameter", outer_diameter_mm),
      ("lead-screw nut length", length_mm),
      ("lead-screw nut flange diameter", flange_diameter_mm),
      ("lead-screw nut flange thickness", flange_thickness_mm),
      ("lead-screw nut thread diameter", nominal_thread_diameter_mm),
      ("lead-screw nut thread pitch", thread_pitch_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if flange_diameter_mm <= outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "nut flange diameter must exceed the nut body diameter",
      ),
    )
  }
  if flange_thickness_mm >= length_mm {
    return Err(
      @common.InvalidDimension(
        "nut flange thickness must be smaller than the nut length",
      ),
    )
  }
  let bore = nominal_thread_diameter_mm - 1.082532 * thread_pitch_mm
  if bore <= 0.0 {
    return Err(
      @common.InvalidDimension("declared thread leaves a non-positive nut bore"),
    )
  }
  if bore >= outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "nut bore must be smaller than the nut body diameter",
      ),
    )
  }
  let ri = bore / 2.0
  let ro = outer_diameter_mm / 2.0
  let rf = flange_diameter_mm / 2.0
  let profile = @cad.RevolvedProfile::new([
    @cad.RevLine((ri, 0.0), (rf, 0.0)),
    @cad.RevLine((rf, 0.0), (rf, flange_thickness_mm)),
    @cad.RevLine((rf, flange_thickness_mm), (ro, flange_thickness_mm)),
    @cad.RevLine((ro, flange_thickness_mm), (ro, length_mm)),
    @cad.RevLine((ro, length_mm), (ri, length_mm)),
    @cad.RevLine((ri, length_mm), (ri, 0.0)),
  ])
  let features = @common.FeatureRecord::new(
    modeled=["nut-body", "flange", "bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="thread",
        reason="declared by the `thread` connector; the internal thread form is not modelled",
      ),
      @common.Omission::new(
        feature="lubrication-and-tolerance-class",
        reason="no tolerance class, backlash, or lubrication feature is asserted",
      ),
    ],
  )
  let name = "lead-nut-\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Lead-screw nut \{@cad.fmt_double(nominal_thread_diameter_mm, None)} x \{@cad.fmt_double(thread_pitch_mm, None)}",
        family="lead-screw nut (envelope)",
        size="\{@cad.fmt_double(nominal_thread_diameter_mm, None)}x\{@cad.fmt_double(thread_pitch_mm, None)}",
        source="Parametric flanged nut with an ISO metric minor-diameter bore and a declared thread. No standard table is implied.",
      ),
      description="Flanged lead-screw nut with a real cylindrical bore at the thread minor diameter. The thread is connector metadata and is not modelled.",
      features~,
    )
    .add_layer(profile.as_shape(), name="body", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=nominal_thread_diameter_mm,
        depth_mm=length_mm,
        description="declared internal thread; entered from the positive-Z face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore,
        depth_mm=length_mm,
        description="modelled minor-diameter bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "flange-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=flange_diameter_mm,
        description="flange mounting face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-positive",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=outer_diameter_mm,
        description="positive-Z nut face",
      ),
    ),
  )
}

///|
/// lead_screw_travel_mm returns the usable nut travel along a lead screw.
///
/// The nut can travel `screw_length - nut_length` millimetres. A non-positive
/// result means the nut is longer than the screw.
pub fn lead_screw_travel_mm(
  screw_length_mm : Double,
  nut_length_mm : Double,
) -> Result[Double, @common.SpecError] {
  let travel = screw_length_mm - nut_length_mm
  if travel <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "lead-screw nut is not shorter than the screw; travel is not positive",
      ),
    )
  }
  Ok(travel)
}
