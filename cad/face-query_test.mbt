///|
/// Black-box tests for planar face discovery and sketch-on-face placement.

///|
fn len3(v : @cad.Vec3) -> Double {
  let (x, y, z) = v
  (x * x + y * y + z * z).sqrt()
}

///|
fn dot3(a : @cad.Vec3, b : @cad.Vec3) -> Double {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  ax * bx + ay * by + az * bz
}

///|
fn box_faces() -> @cad.FaceSet {
  @cad.Design::new(name="box")
  .add(@cad.Cuboid::new(20.0, 20.0, 20.0).with_name("box"))
  .planar_faces()
}

///|
fn has_normal(faces : @cad.FaceSet, dir : @cad.Vec3) -> Bool {
  let d = len3(dir)
  faces.faces.any(fn(f) { dot3(f.normal, dir) / d > 1.0 - 1.0e-6 })
}

///|
test "a cuboid exposes six planar faces" {
  let faces = box_faces()
  inspect(faces.length(), content="6")
  for f in faces.faces {
    assert_approx_eq(len3(f.normal), 1.0)
    assert_approx_eq(f.area, 400.0)
    assert_approx_eq(dot3(f.u, f.normal), 0.0)
    assert_approx_eq(dot3(f.v, f.normal), 0.0)
    assert_approx_eq(dot3(f.u, f.v), 0.0)
    assert_approx_eq(len3(f.u), 1.0)
    assert_approx_eq(len3(f.v), 1.0)
    // Right-handed face frame: u x v == normal.
    let (ux, uy, uz) = f.u
    let (vx, vy, vz) = f.v
    let cross = (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)
    assert_approx_eq(cross.0, f.normal.0)
    assert_approx_eq(cross.1, f.normal.1)
    assert_approx_eq(cross.2, f.normal.2)
  }
  // Exactly one face points along each axis direction.
  for
    dir in [
      (1.0, 0.0, 0.0),
      (-1.0, 0.0, 0.0),
      (0.0, 1.0, 0.0),
      (0.0, -1.0, 0.0),
      (0.0, 0.0, 1.0),
      (0.0, 0.0, -1.0),
    ] {
    assert_true(has_normal(faces, dir))
  }
}

///|
test "aligned_with selects the top face" {
  let top = box_faces().aligned_with((0.0, 0.0, 1.0))
  inspect(top.length(), content="1")
  let f = top.faces[0]
  assert_approx_eq(f.normal.0, 0.0)
  assert_approx_eq(f.normal.1, 0.0)
  assert_approx_eq(f.normal.2, 1.0)
  assert_approx_eq(f.point.0, 0.0)
  assert_approx_eq(f.point.1, 0.0)
  assert_approx_eq(f.point.2, 20.0)
  assert_approx_eq(f.area, 400.0)
  // A non-unit query direction is normalised.
  inspect(box_faces().aligned_with((0.0, 0.0, 3.0)).length(), content="1")
}

///|
test "sort_by_z orders faces by their plane origin" {
  let faces = box_faces()
  let high = faces.sort_by_z()
  assert_approx_eq(high.faces[0].point.2, 0.0)
  assert_approx_eq(high.faces[5].point.2, 20.0)
  let low = faces.sort_by_z(ascending=false)
  assert_approx_eq(low.faces[0].point.2, 20.0)
  assert_approx_eq(low.faces[5].point.2, 0.0)
}

///|
test "first_matching finds a face by predicate" {
  let faces = box_faces()
  let found = faces.first_matching(fn(f) { f.point.2 > 10.0 })
  match found {
    Some(f) => assert_approx_eq(f.point.2, 20.0)
    None => fail("expected a matching face")
  }
  assert_true(faces.first_matching(fn(_f) { false }) is None)
}

///|
test "a cylinder exposes its two planar caps, not the lateral surface" {
  let faces = @cad.Design::new(name="cyl")
    .add(@cad.Cylinder::new(6.0, 10.0).with_name("cyl"))
    .planar_faces()
  inspect(faces.length(), content="2")
  for f in faces.faces {
    // pi * 3^2
    assert_approx_eq(f.area, 28.27433388)
    assert_approx_eq(f.normal.0, 0.0)
    assert_approx_eq(f.normal.1, 0.0)
  }
  let sorted = faces.sort_by_z()
  assert_approx_eq(sorted.faces[0].point.2, 0.0)
  assert_approx_eq(sorted.faces[1].point.2, 10.0)
  // A circular cap's center is the plane origin, not a rim vertex.
  let top_center = sorted.faces[1].center()
  assert_approx_eq(top_center.0, 0.0)
  assert_approx_eq(top_center.1, 0.0)
  assert_approx_eq(top_center.2, 10.0)
}

///|
test "a profile on a face is rotated into the face frame" {
  let top = box_faces().aligned_with((0.0, 0.0, 1.0)).faces[0]
  let profile = @cad.Profile2D::new(@cad.Profile2D::circle(6.0, segments=32))
  let boss = profile.on_face(top, 5.0, name="boss")
  // Non-`into` placement starts on the face and extrudes outward.
  assert_approx_eq(boss.tx, 0.0)
  assert_approx_eq(boss.ty, 0.0)
  assert_approx_eq(boss.tz, 20.0)
  let (nx, ny, nz) = @cad.rotate_point(
    (0.0, 0.0, 1.0),
    boss.rx,
    boss.ry,
    boss.rz,
  )
  assert_approx_eq(nx, top.normal.0)
  assert_approx_eq(ny, top.normal.1)
  assert_approx_eq(nz, top.normal.2)
  let (ux, uy, uz) = @cad.rotate_point(
    (1.0, 0.0, 0.0),
    boss.rx,
    boss.ry,
    boss.rz,
  )
  assert_approx_eq(ux, top.u.0)
  assert_approx_eq(uy, top.u.1)
  assert_approx_eq(uz, top.u.2)
}

///|
test "an into profile starts below the face" {
  let top = box_faces().aligned_with((0.0, 0.0, 1.0)).faces[0]
  let profile = @cad.Profile2D::new(@cad.Profile2D::circle(6.0, segments=32))
  let hole = profile.on_face(top, 25.0, into=true, name="hole")
  assert_approx_eq(hole.tx, 0.0)
  assert_approx_eq(hole.ty, 0.0)
  assert_approx_eq(hole.tz, -5.0)
  let (nx, ny, nz) = @cad.rotate_point(
    (0.0, 0.0, 1.0),
    hole.rx,
    hole.ry,
    hole.rz,
  )
  assert_approx_eq(nx, 0.0)
  assert_approx_eq(ny, 0.0)
  assert_approx_eq(nz, 1.0)
}

///|
test "cut_on_face builds a nominal difference" {
  let base = @cad.Cuboid::new(40.0, 30.0, 10.0).with_name("block")
  let top = @cad.Design::new(name="block")
    .add(base)
    .planar_faces()
    .aligned_with((0.0, 0.0, 1.0)).faces[0]
  let profile = @cad.Profile2D::new(@cad.Profile2D::circle(8.0, segments=32))
  let design = @cad.Design::new(name="hole").add(
    @cad.cut_on_face(base, profile, top, 10.0),
  )
  // The nominal backend reports the difference; evaluation is opt-in.
  inspect(design.diagnostics().length(), content="1")
  assert_true(design.to_csg_step().contains("BOOLEAN_RESULT("))
}

///|
async fn face_command_in_path(name : String) -> Bool {
  let path = @env.get_env_var("PATH").unwrap_or("")
  for dir in path.split(":").collect() {
    let dir = dir.to_owned()
    if !dir.is_empty() && @fs.exists(dir + "/" + name) {
      return true
    }
  }
  false
}

///|
async test "a face-query cut evaluates to a real trimmed solid" {
  if !face_command_in_path("python3") ||
    !(face_command_in_path("DRAWEXE") || face_command_in_path("occt-draw")) {
    return
  }
  let base = @cad.Cuboid::new(40.0, 30.0, 10.0).with_name("block")
  let top = @cad.Design::new(name="block")
    .add(base)
    .planar_faces()
    .aligned_with((0.0, 0.0, 1.0)).faces[0]
  let profile = @cad.Profile2D::new(@cad.Profile2D::circle(8.0, segments=32))
  let design = @cad.Design::new(name="hole").add(
    @cad.cut_on_face(base, profile, top, 10.0),
  )
  let dir = @fs.tmpdir(prefix="face-cut-")
  defer @fs.rmdir(dir, recursive=true)
  let out = dir + "/cut.step"
  design.write_step_evaluated(Some(out))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("MANIFOLD_SOLID_BREP"))
  assert_false(text.contains("BOOLEAN_RESULT("))
  // Trimming produces many more faces than the six-faced block.
  assert_true(text.split("ADVANCED_FACE(").count() - 1 >= 10)
  let (code, output) = run_validator([
    "./scripts/validate_step.py", "--no-mesh", out,
  ])
  assert_validator_ok(code, output)
}
