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
      chamfer_size_mm?=1.0,
      fillet_radius_mm?=0.0,
      fillet_segments?=6,
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
    center?=(0.0, 0.0, 0.0),
    normal_dir?=(0.0, 1.0, 0.0),
    right_dir?=(1.0, 0.0, 0.0),
  )
  let swept = @cad.SweptProfile::new(
      path=sweep_path,
      profile=sweep_profile,
      make_start_cap?=true,
      make_end_cap?=false,
    )
    .with_name("sweep")
    .with_color(@cad.Rgb::purple())
  let union_node = @cad.union_all(
    [
      @cad.Cuboid::new(2.0, 2.0, 2.0).with_name("a"),
      @cad.Cuboid::new(1.0, 3.0, 1.0).with_name("b"),
    ],
    name?="combo",
  ).with_color(@cad.Rgb::cyan())
  let cases : Array[(String, @cad.Design, Array[String])] = [
    (
      "header",
      @cad.Design::new(name?="header-model"),
      [
        "Blender 5.0 Python3 script generated", "def get_material(color):", "def create_cuboid_object(name, sx, sy, sz, collection):",
        "def create_extruded_profile_object(name, loops, height, collection):", "def create_swept_profile_object(name, path_points, path_normals, path_tangents",
        "def main():",
      ],
    ),
    (
      "cuboid",
      @cad.Design::new(name?="cube-model").add(cube),
      [
        "create_cuboid_object('cube', 1.25, 2.5, 3.75, collection)", "get_material((0.8, 0, 0, 1.0))",
        "(10, 20, 30), (15, 25, 35)",
      ],
    ),
    (
      "chamfer_block",
      @cad.Design::new(name?="block-model").add(chamfer_block),
      [
        "create_chamfer_block_object('block', 20, 10, 5, 1, 0, 6, collection)", "get_material((0.2, 0.6, 1, 1.0))",
      ],
    ),
    (
      "extruded_profile",
      @cad.Design::new(name?="plate-model").add(extrude),
      [
        "create_extruded_profile_object('plate', [[(0, 0), (10, 0), (10, 5), (0, 5)], [(2, 2), (3, 2), (3, 3), (2, 3)]], 4, collection)",
        "get_material((0, 0.8, 0, 1.0))",
      ],
    ),
    (
      "swept_profile",
      @cad.Design::new(name?="sweep-model").add(swept),
      [
        "create_swept_profile_object('sweep', [(0, 0, 0), (0, 0, 10)], [(0, 1, 0), (0, 1, 0)], [(0, 0, 1), (0, 0, 1)], (0, 0, 0)",
        "[(-1, -1, 0)", "(0, 1, 0), (1, 0, 0), True, False, collection)",
      ],
    ),
    (
      "union",
      @cad.Design::new(name?="union-model").add(union_node),
      [
        "create_cuboid_object('a', 2, 2, 2, collection)", "create_cuboid_object('b', 1, 3, 1, collection)",
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
