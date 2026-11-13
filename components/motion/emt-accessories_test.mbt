///|
fn emt_acc_has(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn emt_acc_connector(
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
fn emt_acc_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn emt_acc_volume(part : @common.Component) -> Double {
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  volume
}

///|
fn emt_size_12() -> @motion.EmtSize {
  match @motion.emt_size("1/2") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
test "EMT end cap is a stepped solid with a plug" {
  let part = match @motion.emt_end_cap(emt_size_12(), 3.0, 15.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(emt_acc_near(x1 - x0, 17.9324))
  assert_true(emt_acc_near(z0, 0.0))
  assert_true(emt_acc_near(z1, 18.0))
  assert_true(part.layers().length() == 1)
  assert_true((emt_acc_volume(part) - 3605.913).abs() < 0.2)
  for name in ["cap-face", "tube-face", "plug", "plug-end"] {
    if !emt_acc_has(part, name) {
      abort("EMT end cap is missing connector " + name)
    }
  }
  let plug = emt_acc_connector(part, "plug")
  match plug.diameter_mm {
    Some(d) => assert_true(emt_acc_near(d, 15.5488))
    None => fail("expected the plug diameter")
  }
  assert_true(plug.kind is @common.MateKind::CylindricalShaft)
  assert_true(plug.gender is @common.MateGender::Male)
}

///|
test "EMT end cap rejects impossible plugs" {
  assert_true(@motion.emt_end_cap(emt_size_12(), 0.0, 15.0) is Err(_))
  assert_true(
    @motion.emt_end_cap(emt_size_12(), 3.0, 15.0, plug_clearance_mm=20.0)
    is Err(_),
  )
  assert_true(
    @motion.emt_end_cap(emt_size_12(), 3.0, 15.0, cap_diameter_mm=10.0)
    is Err(_),
  )
}

///|
test "EMT split clamp has a ring, a gap, ears, and a cross bolt" {
  let part = match @motion.emt_split_clamp(emt_size_12(), 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(emt_acc_near(x0, -12.2162))
  assert_true(emt_acc_near(x1, 20.2162))
  assert_true(emt_acc_near(y0, -12.2162))
  assert_true(emt_acc_near(y1, 12.2162))
  assert_true(emt_acc_near(z0, 0.0))
  assert_true(emt_acc_near(z1, 20.0))
  assert_true(part.layers().length() == 3)
  assert_true((emt_acc_volume(part) - 5674.634).abs() < 0.5)
  for name in ["bore", "outer-seat", "face-a", "face-b", "gap", "bolt-hole"] {
    if !emt_acc_has(part, name) {
      abort("EMT split clamp is missing connector " + name)
    }
  }
  let bore = emt_acc_connector(part, "bore")
  match bore.diameter_mm {
    Some(d) => assert_true(emt_acc_near(d, 18.4324))
    None => fail("expected the clamp bore diameter")
  }
  let bolt = emt_acc_connector(part, "bolt-hole")
  assert_true(emt_acc_near(bolt.placement.trans.0, 16.2162))
  assert_true(emt_acc_near(bolt.placement.trans.1, 0.0))
  assert_true(emt_acc_near(bolt.axis.1, 1.0))
  match bolt.diameter_mm {
    Some(d) => assert_true(emt_acc_near(d, 5.5))
    None => fail("expected the clamp bolt diameter")
  }
}

///|
test "EMT split clamp rejects impossible gaps and ears" {
  assert_true(
    @motion.emt_split_clamp(emt_size_12(), 20.0, gap_mm=40.0) is Err(_),
  )
  assert_true(
    @motion.emt_split_clamp(emt_size_12(), 20.0, bolt_diameter_mm=8.0) is Err(_),
  )
  assert_true(
    @motion.emt_split_clamp(emt_size_12(), 20.0, ear_embed_mm=4.0) is Err(_),
  )
}
