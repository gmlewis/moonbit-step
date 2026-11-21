///|
test "harmonic params validation rejects odd tooth counts and too-small cups" {
  assert_true(@harmonic.HarmonicParams::new(flexspline_teeth=59) is Err(_))
  assert_true(@harmonic.HarmonicParams::new(flexspline_teeth=20) is Err(_))
  assert_true(@harmonic.HarmonicParams::new(tooth_diff=1) is Err(_))
  assert_true(
    @harmonic.HarmonicParams::new(gear_length_mm=12.0, cup_length_mm=14.0)
    is Err(_),
  )
  assert_true(@harmonic.HarmonicParams::new() is Ok(_))
}

///|
test "harmonic layout reduction ratio and radial balance symmetry" {
  let params = match
    @harmonic.HarmonicParams::new(flexspline_teeth=60, tooth_diff=2) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let layout = @harmonic.harmonic_layout(params)
  assert_eq(layout.circular_spline_teeth, 62)
  assert_eq(layout.signed_reduction, -30.0)
  assert_eq(layout.reduction_ratio, 30.0)
  // Both deformed flexspline and elliptical wave generator are 180-deg
  // symmetric, so their centroid stays at (0, 0) at every input angle.
  for deg in [0.0, 37.0, 90.0, 145.0, 270.0] {
    let kin = @harmonic.harmonic_kinematics(layout, deg)
    let flex = @harmonic.harmonic_flexspline_outline(
      layout,
      wave_gen_rad=kin.wave_gen_rad,
      deformed=true,
    )
    let mut fx = 0.0
    let mut fy = 0.0
    for pt in flex {
      fx = fx + pt.0
      fy = fy + pt.1
    }
    assert_true((fx / flex.length().to_double()).abs() < 1.0e-9)
    assert_true((fy / flex.length().to_double()).abs() < 1.0e-9)

    let wg = @harmonic.harmonic_wave_generator_outline(
      layout,
      wave_gen_rad=kin.wave_gen_rad,
    )
    let mut wx = 0.0
    let mut wy = 0.0
    for pt in wg {
      wx = wx + pt.0
      wy = wy + pt.1
    }
    assert_true((wx / wg.length().to_double()).abs() < 1.0e-9)
    assert_true((wy / wg.length().to_double()).abs() < 1.0e-9)
  }
}

///|
test "deformed flexspline engages at major axis and clears at minor axis" {
  let params = match
    @harmonic.HarmonicParams::new(
      module_mm=1.0,
      flexspline_teeth=60,
      tooth_diff=2,
      tolerance_mm=0.15,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let layout = @harmonic.harmonic_layout(params)
  let flex = @harmonic.harmonic_flexspline_outline(
    layout,
    wave_gen_rad=0.0,
    deformed=true,
  )
  // Check signed area > 0 (CCW).
  let n = flex.length()
  let mut area2 = 0.0
  for i in 0..<n {
    let a = flex[i]
    let b = flex[(i + 1) % n]
    area2 = area2 + (a.0 * b.1 - b.0 * a.1)
  }
  assert_true(area2 > 0.0)
  // Find max radius near major axis (|y| small) and max radius near minor axis (|x| small).
  let mut max_r_major = 0.0
  let mut max_r_minor = 0.0
  for pt in flex {
    let r = (pt.0 * pt.0 + pt.1 * pt.1).sqrt()
    let ang = @math.atan2(pt.1, pt.0).abs()
    if ang < 0.08 || (3.141592653589793 - ang).abs() < 0.08 {
      if r > max_r_major {
        max_r_major = r
      }
    }
    if (ang - 1.5707963267948966).abs() < 0.08 {
      if r > max_r_minor {
        max_r_minor = r
      }
    }
  }
  // Major axis: flexspline tips engage past circular spline tips, yet clear circular spline root.
  assert_true(max_r_major > layout.circ_tip_radius_mm)
  assert_true(max_r_major < layout.circ_root_radius_mm)
  // Minor axis: flexspline tips completely disengage inside circular spline tips.
  assert_true(max_r_minor < layout.circ_tip_radius_mm)
}

///|
test "harmonic_gearbox builds valid STEP in both deformed and unstressed modes" {
  for deformed in [true, false] {
    let params = match @harmonic.HarmonicParams::new(deformed~) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    let comp = match @harmonic.harmonic_gearbox(params) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    let names = comp.connectors().map(fn(c) { c.name })
    assert_true(names.contains("ring-outer-seat"))
    assert_true(names.contains("ring-face-a"))
    assert_true(names.contains("ring-face-b"))
    assert_true(names.contains("input-bore"))
    assert_true(names.contains("output-face"))
    let step_text = comp.to_design().to_step_file()
    assert_true(step_text.contains("ISO-10303-21;"))
    assert_true(step_text.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
  }
}

///|
test "flat_harmonic_gearbox builds compact pancake split-ring STEP component" {
  let params = match @harmonic.FlatHarmonicParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let fl = @harmonic.flat_harmonic_layout(params)
  assert_eq(fl.base.signed_reduction, -30.0)
  // Pancake profile (15 mm) is significantly shorter than cup-style (24 mm).
  assert_true(fl.total_length_mm < 20.0)
  let comp = match @harmonic.flat_harmonic_gearbox(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let step_text = comp.to_design().to_step_file()
  assert_true(step_text.contains("ISO-10303-21;"))
  assert_true(step_text.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
}
