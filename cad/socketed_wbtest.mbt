///|
const TEST_LENGTH_EPS : Double = 1.0e-9

///|
const TEST_VALUE_EPS : Double = 1.0e-6

///|
fn socket_count_sub(haystack : String, needle : String) -> Int32 {
  haystack.split(needle).collect().length() - 1
}

///|
test "socketed solid inventory, volume and socket section are exact" {
  let body = RevolvedProfile::chamfered_cylinder(10.0, 10.0, top_chamfer=1.0)
  let socket = SocketedSolid::new(body, 4.0, 5.0)
  let shape = socket.as_shape()
  let inventory = shape.surface_inventory()
  // Body: bottom disc + top disc planes, one cylinder, one cone. The top disc
  // is replaced by the annular top, six walls, and the floor.
  assert_eq(inventory.plane, 9)
  assert_eq(inventory.cylinder, 1)
  assert_eq(inventory.cone, 1)
  assert_eq(inventory.sphere, 0)
  assert_eq(inventory.torus, 0)
  let body_volume = body.volume()
  let pocket_area = Double::sqrt(3.0) / 2.0 * 4.0 * 4.0
  let expected = body_volume - pocket_area * 5.0
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true((volume - expected).abs() < TEST_VALUE_EPS)
  let section = match shape.section_at_local(7.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true((section.inner_radius_mm - 2.0).abs() < TEST_LENGTH_EPS)
  assert_true(
    (section.area_mm2 - (@math.PI * 25.0 - pocket_area)).abs() < TEST_VALUE_EPS,
  )
  assert_true(
    (section.perimeter_mm -
    (2.0 * @math.PI * 5.0 + 2.0 * Double::sqrt(3.0) * 4.0)).abs() <
    TEST_VALUE_EPS,
  )
}

///|
test "socketed solid compiles to one closed analytic shell" {
  let body = RevolvedProfile::chamfered_cylinder(10.0, 10.0, top_chamfer=1.0)
  let socket = SocketedSolid::new(body, 4.0, 5.0)
  let step = Design::new(name="socketed")
    .add(socket.as_shape().with_name("socketed"))
    .to_step_file()
  // 3 revolved faces (bottom disc, cylinder, cone) + annular top + 6 walls +
  // floor = 11 faces.
  assert_eq(socket_count_sub(step, "ADVANCED_FACE("), 11)
  assert_eq(socket_count_sub(step, "PLANE("), 9)
  assert_eq(socket_count_sub(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(socket_count_sub(step, "CONICAL_SURFACE("), 1)
  assert_eq(socket_count_sub(step, "CLOSED_SHELL("), 1)
  assert_eq(socket_count_sub(step, "MANIFOLD_SOLID_BREP("), 1)
}

///|
test "socketed solid rejects a socket wider than the flat top" {
  let body = RevolvedProfile::cylinder(10.0, 10.0)
  let socket = SocketedSolid::new(body, 20.0, 5.0)
  assert_true(socketed_geometry(socket) is None)
  assert_eq(socket.volume(), 0.0)
}
