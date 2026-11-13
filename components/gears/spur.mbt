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
  root_fillet_radius_mm : Double
  tip_chamfer_mm : Double
  fillet_segments : Int32
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
  root_fillet_radius_mm~ : Double = 0.0,
  tip_chamfer_mm~ : Double = 0.0,
  fillet_segments~ : Int32 = 4,
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
  // Backlash is a per-gear tooth-thickness reduction. More than half the
  // circular pitch would make the tooth thickness negative and the outline
  // self-intersecting (the ring builder already enforces the same bound).
  if backlash_mm >= @math.PI * module_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "gear backlash must be below half the circular pitch (pi * module / 2)",
      ),
    )
  }
  match
    @common.require_non_negative("root fillet radius", root_fillet_radius_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("tip chamfer", tip_chamfer_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if root_fillet_radius_mm > 0.4 * module_mm {
    return Err(
      @common.InvalidParameter(
        "root fillet radius must not exceed 0.4 * module",
      ),
    )
  }
  if tip_chamfer_mm > 0.3 * module_mm {
    return Err(
      @common.InvalidParameter("tip chamfer must not exceed 0.3 * module"),
    )
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
    root_fillet_radius_mm,
    tip_chamfer_mm,
    fillet_segments,
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
  smooth~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let geom = params.geometry()
  if geom.root_radius_mm <= 0.0 {
    return Err(@common.InvalidDimension("gear root radius must be positive"))
  }
  let policy = @common.DetailPolicy::for_level(detail)
  let outline = match
    external_involute_outline_ex(
      params.module_mm,
      params.teeth,
      params.pressure_angle_deg,
      backlash_mm=params.backlash_mm,
      involute_points=params.involute_points,
      arc_points=params.arc_points,
      root_fillet_radius_mm=params.root_fillet_radius_mm,
      tip_chamfer_mm=params.tip_chamfer_mm,
      fillet_segments=params.fillet_segments,
    ) {
    Ok(o) => o
    Err(e) => return Err(e)
  }
  let _ = policy
  // The polyline outline is faceted; `smooth` turns it into one closed cubic
  // B-spline contour (and a Bezier bore) extruded as a single smooth solid.
  let body = if smooth {
    @cad.ExtrudedArcProfile::new(
      arc_outline_runs(outline),
      params.face_width_mm,
      round_bore?=if params.bore_diameter_mm > 0.0 {
        Some(((0.0, 0.0), params.bore_diameter_mm))
      } else {
        None
      },
    ).as_shape()
  } else if params.bore_diameter_mm > 0.0 {
    @cad.ExtrudedProfile::new(
      outline,
      params.face_width_mm,
      round_bore=((0.0, 0.0), params.bore_diameter_mm),
    )
  } else {
    @cad.ExtrudedProfile::new(outline, params.face_width_mm)
  }
  let name = "spur-gear-\{params.designation()}"
  let mut features = @common.FeatureRecord::new(
    modeled=["body", "involute-tooth-envelope"],
    approximated=[
      @common.Approximation::new(
        feature="involute-flank",
        kind=@common.ApproximationKind::PolylineArc,
        // Conservative circle-chord upper bound; the actual involute polyline
        // deviation is smaller. It is never reported as exact (0).
        deviation_mm=@common.chord_deviation(
          geom.outer_radius_mm,
          params.involute_points,
        ),
        control="involute_points=\{params.involute_points} (upper bound)",
      ),
      @common.Approximation::new(
        feature="tip-and-root-arc",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(
          geom.outer_radius_mm,
          params.arc_points,
        ),
        control="arc_points=\{params.arc_points} (upper bound)",
      ),
    ],
    omitted=[
      @common.Omission::new(feature="hub", reason="no hub or web is modelled"),
      @common.Omission::new(
        feature="keyway",
        reason="not modelled; represent it with an evaluated cut",
      ),
    ],
  )
  if params.root_fillet_radius_mm > 0.0 {
    features = features
      .add_modeled("root-fillet")
      .add_approximated(
        @common.Approximation::new(
          feature="root-fillet-arc",
          kind=@common.ApproximationKind::PolylineArc,
          deviation_mm=gear_outline_deviation_mm(
            params.root_fillet_radius_mm,
            params.fillet_segments,
          ),
          control="fillet_segments=\{params.fillet_segments}",
        ),
      )
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="root-fillet",
        reason="sharp root corners at this builder",
      ),
    )
  }
  if params.tip_chamfer_mm > 0.0 {
    features = features.add_modeled("tip-chamfer")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="tip-chamfer",
        reason="not modelled by this builder",
      ),
    )
  }
  let pa = params.pressure_angle_deg * @math.PI / 180.0
  let z_min = 2.0 / (@math.sin(pa) * @math.sin(pa))
  if params.teeth.to_double() < z_min {
    features = features.add_omitted(
      @common.Omission::new(
        feature="undercut",
        reason="tooth count \{params.teeth} is below the standard no-undercut limit \{@cad.fmt_double(z_min, None)}; the profile is the theoretical involute to the base circle, not a cutter-generated trochoid",
      ),
    )
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="undercut",
        reason="not modelled; the profile is the theoretical involute",
      ),
    )
  }
  if params.bore_diameter_mm > 0.0 {
    let segments = if policy.circle_segments < 32 {
      32
    } else {
      policy.circle_segments
    }
    features = features.add_approximated(
      @common.Approximation::new(
        feature="bore",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(
          params.bore_diameter_mm / 2.0,
          segments,
        ),
        control="circle_segments=\{segments}",
      ),
    )
  }
  Ok(
    with_gear_connectors(
      @common.Component::new(
        name~,
        metadata=@common.Metadata::new(
          designation="Spur gear \{params.designation()}",
          standard="ISO 21771 involute geometry (parametric)",
          family="external involute spur gear",
          size=params.designation(),
          source="Involute gear formulas follow ISO 21771 / standard gear practice. Tip/root arcs are polygonal approximations.",
        ),
        description="External involute spur gear with optional central bore. Sharp root corners; no hub, keyway, or fillet.",
        features~,
      ).add_layer(body, name="body", color~),
      params.bore_diameter_mm,
      2.0 * geom.pitch_radius_mm,
      2.0 * geom.outer_radius_mm,
      params.face_width_mm,
    ),
  )
}

///|
/// spur_gear_envelope builds the blank envelope of a spur gear: a plain
/// cylinder at the tip diameter with an optional central bore, centred on
/// z = 0. Some catalogue references are simplified blanks rather than toothed
/// gears; `spur_gear` is the toothed builder.
pub fn spur_gear_envelope(
  params : SpurGearParams,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  let geom = params.geometry()
  let tip_diameter = 2.0 * geom.outer_radius_mm
  let body = if params.bore_diameter_mm > 0.0 {
    @cad.RevolvedProfile::tube(
      tip_diameter,
      params.bore_diameter_mm,
      params.face_width_mm,
    )
  } else {
    @cad.RevolvedProfile::cylinder(tip_diameter, params.face_width_mm)
  }
  let features = @common.FeatureRecord::new(
    modeled=["body", "tip-diameter-envelope", "bore"],
    omitted=[
      @common.Omission::new(
        feature="teeth",
        reason="the reference is a blank envelope; use spur_gear for an involute tooth form",
      ),
    ],
  )
  Ok(
    with_gear_connectors(
      @common.Component::new(
        name="spur-gear-envelope-\{params.designation()}",
        metadata=@common.Metadata::new(
          designation="Spur gear blank \{params.designation()}",
          standard="ISO 21771 tip-diameter envelope",
          family="external spur gear blank",
          size=params.designation(),
          source="tip diameter = module * (teeth + 2); plain cylinder with central bore",
        ),
        description="Spur gear blank envelope: a plain cylinder at the tip diameter with an optional central bore. No tooth form.",
        features~,
      )
      .add_layer(body.as_shape(), name="body", color~)
      .translate(z=-params.face_width_mm / 2.0),
      params.bore_diameter_mm,
      2.0 * geom.pitch_radius_mm,
      tip_diameter,
      params.face_width_mm,
      base_z_mm=-params.face_width_mm / 2.0,
    ),
  )
}
