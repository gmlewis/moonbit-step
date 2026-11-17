///|
fn mp_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn mp_close_vec(a : @cad.Vec3, b : @cad.Vec3, tol : Double) -> Bool {
  mp_close(a.0, b.0, tol) && mp_close(a.1, b.1, tol) && mp_close(a.2, b.2, tol)
}

///|
fn mp_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn mp_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  match part.connector(name) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "Maker Pipe size table uses the published 3/4 in envelope" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_false(size.derived)
  assert_true(mp_close(size.through_pipe_od_mm, 23.4188, 1.0e-9))
  assert_true(mp_close(size.socket_bore_mm, 23.876, 1.0e-9))
  assert_true(mp_close(size.socket_outer_mm, 28.956, 1.0e-9))
  assert_true(mp_close(size.saddle_bore_mm, 23.622, 1.0e-9))
  assert_true(mp_close(size.saddle_outer_mm, 28.702, 1.0e-9))
  assert_true(mp_close(size.tee_branch_depth_mm, 30.988, 1.0e-9))
  assert_true(mp_close(size.branch_centre_to_mouth_mm, 63.5, 1.0e-9))
  assert_true(mp_close(size.run_length_mm, 77.978, 1.0e-9))
}

///|
test "Maker Pipe 1 in size is derived and 1/2 in is refused as non-native" {
  let one = match @makerpipe.makerpipe_size("1") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(one.derived)
  assert_true(mp_close(one.through_pipe_od_mm, 29.5402, 1.0e-9))
  assert_true(one.socket_bore_mm > one.through_pipe_od_mm)
  assert_true(@makerpipe.makerpipe_size("1/2") is Err(_))
  assert_true(@makerpipe.makerpipe_size("2") is Err(_))
}

///|
test "EMT outside diameters match the motion package" {
  let emt = match @motion.emt_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(
    mp_close(emt.outside_diameter_mm, part.through_pipe_od_mm, 1.0e-9),
  )
  let emt1 = match @motion.emt_size("1") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part1 = match @makerpipe.makerpipe_size("1") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(
    mp_close(emt1.outside_diameter_mm, part1.through_pipe_od_mm, 1.0e-9),
  )
}

///|
test "T connector has a run sleeve, one branch socket, and named mates" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.tee(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 2)
  assert_true(part.features().modeled.contains("run-sleeve"))
  assert_true(part.features().modeled.contains("run-bore"))
  assert_false(part.features().modeled.contains("through-bore"))
  for
    name in [
      "origin", "run-axis", "run-a", "run-b", "branch-1", "mouth-1", "bolt",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mp_close(x0, -38.989, 1.0e-6))
  assert_true(mp_close(x1, 38.989, 1.0e-6))
  assert_true(mp_close(y0, -14.478, 1.0e-6))
  assert_true(mp_close(y1, 11.7094 + 30.988, 1.0e-6))
  assert_true(mp_close(z0, -14.478, 1.0e-6))
  assert_true(mp_close(z1, 14.478, 1.0e-6))
  let branch = mp_connector(part, "branch-1")
  assert_eq(branch.kind, @common.MateKind::CylindricalBore)
  assert_eq(branch.gender, @common.MateGender::Female)
  assert_true(mp_close(branch.diameter_mm.unwrap(), 23.876, 1.0e-9))
  assert_true(mp_close_vec(branch.placement.trans, (0.0, 11.7094, 0.0), 1.0e-6))
  assert_true(mp_close_vec(branch.axis, (0.0, 1.0, 0.0), 1.0e-9))
  // The placement's +Z points into the socket, opposite the bore axis.
  assert_true(
    mp_close_vec(
      branch.placement.apply_dir((0.0, 0.0, 1.0)),
      (0.0, -1.0, 0.0),
      1.0e-9,
    ),
  )
}

///|
test "a pipe snapped to the T branch seat extends out through the mouth" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let tee = match @makerpipe.tee(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let emt = match @motion.emt_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let pipe = match @motion.emt_tube(emt, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let socket = mp_connector(tee, "branch-1")
  let leading = mp_connector(pipe, "end-b")
  let (snapped, _) = @common.snap_connectors(socket, leading)
  // The leading pipe end lands on the seat.
  assert_true(
    mp_close_vec(
      snapped.apply_point((0.0, 0.0, 100.0)),
      (0.0, 11.7094, 0.0),
      1.0e-6,
    ),
  )
  // The pipe body extends outward along +Y, not back into the fitting.
  assert_true(
    mp_close_vec(
      snapped.apply_point((0.0, 0.0, 0.0)),
      (0.0, 111.7094, 0.0),
      1.0e-6,
    ),
  )
}

///|
test "90 degree connector has two open sockets and a through saddle" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.elbow_90(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 4)
  assert_true(part.features().modeled.contains("saddle-rims"))
  assert_true(part.features().modeled.contains("through-bore"))
  for
    name in [
      "origin", "through", "through-bore", "socket-1", "mouth-1", "socket-2", "mouth-2",
      "bolt",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let bore = mp_connector(part, "through-bore")
  assert_true(mp_close(bore.diameter_mm.unwrap(), 23.622, 1.0e-9))
  let s1 = mp_connector(part, "socket-1")
  assert_true(mp_close_vec(s1.placement.trans, (11.7094, 0.0, 0.0), 1.0e-6))
  assert_true(mp_close_vec(s1.axis, (1.0, 0.0, 0.0), 1.0e-9))
  let s2 = mp_connector(part, "socket-2")
  assert_true(mp_close_vec(s2.placement.trans, (0.0, 11.7094, 0.0), 1.0e-6))
  assert_true(mp_close_vec(s2.axis, (0.0, 1.0, 0.0), 1.0e-9))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mp_close(x0, -14.478, 1.0e-6))
  assert_true(mp_close(x1, 63.5, 1.0e-6))
  assert_true(mp_close(y0, -14.478, 1.0e-6))
  assert_true(mp_close(y1, 63.5, 1.0e-6))
  assert_true(mp_close(z0, -16.51, 1.0e-6))
  assert_true(mp_close(z1, 16.51, 1.0e-6))
}

///|
test "the saddle family builds the expected socket and saddle layer counts" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let e45 = match @makerpipe.elbow_45(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(e45.layers().length(), 4)
  let e135 = match @makerpipe.elbow_135(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(e135.layers().length(), 4)
  let s180 = match @makerpipe.straight_180(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(s180.layers().length(), 4)
  let four = match @makerpipe.four_way(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(four.layers().length(), 5)
  assert_true(mp_has_connector(four, "socket-3"))
  let five = match @makerpipe.five_way(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(five.layers().length(), 6)
  assert_true(mp_has_connector(five, "socket-4"))
}

///|
test "saddle connector validates branch angles" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(@makerpipe.saddle_connector(size, []) is Err(_))
  let dedup = match @makerpipe.saddle_connector(size, [0.0, 0.0]) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let mut socket_count = 0
  for connector in dedup.connectors() {
    if connector.name.has_prefix("socket-") {
      socket_count = socket_count + 1
    }
  }
  assert_eq(socket_count, 1)
  assert_true(@makerpipe.elbow(size, 0.0) is Err(_))
  assert_true(@makerpipe.elbow(size, 360.0) is Err(_))
}

///|
test "1 in T derives its geometry from the 3/4 in drawing" {
  let size = match @makerpipe.makerpipe_size("1") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.tee(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(part.metadata().source.contains("approximate"))
  let branch = mp_connector(part, "branch-1")
  assert_true(mp_close_vec(branch.placement.trans, (0.0, 14.7701, 0.0), 1.0e-4))
}

///|
test "coupling seats two pipe ends at the centre plane" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.coupling(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 1)
  for
    name in [
      "origin", "seam", "socket-a", "mouth-a", "socket-b", "mouth-b", "bolt",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mp_close(x0, -14.478, 1.0e-6))
  assert_true(mp_close(x1, 14.478, 1.0e-6))
  assert_true(mp_close(y0, -14.478, 1.0e-6))
  assert_true(mp_close(y1, 14.478, 1.0e-6))
  assert_true(mp_close(z0, -30.988, 1.0e-6))
  assert_true(mp_close(z1, 30.988, 1.0e-6))
  let a = mp_connector(part, "socket-a")
  assert_true(mp_close_vec(a.placement.trans, (0.0, 0.0, 0.0), 1.0e-9))
  assert_true(mp_close_vec(a.axis, (0.0, 0.0, -1.0), 1.0e-9))
  assert_true(
    mp_close_vec(
      a.placement.apply_dir((0.0, 0.0, 1.0)),
      (0.0, 0.0, 1.0),
      1.0e-9,
    ),
  )
  let b = mp_connector(part, "socket-b")
  assert_true(mp_close_vec(b.axis, (0.0, 0.0, 1.0), 1.0e-9))
  assert_true(
    mp_close_vec(
      b.placement.apply_dir((0.0, 0.0, 1.0)),
      (0.0, 0.0, -1.0),
      1.0e-9,
    ),
  )
}

///|
test "flange has a mount face, four mount holes, and a seated socket" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.flange(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 2)
  for
    name in [
      "origin", "mount", "socket", "mouth", "mount-hole-1", "mount-hole-2", "mount-hole-3",
      "mount-hole-4",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mp_close(x0, -35.0, 1.0e-6))
  assert_true(mp_close(x1, 35.0, 1.0e-6))
  assert_true(mp_close(y0, -35.0, 1.0e-6))
  assert_true(mp_close(y1, 35.0, 1.0e-6))
  assert_true(mp_close(z0, 0.0, 1.0e-6))
  assert_true(mp_close(z1, 35.988, 1.0e-6))
  let socket = mp_connector(part, "socket")
  assert_true(mp_close_vec(socket.placement.trans, (0.0, 0.0, 5.0), 1.0e-6))
  assert_true(mp_close_vec(socket.axis, (0.0, 0.0, 1.0), 1.0e-9))
  let hole = mp_connector(part, "mount-hole-1")
  assert_true(mp_close(hole.placement.trans.0, 19.091883092, 1.0e-6))
  assert_true(mp_close(hole.placement.trans.1, 19.091883092, 1.0e-6))
}

///|
test "adjustable hinge pivots an end socket about +Y" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.adjustable_hinge(size, 30.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 3)
  for
    name in [
      "origin", "through", "through-bore", "pivot-1", "socket-end-1", "mouth-end-1",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let socket = mp_connector(part, "socket-end-1")
  assert_true(mp_close_vec(socket.placement.trans, (14.351, 0.0, 0.0), 1.0e-6))
  assert_true(mp_close(socket.axis.0, @math.cos(@math.PI / 6.0), 1.0e-9))
  assert_true(mp_close(socket.axis.2, 0.5, 1.0e-9))
  let pivot = mp_connector(part, "pivot-1")
  assert_true(mp_close_vec(pivot.axis, (0.0, 1.0, 0.0), 1.0e-9))
  assert_true(@makerpipe.adjustable_hinge(size, 91.0) is Err(_))
}

///|
test "adjustable 180 has two independent pivoting end sockets" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.adjustable_180(size, 0.0, 0.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 5)
  for
    name in [
      "origin", "through", "through-bore", "pivot-1", "pivot-2", "socket-end-1",
      "socket-end-2", "mouth-end-1", "mouth-end-2",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let s1 = mp_connector(part, "socket-end-1")
  assert_true(mp_close_vec(s1.placement.trans, (14.351, 0.0, 0.0), 1.0e-6))
  assert_true(mp_close_vec(s1.axis, (1.0, 0.0, 0.0), 1.0e-9))
  let s2 = mp_connector(part, "socket-end-2")
  assert_true(mp_close_vec(s2.placement.trans, (-14.351, 0.0, 0.0), 1.0e-6))
  assert_true(mp_close_vec(s2.axis, (-1.0, 0.0, 0.0), 1.0e-9))
  assert_true(@makerpipe.adjustable_180(size, 0.0, -91.0) is Err(_))
}

///|
test "adjustable flange pivots one socket above a mount base" {
  let size = match @makerpipe.makerpipe_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @makerpipe.adjustable_flange(size, 0.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 3)
  for
    name in [
      "origin", "mount", "mount-hole-1", "mount-hole-4", "pivot", "socket-end", "mouth-end",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let socket = mp_connector(part, "socket-end")
  assert_true(mp_close_vec(socket.placement.trans, (0.0, 0.0, 18.478), 1.0e-6))
  assert_true(mp_close_vec(socket.axis, (0.0, 0.0, 1.0), 1.0e-9))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mp_close(x0, -35.0, 1.0e-6))
  assert_true(mp_close(x1, 35.0, 1.0e-6))
  assert_true(mp_close(y0, -35.0, 1.0e-6))
  assert_true(mp_close(y1, 35.0, 1.0e-6))
  assert_true(mp_close(z0, 0.0, 1.0e-6))
  assert_true(z1 > 60.0)
}

///|
test "top rail tee uses the 1.315 in rail envelope and alias mates" {
  let size = @makerpipe.top_rail_size()
  assert_eq(size.trade_size, "1-3/8")
  assert_true(size.derived)
  assert_true(mp_close(size.through_pipe_od_mm, 33.401, 1.0e-9))
  assert_true(mp_close(size.socket_bore_mm, 33.861, 1.0e-9))
  let part = match @makerpipe.top_rail_tee() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.name(), "makerpipe-top-rail-tee")
  assert_true(part.metadata().designation.contains("Top Rail"))
  assert_eq(part.layers().length(), 3)
  for
    name in [
      "origin", "through", "through-bore", "rail", "rail-bore", "socket-1", "mouth-1",
      "bolt",
    ] {
    assert_true(mp_has_connector(part, name))
  }
  let socket = mp_connector(part, "socket-1")
  assert_true(mp_close(socket.diameter_mm.unwrap(), 33.861, 1.0e-9))
  let bore = mp_connector(part, "through-bore")
  assert_true(mp_close(bore.diameter_mm.unwrap(), 33.601, 1.0e-9))
}
