///|
fn an_close(actual : Double, expected : Double, tol : Double) -> Unit {
  if !((actual - expected).abs() <= tol) {
    abort("expected \{expected}, got \{actual} (tol \{tol})")
  }
}

///|
fn an_close_rel(actual : Double, expected : Double, rel : Double) -> Unit {
  let denom = if expected.abs() > 1.0e-12 { expected.abs() } else { 1.0 }
  an_close(actual, expected, denom * rel)
}

///|
fn an_volume(shape : Shape) -> Double {
  match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort("expected a volume, got " + e.message())
  }
}

///|
test "analysis cylinder section and volume are hand-computed" {
  let shape = Cylinder::new(10.0, 10.0)
  let section = match shape.section_at_local(5.0) {
    Ok(s) => s
    Err(_) => abort("expected a cylinder section")
  }
  an_close(section.area_mm2, 78.53981633974483, 1.0e-9)
  an_close(section.perimeter_mm, 31.41592653589793, 1.0e-9)
  an_close(section.outer_radius_mm, 5.0, 1.0e-9)
  an_close(section.inner_radius_mm, 0.0, 1.0e-9)
  assert_eq(section.rings.length(), 1)
  an_close(section.rings[0].outer_radius_mm, 5.0, 1.0e-9)
  an_close(an_volume(shape), 785.3981633974483, 1.0e-9)
  let centroid = match shape.analysis_centroid() {
    Ok(c) => c
    Err(_) => abort("expected a cylinder centroid")
  }
  an_close(centroid.0, 0.0, 1.0e-9)
  an_close(centroid.1, 0.0, 1.0e-9)
  an_close(centroid.2, 5.0, 1.0e-9)
}

///|
test "analysis revolved cylinder mirrors the analytic cylinder" {
  let shape = RevolvedProfile::cylinder(10.0, 10.0).as_shape()
  let section = match shape.section_at_local(5.0) {
    Ok(s) => s
    Err(_) => abort("expected a revolved section")
  }
  an_close(section.area_mm2, 78.53981633974483, 1.0e-9)
  an_close(section.perimeter_mm, 31.41592653589793, 1.0e-9)
  an_close(section.outer_radius_mm, 5.0, 1.0e-9)
  an_close(an_volume(shape), 785.3981633974483, 1.0e-9)
  // Cap planes are valid sections and give the same disc.
  let cap = match shape.section_at_local(0.0) {
    Ok(s) => s
    Err(_) => abort("expected a cap section")
  }
  an_close(cap.area_mm2, 78.53981633974483, 1.0e-9)
}

///|
test "analysis revolved tube is an annulus" {
  let shape = RevolvedProfile::tube(10.0, 6.0, 5.0).as_shape()
  let section = match shape.section_at_local(2.5) {
    Ok(s) => s
    Err(_) => abort("expected a tube section")
  }
  an_close(section.area_mm2, 50.26548245743669, 1.0e-9)
  an_close(section.perimeter_mm, 50.26548245743669, 1.0e-9)
  an_close(section.outer_radius_mm, 5.0, 1.0e-9)
  an_close(section.inner_radius_mm, 3.0, 1.0e-9)
  assert_eq(section.rings.length(), 1)
  an_close(an_volume(shape), 251.32741228718345, 1.0e-9)
}

///|
test "analysis chamfered cylinder section follows the cone" {
  let shape = RevolvedProfile::chamfered_cylinder(
    10.0,
    10.0,
    bottom_chamfer=1.0,
  ).as_shape()
  let at_half = match shape.section_at_local(0.5) {
    Ok(s) => s
    Err(_) => abort("expected a chamfered section")
  }
  let r = 4.5
  an_close(at_half.area_mm2, @math.PI * r * r, 1.0e-9)
  an_close(at_half.outer_radius_mm, r, 1.0e-9)
  let at_mid = match shape.section_at_local(5.0) {
    Ok(s) => s
    Err(_) => abort("expected a mid section")
  }
  an_close(at_mid.area_mm2, 78.53981633974483, 1.0e-9)
  // V = pi * (integral of r(z)^2 over 0..10)
  let expected = @math.PI *
    ((5.0 * 5.0 * 5.0 - 4.0 * 4.0 * 4.0) / 3.0 + 25.0 * 9.0)
  an_close_rel(an_volume(shape), expected, 1.0e-12)
}

///|
test "analysis sphere section, volume and centroid" {
  let shape = RevolvedProfile::sphere(10.0).as_shape()
  let section = match shape.section_at_local(0.0) {
    Ok(s) => s
    Err(_) => abort("expected a sphere equator section")
  }
  an_close(section.area_mm2, 78.53981633974483, 1.0e-7)
  an_close(section.outer_radius_mm, 5.0, 1.0e-7)
  an_close_rel(an_volume(shape), 4.0 / 3.0 * @math.PI * 125.0, 1.0e-9)
  let centroid = match shape.analysis_centroid() {
    Ok(c) => c
    Err(_) => abort("expected a sphere centroid")
  }
  an_close(centroid.2, 0.0, 1.0e-7)
}

///|
test "analysis torus section is an annulus and volume uses Pappus" {
  let shape = RevolvedProfile::new([
    RevArc((4.0, 0.0), (5.0, 1.0), (5.0, 0.0)),
    RevArc((5.0, 1.0), (6.0, 0.0), (5.0, 0.0)),
    RevArc((6.0, 0.0), (5.0, -1.0), (5.0, 0.0)),
    RevArc((5.0, -1.0), (4.0, 0.0), (5.0, 0.0)),
  ]).as_shape()
  let section = match shape.section_at_local(0.0) {
    Ok(s) => s
    Err(_) => abort("expected a torus midplane section")
  }
  an_close(section.area_mm2, 62.83185307179586, 1.0e-7)
  an_close(section.perimeter_mm, 62.83185307179586, 1.0e-7)
  an_close(section.inner_radius_mm, 4.0, 1.0e-7)
  an_close(section.outer_radius_mm, 6.0, 1.0e-7)
  // Pappus: V = 2 * pi^2 * R * rho^2 with R = 5, rho = 1.
  an_close_rel(an_volume(shape), 2.0 * @math.PI * @math.PI * 5.0, 1.0e-9)
}

///|
test "analysis extruded rectangle with a round bore" {
  let shape = ExtrudedProfile::new(
    Profile2D::rect(10.0, 6.0),
    4.0,
    round_bore=((5.0, 3.0), 4.0),
  )
  let section = match shape.section_at_local(2.0) {
    Ok(s) => s
    Err(_) => abort("expected an extruded section")
  }
  let expected_area = 60.0 - @math.PI * 4.0
  an_close(section.area_mm2, expected_area, 1.0e-9)
  an_close(section.perimeter_mm, 32.0 + @math.PI * 4.0, 1.0e-9)
  an_close_rel(an_volume(shape), expected_area * 4.0, 1.0e-12)
  let centroid = match shape.analysis_centroid() {
    Ok(c) => c
    Err(_) => abort("expected an extruded centroid")
  }
  an_close(centroid.0, 5.0, 1.0e-9)
  an_close(centroid.1, 3.0, 1.0e-9)
  an_close(centroid.2, 2.0, 1.0e-9)
}

///|
test "analysis extruded rectangle with a rectangular hole" {
  let hole = Profile2D::rect(2.0, 2.0)
  let shape = ExtrudedProfile::new(Profile2D::rect(10.0, 6.0), 3.0, holes=[hole])
  let section = match shape.section_at_local(1.0) {
    Ok(s) => s
    Err(_) => abort("expected an extruded section")
  }
  an_close(section.area_mm2, 60.0 - 4.0, 1.0e-9)
  an_close(section.perimeter_mm, 32.0 + 8.0, 1.0e-9)
  an_close_rel(an_volume(shape), 56.0 * 3.0, 1.0e-12)
}

///|
test "analysis chamfered hex prism with a round bore" {
  let hex = Profile2D::polygon(6, 10.0, rotation=30.0)
  let prism = ChamferedPrism::from_chamfer(
    hex,
    6.0,
    round_bore=((0.0, 0.0), 4.0),
  )
  let hex_area = 1.5 * Double::sqrt(3.0) * 25.0
  let section = match prism.section_at(3.0) {
    Ok(s) => s
    Err(_) => abort("expected a prism section")
  }
  an_close(section.area_mm2, hex_area - @math.PI * 4.0, 1.0e-6)
  an_close_rel(prism.volume(), (hex_area - @math.PI * 4.0) * 6.0, 1.0e-9)
  let inventory = Shape::ChamferedPrism(prism).surface_inventory()
  assert_eq(inventory.plane, 8)
  assert_eq(inventory.cylinder, 1)
}

///|
test "analysis chamfered prism volume uses the prismatoid bands" {
  let prism = ChamferedPrism::from_chamfer(
    Profile2D::rect(10.0, 10.0),
    5.0,
    top_chamfer=1.0,
    chamfer_depth=1.0,
  )
  // Band 0..4 is a 10x10 square, band 4..5 shrinks from 10x10 to 8x8.
  let v0 = 100.0 * 4.0
  let v1 = 1.0 / 3.0 * (100.0 + 64.0 + Double::sqrt(100.0 * 64.0))
  an_close_rel(prism.volume(), v0 + v1, 1.0e-12)
}

///|
test "analysis cuboid section, volume and centroid" {
  let shape = Cuboid::new(10.0, 6.0, 4.0)
  let section = match shape.section_at_local(2.0) {
    Ok(s) => s
    Err(_) => abort("expected a cuboid section")
  }
  an_close(section.area_mm2, 60.0, 1.0e-9)
  an_close(section.perimeter_mm, 32.0, 1.0e-9)
  an_close(an_volume(shape), 240.0, 1.0e-9)
  let centroid = match shape.analysis_centroid() {
    Ok(c) => c
    Err(_) => abort("expected a cuboid centroid")
  }
  an_close(centroid.0, 5.0, 1.0e-9)
  an_close(centroid.1, 3.0, 1.0e-9)
  an_close(centroid.2, 2.0, 1.0e-9)
}

///|
test "analysis inventory mirrors the analytic compilers" {
  let cyl = Cylinder::new(10.0, 5.0).surface_inventory()
  assert_eq(cyl.plane, 2)
  assert_eq(cyl.cylinder, 1)
  let rev_cyl = RevolvedProfile::cylinder(10.0, 5.0)
    .as_shape()
    .surface_inventory()
  assert_eq(rev_cyl.plane, 2)
  assert_eq(rev_cyl.cylinder, 1)
  let tube = RevolvedProfile::tube(10.0, 6.0, 5.0)
    .as_shape()
    .surface_inventory()
  assert_eq(tube.plane, 2)
  assert_eq(tube.cylinder, 2)
  let sphere = RevolvedProfile::sphere(10.0).as_shape().surface_inventory()
  assert_eq(sphere.sphere, 2)
  assert_eq(sphere.plane, 0)
  let frustum = RevolvedProfile::frustum(4.0, 2.0, 6.0)
    .as_shape()
    .surface_inventory()
  assert_eq(frustum.plane, 2)
  assert_eq(frustum.cone, 1)
  let cuboid = Cuboid::new(1.0, 2.0, 3.0).surface_inventory()
  assert_eq(cuboid.plane, 6)
  let extrusion = ExtrudedProfile::new(
    Profile2D::rect(10.0, 6.0),
    4.0,
    round_bore=((5.0, 3.0), 4.0),
  ).surface_inventory()
  assert_eq(extrusion.plane, 6)
  assert_eq(extrusion.cylinder, 1)
}

///|
test "analysis union inventory is the nominal sum of children" {
  let a = Cylinder::new(10.0, 5.0).with_name("a")
  let b = Cuboid::new(2.0, 2.0, 2.0).with_name("b")
  let union = union_all([a, b])
  let inventory = union.shape.surface_inventory()
  assert_eq(inventory.plane, 8)
  assert_eq(inventory.cylinder, 1)
  let volume = match union.shape.analysis_volume() {
    Ok(v) => v
    Err(_) => abort("expected a nominal union volume")
  }
  an_close(volume, @math.PI * 25.0 * 5.0 + 8.0, 1.0e-9)
}

///|
test "analysis typed errors do not silently approximate" {
  // An empty section is reported, not a zero-area ring.
  match Cylinder::new(10.0, 5.0).section_at_local(9.0) {
    Ok(_) => abort("expected EmptySection")
    Err(EmptySection) => ()
    Err(_) => abort("expected EmptySection, got another error")
  }
  // Bezier and swept profiles require tessellation.
  let bez = ExtrudedBezierProfile::new(
    [
      {
        anchors: [
          {
            position: (0.0, 0.0),
            handle_in: (0.0, 0.0),
            handle_out: (0.0, 0.0),
          },
          {
            position: (1.0, 0.0),
            handle_in: (1.0, 0.0),
            handle_out: (1.0, 0.0),
          },
          {
            position: (1.0, 1.0),
            handle_in: (1.0, 1.0),
            handle_out: (1.0, 1.0),
          },
        ],
        closed: true,
        clear: false,
      },
    ],
    2.0,
  )
  match bez.analysis_volume() {
    Ok(_) => abort("expected a NotAnalytic error")
    Err(NotAnalytic(_)) => ()
    Err(_) => abort("expected NotAnalytic")
  }
  // A nominal difference is not a trimmed solid.
  let diff = difference(Cylinder::new(10.0, 5.0).with_name("base"), [
    Cylinder::new(4.0, 6.0).with_name("cut"),
  ])
  match diff.shape.analysis_volume() {
    Ok(_) => abort("expected a NotAnalytic error for Difference")
    Err(NotAnalytic(_)) => ()
    Err(_) => abort("expected NotAnalytic for Difference")
  }
  match diff.shape.section_at_local(1.0) {
    Ok(_) => abort("expected a NotAnalytic section for Difference")
    Err(NotAnalytic(_)) => ()
    Err(_) => abort("expected NotAnalytic for Difference section")
  }
}
