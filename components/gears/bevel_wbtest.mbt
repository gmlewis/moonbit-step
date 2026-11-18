///|
fn bevel_close(actual : Double, expected : Double, tol : Double) -> Unit {
  if !((actual - expected).abs() <= tol) {
    abort("expected \{expected}, got \{actual} (tol \{tol})")
  }
}

///|
fn bevel_close_rel(actual : Double, expected : Double, rel : Double) -> Unit {
  let denom = if expected.abs() > 1.0e-12 { expected.abs() } else { 1.0 }
  bevel_close(actual, expected, denom * rel)
}

///|
fn bevel_count(haystack : String, needle : String) -> Int32 {
  let parts = haystack.split(needle).collect()
  parts.length() - 1
}

///|
fn bevel_p2040(bore~ : Double = 0.0) -> BevelGearParams {
  match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=40,
      shaft_angle_deg=90.0,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=bore,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
}

///|
fn bevel_outline_for(params : BevelGearParams) -> Array[@cad.Vec2] {
  let g = params.geometry()
  match bevel_outline(params, g) {
    Ok((o, _, _)) => o
    Err(e) => abort(e.message())
  }
}

///|
fn bevel_40_20(bore~ : Double = 0.0) -> BevelGearParams {
  match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=40,
      mate_teeth=20,
      shaft_angle_deg=90.0,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=bore,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
}

///|
fn bevel_fraction(x : Double) -> Double {
  x - x.floor()
}

///|
fn bevel_max_radius(points : Array[@cad.Vec2]) -> Double {
  let mut r = 0.0
  for p in points {
    let d = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if d > r {
      r = d
    }
  }
  r
}

///|
fn bevel_min_radius(points : Array[@cad.Vec2]) -> Double {
  let mut r = 1.0e300
  for p in points {
    let d = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if d < r {
      r = d
    }
  }
  r
}

///|
test "bevel geometry follows standard straight-bevel formulas" {
  let params = bevel_p2040()
  let g = params.geometry()
  let delta = @math.atan(20.0 / 40.0)
  let delta_deg = delta * 180.0 / @math.PI
  bevel_close(g.pitch_angle_deg, delta_deg, 1.0e-9)
  bevel_close(g.pitch_radius_mm, 20.0, 1.0e-12)
  let cone = 20.0 / @math.sin(delta)
  bevel_close_rel(g.cone_distance_mm, cone, 1.0e-12)
  bevel_close_rel(g.apex_distance_mm, cone * @math.cos(delta), 1.0e-12)
  bevel_close_rel(g.virtual_pitch_radius_mm, 20.0 / @math.cos(delta), 1.0e-12)
  bevel_close_rel(g.virtual_teeth, 20.0 / @math.cos(delta), 1.0e-12)
  let face = delta + @math.atan(2.0 / cone)
  let root = delta - @math.atan(2.5 / cone)
  bevel_close(g.face_cone_angle_deg, face * 180.0 / @math.PI, 1.0e-9)
  bevel_close(g.root_cone_angle_deg, root * 180.0 / @math.PI, 1.0e-9)
  bevel_close_rel(g.axial_face_width_mm, 10.0 * @math.cos(delta), 1.0e-12)
  bevel_close_rel(g.small_end_scale, (cone - 10.0) / cone, 1.0e-12)
}

///|
test "bevel geometry handles a miter pair and a non-right shaft angle" {
  let miter = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      shaft_angle_deg=90.0,
      face_width_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  bevel_close(miter.geometry().pitch_angle_deg, 45.0, 1.0e-9)
  let angled = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=40,
      shaft_angle_deg=120.0,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  bevel_close(angled.geometry().pitch_angle_deg, 30.0, 1.0e-9)
  let standalone = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=16,
      pitch_angle_deg=30.0,
      face_width_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  bevel_close(standalone.geometry().pitch_angle_deg, 30.0, 1.0e-12)
  // A standalone gear ignores the shaft angle.
  let ignored_shaft = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=16,
      pitch_angle_deg=30.0,
      shaft_angle_deg=0.0,
      face_width_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  bevel_close(ignored_shaft.geometry().pitch_angle_deg, 30.0, 1.0e-12)
}

///|
test "bevel tooth sector projects the pitch point and cone extents exactly" {
  let params = bevel_p2040()
  let g = params.geometry()
  let (sector, _gap_pts, _gap_dev) = match bevel_tooth_sector(params, g) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let pitch = bevel_project_sector(g, [(g.virtual_pitch_radius_mm, 0.0)])[0]
  bevel_close_rel(pitch.0, g.pitch_radius_mm, 1.0e-12)
  bevel_close(pitch.1, 0.0, 1.0e-12)

  let outline = bevel_outline_for(params)
  let tip = g.apex_distance_mm *
    @math.tan(g.face_cone_angle_deg * @math.PI / 180.0)
  bevel_close_rel(bevel_max_radius(outline), tip, 1.0e-12)
  let root = g.apex_distance_mm *
    @math.tan(g.root_cone_angle_deg * @math.PI / 180.0)
  assert_true(bevel_min_radius(outline) >= root - 1.0e-9)
  assert_true(bevel_min_radius(outline) <= root + 0.05)
  assert_true(@cad.polygon_area_2d(outline) > 0.0)
  // Replication drops exactly one duplicated junction point per sector.
  assert_eq(outline.length(), g.teeth * (sector.length() - 1))
}

///|
test "bevel gear builds a watertight single-layer component" {
  let params = bevel_p2040()
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let layers = component.layers()
  assert_eq(layers.length(), 1)
  let g = params.geometry()
  let outline = bevel_outline_for(params)
  let area = @cad.polygon_area_2d(outline)
  let h = g.axial_face_width_mm
  let k = g.small_end_scale
  let volume = match layers[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  bevel_close_rel(volume, area * h * (1.0 + k + k * k) / 3.0, 1.0e-9)

  let tip = g.apex_distance_mm *
    @math.tan(g.face_cone_angle_deg * @math.PI / 180.0)
  let (x0, x1, y0, y1, z0, z1) = layers[0].shape.bounding_box()
  bevel_close_rel(x0, -tip, 1.0e-9)
  bevel_close_rel(x1, tip, 1.0e-9)
  bevel_close_rel(y0, -tip, 1.0e-9)
  bevel_close_rel(y1, tip, 1.0e-9)
  bevel_close(z0, 0.0, 1.0e-12)
  bevel_close_rel(z1, h, 1.0e-12)

  let inventory = layers[0].shape.surface_inventory()
  assert_eq(inventory.plane, 2 + outline.length())
  assert_eq(inventory.cylinder, 0)
  assert_eq(inventory.cone, 0)
  assert_eq(inventory.bspline, 0)

  let step = component.to_step(checked=true)
  assert_false(step.contains("B_SPLINE_SURFACE"))
  assert_false(step.contains("CONICAL_SURFACE("))
  assert_eq(bevel_count(step, "CYLINDRICAL_SURFACE("), 0)
}

///|
test "bevel gear bore stays analytic and does not scale" {
  let params = bevel_p2040(bore=6.0)
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let g = params.geometry()
  let outline = bevel_outline_for(params)
  let area = @cad.polygon_area_2d(outline)
  let h = g.axial_face_width_mm
  let k = g.small_end_scale
  let volume = match component.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = area * h * (1.0 + k + k * k) / 3.0 - @math.PI * 9.0 * h
  bevel_close_rel(volume, expected, 1.0e-9)
  let inventory = component.layers()[0].shape.surface_inventory()
  assert_eq(inventory.cylinder, 1)
  let step = component.to_step(checked=true)
  assert_eq(bevel_count(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(bevel_count(step, "CIRCLE("), 2)
}

///|
test "bevel gear connectors describe the faces, bore, and apex" {
  let params = bevel_p2040(bore=6.0)
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(component.connectors().length(), 5)
  for
    name in [
      "bore", "reference-plane", "front-face", "pitch-apex", "reference-circle",
    ] {
    assert_true(
      match component.connector(name) {
        Ok(_) => true
        Err(_) => false
      },
    )
  }
  let bore = match component.connector("bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(bore.kind == @common.MateKind::CylindricalBore)
  assert_true(bore.gender == @common.MateGender::Female)
  let apex = match component.connector("pitch-apex") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(apex.kind == @common.MateKind::Datum)
  let face = match component.connector("reference-plane") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(face.kind == @common.MateKind::PlaneFace)
}

///|
test "bevel gear rejects invalid requests" {
  let bad_teeth = BevelGearParams::new(module_mm=2.0, teeth=5, mate_teeth=40)
  assert_true(
    match bad_teeth {
      Ok(_) => false
      Err(_) => true
    },
  )
  let bad_face = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    face_width_mm=20.0,
  )
  assert_true(
    match bad_face {
      Ok(_) => false
      Err(_) => true
    },
  )
  let both = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    pitch_angle_deg=30.0,
  )
  assert_true(
    match both {
      Ok(_) => false
      Err(_) => true
    },
  )
  let neither = BevelGearParams::new(module_mm=2.0, teeth=20)
  assert_true(
    match neither {
      Ok(_) => false
      Err(_) => true
    },
  )
  let bad_bore = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    bore_diameter_mm=200.0,
  )
  assert_true(
    match bad_bore {
      Ok(_) => false
      Err(_) => true
    },
  )
  let bad_angle = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    pressure_angle_deg=40.0,
  )
  assert_true(
    match bad_angle {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
fn bevel_check_contact(
  pair : @assemblies.Assembly,
  driver : BevelGearParams,
  driven : BevelGearParams,
) -> Unit {
  let items = pair.items()
  if items.length() != 2 {
    abort("expected 2 pair items, got \{items.length()}")
  }
  let g1 = driver.geometry()
  let g2 = driven.geometry()
  let apex1 = items[0].placement.apply_point((0.0, 0.0, g1.apex_distance_mm))
  let apex2 = items[1].placement.apply_point((0.0, 0.0, g2.apex_distance_mm))
  for apex in [apex1, apex2] {
    bevel_close(apex.0, 0.0, 1.0e-9)
    bevel_close(apex.1, 0.0, 1.0e-9)
    bevel_close(apex.2, 0.0, 1.0e-9)
  }
  let a1 = items[0].placement.apply_dir((0.0, 0.0, 1.0))
  let a2 = items[1].placement.apply_dir((0.0, 0.0, 1.0))
  bevel_close(a1.0, 0.0, 1.0e-12)
  bevel_close(a1.1, 0.0, 1.0e-12)
  bevel_close(a1.2, 1.0, 1.0e-12)
  let dot = a1.0 * a2.0 + a1.1 * a2.1 + a1.2 * a2.2
  bevel_close(dot, @math.cos(driver.shaft_angle_deg * @math.PI / 180.0), 1.0e-9)
  // The common generator carries the outer pitch point of both gears.
  let delta1 = g1.pitch_angle_deg * @math.PI / 180.0
  let radius = g1.cone_distance_mm
  let p_out = (radius * @math.sin(delta1), 0.0, -radius * @math.cos(delta1))
  let l1 = items[0].placement.inverse().apply_point(p_out)
  bevel_close(l1.0, g1.pitch_radius_mm, 1.0e-9)
  bevel_close(l1.1, 0.0, 1.0e-9)
  bevel_close(l1.2, 0.0, 1.0e-9)
  let l2 = items[1].placement.inverse().apply_point(p_out)
  let r2 = Double::sqrt(l2.0 * l2.0 + l2.1 * l2.1)
  bevel_close(r2, g2.pitch_radius_mm, 1.0e-9)
  bevel_close(l2.2, 0.0, 1.0e-9)
  // The contact lands on a tooth space of the driven gear.
  let pitch2 = 2.0 * @math.PI / driven.teeth.to_double()
  let space = @math.PI / driven.teeth.to_double()
  let az = @math.atan2(l2.1, l2.0)
  let frac = bevel_fraction((az - space) / pitch2)
  if !(frac < 1.0e-9 || frac > 1.0 - 1.0e-9) {
    abort("bevel contact is not on a driven tooth space (fraction \{frac})")
  }
}

///|
test "bevel pair shares the apex and phases a space onto the contact" {
  let driver = bevel_p2040()
  let driven = bevel_40_20()
  let pair = match bevel_gear_pair(driver, driven) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  bevel_check_contact(pair, driver, driven)
}

///|
test "bevel pair phases an odd driven tooth count" {
  let driver = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=41,
      shaft_angle_deg=90.0,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let driven = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=41,
      mate_teeth=20,
      shaft_angle_deg=90.0,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let pair = match bevel_gear_pair(driver, driven) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  bevel_check_contact(pair, driver, driven)
}

///|
fn bevel_local_inside(
  params : BevelGearParams,
  g : BevelGearGeometry,
  outline : Array[@cad.Vec2],
  p : @cad.Vec3,
) -> Bool {
  if p.2 < 0.0 || p.2 > g.axial_face_width_mm {
    return false
  }
  let s = (g.apex_distance_mm - p.2) / g.apex_distance_mm
  if s <= 0.0 {
    return false
  }
  let q = (p.0 / s, p.1 / s)
  if !@cad.is_point_in_polygon(q, outline) {
    return false
  }
  if params.bore_diameter_mm <= 0.0 {
    return true
  }
  let rb = params.bore_diameter_mm / 2.0
  p.0 * p.0 + p.1 * p.1 > rb * rb
}

///|
/// bevel_interference counts sampled surface points of each gear, moved 0.001 mm
/// into its material, that lie inside the other gear. A zero count is an
/// interference sanity check, not a contact solve.
fn bevel_interference(
  pair : @assemblies.Assembly,
  driver : BevelGearParams,
  driven : BevelGearParams,
) -> Int32 {
  let items = pair.items()
  let placements = [items[0].placement, items[1].placement]
  let params = [driver, driven]
  let geoms = [driver.geometry(), driven.geometry()]
  let outlines = [bevel_outline_for(driver), bevel_outline_for(driven)]
  let mut hits = 0
  for which in 0..<2 {
    let hg = geoms[which]
    let ho = outlines[which]
    let hp = placements[which]
    let other = params[1 - which]
    let og = geoms[1 - which]
    let oo = outlines[1 - which]
    let inv_other = placements[1 - which].inverse()
    let n = ho.length()
    let z_levels = 5
    for k in 0..<z_levels {
      let z = hg.axial_face_width_mm *
        (k.to_double() + 0.5) /
        z_levels.to_double()
      let s = (hg.apex_distance_mm - z) / hg.apex_distance_mm
      let mut i = 0
      while i < n {
        let (x, y) = ho[i]
        let r = Double::sqrt(x * x + y * y)
        let shrink = if r > 0.0 { (r - 1.0e-3) / r } else { 1.0 }
        let world = hp.apply_point((s * x * shrink, s * y * shrink, z))
        if bevel_local_inside(other, og, oo, inv_other.apply_point(world)) {
          hits = hits + 1
        }
        i = i + 5
      }
    }
  }
  hits
}

///|
test "bevel pair teeth clear at the nominal mesh" {
  for bl in [0.0, 0.05] {
    let driver = match
      BevelGearParams::new(
        module_mm=2.0,
        teeth=20,
        mate_teeth=40,
        shaft_angle_deg=90.0,
        face_width_mm=10.0,
        backlash_mm=bl,
      ) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    let driven = match
      BevelGearParams::new(
        module_mm=2.0,
        teeth=40,
        mate_teeth=20,
        shaft_angle_deg=90.0,
        face_width_mm=10.0,
        backlash_mm=bl,
      ) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    let pair = match bevel_gear_pair(driver, driven) {
      Ok(a) => a
      Err(e) => abort(e.message())
    }
    let hits = bevel_interference(pair, driver, driven)
    if hits != 0 {
      abort(
        "bevel pair interference: \{hits} sampled points overlap at backlash \{bl} mm",
      )
    }
  }
}

///|
test "bevel root fillet adds material and is declared" {
  let sharp = bevel_p2040()
  let filleted = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=40,
      shaft_angle_deg=90.0,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      root_fillet_radius_mm=0.2,
      fillet_segments=4,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let sharp_component = match bevel_gear(sharp) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let filleted_component = match bevel_gear(filleted) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let sharp_volume = match sharp_component.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let filleted_volume = match
    filleted_component.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(filleted_volume > sharp_volume)
  assert_true(filleted_component.features().has_modeled("root-fillet"))
  assert_true(filleted_component.features().has_approximated("root-fillet-arc"))
  let sharp_outline = bevel_outline_for(sharp)
  let filleted_outline = bevel_outline_for(filleted)
  assert_true(
    bevel_min_radius(filleted_outline) >=
    bevel_min_radius(sharp_outline) - 1.0e-9,
  )
  let step = filleted_component.to_step(checked=true)
  assert_true(step.contains("ADVANCED_FACE("))
}

///|
test "bevel root fillet rejects an oversized request" {
  let above_factor = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    face_width_mm=10.0,
    root_fillet_radius_mm=0.9,
  )
  assert_true(
    match above_factor {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "bevel hub adds a back layer and moves the bore entrance" {
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=40,
      shaft_angle_deg=90.0,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=6.0,
      hub_diameter_mm=14.0,
      hub_length_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let layers = component.layers()
  assert_eq(layers.length(), 2)
  assert_true(layers[1].name.contains("/hub"))
  let g = params.geometry()
  let (_x0, _x1, _y0, _y1, z0, z1) = component.bounding_box()
  bevel_close_rel(z0, -8.0, 1.0e-9)
  bevel_close_rel(z1, g.axial_face_width_mm, 1.0e-9)
  let hub_volume = match layers[1].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  bevel_close_rel(hub_volume, @math.PI * (7.0 * 7.0 - 3.0 * 3.0) * 8.0, 1.0e-9)
  let bore = match component.connector("bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  bevel_close_rel(bore.placement.trans.2, -8.0, 1.0e-9)
  bevel_close_rel(
    bore.depth_mm.unwrap_or(0.0),
    8.0 + g.axial_face_width_mm,
    1.0e-9,
  )
  assert_eq(component.connectors().length(), 7)
  assert_true(
    match component.connector("hub-face") {
      Ok(_) => true
      Err(_) => false
    },
  )
  assert_true(
    match component.connector("hub-outer") {
      Ok(_) => true
      Err(_) => false
    },
  )
  assert_true(component.features().has_modeled("hub"))
}

///|
test "bevel hub without a bore is a solid back boss" {
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=40,
      face_width_mm=10.0,
      hub_diameter_mm=14.0,
      hub_length_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(component.layers().length(), 2)
  let hub_volume = match component.layers()[1].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  bevel_close_rel(hub_volume, @math.PI * 7.0 * 7.0 * 8.0, 1.0e-9)
  assert_eq(component.connectors().length(), 6)
}

///|
test "bevel hub rejects one-sided or undersized dimensions" {
  let one_sided = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    face_width_mm=10.0,
    hub_diameter_mm=14.0,
  )
  assert_true(
    match one_sided {
      Ok(_) => false
      Err(_) => true
    },
  )
  let undersized = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=40,
    face_width_mm=10.0,
    bore_diameter_mm=6.0,
    hub_diameter_mm=6.0,
    hub_length_mm=8.0,
  )
  assert_true(
    match undersized {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "bevel back-cone end matches the McMaster 2600N5 envelope" {
  // McMaster-Carr metric bevel gear 2600N5 (90-degree shaft angle, module 2,
  // 20 teeth, 20-degree pressure angle): pitch dia 40 mm, OD 42.8 mm, face
  // width 10 mm, shaft 15 mm, hub 34 mm x 14 mm, overall width 24.9 mm, and
  // mounting distance 37 mm. The back-cone end reproduces the catalogue OD
  // exactly; the catalogue's overall width and mounting distance carry about
  // 1-2 mm of extra backing beyond the root-circle backing plane modelled here.
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      shaft_angle_deg=90.0,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      hub_diameter_mm=34.0,
      hub_length_mm=14.0,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let g = params.geometry()
  bevel_close_rel(2.0 * g.pitch_radius_mm, 40.0, 1.0e-12)
  assert_true((2.0 * g.standard_outer_radius_mm - 42.8).abs() <= 0.05)
  bevel_close_rel(
    g.axial_face_width_mm,
    10.0 * @math.cos(@math.PI / 4.0),
    1.0e-12,
  )
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(component.layers().length(), 2)
  let (x0, x1, _y0, _y1, z0, z1) = component.layers()[0].shape.bounding_box()
  // The back-cone tooth ends reproduce the standard outside diameter.
  bevel_close_rel(x1 - x0, 2.0 * g.standard_outer_radius_mm, 1.0e-9)
  bevel_close_rel(z1, g.axial_face_width_mm, 1.0e-12)
  assert_true(z0 < 0.0 && z0 > -0.05 * g.module_mm - 2.0)
  let features = component.features()
  assert_true(features.has_modeled("back-cone-end"))
  assert_true(features.has_modeled("backing-plane"))
  assert_true(features.has_approximated("root-cone-snap"))
  assert_true(features.has_approximated("back-cone-cap"))
  assert_true(features.has_modeled("bore"))
  assert_true(features.has_modeled("hub"))
  assert_false(features.has_approximated("flat-back-envelope"))
  let inventory = component.layers()[0].shape.surface_inventory()
  assert_eq(inventory.cylinder, 1)
  // Smooth back-cone body: two planar caps, one trimmed analytic back-cone
  // face per tooth, and one B-spline side per strip plus one gap land.
  assert_eq(inventory.plane, 2)
  assert_eq(inventory.cone, 20)
  assert_eq(inventory.bspline, 4 * 20)
  let step = component.to_step(checked=true)
  // Body bore, hub outside diameter, and hub bore.
  assert_eq(bevel_count(step, "CYLINDRICAL_SURFACE("), 3)
  assert_eq(bevel_count(step, "CIRCLE("), 6)
}

///|
test "back-cone end rejects the root fillet and an oversized hub" {
  let filleted = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      root_fillet_radius_mm=0.2,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(
    match bevel_gear(filleted) {
      Ok(_) => false
      Err(_) => true
    },
  )
  let big_hub = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      hub_diameter_mm=40.0,
      hub_length_mm=8.0,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(
    match bevel_gear(big_hub) {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "back-cone end works without a bore or hub" {
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(component.layers().length(), 1)
  let inventory = component.layers()[0].shape.surface_inventory()
  assert_eq(inventory.cylinder, 0)
  assert_true(
    match component.connector("bore") {
      Ok(_) => false
      Err(_) => true
    },
  )
  let step = component.to_step(checked=true)
  assert_eq(bevel_count(step, "CYLINDRICAL_SURFACE("), 0)
}

///|
test "bevel tip chamfer is modelled on both end faces" {
  for end_face in [Flat, BackCone] {
    let params = match
      BevelGearParams::new(
        module_mm=2.0,
        teeth=20,
        mate_teeth=20,
        face_width_mm=10.0,
        bore_diameter_mm=6.0,
        tip_chamfer_mm=0.1,
        end_face~,
      ) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    let component = match bevel_gear(params) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(component.features().has_modeled("tip-chamfer"))
    let step = component.to_step(checked=true)
    assert_true(step.contains("ADVANCED_FACE("))
  }
}

///|
test "bevel tip chamfer rejects an oversized request" {
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      tip_chamfer_mm=5.0,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(
    match bevel_gear(params) {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "back-cone keyway and set-screw produce one evaluated layer" {
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      hub_diameter_mm=34.0,
      hub_length_mm=14.0,
      keyway_width_mm=5.0,
      keyway_depth_mm=2.3,
      set_screw_diameter_mm=5.0,
      edge_chamfer_mm=0.375,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // The cuts and chamfer force one evaluated boolean layer over the fused
  // body and hub; the flat writer refuses it, as documented.
  assert_eq(component.layers().length(), 1)
  assert_true(component.features().has_modeled("keyway"))
  assert_true(component.features().has_modeled("set-screw-hole"))
  assert_true(component.features().has_modeled("edge-chamfers"))
  assert_eq(component.connectors().length(), 10)
  assert_true(
    match component.connector("keyway") {
      Ok(_) => true
      Err(_) => false
    },
  )
  assert_true(
    match component.connector("set-screw-hole") {
      Ok(_) => true
      Err(_) => false
    },
  )
  assert_true(
    match component.connector("set-screw-thread") {
      Ok(_) => true
      Err(_) => false
    },
  )
  let (x0, x1, _y0, _y1, z0, z1) = component.bounding_box()
  let g = params.geometry()
  bevel_close_rel(x1 - x0, 2.0 * g.standard_outer_radius_mm, 1.0e-9)
  let (root_z, _root_radius) = bevel_back_cone_root(g)
  bevel_close_rel(z0, root_z - params.hub_length_mm, 1.0e-9)
  bevel_close_rel(z1, g.axial_face_width_mm, 1.0e-9)
}

///|
test "bevel keyway and set-screw validation" {
  let no_bore = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=20,
    face_width_mm=10.0,
    keyway_width_mm=5.0,
    keyway_depth_mm=2.3,
    end_face=BackCone,
  )
  assert_true(
    match no_bore {
      Ok(_) => false
      Err(_) => true
    },
  )
  let overlap = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=20,
    face_width_mm=10.0,
    bore_diameter_mm=15.0,
    hub_diameter_mm=34.0,
    hub_length_mm=14.0,
    keyway_width_mm=5.0,
    keyway_depth_mm=2.3,
    set_screw_diameter_mm=5.0,
    set_screw_angle_deg=270.0,
    end_face=BackCone,
  )
  assert_true(
    match overlap {
      Ok(_) => false
      Err(_) => true
    },
  )
  let flat_chamfer = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=20,
    face_width_mm=10.0,
    bore_diameter_mm=15.0,
    hub_diameter_mm=34.0,
    hub_length_mm=14.0,
    edge_chamfer_mm=0.375,
    end_face=Flat,
  )
  assert_true(
    match flat_chamfer {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "explicit end chamfer builds a closed band" {
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      hub_diameter_mm=34.0,
      hub_length_mm=14.0,
      end_chamfer_mm=0.375,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(component.features().has_modeled("end-chamfer"))
  let inventory = component.layers()[0].shape.surface_inventory()
  // Three side strips plus the gap land, each with a side and a chamfer-band
  // surface, one trimmed back-cone face per tooth, two planes, and the bore.
  assert_eq(inventory.bspline, 8 * 20)
  assert_eq(inventory.cone, 20)
  assert_eq(inventory.plane, 2)
  assert_eq(inventory.cylinder, 1)
  let step = component.to_step(checked=true)
  assert_true(step.contains("B_SPLINE_SURFACE_WITH_KNOTS"))
}

///|
test "bevel end chamfer validation" {
  let too_large = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=20,
    face_width_mm=10.0,
    bore_diameter_mm=15.0,
    hub_diameter_mm=34.0,
    hub_length_mm=14.0,
    end_chamfer_mm=1.5,
    end_face=BackCone,
  )
  assert_true(
    match too_large {
      Ok(_) => false
      Err(_) => true
    },
  )
  let flat = BevelGearParams::new(
    module_mm=2.0,
    teeth=20,
    mate_teeth=20,
    face_width_mm=10.0,
    bore_diameter_mm=15.0,
    hub_diameter_mm=34.0,
    hub_length_mm=14.0,
    end_chamfer_mm=0.3,
    end_face=Flat,
  )
  assert_true(
    match flat {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "tip land reproduces the golden outside diameter" {
  let land_radius = 21.0607
  let params = match
    BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      hub_diameter_mm=34.0,
      hub_length_mm=14.0,
      tip_land_radius_mm=land_radius,
      end_face=BackCone,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let component = match bevel_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, _z0, _z1) = component.bounding_box()
  // The virtual addendum is solved so the projected tip reaches the land.
  bevel_close_rel(x1 - x0, 2.0 * land_radius, 1.0e-4)
  let step = component.to_step(checked=true)
  assert_true(step.contains("CONICAL_SURFACE"))
}
