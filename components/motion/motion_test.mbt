///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "plain shaft dimensions" {
  let part = match @motion.shaft(10.0, 50.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -5.0))
  assert_true(close(x1, 5.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 50.0))
  assert_true(@motion.shaft(0.0, 50.0) is Err(_))
}

///|
test "stepped shaft stacks segments in z" {
  let segments = [
    match @motion.ShaftSegment::new(10.0, 20.0) {
      Ok(s) => s
      Err(e) => abort(e.message())
    },
    match @motion.ShaftSegment::new(16.0, 30.0) {
      Ok(s) => s
      Err(e) => abort(e.message())
    },
  ]
  let part = match @motion.stepped_shaft(segments) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -8.0))
  assert_true(close(x1, 8.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 50.0))
  assert_eq(part.layers().length(), 2)
}

///|
test "spacer is a tube with the requested bore" {
  let part = match @motion.spacer(12.0, 8.0, 10.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true(close(x0, -6.0))
  assert_true(close(x1, 6.0))
  assert_true(close(z1, 10.0))
  assert_true(@motion.spacer(8.0, 10.0, 10.0) is Err(_))
}

///|
test "bearing 608 envelope" {
  let part = match @motion.bearing_by_designation("608") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -11.0))
  assert_true(close(x1, 11.0))
  assert_true(close(y0, -11.0))
  assert_true(close(y1, 11.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 7.0))
  assert_eq(part.layers().length(), 10)
}

///|
test "bearing table rejects unknown designations" {
  assert_true(@motion.bearing_size("9999") is Err(_))
  assert_true(@motion.bearing_size("6204") is Ok(_))
  let size = match @motion.bearing_size("6204") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(close(size.bore_mm, 20.0))
  assert_true(close(size.outer_mm, 47.0))
  assert_true(close(size.width_mm, 14.0))
}

///|
test "key is a rectangular solid" {
  let part = match @motion.key(20.0, 6.0, 6.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, y1, _z0, z1) = part.bounding_box()
  assert_true(close(x0, 0.0))
  assert_true(close(x1, 20.0))
  assert_true(close(y1, 6.0))
  assert_true(close(z1, 6.0))
}

///|
test "compression spring builds and rejects overlapping coils" {
  let spring = match @motion.compression_spring(10.0, 1.0, 20.0, 8) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(spring.layers().length(), 1)
  let (x0, x1, y0, y1, z0, z1) = spring.bounding_box()
  // Mean diameter 10, wire 1: the wire surface spans 4.5..5.5 mm radially and
  // exactly 0..20 mm axially (the path is inset by the wire radius at each end).
  assert_true(close(x0, -5.5))
  assert_true(close(x1, 5.5))
  assert_true(close(y0, -5.5))
  assert_true(close(y1, 5.5))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 20.0))
  assert_true(@motion.compression_spring(10.0, 2.0, 5.0, 8) is Err(_))
  assert_true(@motion.compression_spring(1.0, 2.0, 20.0, 8) is Err(_))
}

///|
test "hex standoff dimensions" {
  let part = match @motion.standoff(6.0, 20.0, 3.5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -3.0))
  assert_true(close(x1, 3.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 20.0))
  assert_true(@motion.standoff(6.0, 20.0, 7.0) is Err(_))
}

///|
test "dowel pin is a plain cylinder" {
  let part = match @motion.dowel_pin(4.0, 16.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true(close(x0, -2.0))
  assert_true(close(x1, 2.0))
  assert_true(close(z1, 16.0))
  assert_true(part.name().contains("dowel-pin"))
}

///|
test "bearing rolling elements are analytical spheres" {
  let part = match @motion.bearing_by_designation("608") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = part.layers().map(fn(l) { l.name })
  let ball_layers = names.filter(fn(n) { n.contains("ball-") })
  assert_eq(ball_layers.length(), 8)
  let step = part.to_step()
  // Each ball is a closed SPHERICAL_SURFACE solid; two faces per sphere share
  // the equator, so 8 balls contribute 16 spherical surfaces.
  assert_true(step.contains("SPHERICAL_SURFACE"))
}

///|
test "detailed bearing rings carry chamfers" {
  let part = match @motion.bearing_by_designation("608", detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 10)
  let step = part.to_step()
  assert_true(step.contains("SPHERICAL_SURFACE"))
  // The chamfered rings are ruled polygon stacks, not plain cylinders.
  let names = part.layers().map(fn(l) { l.name })
  assert_true(names.any(fn(n) { n.contains("outer-ring") }))
}

///|
test "filleted stepped shaft has a toroidal shoulder fillet" {
  let segments : Array[(Double, Double)] = [(10.0, 20.0), (16.0, 15.0)]
  let part = match
    @motion.filleted_stepped_shaft(segments, fillet_radius_mm=2.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -8.0))
  assert_true(close(x1, 8.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 35.0))
  assert_true(part.to_step().contains("TOROIDAL_SURFACE"))
  let sharp = match @motion.filleted_stepped_shaft(segments) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_false(sharp.to_step().contains("TOROIDAL_SURFACE"))
}

///|
test "bearing feature record lists spheres and omitted seals" {
  let part = match @motion.bearing_by_designation("608") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = part.features()
  assert_true(features.has_modeled("ball-sphere"))
  assert_true(features.omission_reason("seal") is Some(_))
  assert_true(features.omission_reason("cage") is Some(_))
  let detailed = match @motion.bearing_by_designation("608", detail=Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(detailed.features().has_modeled("ring-edge-chamfer"))
}

///|
test "filleted shaft feature record lists the shoulder fillet" {
  let segments : Array[(Double, Double)] = [(10.0, 20.0), (16.0, 15.0)]
  let part = match
    @motion.filleted_stepped_shaft(segments, fillet_radius_mm=2.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(part.features().has_modeled("shoulder-fillet"))
  assert_true(part.features().omission_reason("keyway") is Some(_))
}

///|
test "shoulder fillet sits at the re-entrant corner" {
  let segments : Array[(Double, Double)] = [(10.0, 20.0), (16.0, 15.0)]
  let part = match
    @motion.filleted_stepped_shaft(segments, fillet_radius_mm=2.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let step = part.to_step()
  // Small radius 5, fillet 2: the tangent torus centre is at r = 7, not the
  // outer rim of the larger cylinder (which the old code reported as r = 6).
  assert_true(step.contains("TOROIDAL_SURFACE"))
  assert_true(step.contains(",7.0,2.0);"))
  assert_false(step.contains(",6.0,2.0);"))
}

///|
test "equal diameters and the maximum shoulder fillet build" {
  // Equal consecutive diameters must not emit a zero-length shoulder line.
  let equal : Array[(Double, Double)] = [(10.0, 20.0), (10.0, 10.0)]
  let plain = match @motion.filleted_stepped_shaft(equal) {
    Ok(c) => c
    Err(e) => abort("equal-diameter shaft rejected: " + e.message())
  }
  assert_false(plain.to_step().contains("TOROIDAL_SURFACE"))
  // fillet radius == radial step (2 mm) is the largest feasible fillet.
  let max_fillet : Array[(Double, Double)] = [(10.0, 20.0), (14.0, 15.0)]
  let part = match
    @motion.filleted_stepped_shaft(max_fillet, fillet_radius_mm=2.0) {
    Ok(c) => c
    Err(e) => abort("maximum fillet rejected: " + e.message())
  }
  assert_true(part.to_step().contains("TOROIDAL_SURFACE"))
  assert_true(part.to_step().contains(",7.0,2.0);"))
}

///|
test "no shoulder fillet is claimed when none is modelled" {
  let decreasing : Array[(Double, Double)] = [(16.0, 15.0), (10.0, 20.0)]
  let no_fillet = match
    @motion.filleted_stepped_shaft(decreasing, fillet_radius_mm=2.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_false(no_fillet.features().has_modeled("shoulder-fillet"))
  assert_true(
    no_fillet.features().omission_reason("shoulder-fillet") is Some(_),
  )
  let single : Array[(Double, Double)] = [(10.0, 20.0)]
  let one_step = match
    @motion.filleted_stepped_shaft(single, fillet_radius_mm=2.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_false(one_step.features().has_modeled("shoulder-fillet"))
}

///|
test "bearing rejects overlapping rollers and an impossible chamfer" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(@motion.bearing(size, roller_count=34) is Err(_))
  assert_true(@motion.bearing(size, roller_count=33) is Ok(_))
  // A 0.1 mm ring cannot absorb the 0.2 mm minimum edge chamfer.
  assert_true(
    @motion.bearing(
      size,
      ring_thickness_mm=0.1,
      detail=@common.DetailLevel::Detailed,
    )
    is Err(_),
  )
  // Simplified rings have no chamfer. A thin ring leaves a 6.8 mm ball, so
  // only six rollers fit around the 7.5 mm pitch radius.
  assert_true(
    @motion.bearing(size, ring_thickness_mm=0.1, roller_count=6) is Ok(_),
  )
  assert_true(@motion.bearing(size, ring_thickness_mm=0.1) is Err(_))
}

///|
test "bearing with zero rollers is a rings-only envelope" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.bearing(size, roller_count=0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 2)
  assert_false(part.to_step().contains("SPHERICAL_SURFACE"))
  let features = part.features()
  assert_false(features.has_modeled("ball-sphere"))
  assert_true(features.omission_reason("rolling-elements") is Some(_))
}

///|
test "bearing 628 is an 8 x 24 x 8 boundary envelope" {
  let size = match @motion.bearing_size("628") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(close(size.bore_mm, 8.0))
  assert_true(close(size.outer_mm, 24.0))
  assert_true(close(size.width_mm, 8.0))
}

///|
fn motion_count_sub(haystack : String, needle : String) -> Int32 {
  haystack.split(needle).collect().length() - 1
}

///|
test "shielded bearing is a single-solid 14-face envelope" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.shielded_bearing(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 1)
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -11.0))
  assert_true(close(x1, 11.0))
  assert_true(close(z0, -3.5))
  assert_true(close(z1, 3.5))
  let step = part.to_step()
  assert_eq(motion_count_sub(step, "ADVANCED_FACE("), 14)
  assert_eq(motion_count_sub(step, "CYLINDRICAL_SURFACE("), 2)
  assert_eq(motion_count_sub(step, "CONICAL_SURFACE("), 6)
  assert_eq(motion_count_sub(step, "PLANE("), 6)
  assert_eq(motion_count_sub(step, "SPHERICAL_SURFACE("), 0)
  // One solid style plus two black flat-shield face styles. The 45-degree
  // groove walls stay metal and carry no extra style.
  assert_eq(motion_count_sub(step, "STYLED_ITEM("), 3)
  assert_eq(motion_count_sub(step, "COLOUR_RGB("), 3)
  let features = part.features()
  assert_true(features.has_modeled("shield-groove"))
  assert_true(features.has_modeled("shield-face-black"))
  assert_true(features.omission_reason("rolling-elements") is Some(_))
}
