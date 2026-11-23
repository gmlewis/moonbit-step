///|
/// bevel_gear builds an external straight bevel gear.
///
/// Axis +Z. The large flat face is at z = 0 and the small end at
/// z = axial_face_width_mm; the pitch cone apex is at
/// z = apex_distance_mm. Teeth are the Tredgold back-cone equivalent involute;
/// the exact octoid/spherical involute is not modelled. The root fillet is
/// optional and is applied in the back-cone construction plane. No hub, web, or
/// crown is modelled.
pub fn bevel_gear(
  params : BevelGearParams,
  detail~ : @common.DetailLevel = Detailed,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let g = params.geometry()
  match params.end_face {
    BackCone =>
      return bevel_gear_back_cone(
        params,
        g,
        detail~,
        orient_to_reference~,
        color~,
      )
    Flat => ()
  }
  let (outline, gap_pts, gap_deviation) = match bevel_outline(params, g) {
    Ok(o) => o
    Err(e) => return Err(e)
  }
  let has_bore = params.bore_diameter_mm > 0.0
  let has_hub = params.hub_diameter_mm > 0.0
  let shape = @cad.ConicalExtrusion::new(
    outline,
    g.axial_face_width_mm,
    g.apex_distance_mm,
    round_bore?=if has_bore {
      Some(((0.0, 0.0), params.bore_diameter_mm))
    } else {
      None
    },
  )
  let tip_radius = g.apex_distance_mm *
    @math.tan(g.face_cone_angle_deg * @math.PI / 180.0)
  let name = "bevel-gear-\{params.designation()}"
  let mut features = @common.FeatureRecord::new(
    modeled=["body", "straight-bevel-cones", "flat-back", "flat-front"],
    approximated=[
      @common.Approximation::new(
        feature="involute-flank",
        kind=@common.ApproximationKind::PolylineArc,
        // Conservative circle-chord upper bound; the actual Tredgold flank
        // deviation is smaller.
        deviation_mm=@common.chord_deviation(tip_radius, params.involute_points),
        control="involute_points=\{params.involute_points} (upper bound)",
      ),
      @common.Approximation::new(
        feature="tip-and-root-arc",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(tip_radius, params.arc_points),
        control="arc_points=\{params.arc_points} (upper bound)",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="exact-octoid-or-spherical-involute",
        reason="the tooth sector is the Tredgold back-cone equivalent spur gear projected to the pitch apex; the exact octoid/spherical involute is not modelled",
      ),
      @common.Omission::new(
        feature="crown",
        reason="no lengthwise or heightwise crowning",
      ),
      @common.Omission::new(
        feature="profile-shift",
        reason="no profile shift is modelled",
      ),
      @common.Omission::new(
        feature="keyway",
        reason="no keyway is modelled; represent it with an evaluated cut",
      ),
      @common.Omission::new(
        feature="set-screw",
        reason="no tapped set-screw hole is modelled",
      ),
      @common.Omission::new(
        feature="contact-analysis",
        reason="static envelope; no contact, load, wear, or strength rating",
      ),
    ],
  )
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
  if gap_pts < params.arc_points {
    features = features.add_approximated(
      @common.Approximation::new(
        feature="root-gap-chord",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=gap_deviation,
        control="root_gap_segments=\{gap_pts} (reduced to seat the root fillet)",
      ),
    )
  }
  if params.root_fillet_radius_mm > 0.0 {
    features = features
      .add_modeled("root-fillet")
      .add_approximated(
        @common.Approximation::new(
          feature="root-fillet-arc",
          kind=@common.ApproximationKind::PolylineArc,
          deviation_mm=@common.chord_deviation(
            params.root_fillet_radius_mm,
            params.fillet_segments,
          ),
          control="fillet_segments=\{params.fillet_segments} (back-cone construction radius)",
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
  if has_bore {
    features = features.add_modeled("bore")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="bore",
        reason="bore_diameter_mm is 0; no central bore is modelled",
      ),
    )
  }
  if has_hub {
    features = features.add_modeled("hub")
  } else {
    features = features.add_omitted(
      @common.Omission::new(feature="hub", reason="no hub is modelled"),
    )
  }
  if tip_radius > g.standard_outer_radius_mm + @step.TOL_1E9 {
    features = features.add_approximated(
      @common.Approximation::new(
        feature="flat-back-envelope",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=tip_radius - g.standard_outer_radius_mm,
        control="flat back through the reference plane; standard back-cone OD = d + 2*h_a*cos(delta)",
      ),
    )
  }
  let pa = params.pressure_angle_deg * @math.PI / 180.0
  let z_min = 2.0 / (@math.sin(pa) * @math.sin(pa))
  if g.virtual_teeth < z_min {
    features = features.add_omitted(
      @common.Omission::new(
        feature="undercut",
        reason="equivalent tooth count \{@cad.fmt_double(g.virtual_teeth, None)} is below the standard no-undercut limit \{@cad.fmt_double(z_min, None)}; the profile is the theoretical involute, not a cutter-generated trochoid",
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
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Bevel gear \{params.designation()}",
      standard="ISO 23509 bevel geometry; Tredgold back-cone equivalent spur gear (approximate tooth form)",
      family="external straight bevel gear",
      size=params.designation(),
      source="Pitch, face, and root cones follow standard straight-bevel practice. The tooth sector is the back-cone equivalent spur gear projected to the pitch apex. End faces are planes perpendicular to the gear axis.",
    ),
    description="External straight bevel gear with flat axial end faces, an optional central bore, an optional root fillet, and an optional hub behind the large face. Teeth are the Tredgold back-cone equivalent involute; the exact octoid/spherical involute is not modelled. The root fillet is applied in the back-cone construction plane. No web or crown.",
    features~,
  ).add_layer(shape, name="body", color~)
  if has_hub {
    let hub_shape = if has_bore {
      @cad.RevolvedProfile::tube(
        params.hub_diameter_mm,
        params.bore_diameter_mm,
        params.hub_length_mm,
      ).as_shape()
    } else {
      @cad.RevolvedProfile::cylinder(
        params.hub_diameter_mm,
        params.hub_length_mm,
      ).as_shape()
    }
    component = component.add_layer(
      hub_shape,
      name="hub",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, -params.hub_length_mm),
    )
  }
  let result = with_bevel_connectors(component, params, g, tip_radius)
  if orient_to_reference && has_hub {
    Ok(result.translate(z=params.hub_length_mm))
  } else {
    Ok(result)
  }
}

///|
/// bevel_keyway_cutter returns a radial rectangular cutter that opens a
/// parallel keyway through the bore, from `back_z_mm` to `front_z_mm`.
fn bevel_keyway_cutter(
  params : BevelGearParams,
  back_z_mm : Double,
  front_z_mm : Double,
) -> @cad.SceneNode {
  let bore_r = params.bore_diameter_mm / 2.0
  let floor_r = bore_r + params.keyway_depth_mm
  let half = params.keyway_width_mm / 2.0
  let ang = params.keyway_angle_deg * @math.PI / 180.0
  let ux = @math.cos(ang)
  let uy = @math.sin(ang)
  let vx = -uy
  let vy = ux
  let corner = fn(ru : Double, rv : Double) -> @cad.Vec2 {
    (ru * ux + rv * vx, ru * uy + rv * vy)
  }
  let outer : Array[@cad.Vec2] = [
    corner(0.0, half),
    corner(0.0, -half),
    corner(floor_r, -half),
    corner(floor_r, half),
  ]
  let height = front_z_mm - back_z_mm + 2.0
  @cad.ExtrudedProfile::new(outer, height)
  .with_name("keyway-cutter")
  .translate(z=back_z_mm - 1.0)
}

///|
/// bevel_set_screw_cutter returns the radial drill that opens the set-screw
/// hole from the hub outside diameter into the bore at axial position `z_mm`.
fn bevel_set_screw_cutter(
  params : BevelGearParams,
  z_mm : Double,
) -> @cad.SceneNode {
  let hub_r = params.hub_diameter_mm / 2.0
  let start_r = hub_r + 1.0
  let length = start_r + 1.0
  let ang = params.set_screw_angle_deg * @math.PI / 180.0
  let ux = @math.cos(ang)
  let uy = @math.sin(ang)
  // A +Z cylinder rotated onto +Y and then about Z so its axis points inward
  // along -u, starting one millimetre outside the hub and ending past the axis.
  @cad.Cylinder::new(
    params.set_screw_diameter_mm + params.set_screw_clearance_mm,
    length,
  )
  .with_name("set-screw-hole-cutter")
  .rotate_x(-90.0)
  .rotate_z(params.set_screw_angle_deg + 90.0)
  .translate(x=start_r * ux, y=start_r * uy, z=z_mm)
}

///|
/// bevel_hub_backing_shape returns the hub as one revolved solid: a cylindrical
/// hub of `hub_length_mm`, followed by a back-cone conical backing out to the
/// root circle at the gear's back-cone angle (90 - pitch_angle). The axial
/// backing length equals `(root_radius_mm - hub_r) * tan(pitch_angle)`.
fn bevel_hub_backing_shape(
  params : BevelGearParams,
  bore_radius_mm : Double,
  root_radius_mm : Double,
) -> @cad.Shape {
  let hub_r = params.hub_diameter_mm / 2.0
  let setback = (root_radius_mm - hub_r) * @math.tan(params.pitch_angle_rad())
  let top = params.hub_length_mm + setback
  if bore_radius_mm > 0.0 {
    @cad.RevolvedProfile::polyline(
      [
        (bore_radius_mm, 0.0),
        (hub_r, 0.0),
        (hub_r, params.hub_length_mm),
        (root_radius_mm, top),
        (bore_radius_mm, top),
      ],
      closed=true,
    ).as_shape()
  } else {
    @cad.RevolvedProfile::polyline([
      (0.0, 0.0),
      (hub_r, 0.0),
      (hub_r, params.hub_length_mm),
      (root_radius_mm, top),
      (0.0, top),
    ]).as_shape()
  }
}

///|
/// bevel_snap_tip_land moves each tooth's tip-land profile points onto the face
/// (tip) cone: the back row onto the cone's intersection circle with the back
/// cone, the front row onto the cone at the front plane. The tip land then
/// coincides with the analytic outer shell. The Tredgold tip arc otherwise sits
/// inside the cone at its corners, and a boolean trim can only remove material,
/// so the tooth's outer edge would stop short of the shell.
fn bevel_snap_tip_land(
  back : Array[@cad.Vec3],
  front : Array[@cad.Vec3],
  tips : Array[(Int32, Int32)],
  r_tip : Double,
  z_tip : Double,
  front_z : Double,
  front_radius : Double,
) -> Unit {
  for tip_range in tips {
    let (tip_start, tip_end) = tip_range
    for i in tip_start..<=tip_end {
      let bp = back[i]
      let ba = @math.atan2(bp.1, bp.0)
      back[i] = (r_tip * @math.cos(ba), r_tip * @math.sin(ba), z_tip)
      let fp = front[i]
      let fa = @math.atan2(fp.1, fp.0)
      front[i] = (
        front_radius * @math.cos(fa),
        front_radius * @math.sin(fa),
        front_z,
      )
    }
  }
}
