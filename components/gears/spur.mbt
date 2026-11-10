///|
/// SpurGearParams is a validated external involute spur gear request.
pub(all) struct SpurGearParams {
  module_mm : Double
  teeth : Int32
  pressure_angle_deg : Double
  face_width_mm : Double
  bore_diameter_mm : Double
  backlash_mm : Double
  involute_points : Int32
  arc_points : Int32
}

///|
/// SpurGearParams::new validates a spur gear request.
pub fn SpurGearParams::new(
  module_mm~ : Double,
  teeth~ : Int32,
  pressure_angle_deg~ : Double = 20.0,
  face_width_mm~ : Double = 10.0,
  bore_diameter_mm~ : Double = 0.0,
  backlash_mm~ : Double = 0.0,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
) -> Result[SpurGearParams, @common.SpecError] {
  match @common.require_positive("gear module", module_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if teeth < 6 {
    return Err(@common.InvalidParameter("gear teeth must be >= 6"))
  }
  match
    @common.require_in_range("pressure angle", pressure_angle_deg, 10.0, 35.0) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("face width", face_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("bore diameter", bore_diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("gear backlash", backlash_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bore_diameter_mm >= module_mm * teeth.to_double() - 2.5 * module_mm {
    return Err(
      @common.InvalidDimension("bore diameter leaves no tooth root material"),
    )
  }
  Ok({
    module_mm,
    teeth,
    pressure_angle_deg,
    face_width_mm,
    bore_diameter_mm,
    backlash_mm,
    involute_points,
    arc_points,
  })
}

///|
/// SpurGearParams::geometry returns the computed radii.
pub fn SpurGearParams::geometry(self : SpurGearParams) -> InvoluteGearGeometry {
  involute_gear_geometry(self.module_mm, self.teeth, self.pressure_angle_deg)
}

///|
/// SpurGearParams::designation returns a compact gear designation.
pub fn SpurGearParams::designation(self : SpurGearParams) -> String {
  "m\{@cad.fmt_double(self.module_mm, None)}-z\{self.teeth}"
}

///|
/// spur_gear builds an external involute spur gear.
///
/// Axis +Z, base at z = 0. The gear body is one watertight extrusion with an
/// optional central bore. Teeth are true involute flanks; the tip and root
/// arcs are polygonal approximations controlled by `arc_points`.
pub fn spur_gear(
  params : SpurGearParams,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  let geom = params.geometry()
  if geom.root_radius_mm <= 0.0 {
    return Err(@common.InvalidDimension("gear root radius must be positive"))
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let outline = external_involute_outline(
    params.module_mm,
    params.teeth,
    params.pressure_angle_deg,
    backlash_mm=params.backlash_mm,
    involute_points=params.involute_points,
    arc_points=params.arc_points,
  )
  let holes : Array[Array[@cad.Vec2]] = []
  if params.bore_diameter_mm > 0.0 {
    let segments = if policy.circle_segments < 32 {
      32
    } else {
      policy.circle_segments
    }
    holes.push(@cad.Profile2D::circle(params.bore_diameter_mm, segments~).rev())
  }
  let body = @cad.ExtrudedProfile::new(outline, params.face_width_mm, holes~)
  let name = "spur-gear-\{params.designation()}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Spur gear \{params.designation()}",
        standard="ISO 21771 involute geometry (parametric)",
        family="external involute spur gear",
        size=params.designation(),
        source="Involute gear formulas follow ISO 21771 / standard gear practice. Tip/root arcs are polygonal approximations. Root fillet is not modeled. See components/DATA_SOURCES.md.",
      ),
      description="External involute spur gear with optional central bore. Sharp root corners; no hub, keyway, or fillet.",
    ).add_layer(body, name="body", color~),
  )
}
