///|
fn rivet_has(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn rivet_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  for connector in part.connectors() {
    if connector.name == name {
      return connector
    }
  }
  abort("missing connector " + name)
}

///|
test "generic solid rivet has a head and a shank" {
  let part = match @fasteners.solid_rivet(3.0, 10.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 5.4).abs() < 1.0e-6)
  assert_true((y1 - y0 - 5.4).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 10.0).abs() < 1.0e-6)
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true((volume - 87.305).abs() < 0.2)
  for name in ["head-seat", "head-underside", "shank", "tail-face"] {
    if !rivet_has(part, name) {
      abort("solid rivet is missing connector " + name)
    }
  }
  let shank = rivet_connector(part, "shank")
  match shank.diameter_mm {
    Some(d) => assert_true((d - 3.0).abs() < 1.0e-9)
    None => fail("expected the rivet shank diameter")
  }
  match shank.depth_mm {
    Some(d) => assert_true((d - 8.95).abs() < 1.0e-9)
    None => fail("expected the rivet shank depth")
  }
  assert_true(shank.gender is @common.MateGender::Male)
  assert_true(rivet_connector(part, "head-seat").axis.2 < -0.99)
}

///|
test "generic solid rivet accepts explicit head dimensions" {
  let part = match
    @fasteners.solid_rivet(4.0, 12.0, head_diameter_mm=8.0, head_height_mm=2.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, _z0, _z1) = part.bounding_box()
  assert_true((x1 - x0 - 8.0).abs() < 1.0e-6)
}

///|
test "generic solid rivet rejects impossible heads" {
  assert_true(@fasteners.solid_rivet(3.0, 10.0, head_diameter_mm=2.0) is Err(_))
  assert_true(@fasteners.solid_rivet(3.0, 10.0, head_height_mm=10.0) is Err(_))
  assert_true(@fasteners.solid_rivet(0.0, 10.0) is Err(_))
  assert_true(@fasteners.solid_rivet(3.0, 0.0) is Err(_))
}
