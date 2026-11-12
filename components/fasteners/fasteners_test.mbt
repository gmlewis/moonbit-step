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
  // Datum is the head underside: head 0..k, shank -length..0.
  assert_true(close(z0, -20.0))
  assert_true(close(z1, 4.0))
  assert_true(screw.name() == "ISO4762-M4-20")
  assert_true(screw.metadata().designation == "ISO 4762 - M4 x 20")
  assert_true(screw.metadata().standard == "ISO 4762:2004")
}

///|
test "simplified screw is one socketed solid with a blind socket and no thread" {
  let screw = unwrap_screw(@standards.M4, 20.0, Simplified)
  let names = layer_names(screw)
  assert_false(names.any(fn(n) { n.contains("thread") }))
  assert_true(names.length() == 1)
  match layer_shape(screw, "ISO4762-M4-20/body") {
    Some(@cad.Shape::SocketedSolid(_)) => ()
    _ => abort("simplified screw should be one socketed solid")
  }
}

///|
test "fully modeled screw adds a swept helical thread to one core solid" {
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let names = layer_names(screw)
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/body" }))
  assert_true(names.any(fn(n) { n == "ISO4762-M4-20/helical-thread" }))
  // The core and head are one closed solid; only the swept ridge is layered on
  // top of it. Its bounding box covers the whole part.
  let body = match layer_shape(screw, "ISO4762-M4-20/body") {
    Some(shape) => shape
    None => abort("missing body")
  }
  match body {
    @cad.Shape::SocketedSolid(_) => ()
    _ => abort("core and head should be one socketed solid")
  }
  let (hx0, hx1, _hy0, _hy1, hz0, hz1) = body.bounding_box()
  assert_true(close(hx0, -3.5))
  assert_true(close(hx1, 3.5))
  assert_true(close(hz0, 0.0))
  assert_true(close(hz1, 24.0))
}

///|
test "m3 m4 m5 screws all build" {
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let screw = unwrap_screw(size, size.nominal_diameter_mm() * 5.0, Simplified)
    let (_x0, _x1, _y0, _y1, z0, z1) = screw.bounding_box()
    assert_true(close(z0, -size.nominal_diameter_mm() * 5.0))
    assert_true(z1 > 0.0)
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
test "din 125 a washer dimensions" {
  let washer = match @fasteners.din125_washer(@standards.M3) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = washer.bounding_box()
  assert_true(close(x0, -3.5))
  assert_true(close(x1, 3.5))
  assert_true(close(y0, -3.5))
  assert_true(close(y1, 3.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 0.5))
  assert_true(washer.name() == "DIN125-M3")
  assert_true(washer.metadata().designation == "DIN 125 A - M3")
  assert_true(washer.metadata().standard == "DIN 125 A")
  // One analytic annular layer (a revolved tube): no polygon approximation.
  let names = layer_names(washer)
  assert_true(names.length() == 1)
  assert_true(names.any(fn(n) { n == "DIN125-M3/body" }))
  let features = washer.features()
  assert_true(features.has_modeled("through-bore"))
  assert_true(features.has_omitted("edge-chamfer"))
  // M8 reference thickness is the ISO 7089 h_max of 1.8 mm (nominal 1.6).
  let m8 = match @fasteners.din125_washer(@standards.M8) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (mx0, mx1, my0, my1, mz0, mz1) = m8.bounding_box()
  assert_true(close(mx0, -8.0))
  assert_true(close(mx1, 8.0))
  assert_true(close(my0, -8.0))
  assert_true(close(my1, 8.0))
  assert_true(close(mz0, 0.0))
  assert_true(close(mz1, 1.8))
  assert_true(m8.name() == "DIN125-M8")
  assert_true(m8.metadata().designation == "DIN 125 A - M8")
}

///|
test "din 127 b spring washer geometry" {
  let washer = match @fasteners.din127_washer(@standards.M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = washer.bounding_box()
  // The radial section spans d1 = 4.1 to d2 = 7.6; the split gap slightly
  // shortens the +X extent. The free height is s + pitch * coverage = 1.773 mm.
  assert_true(close(z0, 0.0))
  assert_true(z1 > 1.76 && z1 < 1.78)
  assert_true(x1 - x0 > 7.54 && x1 - x0 < 7.60)
  assert_true(y1 - y0 > 7.59 && y1 - y0 < 7.61)
  assert_true(washer.name() == "DIN127-M4")
  assert_true(washer.metadata().designation == "DIN 127 B - M4")
  assert_true(washer.metadata().standard == "DIN 127 B")
  let features = washer.features()
  assert_true(features.has_modeled("split-gap"))
  assert_true(features.has_approximated("helical-body"))
  assert_true(features.has_omitted("edge-radius"))
  let step = washer.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
}

///|
test "din 440 v large washer geometry" {
  let washer = match @fasteners.din440_washer(@standards.M5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = washer.bounding_box()
  assert_true(close(x0, -9.0))
  assert_true(close(x1, 9.0))
  assert_true(close(y0, -9.0))
  assert_true(close(y1, 9.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 2.0))
  assert_true(washer.name() == "DIN440V-M5")
  assert_true(washer.metadata().designation == "DIN 440 V - M5")
  let features = washer.features()
  assert_true(features.has_modeled("outer-cylinder"))
  assert_true(features.has_modeled("square-bore"))
  assert_true(features.has_omitted("edge-chamfer"))
  let step = washer.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
  assert_true(step.contains("CYLINDRICAL_SURFACE"))
}

///|
test "din 7349 thick washer geometry" {
  let washer = match @fasteners.din7349_washer(@standards.M3) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = washer.bounding_box()
  assert_true(close(x0, -4.5))
  assert_true(close(x1, 4.5))
  assert_true(close(y0, -4.5))
  assert_true(close(y1, 4.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 1.0))
  assert_true(washer.name() == "DIN7349-M3")
  assert_true(washer.metadata().designation == "DIN 7349 - M3")
  let features = washer.features()
  assert_true(features.has_modeled("through-bore"))
  assert_true(features.has_omitted("edge-chamfer"))
  let step = washer.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
}

///|
test "din 913 set screw geometry" {
  let screw = match @fasteners.din913(@standards.M3, 5.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = screw.bounding_box()
  assert_true(close(x0, -1.5))
  assert_true(close(x1, 1.5))
  assert_true(close(y0, -1.5))
  assert_true(close(y1, 1.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 5.0))
  assert_true(screw.name() == "DIN913-M3x5")
  assert_true(screw.metadata().designation == "DIN 913 - M3 x 5")
  let features = screw.features()
  assert_true(features.has_modeled("hex-socket"))
  assert_true(features.has_modeled("point-cone"))
  assert_true(features.has_omitted("thread"))
  let step = screw.to_step(checked=true)
  assert_true(step.contains("CONICAL_SURFACE"))
  assert_true(step.contains("CYLINDRICAL_SURFACE"))
}

///|
test "din 93 tab washer geometry" {
  let washer = match @fasteners.din93_tab_washer(@standards.M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = washer.bounding_box()
  assert_true(close(x0, -14.0))
  assert_true(close(x1, 7.0))
  assert_true(close(y0, -7.0))
  assert_true(close(y1, 7.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 0.38))
  assert_true(washer.name() == "DIN93-M4")
  assert_true(washer.metadata().designation == "DIN 93 - M4")
  let features = washer.features()
  assert_true(features.has_modeled("transition-fillets"))
  assert_true(features.has_modeled("tab"))
  assert_true(features.has_omitted("service-bend"))
  let step = washer.to_step(checked=true)
  assert_true(step.contains("CYLINDRICAL_SURFACE"))
  assert_true(step.contains("CLOSED_SHELL"))
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
  // The head hexagon has a vertex on +X (like the reference STEP models), so
  // the across-corners span is s / cos 30 = 7 / sqrt(3) = 4.04145 for M4.
  assert_true(close(x0, -7.0 / 1.7320508075688772))
  assert_true(close(x1, 7.0 / 1.7320508075688772))
  // Head underside at 0; the M4 reference head height is the upper standard
  // limit, 3.0 mm (nominal 2.8 mm).
  assert_true(close(z0, -20.0))
  assert_true(close(z1, 3.0))
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
  // Head underside at 0; ISO 7380 M4 head height is 2.2 mm.
  assert_true(close(z0, -16.0))
  assert_true(close(z1, 2.2))
  assert_true(screw.metadata().standard == "ISO 7380-1:2022")
  let names = layer_names(screw)
  assert_true(names.length() == 1)
  match layer_shape(screw, "ISO7380-M4-16/body") {
    Some(@cad.Shape::SocketedSolid(_)) => ()
    _ => abort("button head should be one socketed solid")
  }
}

///|
test "iso10642 M4x16 detailed countersunk head dimensions and layers" {
  let screw = match
    @fasteners.iso10642_screw(@standards.M4, 16.0, detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = screw.bounding_box()
  // ISO 10642:2026 head: sharp dk 8.0, edge radius 0.2; the in-memory
  // envelope is the head edge torus outer radius.
  assert_true(close(x0, -3.717142227893211))
  assert_true(close(x1, 3.717142227893211))
  // Datum is the flush top face: top at 0, tip at -length.
  assert_true(close(z0, -16.0))
  assert_true(close(z1, 0.0))
  assert_true(screw.metadata().standard == "ISO 10642:2026")
  // One closed solid carries the countersink cone and the blind hex socket.
  assert_true(layer_names(screw).length() == 1)
  match layer_shape(screw, "ISO10642-M4-16/body") {
    Some(@cad.Shape::SocketedSolid(_)) => ()
    _ => abort("countersunk head should be one socketed solid")
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
  assert_true(features.has_modeled("shank-tip-chamfer"))
  assert_true(features.omission_reason("thread") is Some(_))
  // The socket rim and floor are typed omissions: the golden's rim is a
  // conical countersink and its floor a conical drill point, neither of which
  // can be emitted soundly without hyperbola-bounded cone faces.
  assert_true(features.has_omitted("socket-lead-in-cone"))
  assert_true(features.has_omitted("socket-floor-cone"))
  assert_true(features.has_omitted("under-head-radius"))
}

///|
test "detailed screw is one solid with conical tip and head breaks" {
  let detailed = unwrap_screw(@standards.M4, 20.0, Detailed)
  let detailed_body = match layer_shape(detailed, "ISO4762-M4-20/body") {
    Some(shape) => shape
    None => abort("missing detailed body")
  }
  match detailed_body {
    @cad.Shape::SocketedSolid(_) => ()
    _ => abort("detailed screw should be one socketed solid")
  }
  let inventory = detailed_body.surface_inventory()
  assert_true(inventory.cone == 2)
  assert_true(inventory.cylinder == 2)
  let simplified = unwrap_screw(@standards.M4, 20.0, Simplified)
  let simplified_body = match layer_shape(simplified, "ISO4762-M4-20/body") {
    Some(shape) => shape
    None => abort("missing simplified body")
  }
  let simple_inventory = simplified_body.surface_inventory()
  assert_true(simple_inventory.cone == 0)
}

///|
test "ISO 4762 thread length is measured from the tip" {
  // M4 x 20: b = 2d + 6 = 14 mm, so the thread occupies z = 0 .. 14 and the
  // plain shank is under the head (z = 14 .. 20). The single body profile
  // records that split as an annular step at z = 14.
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let body = match layer_shape(screw, "ISO4762-M4-20/body") {
    Some(@cad.Shape::SocketedSolid(s)) => s
    _ => abort("missing socketed body")
  }
  let mut step_at_14 = false
  for seg in body.body_segments() {
    match seg {
      @cad.RevSegment::RevLine(a, b) =>
        if close(a.1, 14.0) && close(b.1, 14.0) && (a.0 - b.0).abs() > 0.1 {
          step_at_14 = true
        }
      @cad.RevSegment::RevArc(_, _, _) => ()
    }
  }
  assert_true(step_at_14)
  assert_true(close(layer_z(screw, "ISO4762-M4-20/helical-thread"), -20.0))
}

///|
test "ISO 4762 fully modeled core carries a tip chamfer" {
  let screw = unwrap_screw(@standards.M4, 20.0, FullyModeled)
  let body = match layer_shape(screw, "ISO4762-M4-20/body") {
    Some(@cad.Shape::SocketedSolid(s)) => s
    _ => abort("missing socketed body")
  }
  let mut tip_cone = false
  for seg in body.body_segments() {
    match seg {
      @cad.RevSegment::RevLine(a, b) =>
        if a.1 < 1.0 &&
          b.1 < 1.0 &&
          (a.0 - b.0).abs() > 1.0e-6 &&
          (a.1 - b.1).abs() > 1.0e-6 {
          tip_cone = true
        }
      @cad.RevSegment::RevArc(_, _, _) => ()
    }
  }
  assert_true(tip_cone)
}

///|
test "ISO 4014 thread length is measured from the tip" {
  let bolt = match
    @fasteners.iso4014(@standards.M8, 80.0, detail=FullyModeled) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(close(layer_z(bolt, "ISO4014-M8-80/thread-core"), -80.0))
  // b = 2 * 8 + 6 = 22 mm for L <= 125, measured from the tip at -80.
  assert_true(close(layer_z(bolt, "ISO4014-M8-80/plain-shank"), -58.0))
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
  let head = match layer_shape(screw, "ISO4017-M4-20/hex-head") {
    Some(shape) => shape
    None => abort("missing hex head")
  }
  match head {
    @cad.Shape::HexHeadWasherFace(_) => ()
    _ => abort("detailed hex head should be a conical-washer-face head")
  }
  let simplified = match @fasteners.iso4017(@standards.M4, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(simplified.features().has_modeled("hex-head-chamfer"))
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
  assert_true(button.features().has_modeled("head-dome-revolution"))
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
    assert_true(screw_features.has_modeled("socket-floor-plane"))
    assert_true(screw_features.has_omitted("socket-lead-in-cone"))
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
    assert_true(button.features().has_modeled("socket-floor-plane"))
    assert_true(button.features().has_omitted("socket-lead-in-cone"))
    assert_true(button.features().has_modeled("shank-tip-chamfer"))
    let countersunk = match
      @fasteners.iso10642_screw(size, length, detail=Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(countersunk.features().has_modeled("socket-floor-plane"))
    assert_true(countersunk.features().has_omitted("socket-lead-in-cone"))
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
    let detailed_body = match layer_shape(detailed, detailed.name() + "/body") {
      Some(shape) => shape
      None => abort("missing detailed body")
    }
    match detailed_body {
      @cad.Shape::SocketedSolid(_) => ()
      _ => abort("detailed " + size.designation() + " is not one solid")
    }
    assert_true(detailed_body.surface_inventory().cone >= 1)
    let simplified = unwrap_screw(size, length, Simplified)
    let simplified_body = match
      layer_shape(simplified, simplified.name() + "/body") {
      Some(shape) => shape
      None => abort("missing simplified body")
    }
    assert_true(simplified_body.surface_inventory().cone == 0)
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
