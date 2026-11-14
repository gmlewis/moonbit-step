///|
/// eccentric_cam_radius_mm returns the cam outline radius at an angle.
///
/// The cam is a circle of radius `base_radius_mm` whose centre is offset by
/// `eccentricity_mm` along +X from the rotation axis. For an angle measured
/// from +X, the outline radius is
/// `e * cos(angle) + sqrt(R^2 - (e * sin(angle))^2)`.
pub fn eccentric_cam_radius_mm(
  base_radius_mm : Double,
  eccentricity_mm : Double,
  angle_deg : Double,
) -> Double {
  let angle = angle_deg * @math.PI / 180.0
  let s = @math.sin(angle)
  let c = @math.cos(angle)
  let inside = base_radius_mm * base_radius_mm -
    eccentricity_mm * eccentricity_mm * s * s
  let root = if inside <= 0.0 { 0.0 } else { inside.sqrt() }
  eccentricity_mm * c + root
}

///|
/// eccentric_cam_lift_mm returns the follower lift above the minimum radius.
///
/// The minimum radius is `R - e` and the maximum is `R + e`, so the lift ranges
/// from 0 (at 180 degrees) to `2 * e` (at 0 degrees).
pub fn eccentric_cam_lift_mm(
  base_radius_mm : Double,
  eccentricity_mm : Double,
  angle_deg : Double,
) -> Double {
  eccentric_cam_radius_mm(base_radius_mm, eccentricity_mm, angle_deg) -
  (base_radius_mm - eccentricity_mm)
}

///|
/// eccentric_cam builds a circular eccentric cam plate.
///
/// Frame: the rotation axis is +Z through the origin; the cam outline is a
/// circle of `base_radius_mm` centred at `(eccentricity, 0)`, extruded from
/// `z = 0` to `z = width`. The bore is an analytic through cylinder on the
/// rotation axis. `eccentric_cam_lift_mm` describes the roller-follower lift
/// envelope. No torque, contact stress, or wear rating is implied.
pub fn eccentric_cam(
  base_radius_mm : Double,
  eccentricity_mm : Double,
  width_mm : Double,
  bore_diameter_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("cam base radius", base_radius_mm),
      ("cam width", width_mm),
      ("cam bore diameter", bore_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match mechanism_non_negative_checks([("cam eccentricity", eccentricity_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if eccentricity_mm >= base_radius_mm {
    return Err(
      @common.InvalidDimension(
        "cam eccentricity must be smaller than the base radius",
      ),
    )
  }
  let bore_radius = bore_diameter_mm / 2.0
  if bore_radius >= base_radius_mm - eccentricity_mm {
    return Err(
      @common.InvalidDimension(
        "cam bore does not fit inside the narrowest part of the eccentric outline",
      ),
    )
  }
  let outline = circle_loop(eccentricity_mm, 0.0, base_radius_mm)
  let bore = circle_loop(0.0, 0.0, bore_radius)
  let body = @cad.ExtrudedArcProfile::new(outline, width_mm, holes=[bore]).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["eccentric-cam-outline", "rotation-bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="cam-profile-optimisation",
        reason="the outline is a simple eccentric circle; no dwell or jerk profile is shaped",
      ),
      @common.Omission::new(
        feature="contact-stress-and-wear",
        reason="no load, stress, or life rating is implied",
      ),
    ],
  )
  let name = "eccentric-cam-\{@cad.fmt_double(base_radius_mm, None)}x\{@cad.fmt_double(eccentricity_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Eccentric cam R\{@cad.fmt_double(base_radius_mm, None)} e\{@cad.fmt_double(eccentricity_mm, None)}",
        family="eccentric cam (engineering envelope)",
        size="\{@cad.fmt_double(base_radius_mm, None)}x\{@cad.fmt_double(eccentricity_mm, None)}",
        source="Circular eccentric cam with an analytic bore. Lift is 2 e; no cam-law optimisation is asserted.",
      ),
      description="Circular eccentric cam plate with a real bore on the rotation axis. Follower lift ranges from 0 to 2 e.",
      features~,
    )
    .add_layer(body, name="cam", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rotation-bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=width_mm,
        description="cam shaft bore on the rotation axis",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "nose-datum",
        placement=@common.Placement::translation(
          eccentricity_mm + base_radius_mm,
          0.0,
          width_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=base_radius_mm,
        description="maximum-radius (nose) datum at 0 degrees",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * (base_radius_mm + eccentricity_mm),
        description="negative-Z cam face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-b",
        placement=@common.Placement::translation(0.0, 0.0, width_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * (base_radius_mm + eccentricity_mm),
        description="positive-Z cam face",
      ),
    ),
  )
}

///|
/// roller_follower builds a roller and pin for a cam follower.
///
/// Frame: the roller runs along +Z from `z = 0` to `z = width`; the pin is a
/// smaller coaxial cylinder through the roller bore with `pin_length` overall.
/// The bore is larger than the pin by a declared running clearance. The roller
/// is an envelope cylinder: no needle bearing, cage, or contact rating is
/// modelled.
pub fn roller_follower(
  roller_diameter_mm : Double,
  width_mm : Double,
  bore_diameter_mm : Double,
  pin_diameter_mm : Double,
  pin_length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("roller diameter", roller_diameter_mm),
      ("roller width", width_mm),
      ("roller bore diameter", bore_diameter_mm),
      ("roller pin diameter", pin_diameter_mm),
      ("roller pin length", pin_length_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bore_diameter_mm >= roller_diameter_mm {
    return Err(
      @common.InvalidDimension("roller bore does not fit the roller diameter"),
    )
  }
  if pin_diameter_mm >= bore_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "roller pin must be smaller than the roller bore",
      ),
    )
  }
  if pin_length_mm < width_mm {
    return Err(
      @common.InvalidDimension(
        "roller pin must be at least as long as the roller",
      ),
    )
  }
  let pin_z = (width_mm - pin_length_mm) / 2.0
  let features = @common.FeatureRecord::new(
    modeled=["roller", "bore", "pin"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="needle-bearing",
        reason="the roller is a plain envelope cylinder; no bearing or cage is modelled",
      ),
      @common.Omission::new(
        feature="contact-stress-and-wear",
        reason="no load, stress, or life rating is implied",
      ),
    ],
  )
  let name = "roller-follower-\{@cad.fmt_double(roller_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Roller follower \{@cad.fmt_double(roller_diameter_mm, None)} x \{@cad.fmt_double(width_mm, None)}",
        family="roller follower (engineering envelope)",
        size="\{@cad.fmt_double(roller_diameter_mm, None)}x\{@cad.fmt_double(width_mm, None)}",
        source="Plain roller and pin envelope with a declared running clearance.",
      ),
      description="Roller follower with a plain envelope roller, an analytic bore, and a smaller coaxial pin.",
      features~,
    )
    .add_layer(
      mechanism_tube_z(roller_diameter_mm, bore_diameter_mm, width_mm),
      name="roller",
      color~,
    )
    .add_layer(
      mechanism_cylinder_z(pin_diameter_mm, pin_length_mm),
      name="pin",
      color=@cad.Rgb::grey(),
      placement=@common.Placement::translation(0.0, 0.0, pin_z),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "roller-surface",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=roller_diameter_mm,
        depth_mm=width_mm,
        description="roller outer running surface",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bore_diameter_mm,
        depth_mm=width_mm,
        description="roller bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-a",
        placement=@common.Placement::translation(0.0, 0.0, pin_z),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=pin_diameter_mm,
        depth_mm=pin_length_mm,
        description="negative-Z pin end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pin-b",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          pin_z + pin_length_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=pin_diameter_mm,
        depth_mm=pin_length_mm,
        description="positive-Z pin end",
      ),
    ),
  )
}
