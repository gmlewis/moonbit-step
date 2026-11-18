///|
fn assert_closed_manifold_edges(step : String) -> Unit raise {
  let edge_ids : Array[String] = []
  let pos_counts : Map[String, Int32] = Map([])
  let neg_counts : Map[String, Int32] = Map([])
  for raw in step.split("\n") {
    let line = raw.to_owned().trim().to_owned()
    if line.contains("=EDGE_CURVE(") {
      let id = line.split("=").head().unwrap().to_owned()
      edge_ids.push(id)
    } else if line.contains("=ORIENTED_EDGE(") {
      let body = line.split("(").drop(1).head().unwrap().to_owned()
      let parts = body.split(",").map(fn(s) { s.to_owned() }).collect()
      let eid = parts[3]
      let sense = parts[4].contains(".T.")
      if sense {
        pos_counts.set(eid, pos_counts.get(eid).unwrap_or(0) + 1)
      } else {
        neg_counts.set(eid, neg_counts.get(eid).unwrap_or(0) + 1)
      }
    }
  }
  assert_true(edge_ids.length() > 0)
  for id in edge_ids {
    assert_eq(pos_counts.get(id).unwrap_or(0), 1)
    assert_eq(neg_counts.get(id).unwrap_or(0), 1)
  }
}

///|
test "PipeJunction emits watertight 2-manifold analytic B-Rep for tee, cross, corner, 4way, 5way" {
  let tee = PipeJunction::new(
    [(0.0, 0.0, -1.0), (0.0, 0.0, 1.0), (1.0, 0.0, 0.0)],
    34.0,
    21.0,
    27.0,
    14.5,
    22.0,
    mouth_chamfer_mm=0.5,
  )
  let corner = PipeJunction::new(
    [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)],
    34.0,
    21.0,
    27.0,
    14.5,
    22.0,
  )
  let four_way = PipeJunction::new(
    [(1.0, 0.0, 0.0), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)],
    34.0,
    21.0,
    27.0,
    14.5,
    22.0,
  )
  let five_way = PipeJunction::new(
    [
      (1.0, 0.0, 0.0),
      (-1.0, 0.0, 0.0),
      (0.0, 1.0, 0.0),
      (0.0, -1.0, 0.0),
      (0.0, 0.0, 1.0),
    ],
    34.0,
    21.0,
    27.0,
    14.5,
    22.0,
  )
  for
    pair in [
      ("tee", tee, true, false),
      ("corner", corner, true, true),
      ("four_way", four_way, true, false),
      ("five_way", five_way, true, false),
    ] {
    let (name, shape, has_ellipse, has_sphere) = pair
    let step = Design::new(name~).add(shape.with_name(name)).to_step_file()
    assert_eq(step.split("CLOSED_SHELL(").count() - 1, 1)
    assert_eq(step.contains("ELLIPSE("), has_ellipse)
    assert_eq(step.contains("SPHERICAL_SURFACE("), has_sphere)
    assert_false(step.contains("B_SPLINE_SURFACE_WITH_KNOTS("))
    assert_closed_manifold_edges(step)
  }
}

///|
test "PipeJunction validation rejects duplicate, diagonal, or undersized geometry" {
  let empty : PipeJunction = {
    ports: [],
    outer_diameter_mm: 34.0,
    through_bore_mm: 21.0,
    socket_bore_mm: 27.0,
    center_to_seat_mm: 14.5,
    socket_depth_mm: 22.0,
    mouth_chamfer_mm: 0.0,
  }
  let diag : PipeJunction = { ..empty, ports: [(1.0, 1.0, 0.0)], }
  let dup : PipeJunction = {
    ..empty,
    ports: [(1.0, 0.0, 0.0), (1.0, 0.0, 0.0)],
  }
  let short_seat : PipeJunction = {
    ..empty,
    ports: [(1.0, 0.0, 0.0)],
    center_to_seat_mm: 13.0,
  }
  assert_false(empty.validate())
  assert_false(diag.validate())
  assert_false(dup.validate())
  // center_to_seat <= socket_bore/2 violates bore non-overlap.
  assert_false(short_seat.validate())
}
