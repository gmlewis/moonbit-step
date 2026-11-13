///|
fn session18_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "DIN 472 nominal bore accepts a matching shaft by named connectors" {
  let ring = match @fasteners.din472_ring(20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let shaft = match @motion.shaft(20.0, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="bore",
    child="shaft-a",
    description="a 20 mm shaft through the DIN 472 nominal bore (d1)",
  )
  let assembly = @assemblies.Assembly::new(name="din472-shaft-fit").add(
    ring,
    instance_name="ring",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("ring", shaft, pair, instance_name="shaft") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  // The nominal bore d1 and the shaft diameter are both 20 mm.
  assert_true(session18_close(alignment.nominal_diameter_gap_mm(), 0.0, 1.0e-9))
}

///|
test "DIN 472 groove-seat declares the d2 x m bore-groove interface" {
  let ring = match @fasteners.din472_ring(20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let seat = match ring.connector("groove-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(seat.kind is @common.MateKind::Datum)
  match seat.diameter_mm {
    Some(d) => assert_true(session18_close(d, 21.0, 1.0e-9))
    None => fail("groove-seat should carry d2")
  }
  match seat.depth_mm {
    Some(d) => assert_true(session18_close(d, 1.1, 1.0e-9))
    None => fail("groove-seat should carry the groove width m")
  }
  // The ring's faces are parallel planes s = 1.0 mm apart.
  let negative = match ring.connector("face-negative") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let positive = match ring.connector("face-positive") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(negative.kind is @common.MateKind::PlaneFace)
  assert_true(positive.kind is @common.MateKind::PlaneFace)
  assert_true(
    session18_close(
      positive.placement.trans.2 - negative.placement.trans.2,
      1.0,
      1.0e-9,
    ),
  )
}
