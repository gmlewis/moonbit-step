///|
fn circle_radii(step : String) -> Array[Double] {
  let out : Array[Double] = []
  let parts = step.split("CIRCLE('',").collect()
  for i in 1..<parts.length() {
    let body = parts[i].split(")").collect()[0]
    let fields = body.split(",").collect()
    if fields.length() >= 2 {
      let r = @string.parse_double(fields[1]) catch { _ => 0.0 }
      out.push(r)
    }
  }
  out
}

///|
/// oriented_edge_uses returns (edge_id, sense) pairs for every ORIENTED_EDGE.
fn oriented_edge_uses(step : String) -> Array[(String, Bool)] {
  let out : Array[(String, Bool)] = []
  let parts = step.split("ORIENTED_EDGE('',*,*,").collect()
  for i in 1..<parts.length() {
    let body = parts[i].split(");").collect()[0]
    let fields = body.split(",").collect()
    if fields.length() >= 2 {
      out.push((fields[0].to_owned(), fields[1].contains("T")))
    }
  }
  out
}

///|
test "cylinder emits analytic surfaces" {
  let step = Design::new(name="cylinder")
    .add(Cylinder::new(10.0, 5.0).with_name("pin"))
    .to_step_file()
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="3")
  inspect(step.split("CYLINDRICAL_SURFACE(").count() - 1, content="1")
  inspect(step.split("PLANE(").count() - 1, content="2")
  inspect(step.split("CIRCLE(").count() - 1, content="2")
  inspect(step.split("LINE(").count() - 1, content="1")
  inspect(step.split("EDGE_CURVE(").count() - 1, content="3")
}

///|
test "cylinder radius and height are exact" {
  let step = Design::new(name="cylinder")
    .add(Cylinder::new(10.0, 5.0).with_name("pin"))
    .to_step_file()
  let radii = circle_radii(step)
  inspect(radii.length(), content="2")
  for r in radii {
    assert_true((r - 5.0).abs() < 1.0e-9)
  }
  let (min, max) = points_bounds(step_points(step))
  assert_true((min.2 - 0.0).abs() < 1.0e-9)
  assert_true((max.2 - 5.0).abs() < 1.0e-9)
  // The seam vertices are the only boundary points emitted: (r,0,0) and
  // (r,0,h). The circular rims themselves are analytic.
  assert_true((min.0 - 0.0).abs() < 1.0e-9)
  assert_true((max.0 - 5.0).abs() < 1.0e-9)
}

///|
test "cylinder seam edge is used twice in opposite directions" {
  let step = Design::new(name="cylinder")
    .add(Cylinder::new(10.0, 5.0).with_name("pin"))
    .to_step_file()
  let uses = oriented_edge_uses(step)
  inspect(uses.length(), content="6")
  let senses : Map[String, Array[Bool]] = Map([])
  for u in uses {
    let (edge, sense) = u
    let list = match senses.get(edge) {
      Some(l) => l
      None => []
    }
    list.push(sense)
    senses.set(edge, list)
  }
  inspect(senses.length(), content="3")
  for _edge, list in senses {
    inspect(list.length(), content="2")
    assert_true(list[0] != list[1])
  }
}
