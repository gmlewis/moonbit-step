///|
/// Regression tests for the generic T-slot extrusion frame.
///
/// The frame semantics implemented and tested here are:
/// - `width`, `depth`, and `height` are overall outside dimensions;
/// - four vertical posts occupy the corners for the full height;
/// - X rails span the clear distance between the posts (`width - 2 * profile
///   width`) and Y rails span `depth - 2 * profile height`;
/// - all joints are square butt contacts at post inner faces; there is no
///   positive-volume interpenetration.
fn close_mm(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn make_frame(
  width : Double,
  depth : Double,
  height : Double,
) -> @assemblies.Assembly {
  match
    @assemblies.extrusion_frame(
      width,
      depth,
      height,
      @profiles.TSlotProfile::generic_2020(),
    ) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
}

///|
fn find_frame_item(
  frame : @assemblies.Assembly,
  name : String,
) -> @assemblies.AssemblyItem {
  for item in frame.items() {
    if item.instance_name == name {
      return item
    }
  }
  abort("missing frame instance: " + name)
}

///|
fn item_cut_length(item : @assemblies.AssemblyItem) -> Double {
  let layer = item.component.layers()[0]
  let (_x0, _x1, _y0, _y1, z0, z1) = layer.shape.bounding_box()
  z1 - z0
}

///|
fn item_world_aabb(
  item : @assemblies.AssemblyItem,
) -> (Double, Double, Double, Double, Double, Double) {
  let obb = @collision.placed_shapes(
      item.instance_name,
      item.component,
      item.placement,
    )[0].obb
  let box = obb.aabb()
  (
    box.min_pt.0,
    box.max_pt.0,
    box.min_pt.1,
    box.max_pt.1,
    box.min_pt.2,
    box.max_pt.2,
  )
}

///|
test "frame members have explicit cut lengths" {
  let frame = make_frame(400.0, 300.0, 500.0)
  let profile = @profiles.TSlotProfile::generic_2020()
  let (pw, ph) = profile.size()
  assert_true(
    close_mm(item_cut_length(find_frame_item(frame, "post-ws")), 500.0),
  )
  assert_true(
    close_mm(
      item_cut_length(find_frame_item(frame, "rail-x-bottom-s")),
      400.0 - 2.0 * pw,
    ),
  )
  assert_true(
    close_mm(
      item_cut_length(find_frame_item(frame, "rail-y-bottom-w")),
      300.0 - 2.0 * ph,
    ),
  )
}

///|
test "frame rails land between post inner faces" {
  let frame = make_frame(400.0, 300.0, 500.0)
  let (x0, x1, y0, y1, z0, z1) = item_world_aabb(
    find_frame_item(frame, "rail-x-bottom-s"),
  )
  assert_true(close_mm(x0, -180.0))
  assert_true(close_mm(x1, 180.0))
  assert_true(close_mm(y0, -150.0))
  assert_true(close_mm(y1, -130.0))
  assert_true(close_mm(z0, 0.0))
  assert_true(close_mm(z1, 20.0))
  let (yx0, yx1, yy0, yy1, yz0, yz1) = item_world_aabb(
    find_frame_item(frame, "rail-y-bottom-w"),
  )
  assert_true(close_mm(yx0, -200.0))
  assert_true(close_mm(yx1, -180.0))
  assert_true(close_mm(yy0, -130.0))
  assert_true(close_mm(yy1, 130.0))
  assert_true(close_mm(yz0, 0.0))
  assert_true(close_mm(yz1, 20.0))
}

///|
test "frame has no unintended positive-volume interpenetration" {
  let frame = make_frame(400.0, 300.0, 500.0)
  let collisions = frame.collisions()
  if !collisions.is_empty() {
    let lines = collisions.map(fn(r) { r.summary() })
    abort("frame collisions:\n" + lines.join("\n"))
  }
  assert_true(collisions.is_empty())
}

///|
test "frame members touch at intended joints and remain connected" {
  let frame = make_frame(400.0, 300.0, 500.0)
  let contacts = frame.contacts()
  assert_true(contacts.length() > 0)
  assert_true(frame.is_connected())
  assert_true(frame.disconnected_instances().is_empty())
}

///|
test "frame members are distinct and not coincident" {
  let frame = make_frame(400.0, 300.0, 500.0)
  let shapes = frame.placed_shapes()
  assert_eq(shapes.length(), 12)
  for i in 0..<shapes.length() {
    for j in (i + 1)..<shapes.length() {
      let a = shapes[i].obb
      let b = shapes[j].obb
      let same = close_mm(a.center.0, b.center.0) &&
        close_mm(a.center.1, b.center.1) &&
        close_mm(a.center.2, b.center.2)
      assert_false(same)
    }
  }
}

///|
test "frame overall dimensions are the declared outside dimensions" {
  for (w, d, h) in [(400.0, 300.0, 500.0), (600.0, 300.0, 400.0)] {
    let frame = make_frame(w, d, h)
    let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
    assert_true(close_mm(x1 - x0, w))
    assert_true(close_mm(y1 - y0, d))
    assert_true(close_mm(z1 - z0, h))
    assert_true(frame.collisions().is_empty())
    assert_true(frame.is_connected())
  }
}

///|
test "frame near-minimum span is collision free" {
  let profile = @profiles.TSlotProfile::generic_2020()
  let (pw, ph) = profile.size()
  let width = 2.0 * pw + 5.0
  let depth = 2.0 * ph + 5.0
  let taller = if pw > ph { pw } else { ph }
  let height = 2.0 * taller + 5.0
  let frame = make_frame(width, depth, height)
  assert_true(frame.collisions().is_empty())
  assert_true(frame.is_connected())
}

///|
test "frame rejects spans that leave no rail length" {
  let profile = @profiles.TSlotProfile::generic_2020()
  let (pw, ph) = profile.size()
  let taller = if pw > ph { pw } else { ph }
  assert_true(
    @assemblies.extrusion_frame(2.0 * pw, 300.0, 500.0, profile) is Err(_),
  )
  assert_true(
    @assemblies.extrusion_frame(400.0, 2.0 * ph, 500.0, profile) is Err(_),
  )
  assert_true(
    @assemblies.extrusion_frame(400.0, 300.0, 2.0 * taller, profile) is Err(_),
  )
}

///|
test "frame STEP export preserves twelve separate solids" {
  let frame = make_frame(400.0, 300.0, 500.0)
  let step = frame.to_step(checked=true)
  let solids = step.split("MANIFOLD_SOLID_BREP(").count() - 1
  assert_eq(solids, 12)
  let reparsed = @parse.parse_repository_from_string(step) catch {
    @parse.StepParseError(_) => abort("generated frame STEP did not re-parse")
  }
  assert_true(reparsed.len() > 0)
  let round_trip = reparsed.to_step_file()
  let round_trip_solids = round_trip.split("MANIFOLD_SOLID_BREP(").count() - 1
  assert_eq(round_trip_solids, 12)
}

///|
test "non-square 2040 profile frame is collision free" {
  let profile = @profiles.TSlotProfile::generic_2040()
  let frame = match @assemblies.extrusion_frame(400.0, 300.0, 500.0, profile) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
  assert_true(close_mm(x1 - x0, 400.0))
  assert_true(close_mm(y1 - y0, 300.0))
  assert_true(close_mm(z1 - z0, 500.0))
  assert_true(frame.collisions().is_empty())
  assert_true(frame.is_connected())
  // X rails are 20 mm thick in Z; Y rails are 40 mm thick in Z.
  let (_, _, _, _, xz0, xz1) = item_world_aabb(
    find_frame_item(frame, "rail-x-bottom-s"),
  )
  assert_true(close_mm(xz0, 0.0))
  assert_true(close_mm(xz1, 20.0))
  let (_, _, _, _, yz0, yz1) = item_world_aabb(
    find_frame_item(frame, "rail-y-bottom-w"),
  )
  assert_true(close_mm(yz0, 0.0))
  assert_true(close_mm(yz1, 40.0))
}
