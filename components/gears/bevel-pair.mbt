///|
/// with_back_cone_connectors attaches the backing plane, front face, bore,
/// hub, and pitch datums to a back-cone-ended gear.
fn with_back_cone_connectors(
  component : @common.Component,
  params : BevelGearParams,
  g : BevelGearGeometry,
  front_max_mm : Double,
  root_z_mm : Double,
  root_radius_mm : Double,
) -> @common.Component {
  let has_hub = params.hub_diameter_mm > 0.0
  let has_bore = params.bore_diameter_mm > 0.0
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let hub_back = if has_hub {
    root_z_mm -
    params.hub_length_mm -
    (root_radius_mm - params.hub_diameter_mm / 2.0) * @math.tan(delta)
  } else {
    root_z_mm
  }
  let front_z = g.axial_face_width_mm
  let bore_top_z = match params.front_recess_z_mm {
    Some(rz) => rz
    None => front_z
  }
  let bore = if has_bore {
    component.with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, hub_back),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.bore_diameter_mm,
        depth_mm=bore_top_z - hub_back,
        description="central bore, entered from the backing/hub end",
      ),
    )
  } else {
    component
  }
  let base = bore
    .with_connector_unchecked(
      @common.MateConnector::new(
        "backing-plane",
        placement=@common.Placement::translation(0.0, 0.0, root_z_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * root_radius_mm,
        description="flat backing face at the root circle",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "front-face",
        placement=@common.Placement::translation(0.0, 0.0, front_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * front_max_mm,
        description="small flat end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pitch-apex",
        placement=@common.Placement::translation(0.0, 0.0, g.apex_distance_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * g.cone_distance_mm,
        description="pitch cone apex datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "reference-circle",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * g.pitch_radius_mm,
        description="outer reference circle datum",
      ),
    )
  let with_hub = if has_hub {
    base
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hub-face",
        placement=@common.Placement::translation(0.0, 0.0, hub_back),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=params.hub_diameter_mm,
        description="hub back face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hub-outer",
        placement=@common.Placement::translation(0.0, 0.0, hub_back),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=params.hub_diameter_mm,
        depth_mm=params.hub_length_mm,
        description="hub outside diameter",
      ),
    )
  } else {
    base
  }
  let bore_r = params.bore_diameter_mm / 2.0
  let keyed = if params.keyway_width_mm > 0.0 && bore_r > 0.0 {
    let ang = params.keyway_angle_deg * @math.PI / 180.0
    let floor_r = bore_r + params.keyway_depth_mm
    with_hub.with_connector_unchecked(
      @common.MateConnector::new(
        "keyway",
        placement=@common.Placement::translation(
          floor_r * @math.cos(ang),
          floor_r * @math.sin(ang),
          hub_back,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=params.keyway_width_mm,
        depth_mm=bore_top_z - hub_back,
        description="parallel bore keyway, width given, entered from the hub end along +Z",
      ),
    )
  } else {
    with_hub
  }
  if params.set_screw_diameter_mm > 0.0 && has_hub {
    let ang = params.set_screw_angle_deg * @math.PI / 180.0
    let ux = @math.cos(ang)
    let uy = @math.sin(ang)
    let offset = match params.set_screw_offset_mm {
      Some(value) => value
      None => params.hub_length_mm / 2.0
    }
    let z_s = hub_back + offset
    let hub_r = params.hub_diameter_mm / 2.0
    let wall = hub_r - bore_r
    keyed
    .with_connector_unchecked(
      @common.MateConnector::new(
        "set-screw-hole",
        placement=@common.Placement::translation(hub_r * ux, hub_r * uy, z_s),
        axis=(-ux, -uy, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.set_screw_diameter_mm + params.set_screw_clearance_mm,
        depth_mm=wall,
        description="modelled radial set-screw hole through the hub wall",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "set-screw-thread",
        placement=@common.Placement::translation(hub_r * ux, hub_r * uy, z_s),
        axis=(-ux, -uy, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=params.set_screw_diameter_mm,
        depth_mm=wall,
        description="declared set-screw thread; threads are not modelled",
      ),
    )
  } else {
    keyed
  }
}

///|
/// bevel_gear_pair builds an external straight bevel pair in its meshing pose.
///
/// Both gears share the pitch cone apex at the world origin. The driver's axis
/// is +Z and its body lies on -Z; the driven gear's axis is
/// `(-sin Sigma, 0, cos Sigma)`, so its body lies on the opposite side of the
/// apex and the two pitch cones are tangent along the common generator.
///
/// The driven gear is phased about its own axis so that a tooth space faces the
/// driver's tooth at that generator. The phase is computed from the geometry
/// rather than assumed, so odd tooth counts work as well as even ones. This is
/// a static assembly; it does not solve a kinematic train.
pub fn bevel_gear_pair(
  driver : BevelGearParams,
  driven : BevelGearParams,
  detail~ : @common.DetailLevel = Detailed,
  driver_color~ : @cad.Rgb = @cad.Rgb::orange(),
  driven_color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@assemblies.Assembly, @common.SpecError] {
  if !@common.near(driver.module_mm, driven.module_mm, tol=@step.TOL_1E9) {
    return Err(@common.InvalidParameter("bevel pair requires the same module"))
  }
  if !@common.near(
      driver.pressure_angle_deg,
      driven.pressure_angle_deg,
      tol=@step.TOL_1E9,
    ) {
    return Err(
      @common.InvalidParameter("bevel pair requires the same pressure angle"),
    )
  }
  if !@common.near(
      driver.shaft_angle_deg,
      driven.shaft_angle_deg,
      tol=@step.TOL_1E9,
    ) {
    return Err(
      @common.InvalidParameter("bevel pair requires the same shaft angle"),
    )
  }
  if !@common.near(
      driver.addendum_factor,
      driven.addendum_factor,
      tol=@step.TOL_1E9,
    ) ||
    !@common.near(
      driver.dedendum_factor,
      driven.dedendum_factor,
      tol=@step.TOL_1E9,
    ) {
    return Err(
      @common.InvalidParameter(
        "bevel pair requires the same addendum and dedendum factors",
      ),
    )
  }
  let g1 = driver.geometry()
  let g2 = driven.geometry()
  if !@common.near(
      g1.pitch_angle_deg + g2.pitch_angle_deg,
      driver.shaft_angle_deg,
      tol=@step.TOL_1E6,
    ) {
    return Err(
      @common.InvalidParameter(
        "bevel pair pitch angles do not sum to the shaft angle",
      ),
    )
  }
  if !@common.near(g1.cone_distance_mm, g2.cone_distance_mm, tol=@step.TOL_1E6) {
    return Err(@common.InvalidParameter("bevel pair cone distances differ"))
  }
  let driver_component = match bevel_gear(driver, detail~, color=driver_color) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let driven_component = match bevel_gear(driven, detail~, color=driven_color) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  // Driver: apex at the origin, axis +Z, body on -Z.
  let p1 = @common.Placement::translation(0.0, 0.0, -g1.apex_distance_mm)

  // Driven: rotate its local +Z to (-sin Sigma, 0, cos Sigma), phase it about
  // its own axis, then move its apex to the origin.
  let sigma_deg = driver.shaft_angle_deg
  let delta1 = g1.pitch_angle_deg * @math.PI / 180.0
  let generator = (@math.sin(delta1), 0.0, -@math.cos(delta1))
  let pre = @common.Placement::rotation_y(sigma_deg)
  let contact = pre.apply_dir(generator)
  let theta2 = @math.atan2(contact.1, contact.0)
  let pitch2 = 2.0 * @math.PI / driven.teeth.to_double()
  let half_space = @math.PI / driven.teeth.to_double()
  let phase = theta2 -
    half_space -
    pitch2 * Double::floor((theta2 - half_space) / pitch2)
  let phase_deg = phase * 180.0 / @math.PI
  let rot = @common.Placement::compose(
    @common.Placement::rotation_y(-sigma_deg),
    @common.Placement::rotation_z(phase_deg),
  )
  let apex2 = rot.apply_dir((0.0, 0.0, g2.apex_distance_mm))
  let p2 = @common.Placement::compose(
    @common.Placement::translation(-apex2.0, -apex2.1, -apex2.2),
    rot,
  )
  let name = "bevel-gear-pair-\{driver.designation()}-\{driven.designation()}"
  Ok(
    @assemblies.Assembly::new(
      name~,
      description="External straight bevel gear pair with the pitch apex at the origin and the driven gear phased for mesh. Static assembly; no kinematic constraints.",
    )
    .add(driver_component, placement=p1, instance_name="driver")
    .add(driven_component, placement=p2, instance_name="driven"),
  )
}

///|
/// with_bevel_connectors attaches a bore (when present), the reference circle,
/// the flat end faces, and the pitch apex to a straight bevel gear.
fn with_bevel_connectors(
  component : @common.Component,
  params : BevelGearParams,
  g : BevelGearGeometry,
  tip_radius_mm : Double,
) -> @common.Component {
  let inner_tip = tip_radius_mm * g.small_end_scale
  let has_hub = params.hub_diameter_mm > 0.0
  let bore_z = if has_hub { -params.hub_length_mm } else { 0.0 }
  let bore_depth = g.axial_face_width_mm +
    (if has_hub { params.hub_length_mm } else { 0.0 })
  let bore = if params.bore_diameter_mm > 0.0 {
    component.with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, bore_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.bore_diameter_mm,
        depth_mm=bore_depth,
        description=if has_hub {
          "central bore, entered from the hub face"
        } else {
          "central bore, entered from the large end"
        },
      ),
    )
  } else {
    component
  }
  let with_faces = bore
    .with_connector_unchecked(
      @common.MateConnector::new(
        "reference-plane",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * tip_radius_mm,
        description="large flat end face (back face)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "front-face",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          g.axial_face_width_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * inner_tip,
        description="small flat end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pitch-apex",
        placement=@common.Placement::translation(0.0, 0.0, g.apex_distance_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * g.cone_distance_mm,
        description="pitch cone apex datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "reference-circle",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=2.0 * g.pitch_radius_mm,
        description="outer reference circle datum on the large face",
      ),
    )
  if has_hub {
    with_faces
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hub-face",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          -params.hub_length_mm,
        ),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=params.hub_diameter_mm,
        description="hub back face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "hub-outer",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          -params.hub_length_mm,
        ),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=params.hub_diameter_mm,
        depth_mm=params.hub_length_mm,
        description="hub outside diameter",
      ),
    )
  } else {
    with_faces
  }
}
