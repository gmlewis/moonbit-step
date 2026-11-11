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
fn layer_z(c : @common.Component, name : String) -> Double {
  for layer in c.layers() {
    if layer.name == name {
      return layer.placement.trans.2
    }
  }
  abort("missing layer " + name)
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
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/head-shell" }))
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
  let head = match layer_shape(screw, "ISO4762-M4-20/head-shell") {
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
test "external thread ridge follows the ISO 68-1 basic profile" {
  for size in @standards.MetricSize::all() {
    let thread = @standards.ThreadSpec::coarse(size)
    let d = size.nominal_diameter_mm()
    let h3 = thread.external_thread_depth_mm()
    let crest = @fasteners.external_thread_crest_radius_mm(thread)
    let root = @fasteners.external_thread_root_radius_mm(thread)
    let center = @fasteners.external_thread_ridge_center_radius_mm(thread)
    // Crest on the nominal major diameter, root on the basic minor diameter.
    assert_true(close(crest, d / 2.0))
    assert_true(close(root, thread.external_minor_diameter_mm() / 2.0))
    assert_true(close(center + h3 / 2.0, crest))
    assert_true(close(center - h3 / 2.0, root))
  }
}

///|
test "internal thread ridge is attached for every size and clearance" {
  for size in @standards.MetricSize::all() {
    let thread = @standards.ThreadSpec::coarse(size)
    let d = size.nominal_diameter_mm()
    let h1 = thread.internal_thread_depth_mm()
    let d1 = thread.internal_minor_diameter_mm()
    assert_true(
      close(@fasteners.internal_thread_crest_radius_mm(thread), d1 / 2.0),
    )
    assert_true(
      close(@fasteners.internal_thread_root_radius_mm(thread), d / 2.0),
    )
    for clearance in [0.0, 0.05, 0.1, 0.2] {
      let center = @fasteners.internal_thread_ridge_center_radius_mm(
        thread,
        radial_offset_mm=clearance,
      )
      let crest = center - h1 / 2.0
      let root = center + h1 / 2.0
      let bore_radius = d / 2.0 + clearance
      // The crest is the basic internal minor diameter, shifted by clearance.
      assert_true(close(crest, d1 / 2.0 + clearance))
      // The root reaches the modelled bore exactly; the builder then embeds it
      // by `embed_mm` so the swept ridge is attached to the body.
      assert_true(close(root, bore_radius))
    }
  }
}

///|
test "fully modeled M20 nut ridge reaches the bore (regression)" {
  // Before the ISO 68-1 placement fix the ridge centre sat at the pitch
  // radius: the M20 ridge's outer radius was 9.9647 mm inside a 10 mm bore, so
  // the thread solid floated free of the nut body.
  let nut = match @fasteners.iso4032_nut(@standards.M20, detail=FullyModeled) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let ridge = match layer_shape(nut, "ISO4032-M20/helical-thread") {
    Some(shape) => shape
    None => abort("missing internal helical ridge")
  }
  let (x0, x1, _y0, _y1, z0, z1) = ridge.bounding_box()
  // Root radius 10 mm plus the 0.1 mm embed on both sides.
  assert_true(x1 > 10.0)
  assert_true(x1 < 10.11)
  assert_true(x0 < -10.0)
  // Axially contained in the nut height.
  assert_true(z0 >= 0.0)
  assert_true(z1 <= nut.size().2 + 1.0e-9)
}

///|
test "fully modeled M4 screw crest is on the nominal major diameter" {
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let ridge = match layer_shape(screw, "ISO4762-M4-20/helical-thread") {
    Some(shape) => shape
    None => abort("missing helical ridge")
  }
  let (x0, x1, _y0, _y1, _z0, _z1) = ridge.bounding_box()
  // Crest radius 2.0 (not the 1.9873 mm produced by a pitch-diameter centre).
  assert_true(close(x1, 2.0))
  assert_true(close(x0, -2.0))
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
  let (x0, x1, _y0, _y1, z0, z1) = screw.bounding_box()
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
  assert_true(features.has_modeled("through-bore"))
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
  // The socket lead-in and the tip chamfer are now real geometry at Detailed.
  assert_true(features.has_modeled("socket-lead-in-chamfer"))
  assert_true(features.has_modeled("shank-tip-chamfer"))
  // The under-head radius is still a typed omission because no verified value
  // exists.
  assert_true(features.has_omitted("under-head-radius"))
}

///|
test "detailed screw tip is a real chamfered solid, simplified is a cylinder" {
  let detailed = unwrap_screw(@standards.M4, 20.0, Detailed)
  let detailed_shank = match layer_shape(detailed, "ISO4762-M4-20/shank") {
    Some(shape) => shape
    None => abort("missing detailed shank")
  }
  match detailed_shank {
    @cad.Shape::RevolvedProfile(_) => ()
    _ => abort("detailed shank should carry an analytic conical tip chamfer")
  }
  let simplified = unwrap_screw(@standards.M4, 20.0, Simplified)
  let simplified_shank = match layer_shape(simplified, "ISO4762-M4-20/shank") {
    Some(shape) => shape
    None => abort("missing simplified shank")
  }
  match simplified_shank {
    @cad.Shape::Cylinder(_) => ()
    _ => abort("simplified shank should be a plain cylinder")
  }
}

///|
test "ISO 4762 thread length is measured from the tip" {
  // M4 x 20: b = 2d + 6 = 14 mm, so the thread occupies z = 0 .. 14 and the
  // plain shank is under the head (z = 14 .. 20). A previous build reversed
  // this, leaving the nut of a bolted joint on an unthreaded tip.
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  assert_true(close(layer_z(screw, "ISO4762-M4-20/thread-core"), 0.0))
  assert_true(close(layer_z(screw, "ISO4762-M4-20/plain-shank"), 14.0))
}

///|
test "ISO 4762 fully modeled core carries a tip chamfer" {
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let core = match layer_shape(screw, "ISO4762-M4-20/thread-core") {
    Some(shape) => shape
    None => abort("missing thread core")
  }
  match core {
    @cad.Shape::RevolvedProfile(_) => ()
    _ => abort("fully modeled thread core should carry an analytic tip chamfer")
  }
}

///|
test "ISO 4014 thread length is measured from the tip" {
  let bolt = match
    @fasteners.iso4014(@standards.M8, 80.0, detail=FullyModeled) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(close(layer_z(bolt, "ISO4014-M8-80/thread-core"), 0.0))
  // b = 2 * 8 + 6 = 22 mm for L <= 125.
  assert_true(close(layer_z(bolt, "ISO4014-M8-80/plain-shank"), 22.0))
}

///|
test "detailed hex head models a head chamfer and a tip chamfer" {
  let screw = match @fasteners.iso4017(@standards.M4, 20.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = screw.features()
  assert_true(features.has_modeled("hex-head-chamfer"))
  assert_true(features.has_modeled("shank-tip-chamfer"))
  assert_true(features.has_approximated("hex-head-chamfer-band"))
  let head = match layer_shape(screw, "ISO4017-M4-20/hex-head") {
    Some(shape) => shape
    None => abort("missing hex head")
  }
  match head {
    @cad.Shape::ChamferedPrism(_) => ()
    _ => abort("detailed hex head should be a chamfered prism")
  }
  let simplified = match @fasteners.iso4017(@standards.M4, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_false(simplified.features().has_modeled("hex-head-chamfer"))
}

///|
test "detailed DIN 976 rod chamfers both ends with a typed lead-in" {
  let rod = match @fasteners.din976(@standards.M5, 50.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(rod.features().has_modeled("thread-lead-in-chamfer"))
  let body = match layer_shape(rod, "DIN976-M5x50/rod") {
    Some(shape) => shape
    None => abort("missing rod layer")
  }
  let (x0, x1, _y0, _y1, z0, z1) = body.bounding_box()
  assert_true(z0 >= 0.0)
  assert_true(close(z1, 50.0))
  assert_true(close(x1, 2.5))
  assert_true(x0 <= -2.5)
}

///|
test "plain washer claims no edge chamfer at any detail level" {
  for
    detail in [
      @common.DetailLevel::Simplified,
      @common.DetailLevel::Detailed,
      @common.DetailLevel::FullyModeled,
    ] {
    let washer = match @fasteners.iso7089_washer(@standards.M4, detail~) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    let features = washer.features()
    assert_false(features.has_modeled("edge-chamfer"))
    assert_false(features.has_approximated("edge-chamfer"))
    let reason = match features.omission_reason("edge-chamfer") {
      Some(r) => r
      None => abort("edge-chamfer should be an omission")
    }
    assert_true(reason.contains("ISO 7089"))
  }
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
  assert_true(features.has_modeled("through-bore"))
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

///|
test "thread ridge handedness changes the swept geometry" {
  let right = @standards.ThreadSpec::coarse(@standards.M4)
  let left = right.with_hand(@standards.ThreadHand::Left)
  let right_shape = match
    @fasteners.external_thread_ridge(right, 12.0, segments_per_turn=12) {
    Some(s) => s
    None => abort("right-hand ridge was not generated")
  }
  let left_shape = match
    @fasteners.external_thread_ridge(left, 12.0, segments_per_turn=12) {
    Some(s) => s
    None => abort("left-hand ridge was not generated")
  }
  let right_step = @cad.Design::new(name="right")
    .add(right_shape.with_name("ridge"))
    .to_step_file()
  let left_step = @cad.Design::new(name="left")
    .add(left_shape.with_name("ridge"))
    .to_step_file()
  assert_true(right_step.contains("MANIFOLD_SOLID_BREP("))
  assert_true(left_step.contains("MANIFOLD_SOLID_BREP("))
  // Compare only the DATA section: the header timestamp would otherwise make
  // the assertion pass even when the geometry is identical.
  let right_data = right_step.split("DATA;").collect()
  let left_data = left_step.split("DATA;").collect()
  assert_true(right_data.length() == 2 && left_data.length() == 2)
  assert_true(right_data[1] != left_data[1])
}

///|
test "M2-M5 detailed and full detail records the required features" {
  let sizes = [
    @standards.M2,
    @standards.M2_5,
    @standards.M3,
    @standards.M4,
    @standards.M5,
  ]
  for size in sizes {
    let d = size.nominal_diameter_mm()
    let length = d * 4.0
    let screw_detailed = unwrap_screw(size, length, Detailed)
    let screw_features = screw_detailed.features()
    assert_true(screw_features.has_modeled("head-chamfer"))
    assert_true(screw_features.has_modeled("socket-lead-in-chamfer"))
    assert_true(screw_features.has_modeled("shank-tip-chamfer"))
    assert_true(screw_features.has_omitted("under-head-radius"))
    let screw_full = unwrap_screw(size, length, FullyModeled)
    assert_true(screw_full.features().has_modeled("helical-thread"))

    let nut_detailed = match @fasteners.iso4032_nut(size, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(nut_detailed.features().has_modeled("nut-face-chamfer"))
    let nut_full = match @fasteners.iso4032_nut(size, detail=FullyModeled) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(nut_full.features().has_modeled("helical-thread"))

    let hex_screw = match @fasteners.iso4017(size, length, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(hex_screw.features().has_modeled("hex-head-chamfer"))
    assert_true(hex_screw.features().has_modeled("shank-tip-chamfer"))
    let hex_bolt = match @fasteners.iso4014(size, length, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(hex_bolt.features().has_modeled("hex-head-chamfer"))
    assert_true(hex_bolt.features().has_modeled("shank-tip-chamfer"))

    let rod_detailed = match @fasteners.din976(size, 25.0, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(rod_detailed.features().has_modeled("thread-lead-in-chamfer"))
    let rod_full = match @fasteners.din976(size, 25.0, detail=FullyModeled) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(rod_full.features().has_modeled("helical-thread"))

    let washer = match @fasteners.iso7089_washer(size) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(washer.features().omission_reason("edge-chamfer") is Some(_))
  }
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let length = size.nominal_diameter_mm() * 4.0
    let button = match @fasteners.iso7380_screw(size, length, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(button.features().has_modeled("socket-lead-in-chamfer"))
    assert_true(button.features().has_modeled("shank-tip-chamfer"))
    let countersunk = match
      @fasteners.iso10642_screw(size, length, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(countersunk.features().has_modeled("socket-lead-in-chamfer"))
    assert_true(countersunk.features().has_modeled("shank-tip-chamfer"))
  }
}

///|
test "M2-M5 tip chamfer is real geometry at Detailed and absent at Simplified" {
  for
    size in [
      @standards.M2,
      @standards.M2_5,
      @standards.M3,
      @standards.M4,
      @standards.M5,
    ] {
    let length = size.nominal_diameter_mm() * 4.0
    let detailed = unwrap_screw(size, length, Detailed)
    let detailed_shank = match
      layer_shape(detailed, detailed.name() + "/shank") {
      Some(shape) => shape
      None => abort("missing detailed shank")
    }
    match detailed_shank {
      @cad.Shape::RevolvedProfile(_) => ()
      _ => abort("detailed " + size.designation() + " shank is not chamfered")
    }
    let simplified = unwrap_screw(size, length, Simplified)
    let simplified_shank = match
      layer_shape(simplified, simplified.name() + "/shank") {
      Some(shape) => shape
      None => abort("missing simplified shank")
    }
    match simplified_shank {
      @cad.Shape::Cylinder(_) => ()
      _ => abort("simplified " + size.designation() + " shank is not plain")
    }
  }
}

///|
test "socket lead-in hole levels span the socket band" {
  let levels = @fasteners.socket_lead_in_hole_levels(0.0, 2.0, 0.25)
  assert_eq(levels.length(), 3)
  assert_true(close(levels[0].0, 0.0))
  assert_true(close(levels[1].0, 1.75))
  assert_true(close(levels[2].0, 2.0))
  assert_true(close(levels[2].1, 0.0))
  // A socket no deeper than the lead-in falls back to a vertical hole.
  let shallow = @fasteners.socket_lead_in_hole_levels(0.0, 0.2, 0.25)
  assert_eq(shallow.length(), 2)
  assert_true(close(shallow[0].1, shallow[1].1))
}
