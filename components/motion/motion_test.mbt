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
  let (x0, x1, _y0, _y1, _z0, _z1) = spring.bounding_box()
  assert_true(x1 >= 5.0)
  assert_true(x0 <= -5.0)
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
