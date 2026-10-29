///|
/// step_points extracts every CARTESIAN_POINT coordinate triple from STEP text.
fn step_points(step : String) -> Array[Vec3] {
  let out : Array[Vec3] = []
  let marker = "CARTESIAN_POINT('',("
  let parts = step.split(marker).collect()
  for i in 1..<parts.length() {
    let coords = parts[i].split(")").collect()[0]
    let xyz = coords.split(",").collect()
    if xyz.length() == 3 {
      let x = @string.parse_double(xyz[0]) catch { _ => 0.0 }
      let y = @string.parse_double(xyz[1]) catch { _ => 0.0 }
      let z = @string.parse_double(xyz[2]) catch { _ => 0.0 }
      out.push((x, y, z))
    }
  }
  out
}

///|
fn points_bounds(pts : Array[Vec3]) -> (Vec3, Vec3) {
  let mut min = (1.0e30, 1.0e30, 1.0e30)
  let mut max = (-1.0e30, -1.0e30, -1.0e30)
  for p in pts {
    if p.0 < min.0 {
      min = (p.0, min.1, min.2)
    }
    if p.1 < min.1 {
      min = (min.0, p.1, min.2)
    }
    if p.2 < min.2 {
      min = (min.0, min.1, p.2)
    }
    if p.0 > max.0 {
      max = (p.0, max.1, max.2)
    }
    if p.1 > max.1 {
      max = (max.0, p.1, max.2)
    }
    if p.2 > max.2 {
      max = (max.0, max.1, p.2)
    }
  }
  (min, max)
}

///|
fn assert_near(actual : Double, expected : Double) -> Unit {
  if (actual - expected).abs() > 1.0e-9 {
    abort("expected \{expected}, got \{actual}")
  }
}

///|
test "translate on a difference moves base and cutters" {
  let base = Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = Cuboid::new(4.0, 4.0, 10.0).with_name("cutter").translate(z=-2.0)
  let cut = difference(base, [cutter], name="cut").translate(x=10.0, y=3.0)
  let step = Design::new(name="translate-difference").add(cut).to_step_file()
  let (min, _max) = points_bounds(step_points(step))
  assert_near(min.0, 10.0)
  assert_near(min.1, 3.0)
  assert_near(min.2, -2.0)
}

///|
test "rotation on a union rotates all children" {
  let a = Cuboid::new(10.0, 5.0, 2.0).with_name("a")
  let b = Cuboid::new(10.0, 5.0, 2.0).with_name("b").translate(x=20.0)
  let u = union_all([a, b], name="pair").rotate_z(90.0)
  let step = Design::new(name="rotate-union").add(u).to_step_file()
  let (min, max) = points_bounds(step_points(step))
  // The union's x extent (0..30) becomes its y extent (0..30) and the
  // original y extent (0..5) becomes x (-5..0).
  assert_near(min.0, -5.0)
  assert_near(max.0, 0.0)
  assert_near(min.1, 0.0)
  assert_near(max.1, 30.0)
}

///|
test "leaf transforms are unchanged" {
  let node = Cuboid::new(2.0, 3.0, 4.0)
    .with_name("leaf")
    .translate(x=1.0)
    .rotate_z(90.0)
  let step = Design::new(name="leaf-transform").add(node).to_step_file()
  let (min, max) = points_bounds(step_points(step))
  // rotate (x,y) -> (-y,x), then translate x by 1.
  assert_near(min.0, -2.0)
  assert_near(max.0, 1.0)
  assert_near(min.1, 0.0)
  assert_near(max.1, 2.0)
  assert_near(min.2, 0.0)
  assert_near(max.2, 4.0)
}

///|
test "translate after Design::add applies to composites" {
  let base = Cuboid::new(10.0, 10.0, 2.0).with_name("base")
  let cutter = Cuboid::new(2.0, 2.0, 4.0).with_name("cutter")
  let cut = difference(base, [cutter], name="cut")
  let step = Design::new(name="design-translate")
    .add(cut)
    .translate(x=5.0)
    .to_step_file()
  let (min, _max) = points_bounds(step_points(step))
  assert_near(min.0, 5.0)
}
