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

///|
test "iso7380 M4x16 detailed button head dimensions and layers" {
  let screw = match
    @fasteners.iso7380_screw(@standards.M4, 16.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = screw.bounding_box()
  assert_true(close(x0, -3.8))
  assert_true(close(x1, 3.8))
  assert_true(close(y0, -3.8))
  assert_true(close(y1, 3.8))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 18.2))
  assert_true(screw.metadata().standard == "ISO 7380-1:2022")
  let names = layer_names(screw)
  assert_true(names.any(fn(n) { n.contains("head-floor") }))
  assert_true(names.any(fn(n) { n.contains("head-socket") }))
}

///|
test "iso10642 M4x16 detailed countersunk head dimensions and layers" {
  let screw = match
    @fasteners.iso10642_screw(@standards.M4, 16.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = screw.bounding_box()
  assert_true(close(x0, -4.2))
  assert_true(close(x1, 4.2))
  assert_true(close(z0, 0.0))
  // ISO 10642 measures length over the flush countersunk head, so the overall
  // extent equals the nominal length (16 mm), not length + head height.
  assert_true(close(z1, 16.0))
  assert_true(screw.metadata().standard == "ISO 10642:2004")
  // The socket band is a real hex through-hole over an analytic head floor.
  let floor = layer_shape(screw, "ISO10642-M4-16/head-floor")
  match floor {
    Some(@cad.Shape::RevolvedProfile(_)) => ()
    _ => abort("expected a revolved head floor")
  }
  let socket = layer_shape(screw, "ISO10642-M4-16/head-socket")
  match socket {
    Some(@cad.Shape::ChamferedPrism(_)) => ()
    _ => abort("expected a chamfered-prism socket band")
  }
}

///|
test "new head standards reject unsupported sizes and lengths" {
  inspect(
    @fasteners.iso7380_screw(@standards.M2, 16.0) is Err(_),
    content="true",
  )
  inspect(
    @fasteners.iso10642_screw(@standards.M2, 16.0) is Err(_),
    content="true",
  )
  inspect(
    @fasteners.iso7380_screw(@standards.M4, 2.0) is Err(_),
    content="true",
  )
}

///|
test "simplified nut omits the face chamfer with a reason" {
  let nut = match @fasteners.iso4032_nut(@standards.M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = nut.features()
  assert_false(features.has_modeled("nut-face-chamfer"))
  assert_true(features.omission_reason("nut-face-chamfer") is Some(_))
  assert_true(features.has_approximated("through-bore"))
  assert_true(nut.documentation().contains("Features omitted"))
}

///|
test "detailed nut models the face chamfer and records it" {
  let nut = match @fasteners.iso4032_nut(@standards.M4, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = nut.features()
  assert_true(features.has_modeled("nut-face-chamfer"))
  assert_true(features.omission_reason("nut-face-chamfer") is None)
  assert_true(nut.to_step().contains("Features modeled"))
}

///|
test "detailed socket screw models the head chamfer" {
  let screw = unwrap_screw(@standards.M4, 20.0, Detailed)
  let features = screw.features()
  assert_true(features.has_modeled("head-chamfer"))
  assert_true(features.has_modeled("blind-hex-socket"))
  assert_true(features.omission_reason("thread") is Some(_))
  // Remaining fastener features are recorded as typed omissions, not silently
  // pretended.
  assert_true(features.has_omitted("socket-lead-in-chamfer"))
  assert_true(features.has_omitted("shank-tip-chamfer"))
  assert_true(features.has_omitted("under-head-radius"))
}

///|
test "fully modeled screw records the swept thread" {
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let features = screw.features()
  assert_true(features.has_modeled("helical-thread"))
  assert_true(features.has_approximated("helical-ridge"))
  assert_true(features.has_omitted("thread-runout"))
}

///|
test "washer records its modeled body and omitted chamfer" {
  let washer = match @fasteners.iso7089_washer(@standards.M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = washer.features()
  assert_true(features.has_modeled("body"))
  assert_true(features.has_approximated("through-bore"))
  assert_true(features.omission_reason("edge-chamfer") is Some(_))
}

///|
test "button and countersunk heads record analytic dome and cone" {
  let button = match
    @fasteners.iso7380_screw(@standards.M4, 16.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(button.features().has_modeled("head-dome-sphere"))
  let countersunk = match
    @fasteners.iso10642_screw(@standards.M4, 16.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(countersunk.features().has_modeled("head-countersink-cone"))
}
