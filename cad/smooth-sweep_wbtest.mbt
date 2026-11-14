///|
/// A smooth swept profile keeps the faceted sweep's topology but replaces the
/// planar side facets with one ruled B-spline surface per profile edge.
test "smooth sweep emits one ruled bspline surface per edge" {
  let path = helix_path(
    pos=(0.0, 0.0, 0.0),
    size_per_turn=(10.0, 10.0, 0.0),
    num_turns=1.0,
    num_segs_per_turn=12,
    start_angle=0.0,
    clockwise=true,
  )
  let profile = SweepProfile::new(
    [(1.0, 0.0, 0.0), (-1.0, 0.0, 0.0), (-1.0, 0.0, 1.0), (1.0, 0.0, 1.0)],
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let step = Design::new(name="smooth-torus")
    .add(
      SweptProfile::new(
        path~,
        profile~,
        straight_outline=false,
        smooth_sides=true,
      ).with_name("smooth-torus"),
    )
    .to_step_file()
  // Four side surfaces, two planar caps.
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="6")
  inspect(step.split("B_SPLINE_SURFACE_WITH_KNOTS(").count() - 1, content="4")
  // One vertex curve per profile corner.
  inspect(step.split("B_SPLINE_CURVE_WITH_KNOTS(").count() - 1, content="4")
  // Only the cross-section lines at the two caps remain lines. A full turn
  // brings the end cross-section back onto the start one, so they dedupe.
  inspect(step.split("LINE(").count() - 1, content="4")
}

///|
/// A straight loop (straight_outline) keeps its first-frame orientation, so
/// every vertex curve is straight and the side surfaces are exact planes.
test "smooth sweep honors straight and twisted loops" {
  let points : Array[Vec3] = []
  let normals : Array[Vec3] = []
  let tangents : Array[Vec3] = []
  for i in 0..<=8 {
    let angle = i.to_double() / 8.0 * (2.0 * @math.PI)
    points.push((0.0, i.to_double(), 0.0))
    normals.push((@math.cos(angle), 0.0, @math.sin(angle)))
    tangents.push((0.0, 1.0, 0.0))
  }
  let path : SweepPath = { points, normals, tangents, }
  let profile = SweepProfile::new(
    [(5.0, 0.0, 0.0), (3.0, 0.0, 0.0), (3.0, 0.0, 2.0), (5.0, 0.0, 2.0)],
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let step = Design::new(name="straight-smooth")
    .add(
      SweptProfile::new(
        path~,
        profile~,
        straight_outline=true,
        smooth_sides=true,
      ).with_name("straight-smooth"),
    )
    .to_step_file()
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="6")
  inspect(step.split("B_SPLINE_SURFACE_WITH_KNOTS(").count() - 1, content="4")
}

///|
/// A profile with a hole gets one side surface per edge of both loops. The
/// caps keep the hole as an inner bound.
test "smooth sweep keeps hole loops" {
  let points : Array[Vec3] = []
  let normals : Array[Vec3] = []
  let tangents : Array[Vec3] = []
  for i in 0..<=6 {
    points.push((0.0, i.to_double(), 0.0))
    normals.push((1.0, 0.0, 0.0))
    tangents.push((0.0, 1.0, 0.0))
  }
  let path : SweepPath = { points, normals, tangents, }
  let profile = SweepProfile::new(
    [(-5.0, 0.0, 5.0), (5.0, 0.0, 5.0), (5.0, 0.0, -5.0), (-5.0, 0.0, -5.0)], // CCW in the local (x, -z) profile frame
    holes=[
      [(-2.0, 0.0, -2.0), (2.0, 0.0, -2.0), (2.0, 0.0, 2.0), (-2.0, 0.0, 2.0)],
    ],
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let step = Design::new(name="smooth-tube")
    .add(
      SweptProfile::new(path~, profile~, smooth_sides=true).with_name(
        "smooth-tube",
      ),
    )
    .to_step_file()
  // Eight side surfaces plus two caps.
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="10")
  inspect(step.split("B_SPLINE_SURFACE_WITH_KNOTS(").count() - 1, content="8")
  inspect(step.split("B_SPLINE_CURVE_WITH_KNOTS(").count() - 1, content="8")
}

///|
/// A sharp crease uses the one-sided chord tangent at the crease, so the two
/// Bezier spans meeting there keep a corner instead of averaging into a wave.
test "sharp crease keeps a piecewise-linear corner" {
  let ctx = StepContext::new()
  let corner_pts : Array[Vec3] = [
    (0.0, 0.0, 0.0),
    (0.0, 0.0, 0.0),
    (0.0, 0.0, 0.0),
    (0.0, 0.0, 0.0),
    (1.0, 0.0, 0.0),
    (1.0, 0.0, 0.0),
    (1.0, 0.0, 0.0),
    (1.0, 0.0, 0.0),
    (1.0, 1.0, 0.0),
    (1.0, 1.0, 0.0),
    (1.0, 1.0, 0.0),
    (1.0, 1.0, 0.0),
  ]
  let indices : Array[Int32] = [0, 1, 2]
  let v_mults : Array[Int32] = [4, 3, 4]
  let v_knots : Array[String] = ["0.0", "1.0", "2.0"]
  let smooth = smooth_curve(ctx, corner_pts, indices, 0, 3, v_mults, v_knots, sharp_creases=[
    1,
  ])
  // Span 0 ends with the chord P1 - P0; span 1 starts with P2 - P1.
  assert_near(smooth.cps_pos[2].0, 2.0 / 3.0)
  assert_near(smooth.cps_pos[2].1, 0.0)
  assert_near(smooth.cps_pos[4].0, 1.0)
  assert_near(smooth.cps_pos[4].1, 1.0 / 3.0)
  // Without the crease the averaged tangent smooths the corner.
  let wavy = smooth_curve(ctx, corner_pts, indices, 0, 3, v_mults, v_knots)
  assert_near(wavy.cps_pos[2].0, 2.0 / 3.0 + 1.0 / 6.0)
  assert_near(wavy.cps_pos[2].1, -1.0 / 6.0)
}
