///|
/// gear_pair_center_distance returns the standard external-mesh centre
/// distance plus an optional offset:
/// `m * (N1 + N2) / 2 + offset`.
pub fn gear_pair_center_distance(
  driver : SpurGearParams,
  driven : SpurGearParams,
  offset_mm~ : Double = 0.0,
) -> Double {
  driver.module_mm * (driver.teeth + driven.teeth).to_double() / 2.0 + offset_mm
}

///|
/// gear_pair builds a two-gear external mesh assembly.
///
/// The driver is at the origin with a tooth centred on +X. The driven gear is
/// placed at the standard centre distance along +X and rotated by half its
/// angular pitch so a tooth space faces the driver. `offset_mm` increases the
/// centre distance, which is the usual way to introduce backlash without
/// altering the tooth form.
///
/// This is a static geometric assembly; it does not solve a kinematic train.
pub fn gear_pair(
  driver : SpurGearParams,
  driven : SpurGearParams,
  offset_mm~ : Double = 0.05,
  detail~ : @common.DetailLevel = Detailed,
) -> Result[@assemblies.Assembly, @common.SpecError] {
  if !@common.near(driver.module_mm, driven.module_mm, tol=1.0e-9) {
    return Err(@common.InvalidParameter("gear pair requires the same module"))
  }
  if !@common.near(
      driver.pressure_angle_deg,
      driven.pressure_angle_deg,
      tol=1.0e-9,
    ) {
    return Err(
      @common.InvalidParameter("gear pair requires the same pressure angle"),
    )
  }
  let driver_component = match spur_gear(driver, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let driven_component = match spur_gear(driven, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let center = gear_pair_center_distance(driver, driven, offset_mm~)
  let half_pitch_deg = 180.0 / driven.teeth.to_double()
  let driven_angle = 180.0 + half_pitch_deg
  let name = "gear-pair-\{driver.designation()}-\{driven.designation()}"
  Ok(
    @assemblies.Assembly::new(
      name~,
      description="External involute gear pair at the standard centre distance plus offset. Static assembly; no kinematic constraints.",
    )
    .add(driver_component, instance_name="driver")
    .add(
      driven_component,
      placement=@common.Placement::at(center, 0.0, 0.0, rz=driven_angle),
      instance_name="driven",
    ),
  )
}
