///|
fn cyc_seg_intersect(
  a : (Double, Double),
  b : (Double, Double),
  c : (Double, Double),
  d : (Double, Double),
) -> Bool {
  fn orient(
    p : (Double, Double),
    q : (Double, Double),
    r : (Double, Double),
  ) -> Double {
    (q.0 - p.0) * (r.1 - p.1) - (q.1 - p.1) * (r.0 - p.0)
  }
  let o1 = orient(a, b, c)
  let o2 = orient(a, b, d)
  let o3 = orient(c, d, a)
  let o4 = orient(c, d, b)
  o1 * o2 < -1.0e-12 && o3 * o4 < -1.0e-12
}

///|
test "cycloidal params validation rejects invalid and cusping configs" {
  assert_true(@cycloidal.CycloidalParams::new(num_lobes=2) is Err(_))
  assert_true(@cycloidal.CycloidalParams::new(num_disks=0) is Err(_))
  assert_true(@cycloidal.CycloidalParams::new(num_disks=4) is Err(_))
  // Excessive eccentricity causes cusping: e * (N + 1) / R >= 0.85.
  assert_true(
    @cycloidal.CycloidalParams::new(
      num_lobes=11,
      pin_circle_radius_mm=42.0,
      eccentricity_mm=3.2,
    )
    is Err(_),
  )
  // Default config is valid.
  assert_true(@cycloidal.CycloidalParams::new() is Ok(_))
}

///|
test "dual and triple cycloidal disks cancel radial center-of-mass unbalance" {
  for num_disks in [2, 3] {
    let params = match @cycloidal.CycloidalParams::new(num_disks~) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    let layout = @cycloidal.cycloidal_layout(params)
    for deg in [0.0, 23.0, 90.0, 147.0, 270.0, 315.0] {
      let kin = @cycloidal.cycloidal_kinematics(layout, deg)
      let mut sx = 0.0
      let mut sy = 0.0
      for d in kin.disks {
        sx = sx + d.center_x_mm
        sy = sy + d.center_y_mm
      }
      assert_true(sx.abs() < 1.0e-9)
      assert_true(sy.abs() < 1.0e-9)
    }
  }
}

///|
test "cycloidal disk outline is simple (non-self-intersecting) and signed CCW" {
  let params = match @cycloidal.CycloidalParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let pts = @cycloidal.cycloidal_disk_outline(params)
  let n = pts.length()
  assert_true(n == 11 * 16)
  // Signed area must be positive (CCW).
  let mut area2 = 0.0
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    area2 = area2 + (a.0 * b.1 - b.0 * a.1)
  }
  assert_true(area2 > 0.0)
  // Non-adjacent edges must not intersect.
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    for j in (i + 2)..<n {
      if i == 0 && j == n - 1 {
        continue
      }
      let c = pts[j]
      let d = pts[(j + 1) % n]
      assert_false(cyc_seg_intersect(a, b, c, d))
    }
  }
}

///|
test "full-360 kinematic clearance: ring pins clear disks and output pins stay in holes" {
  let params = match
    @cycloidal.CycloidalParams::new(num_lobes=11, num_disks=2) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let layout = @cycloidal.cycloidal_layout(params)
  assert_eq(layout.ring_pin_count, 12)
  assert_eq(layout.signed_reduction, -11.0)
  let disk_outlines = layout.disk_phase_rad.map(fn(phase) {
    @cycloidal.cycloidal_disk_outline(
      params,
      lobe_phase_rad=-phase / params.num_lobes.to_double(),
    )
  })
  // Sweep input angle across full 360 deg in 15-deg increments.
  for step in 0..<24 {
    let deg = step.to_double() * 15.0
    let kin = @cycloidal.cycloidal_kinematics(layout, deg)
    let c_out = @math.cos(kin.output_rad)
    let s_out = @math.sin(kin.output_rad)
    for d in 0..<params.num_disks {
      let pose = kin.disks[d]
      let c_d = @math.cos(pose.rotation_rad)
      let s_d = @math.sin(pose.rotation_rad)
      // 1. Every outer ring pin must clear every disk outline vertex by >= ring_pin_radius + tol - chord_margin.
      for pin in layout.ring_pins {
        let mut min_dist = 1.0e9
        for pt in disk_outlines[d] {
          let wx = pose.center_x_mm + pt.0 * c_d - pt.1 * s_d
          let wy = pose.center_y_mm + pt.0 * s_d + pt.1 * c_d
          let dx = wx - pin.0
          let dy = wy - pin.1
          let dist = (dx * dx + dy * dy).sqrt()
          if dist < min_dist {
            min_dist = dist
          }
        }
        assert_true(
          min_dist >= params.ring_pin_radius_mm + params.tolerance_mm - 0.04,
        )
      }
      // 2. Every output pin must stay inside its disk hole with exact radial clearance = tolerance_mm.
      for j in 0..<layout.output_pins.length() {
        let (ox0, oy0) = layout.output_pins[j]
        // Output pin center in housing frame:
        let px = ox0 * c_out - oy0 * s_out
        let py = ox0 * s_out + oy0 * c_out
        // Hole center in housing frame:
        let hx = pose.center_x_mm + ox0 * c_d - oy0 * s_d
        let hy = pose.center_y_mm + ox0 * s_d + oy0 * c_d
        let dist = ((px - hx) * (px - hx) + (py - hy) * (py - hy)).sqrt()
        // Distance between pin center and hole center is always exactly eccentricity_mm.
        assert_true((dist - params.eccentricity_mm).abs() < 1.0e-9)
        let clearance = layout.output_hole_radius_mm -
          dist -
          params.output_pin_radius_mm
        assert_true((clearance - params.tolerance_mm).abs() < 1.0e-9)
      }
    }
  }
}

///|
test "cycloidal_gearbox builds valid STEP component with expected layers and connectors" {
  let params = match @cycloidal.CycloidalParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let comp = match @cycloidal.cycloidal_gearbox(params) {
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
