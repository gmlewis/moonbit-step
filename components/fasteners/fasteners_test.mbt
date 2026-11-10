///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn unwrap_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail : @common.DetailLevel,
) -> @common.Component {
  match @fasteners.iso4762_screw(size, length_mm, detail~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn layer_names(c : @common.Component) -> Array[String] {
  c.layers().map(fn(layer) { layer.name })
}

///|
fn layer_shape(c : @common.Component, name : String) -> @cad.Shape? {
  for layer in c.layers() {
    if layer.name == name {
      return Some(layer.shape)
    }
  }
  None
}

///|
test "m4x20 simplified screw bounding box and metadata" {
  let screw = unwrap_screw(@standards.M4, 20.0, Simplified)
  let (x0, x1, y0, y1, z0, z1) = screw.bounding_box()
  assert_true(close(x0, -3.5))
  assert_true(close(x1, 3.5))
  assert_true(close(y0, -3.5))
  assert_true(close(y1, 3.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 24.0))
  assert_true(screw.name() == "ISO4762-M4-20")
  assert_true(screw.metadata().designation == "ISO 4762 - M4 x 20")
  assert_true(screw.metadata().standard == "ISO 4762:2004")
}

///|
test "simplified screw has no thread layer but has a blind socket" {
  let screw = unwrap_screw(@standards.M4, 20.0, Simplified)
  let names = layer_names(screw)
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/shank" }))
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/head-floor" }))
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/head-socket" }))
  assert_false(names.any(fn(n) { n.contains("thread") }))
}

///|
test "fully modeled screw adds a swept helical thread" {
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let names = layer_names(screw)
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/plain-shank" }))
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/thread-core" }))
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/helical-thread" }))
  // The swept-thread bounding box is deliberately conservative, so inspect
  // the exact analytic core and head layers rather than the whole component.
  let core = match layer_shape(screw, "ISO4762-M4-20/thread-core") {
    Some(shape) => shape
    None => abort("missing thread core")
  }
  let (cx0, cx1, _cy0, _cy1, cz0, cz1) = core.bounding_box()
  assert_true(cx1 <= 1.6)
  assert_true(cx0 >= -1.6)
  assert_true(close(cz0, 0.0))
  assert_true(close(cz1, 14.0))
  let head = match layer_shape(screw, "ISO4762-M4-20/head-floor") {
    Some(shape) => shape
    None => abort("missing head floor")
  }
  let (hx0, hx1, _hy0, _hy1, _hz0, _hz1) = head.bounding_box()
  assert_true(close(hx0, -3.5))
  assert_true(close(hx1, 3.5))
}

///|
test "m3 m4 m5 screws all build" {
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let screw = unwrap_screw(size, size.nominal_diameter_mm() * 5.0, Simplified)
    let (_x0, _x1, _y0, _y1, z0, z1) = screw.bounding_box()
    assert_true(close(z0, 0.0))
    assert_true(z1 > size.nominal_diameter_mm() * 5.0)
  }
}

///|
test "invalid screw length propagates as an error" {
  assert_true(@fasteners.iso4762_screw(@standards.M4, 5.0) is Err(_))
  assert_true(@fasteners.iso4762_screw(@standards.M4, 20.0) is Ok(_))
}

///|
test "hex nut dimensions and layers" {
  let nut = match @fasteners.iso4032_nut(@standards.M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = nut.bounding_box()
  assert_true(close(x0, -3.5))
  assert_true(close(x1, 3.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 3.2))
  assert_true(nut.name() == "ISO4032-M4")
  assert_true(nut.layers().length() == 1)
}

///|
test "fully modeled nut adds an internal helical ridge" {
  let nut = match @fasteners.iso4032_nut(@standards.M4, detail=FullyModeled) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = layer_names(nut)
  assert_true(names.any(fn(n) { n == "ISO4032-M4/body" }))
  assert_true(names.any(fn(n) { n == "ISO4032-M4/helical-thread" }))
  let body = match layer_shape(nut, "ISO4032-M4/body") {
    Some(shape) => shape
    None => abort("missing nut body")
  }
  let (x0, x1, _y0, _y1, _z0, _z1) = body.bounding_box()
  assert_true(close(x0, -3.5))
  assert_true(close(x1, 3.5))
}

///|
test "flat washer dimensions" {
  let washer = match @fasteners.iso7089_washer(@standards.M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = washer.bounding_box()
  assert_true(close(x0, -4.5))
  assert_true(close(x1, 4.5))
  assert_true(close(y0, -4.5))
  assert_true(close(y1, 4.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 0.8))
  assert_true(washer.name() == "ISO7089-M4")
  assert_true(washer.metadata().designation == "ISO 7089 - M4")
}

///|
test "fastener step text is non-empty and watertight-looking" {
  let washer = match @fasteners.iso7089_washer(@standards.M3) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let step = washer.to_step(checked=true)
  assert_true(step.contains("ISO-10303-21"))
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
}

///|
test "iso 4017 hex head screw geometry" {
  let screw = match @fasteners.iso4017(@standards.M4, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = screw.bounding_box()
  assert_true(close(x0, -3.5))
  assert_true(close(x1, 3.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 22.8))
  assert_true(screw.name() == "ISO4017-M4-20")
}

///|
test "iso 4014 bolt with modeled thread splits the shank" {
  let bolt = match
    @fasteners.iso4014(
      @standards.M8,
      80.0,
      detail=@common.DetailLevel::FullyModeled,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = layer_names(bolt)
  assert_true(names.any(fn(n) { n == "ISO4014-M8-80/plain-shank" }))
  assert_true(names.any(fn(n) { n == "ISO4014-M8-80/thread-core" }))
  assert_true(names.any(fn(n) { n == "ISO4014-M8-80/helical-thread" }))
}

///|
test "din 976 rod geometry and layers" {
  let rod = match @fasteners.din976(@standards.M6, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = rod.bounding_box()
  assert_true(close(x0, -3.0))
  assert_true(close(x1, 3.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 100.0))
  let full = match
    @fasteners.din976(
      @standards.M6,
      100.0,
      detail=@common.DetailLevel::FullyModeled,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(
    layer_names(full).any(fn(n) { n == "DIN976-M6x100/helical-thread" }),
  )
}
