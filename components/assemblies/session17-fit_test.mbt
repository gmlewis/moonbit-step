///|
fn session17_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "two MakerBeam extrusions butt together by named end connectors" {
  let beam_a = match
    @profiles.makerbeam_extrusion(@profiles.MakerBeamProfile::mb_1010(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let beam_b = match
    @profiles.makerbeam_extrusion(@profiles.MakerBeamProfile::mb_1010(), 60.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="end-b",
    child="end-a",
    description="butt joint between two MakerBeam 10 x 10 extrusions",
  )
  let assembly = @assemblies.Assembly::new(name="makerbeam-butt").add(
    beam_a,
    instance_name="beam-a",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("beam-a", beam_b, pair, instance_name="beam-b") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  assert_true(session17_close(alignment.nominal_diameter_gap_mm(), 0.0, 1.0e-9))
  // The end connectors are reference datums, so no contact claim is made.
  // The butt joint places the second beam's origin at the first beam's end.
  let (px, py, pz) = alignment.placement.trans
  assert_true(session17_close(px, 0.0, 1.0e-9))
  assert_true(session17_close(py, 0.0, 1.0e-9))
  assert_true(session17_close(pz, 100.0, 1.0e-9))
}

///|
test "MakerBeam end threads declare the M3 x 8 mm interface" {
  let beam = match
    @profiles.makerbeam_extrusion(@profiles.MakerBeamProfile::mb_1010(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  for name in ["end-thread-a", "end-thread-b"] {
    let connector = match beam.connector(name) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(connector.kind is @common.MateKind::Threaded)
    match connector.diameter_mm {
      Some(d) => assert_true(session17_close(d, 3.0, 1.0e-9))
      None => fail("end thread should declare its M3 diameter")
    }
    match connector.depth_mm {
      Some(d) => assert_true(session17_close(d, 8.0, 1.0e-9))
      None => fail("end thread should declare its 8 mm depth")
    }
  }
}

///|
test "DIN 471 free bore is smaller than the nominal shaft" {
  // External retaining rings are sprung open onto the shaft; the free bore d3
  // is smaller than d1, and the groove bottom d2 sits between them.
  let size = match @standards.din471_size(20.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(size.free_inner_diameter_mm < size.shaft_diameter_mm)
  assert_true(size.groove_diameter_mm > size.free_inner_diameter_mm)
  assert_true(size.groove_diameter_mm < size.shaft_diameter_mm)
  let ring = match @fasteners.din471_ring(20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let bore = match ring.connector("bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  match bore.diameter_mm {
    Some(d) =>
      assert_true(session17_close(d, size.free_inner_diameter_mm, 1.0e-9))
    None => fail("ring bore should carry d3")
  }
}
