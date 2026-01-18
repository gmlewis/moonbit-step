///|
test "add_text_on_face orientation" {
  let font = nullpointer
  let cuboid = @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("test-cuboid")

  // Test each face
  let faces = [
    (@cad.Face::Top, "Top"),
    (@cad.Face::Bottom, "Bottom"),
    (@cad.Face::Front, "Front"),
    (@cad.Face::Back, "Back"),
    (@cad.Face::Left, "Left"),
    (@cad.Face::Right, "Right"),
  ]
  for face_tuple in faces {
    let (face, _face_name) = face_tuple
    let d = @cad.Design::new()
      .add(cuboid)
      .add_text_on_face(cuboid, "A", face, font, font_size=2.0)

    // The last node added should be the text node
    let text_node = d.nodes[1]

    // Check normal vector (local +Z)
    let (nx, ny, nz) = @cad.rotate_point(
      (0.0, 0.0, 1.0),
      text_node.rx,
      text_node.ry,
      text_node.rz,
    )

    // Check up vector (local +Y)
    let (ux, uy, uz) = @cad.rotate_point(
      (0.0, 1.0, 0.0),
      text_node.rx,
      text_node.ry,
      text_node.rz,
    )
    // println(
    //   "Face: \{face_name}, Normal: (\{nx}, \{ny}, \{nz}), Up: (\{ux}, \{uy}, \{uz})",
    // )
    match face {
      Top => {
        // Normal should be +Z, Up should be +Y
        assert_approx_eq(nx, 0.0)
        assert_approx_eq(ny, 0.0)
        assert_approx_eq(nz, 1.0)
        assert_approx_eq(ux, 0.0)
        assert_approx_eq(uy, 1.0)
        assert_approx_eq(uz, 0.0)
      }
      Bottom => {
        // Normal should be -Z, Up should be +Y
        assert_approx_eq(nx, 0.0)
        assert_approx_eq(ny, 0.0)
        assert_approx_eq(nz, -1.0)
        assert_approx_eq(ux, 0.0)
        assert_approx_eq(uy, 1.0)
        assert_approx_eq(uz, 0.0)
      }
      Front => {
        // Normal should be +Y, Up should be +Z
        assert_approx_eq(nx, 0.0)
        assert_approx_eq(ny, 1.0)
        assert_approx_eq(nz, 0.0)
        assert_approx_eq(ux, 0.0)
        assert_approx_eq(uy, 0.0)
        assert_approx_eq(uz, 1.0)
      }
      Back => {
        // Normal should be -Y, Up should be +Z
        assert_approx_eq(nx, 0.0)
        assert_approx_eq(ny, -1.0)
        assert_approx_eq(nz, 0.0)
        assert_approx_eq(ux, 0.0)
        assert_approx_eq(uy, 0.0)
        assert_approx_eq(uz, 1.0)
      }
      Left => {
        // Normal should be -X, Up should be +Z
        assert_approx_eq(nx, -1.0)
        assert_approx_eq(ny, 0.0)
        assert_approx_eq(nz, 0.0)
        assert_approx_eq(ux, 0.0)
        assert_approx_eq(uy, 0.0)
        assert_approx_eq(uz, 1.0)
      }
      Right => {
        // Normal should be +X, Up should be +Z
        assert_approx_eq(nx, 1.0)
        assert_approx_eq(ny, 0.0)
        assert_approx_eq(nz, 0.0)
        assert_approx_eq(ux, 0.0)
        assert_approx_eq(uy, 0.0)
        assert_approx_eq(uz, 1.0)
      }
    }
  }
}

///|
fn assert_approx_eq(a : Double, b : Double) -> Unit {
  if (a - b).abs() > 0.0001 {
    panic()
  }
}

///|
let glyphs : Map[String, @fonts.Glyph] = {
  "A": {
    char: "A",
    horiz_adv_x: 0.0,
    gerber_lp: "dc",
    d: "M507 24L48 24L48 530L395 530L395 625L48 625L48 723L507 723L507 24ZM395 269L395 433L138 433L138 269L395 269Z",
    xmin: 48.0,
    ymin: 24.0,
    xmax: 507.0,
    ymax: 723.0,
  },
  "B": {
    char: "B",
    horiz_adv_x: 0.0,
    gerber_lp: "dc",
    d: "M507 21L48 21L48 723L160 723L160 530L507 530L507 21ZM417 269L417 433L160 433L160 269L417 269Z",
    xmin: 48.0,
    ymin: 21.0,
    xmax: 507.0,
    ymax: 723.0,
  },
  "C": {
    char: "C",
    horiz_adv_x: 0.0,
    gerber_lp: "d",
    d: "M507 21L48 21L48 723L507 723L507 625L160 625L160 269L507 269L507 21Z",
    xmin: 48.0,
    ymin: 21.0,
    xmax: 507.0,
    ymax: 723.0,
  },
}

///|
let nullpointer : @fonts.Font = {
  id: "nullpointer",
  horiz_adv_x: 540.0,
  units_per_em: 1000.0,
  ascent: 800.0,
  descent: -200.0,
  glyphs,
}
