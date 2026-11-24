///|
test "goBILDA 4-hole square beam is 8 x 8 x 32 mm" {
  let part = gobilda_ok(@gobilda.gobilda_square_beam())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 4.0).abs() < 1.0e-6)
  assert_true((x1 - 4.0).abs() < 1.0e-6)
  assert_true((y0 + 16.0).abs() < 1.0e-6)
  assert_true((y1 - 16.0).abs() < 1.0e-6)
  assert_true((z0 + 4.0).abs() < 1.0e-6)
  assert_true((z1 - 4.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  // Two end threads plus four through holes.
  assert_eq(part.connectors().length(), 6)
  let thread = match part.connector("end-thread-b") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true((thread.diameter_mm.unwrap() - 4.0).abs() < 1.0e-6)
}

///|
test "goBILDA square beam crossing holes are a nominal difference for the kernel" {
  let part = gobilda_ok(@gobilda.gobilda_square_beam())
  // The flat writer reports the difference as a nominal (warning) boolean.
  assert_true(part.to_design().diagnostics().any(fn(d) { d.is_nominal() }))
  // The design also carries a real CSG boolean tree for a kernel to trim.
  assert_true(part.to_design().to_csg_step().contains("BOOLEAN_RESULT"))
}

///|
test "goBILDA square beam family presets" {
  let family = gobilda_spec(@gobilda.gobilda_square_beam_family())
  let names = family.variant_names()
  assert_true(names.contains("4-hole"))
  assert_true(names.contains("16-hole"))
  let part = gobilda_ok(family.build_variant("4-hole"))
  let (_x0, _x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((y1 - y0 - 32.0).abs() < 1.0e-6)
  assert_true(@gobilda.gobilda_square_beam(holes=0) is Err(_))
}
