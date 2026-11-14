///|
/// Black-box tests for the helical beam coupling.

///|
fn hc_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-3
}

///|
fn hc_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  match part.connector(name) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn hc_has(part : @common.Component, name : String) -> Bool {
  match part.connector(name) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
test "helical coupling default size" {
  let size = @motion.helical_coupling_5_to_8()
  assert_true(hc_close(size.outer_diameter_mm, 25.0))
  assert_true(hc_close(size.length_mm, 30.0))
  assert_true(hc_close(size.bore_small_mm, 5.0))
  assert_true(hc_close(size.bore_large_mm, 8.0))
  assert_true(hc_close(size.bore_step_z_mm, 15.0))
  assert_true(hc_close(size.slit_width_mm, 0.7))
  assert_true(hc_close(size.slit_pitch_mm, 3.2))
  assert_true(hc_close(size.slit_turns, 3.0))
  assert_true(hc_close(size.clamp_screw_x_mm, 8.0))
  assert_true(hc_close(size.clamp_screw_length_mm, 12.0))
  assert_true(hc_close(size.clamp_bottom_start_z_mm, 0.0))
  assert_true(hc_close(size.clamp_top_end_z_mm, 30.0))
}

///|
test "helical coupling has the measured envelope and interfaces" {
  let part = match @motion.helical_coupling() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // Body plus two clamp screws.
  assert_eq(part.layers().length(), 3)
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(hc_close(x0, -12.5))
  assert_true(hc_close(x1, 12.5))
  assert_true(hc_close(y0, -12.5))
  assert_true(hc_close(y1, 12.5))
  assert_true(hc_close(z0, 0.0))
  assert_true(hc_close(z1, 30.0))
  let small = hc_connector(part, "bore-small")
  assert_true(small.kind is @common.MateKind::CylindricalBore)
  assert_true(hc_close(small.diameter_mm.unwrap(), 5.0))
  assert_true(hc_close(small.depth_mm.unwrap(), 15.0))
  let large = hc_connector(part, "bore-large")
  assert_true(hc_close(large.diameter_mm.unwrap(), 8.0))
  assert_true(hc_close(large.depth_mm.unwrap(), 15.0))
  let seat = hc_connector(part, "outer-seat")
  assert_true(hc_close(seat.diameter_mm.unwrap(), 25.0))
  assert_true(hc_has(part, "face-small"))
  assert_true(hc_has(part, "face-large"))
  assert_true(hc_has(part, "clamp-screw-1"))
  assert_true(hc_has(part, "clamp-screw-2"))
  let screw = hc_connector(part, "clamp-screw-1")
  assert_true(screw.kind is @common.MateKind::Threaded)
  for
    name in [
      "body", "stepped-bore", "outer-chamfers", "helical-slit", "clamp-slits", "clamp-screws",
    ] {
    assert_true(part.features().modeled.contains(name))
  }
  assert_eq(part.features().approximated.length(), 1)
  assert_true(
    part.features().approximated[0].kind
    is @common.ApproximationKind::SweptSpline,
  )
  assert_true(part.features().omitted.length() >= 2)
}

///|
test "helical coupling rejects impossible sizes" {
  let good = @motion.helical_coupling_5_to_8()
  // Bores out of order.
  assert_true(
    @motion.helical_coupling(size={ ..good, bore_small_mm: 9.0, }) is Err(_),
  )
  // Slit runs past the length.
  assert_true(
    @motion.helical_coupling(size={ ..good, slit_start_z_mm: 28.0, }) is Err(_),
  )
  // Clamp screw outside its slit.
  assert_true(
    @motion.helical_coupling(size={ ..good, clamp_screw_bottom_z_mm: 9.0, })
    is Err(_),
  )
  // Counterbore wider than the wall.
  assert_true(
    @motion.helical_coupling(size={
      ..good,
      clamp_counterbore_diameter_mm: 20.0,
    })
    is Err(_),
  )
  // Clamp screw not in the wall.
  assert_true(
    @motion.helical_coupling(size={ ..good, clamp_screw_x_mm: 1.0, }) is Err(_),
  )
}

///|
test "helical clamp bolts default to high-contrast orange" {
  let part = match @motion.helical_coupling() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let screw_layers = part
    .layers()
    .filter(fn(layer) { layer.name.contains("clamp-screw-") })
  assert_eq(screw_layers.length(), 2)
  for layer in screw_layers {
    let (r, g, b) = layer.color.channels()
    assert_true(hc_close(r, 1.0))
    assert_true(hc_close(g, 0.6))
    assert_true(hc_close(b, 0.0))
  }
}

///|
async test "helical coupling evaluated STEP retains clamp-bolt colours" {
  if !csc_command_in_path("python3") || !csc_draw_available() {
    return
  }
  let root = csc_repo_root()
  let dir = @fs.tmpdir(prefix="helical-coupling-color-")
  defer @fs.rmdir(dir, recursive=true)
  let part = match @motion.helical_coupling() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let out = dir + "/coupling.step"
  part.write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("COLOUR_RGB("))
}
