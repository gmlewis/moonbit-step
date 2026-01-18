///|
fn assert_contains_all(
  label : String,
  text : String,
  needles : Array[String],
) -> Unit {
  for needle in needles {
    if !text.contains(needle) {
      println("missing in \{label}: \{needle}")
      panic()
    }
  }
}

///|
test "to_blender_python table-driven" {
  let cube = @cad.Cuboid::new(1.25, 2.5, 3.75)
    .with_name("cube")
    .with_color(@cad.Rgb::red())
    .translate(x=10.0, y=20.0, z=30.0)
    .rotate_x(15.0)
    .rotate_y(25.0)
    .rotate_z(35.0)
  let chamfer_block = @cad.CalibrationChamferBlock::new(
      20.0,
      10.0,
      5.0,
      chamfer_size_mm=1.0,
      fillet_radius_mm=0.0,
      fillet_segments=6,
    )
    .with_name("block")
    .with_color(@cad.Rgb::blue())
  let outer = [(0.0, 0.0), (10.0, 0.0), (10.0, 5.0), (0.0, 5.0)]
  let hole = [(2.0, 2.0), (3.0, 2.0), (3.0, 3.0), (2.0, 3.0)]
  let extrude = @cad.ExtrudedProfile::new(outer, 4.0, holes=[hole])
    .with_name("plate")
    .with_color(@cad.Rgb::green())
  let sweep_path : @cad.SweepPath = {
    points: [(0.0, 0.0, 0.0), (0.0, 0.0, 10.0)],
    normals: [(0.0, 1.0, 0.0), (0.0, 1.0, 0.0)],
    tangents: [(0.0, 0.0, 1.0), (0.0, 0.0, 1.0)],
  }
  let sweep_profile : @cad.SweepProfile = @cad.SweepProfile::new(
    [(-1.0, -1.0, 0.0), (1.0, -1.0, 0.0), (1.0, 1.0, 0.0), (-1.0, 1.0, 0.0)],
    center=(0.0, 0.0, 0.0),
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let swept = @cad.SweptProfile::new(
      path=sweep_path,
      profile=sweep_profile,
      make_start_cap=true,
      make_end_cap=false,
    )
    .with_name("sweep")
    .with_color(@cad.Rgb::purple())
  let union_node = @cad.union_all(
    [
      @cad.Cuboid::new(2.0, 2.0, 2.0).with_name("a"),
      @cad.Cuboid::new(1.0, 3.0, 1.0).with_name("b"),
    ],
    name="combo",
  ).with_color(@cad.Rgb::cyan())
  let cases : Array[(String, @cad.Design, Array[String])] = [
    (
      "header",
      @cad.Design::new(name="header-model"),
      [
        "Blender 5.0 Python3 script generated", "def get_material(color):", "def create_cuboid_object(name, sx, sy, sz, collection):",
        "def create_extruded_profile_object(name, loops, height, collection):", "def create_swept_profile_object(name, path_points, path_normals, path_tangents",
        "def main():",
      ],
    ),
    (
      "cuboid",
      @cad.Design::new(name="cube-model").add(cube),
      [
        "create_cuboid_object('cube', 0.00125, 0.0025, 0.00375, collection)", "get_material((0.8, 0, 0, 1.0))",
        "(0.01, 0.02, 0.03), (15, 25, 35)",
      ],
    ),
    (
      "chamfer_block",
      @cad.Design::new(name="block-model").add(chamfer_block),
      [
        "create_chamfer_block_object('block', 0.02, 0.01, 0.005, 0.001, 0, 6, collection)",
        "get_material((0.2, 0.6, 1, 1.0))",
      ],
    ),
    (
      "extruded_profile",
      @cad.Design::new(name="plate-model").add(extrude),
      [
        "create_extruded_profile_object('plate', [[(0, 0), (0.01, 0), (0.01, 0.005), (0, 0.005)], [(0.002, 0.002), (0.003, 0.002), (0.003, 0.003), (0.002, 0.003)]], 0.004, collection)",
        "get_material((0, 0.8, 0, 1.0))", "curve.extrude = height / 2.0", "spline.points[i].co = (x, y, 0.0, 1.0)",
      ],
    ),
    (
      "swept_profile",
      @cad.Design::new(name="sweep-model").add(swept),
      [
        "create_swept_profile_object('sweep', [(0, 0, 0), (0, 0, 0.01)], [(0, 1, 0), (0, 1, 0)], [(0, 0, 1), (0, 0, 1)], (0, 0, 0)",
        "[(-0.001, -0.001, 0)", "(0, 1, 0), (1, 0, 0), True, False, collection)",
      ],
    ),
    (
      "union",
      @cad.Design::new(name="union-model").add(union_node),
      [
        "create_cuboid_object('a', 0.002, 0.002, 0.002, collection)", "create_cuboid_object('b', 0.001, 0.003, 0.001, collection)",
        "join_objects(", "'combo'", "get_material((0, 0.8, 0.8, 1.0))",
      ],
    ),
  ]
  for case in cases {
    let (label, design, needles) = case
    let out = design.to_blender_python()
    assert_contains_all(label, out, needles)
  }
}

///|
test "to_blender_python_coordinates" {
  // Verify that world coordinates of an extrusion in Blender match STEP.
  // STEP: Vertex_Bottom = Rotate( (px, py, 0), rot ) + Trans
  //       Vertex_Top    = Rotate( (px, py, height), rot ) + Trans
  // Blender (symmetric):
  //       Vertex_Bottom = Rotate( (px, py, -height/2), rot ) + (Trans + Rotate( (0,0,height/2), rot ))
  //                     = Rotate( (px, py, 0), rot ) + Trans
  //       Vertex_Top    = Rotate( (px, py, +height/2), rot ) + (Trans + Rotate( (0,0,height/2), rot ))
  //                     = Rotate( (px, py, height), rot ) + Trans

  let px = 10.0
  let py = 20.0
  let height = 50.0
  let tx = 100.0
  let ty = 200.0
  let tz = 300.0
  let rx = 15.0
  let ry = 25.0
  let rz = 35.0

  // 1. Calculate world STEP coordinates
  let step_bottom = @cad.rotate_point((px, py, 0.0), rx, ry, rz)
  let step_bottom = (step_bottom.0 + tx, step_bottom.1 + ty, step_bottom.2 + tz)
  let step_top = @cad.rotate_point((px, py, height), rx, ry, rz)
  let step_top = (step_top.0 + tx, step_top.1 + ty, step_top.2 + tz)

  // 2. Calculate world Blender coordinates (with my fix)
  let h2 = height / 2.0
  let offset = @cad.rotate_point((0.0, 0.0, h2), rx, ry, rz)
  let blender_trans = (tx + offset.0, ty + offset.1, tz + offset.2)
  let blender_bottom_local = (px, py, -h2)
  let blender_bottom_world = @cad.rotate_point(blender_bottom_local, rx, ry, rz)
  let blender_bottom_world = (
    blender_bottom_world.0 + blender_trans.0,
    blender_bottom_world.1 + blender_trans.1,
    blender_bottom_world.2 + blender_trans.2,
  )
  let blender_top_local = (px, py, h2)
  let blender_top_world = @cad.rotate_point(blender_top_local, rx, ry, rz)
  let blender_top_world = (
    blender_top_world.0 + blender_trans.0,
    blender_top_world.1 + blender_trans.1,
    blender_top_world.2 + blender_trans.2,
  )

  // 3. Assert they are identical
  assert_approx_eq(step_bottom.0, blender_bottom_world.0)
  assert_approx_eq(step_bottom.1, blender_bottom_world.1)
  assert_approx_eq(step_bottom.2, blender_bottom_world.2)
  assert_approx_eq(step_top.0, blender_top_world.0)
  assert_approx_eq(step_top.1, blender_top_world.1)
  assert_approx_eq(step_top.2, blender_top_world.2)
}

///|
test "to_blender_python separates statements" {
  let design = @cad.Design::new(name="newline-check")
    .add(@cad.Cuboid::new(1.0, 1.0, 1.0).with_name("a"))
    .add(@cad.Cuboid::new(2.0, 2.0, 2.0).with_name("b"))
  let out = design.to_blender_python()
  assert_true(out.contains(")\n    obj"))
}
