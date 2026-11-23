///|
/// bevel_gear_back_cone builds the standard back-cone-ended gear: tooth ends on
/// the back cone, a flat annular backing plane inside the root circle, an
/// optional bore, and an optional flat-faced hub behind the backing.
fn bevel_gear_back_cone(
  params : BevelGearParams,
  g : BevelGearGeometry,
  detail~ : @common.DetailLevel,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let sector = if params.tip_land_radius_mm > 0.0 {
    // Solve the virtual tip radius so the projected maximum physical radius
    // equals the requested tip-land radius.
    let target = params.tip_land_radius_mm
    let mut lo = g.virtual_pitch_radius_mm
    let mut hi = g.virtual_pitch_radius_mm + g.addendum_mm
    for _ in 0..<48 {
      let mid = 0.5 * (lo + hi)
      let trial = match bevel_tooth_sector(params, g, tip_radius_virtual=mid) {
        Ok((s, _gap, _dev)) => s
        Err(e) => return Err(e)
      }
      if bevel_sector_max_back_radius(g, trial) > target {
        hi = mid
      } else {
        lo = mid
      }
    }
    match bevel_tooth_sector(params, g, tip_radius_virtual=lo) {
      Ok((s, _gap, _dev)) => s
      Err(e) => return Err(e)
    }
  } else {
    match bevel_tooth_sector(params, g) {
      Ok((s, _gap, _dev)) => s
      Err(e) => return Err(e)
    }
  }
  let (back, front, teeth, tips, snap_deviation) = match
    bevel_back_cone_data(g, sector, tooth_phase_deg=params.tooth_phase_deg) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let (root_z, root_radius) = bevel_back_cone_root(g)
  let rb = params.bore_diameter_mm / 2.0
  if rb >= root_radius {
    return Err(
      @common.InvalidParameter(
        "bevel bore does not fit inside the back-cone root circle",
      ),
    )
  }
  let mut back_max = 0.0
  for p in back {
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if r > back_max {
      back_max = r
    }
  }
  let mut front_max = 0.0
  let mut front_min = 1.0e300
  for p in front {
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if r > front_max {
      front_max = r
    }
    if r < front_min {
      front_min = r
    }
  }
  if rb > 0.0 && rb >= front_min {
    return Err(
      @common.InvalidParameter(
        "bevel bore does not fit inside the front root circle",
      ),
    )
  }
  let has_bore = rb > 0.0
  let has_hub = params.hub_diameter_mm > 0.0
  if has_hub && params.hub_diameter_mm / 2.0 > root_radius {
    return Err(
      @common.InvalidParameter(
        "bevel hub does not fit inside the backing root circle",
      ),
    )
  }
  let front_z = g.axial_face_width_mm
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let q = -g.pitch_radius_mm * @math.tan(delta)
  // Crop every tooth's tip land onto the face (tip) cone. The tip cone runs
  // through the outermost back-cone point and the front recess rim; its
  // intersection with the back cone is the circle at (r_tip, z_tip).
  let tip_cone_projected = params.tip_cone_trim &&
    tips.length() == teeth.length() &&
    tips.length() > 0
  if tip_cone_projected {
    let r_tip = if params.od_radius_mm > 0.0 && params.od_radius_mm < back_max {
      params.od_radius_mm
    } else {
      back_max
    }
    let z_tip = root_z + (r_tip - root_radius) * @math.tan(delta)
    bevel_snap_tip_land(
      back,
      front,
      tips,
      r_tip,
      z_tip,
      front_z,
      params.front_recess_radius_mm,
    )
    front_max = 0.0
    for p in front {
      let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
      if r > front_max {
        front_max = r
      }
    }
  }
  let shape = @cad.BevelGearBody::new(
    back,
    front,
    teeth,
    tips~,
    root_z_mm=root_z,
    front_z_mm=front_z,
    bore_radius_mm=rb,
    cone_apex_z_mm=q,
    cone_tan_half_angle=1.0 / @math.tan(delta),
    smooth=true,
    chamfer_mm=params.end_chamfer_mm,
  )
  let name = "bevel-gear-\{params.designation()}"
  let mut features = @common.FeatureRecord::new(
    modeled=[
      "body", "straight-bevel-cones", "back-cone-end", "backing-plane", "front-face",
    ],
    approximated=[
      @common.Approximation::new(
        feature="involute-flank",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(back_max, params.involute_points),
        control="involute_points=\{params.involute_points} (upper bound)",
      ),
      @common.Approximation::new(
        feature="tip-and-root-arc",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(back_max, params.arc_points),
        control="arc_points=\{params.arc_points} (upper bound)",
      ),
      @common.Approximation::new(
        feature="root-cone-snap",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=snap_deviation,
        control="root points projected to the coaxial root circle",
      ),
      @common.Approximation::new(
        feature="back-cone-cap",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(back_max, params.involute_points),
        control="triangle strips between each tooth boundary and the root circle",
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
      @common.Omission::new(feature="web", reason="no web is modelled"),
      @common.Omission::new(
        feature="contact-analysis",
        reason="static envelope; no contact, load, wear, or strength rating",
      ),
    ],
  )
  if tip_cone_projected {
    features = features.add_modeled("tip-cone")
  }
  if params.profile_shift != 0.0 {
    features = features.add_modeled("profile-shift")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="profile-shift",
        reason="no profile shift is modelled",
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
  if params.root_fillet_radius_mm > 0.0 {
    features = features.add_modeled("root-fillet")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="root-fillet",
        reason="root_fillet_radius_mm is 0; the root corners are sharp",
      ),
    )
  }
  let has_keyway = params.keyway_width_mm > 0.0
  let has_set_screw = params.set_screw_diameter_mm > 0.0
  if has_keyway {
    if rb + params.keyway_depth_mm >= front_min {
      return Err(
        @common.InvalidParameter(
          "bevel keyway depth leaves no wall at the small-end root circle",
        ),
      )
    }
    features = features.add_modeled("keyway")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="keyway",
        reason="keyway_width_mm is 0; no keyway is modelled",
      ),
    )
  }
  if has_set_screw {
    features = features.add_modeled("set-screw-hole")
    features = features.add_omitted(
      @common.Omission::new(
        feature="set-screw",
        reason="the set screw is a separate part and is declared by the set-screw-thread connector, not modelled",
      ),
    )
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="set-screw-hole",
        reason="set_screw_diameter_mm is 0; no radial set-screw hole is modelled",
      ),
    )
  }
  if params.edge_chamfer_mm > 0.0 && (rb > 0.0 || has_hub) {
    features = features.add_modeled("edge-chamfers")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="edge-chamfers",
        reason="edge_chamfer_mm is 0; the tooth ends, bore, and hub edges are sharp",
      ),
    )
  }
  if params.end_chamfer_mm > 0.0 {
    features = features.add_modeled("end-chamfer")
  } else {
    features = features.add_omitted(
      @common.Omission::new(
        feature="end-chamfer",
        reason="end_chamfer_mm is 0; the front outline is sharp",
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
  let body_node = shape.with_name("body")
  let tip_source = if tip_cone_projected {
    " The tooth tips are cropped onto the standard face cone."
  } else {
    ""
  }
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Bevel gear \{params.designation()}",
      standard="ISO 23509 bevel geometry; Tredgold back-cone equivalent spur gear; standard back-cone tooth ends",
      family="external straight bevel gear",
      size=params.designation(),
      source="Pitch, face, and root cones follow standard straight-bevel practice. Tooth ends lie on the standard back cone; the backing plane is the coaxial root circle. The tooth sector is the back-cone equivalent spur gear projected to the pitch apex." +
        tip_source,
    ),
    description="External straight bevel gear with standard back-cone tooth ends and a flat root-circle backing plane. Teeth are the Tredgold back-cone equivalent involute; the exact octoid/spherical involute is not modelled. Optional bore, flat-faced hub, keyway, and radial set-screw hole.",
    features~,
  )
  let hub_radius = params.hub_diameter_mm / 2.0
  let hub_setback = if has_hub {
    (root_radius - hub_radius) * @math.tan(delta)
  } else {
    0.0
  }
  let hub_back = root_z - params.hub_length_mm - hub_setback
  let has_edge_chamfer = params.edge_chamfer_mm > 0.0 && (rb > 0.0 || has_hub)
  let has_tip_cone_trim = params.tip_cone_trim
  let has_od_trim = params.od_radius_mm > 0.0 && !has_tip_cone_trim
  let has_front_recess = match params.front_recess_z_mm {
    Some(_) => true
    None => false
  }
  let selector_z_offset = if orient_to_reference { -hub_back } else { 0.0 }
  if has_keyway ||
    has_set_screw ||
    has_edge_chamfer ||
    has_od_trim ||
    has_tip_cone_trim ||
    has_front_recess {
    // The keyway, drill, OD trim, front recess, and chamfers must trim the
    // fused body and hub; the flat writer cannot represent that, so expose one
    // evaluated boolean layer. When a front recess is present, its revolved
    // cutter includes the front bore chamfer directly so only the hub's back
    // face needs edge-chamfering; otherwise chamfer only the exterior bore
    // circle(s) so the body/hub junction never acquires an internal groove.
    let body_solid = if params.edge_chamfer_mm > 0.0 &&
      rb > 0.0 &&
      !has_front_recess {
      let z_filter : Double? = if has_hub {
        Some(front_z + selector_z_offset)
      } else {
        None
      }
      let body_selector = @cad.EdgeSelector::EdgesAtRadii(
        [rb],
        z_filter,
        @step.TOL_1E3,
      )
      @cad.chamfer_edges(
        body_node,
        params.edge_chamfer_mm,
        selector=body_selector,
        name="bore-chamfers",
      )
    } else {
      body_node
    }
    let children : Array[@cad.SceneNode] = [body_solid]
    if has_hub {
      let hub_shape = bevel_hub_backing_shape(params, rb, root_radius)
      let hub_node = hub_shape.with_name("hub").translate(z=hub_back)
      let hub_solid = if has_edge_chamfer {
        let radii : Array[Double] = []
        if params.chamfer_hub_outer {
          radii.push(params.hub_diameter_mm / 2.0)
        }
        if has_bore {
          radii.push(rb)
        }
        if radii.is_empty() {
          hub_node
        } else {
          @cad.chamfer_edges(
            hub_node,
            params.edge_chamfer_mm,
            selector=@cad.EdgeSelector::EdgesAtRadii(
              radii,
              Some(hub_back + selector_z_offset),
              @step.TOL_1E3,
            ),
            name="hub-chamfers",
          )
        }
      } else {
        hub_node
      }
      children.push(hub_solid)
    }
    let fused = if children.length() == 1 {
      children[0]
    } else {
      @cad.union_all(children, name="bevel-gear-body")
    }
    let cutters : Array[@cad.SceneNode] = []
    if has_keyway {
      let keyway_top = match params.front_recess_z_mm {
        Some(rz) => rz
        None => front_z
      }
      cutters.push(bevel_keyway_cutter(params, hub_back, keyway_top))
    }
    if has_set_screw {
      let offset = match params.set_screw_offset_mm {
        Some(value) => value
        None => params.hub_length_mm / 2.0
      }
      cutters.push(bevel_set_screw_cutter(params, hub_back + offset))
    }
    if has_od_trim {
      cutters.push(
        @cad.RevolvedProfile::tube(
          2.0 * (back_max + 2.0),
          2.0 * params.od_radius_mm,
          front_z - root_z + 2.0,
        )
        .as_shape()
        .with_name("od-trim-cutter")
        .translate(z=root_z - 1.0),
      )
    }
    match params.front_recess_z_mm {
      Some(rz) => {
        let cot_d = 1.0 / @math.tan(delta)
        let r_floor = params.front_recess_radius_mm - (front_z - rz) * cot_d
        let ext_z = if has_tip_cone_trim { 2.0 } else { 1.0 }
        let r_top = params.front_recess_radius_mm + ext_z * cot_d
        let z_top = front_z + ext_z
        let profile : Array[@cad.Vec2] = if rb > 0.0 &&
          params.edge_chamfer_mm > 0.0 {
          let c = params.edge_chamfer_mm
          let inset = if rb > 0.5 { 0.5 } else { 0.5 * rb }
          let r_in = rb - inset
          let z_in = rz - c - inset
          [
            (0.0, z_in),
            (r_in, z_in),
            (rb + c, rz),
            (r_floor, rz),
            (r_top, z_top),
            (0.0, z_top),
          ]
        } else {
          [(0.0, rz), (r_floor, rz), (r_top, z_top), (0.0, z_top)]
        }
        cutters.push(
          @cad.RevolvedProfile::polyline(profile)
          .as_shape()
          .with_name("front-recess-cutter"),
        )
      }
      None => ()
    }
    let stage1 = if cutters.is_empty() {
      fused
    } else {
      @cad.difference(fused, cutters, name="body-trimmed")
    }
    // When the tip lands were snapped onto the face cone above, the outer shell
    // is already analytic; a boolean trim would only graze the near-coincident
    // tip surface and leave slivers, so it is skipped.
    let solid = if has_tip_cone_trim && !tip_cone_projected {
      let r_back_tip = if params.od_radius_mm > 0.0 {
        params.od_radius_mm
      } else {
        back_max
      }
      let z_back_tip = root_z + (r_back_tip - root_radius) * @math.tan(delta)
      let dz_tip = z_back_tip - front_z
      if Double::abs(dz_tip) <= @step.TOL_1E12 {
        return Err(
          @common.InvalidParameter(
            "bevel tip cone endpoints have zero axial span",
          ),
        )
      }
      let slope = (r_back_tip - params.front_recess_radius_mm) / dz_tip
      let z0 = root_z - 1.0
      let z1 = front_z + 1.0
      let r0 = params.front_recess_radius_mm + (z0 - front_z) * slope
      let r1 = params.front_recess_radius_mm + (z1 - front_z) * slope
      let r_edge = if r0 > r1 { r0 } else { r1 }
      let r_out = (if r_edge > back_max { r_edge } else { back_max }) + 2.0
      let tip_cutter = @cad.RevolvedProfile::polyline(
          [(r0, z0), (r_out, z0), (r_out, z1), (r1, z1)],
          closed=true,
        )
        .as_shape()
        .with_name("tip-cone-trim-cutter")
      @cad.difference(stage1, [tip_cutter], name="body")
    } else if tip_cone_projected {
      stage1
    } else if cutters.is_empty() {
      fused
    } else {
      @cad.difference(fused, cutters, name="body")
    }
    component = component.add_layer(solid.shape_intent(), name="body", color~)
  } else {
    component = component.add_layer(shape, name="body", color~)
    if has_hub {
      let hub_shape = bevel_hub_backing_shape(params, rb, root_radius)
      component = component.add_layer(
        hub_shape,
        name="hub",
        color~,
        placement=@common.Placement::translation(0.0, 0.0, hub_back),
      )
    }
  }
  let result = with_back_cone_connectors(
    component, params, g, front_max, root_z, root_radius,
  )
  if orient_to_reference {
    Ok(result.translate(z=-hub_back))
  } else {
    Ok(result)
  }
}
