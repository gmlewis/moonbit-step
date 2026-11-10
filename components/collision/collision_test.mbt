///|
fn unit_box(half : Double) -> @collision.Obb {
  @collision.Obb::{
    center: (0.0, 0.0, 0.0),
    half_extents: (half, half, half),
    axes: ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
  }
}

///|
fn translated_box(base : @collision.Obb, x : Double) -> @collision.Obb {
  @collision.Obb::{
    center: (base.center.0 + x, base.center.1, base.center.2),
    half_extents: base.half_extents,
    axes: base.axes,
  }
}

///|
test "identical boxes collide with full penetration" {
  let a = unit_box(5.0)
  let b = unit_box(5.0)
  let result = @collision.classify_obb_pair(a, b)
  assert_true(result.kind is @collision.CollisionKind::Collision)
  assert_true((result.penetration_mm - 10.0).abs() < 1.0e-9)
}

///|
test "face-sharing boxes are contact, not collision" {
  let a = unit_box(5.0)
  let b = translated_box(a, 10.0)
  let result = @collision.classify_obb_pair(a, b)
  assert_true(result.kind is @collision.CollisionKind::Contact)
  assert_true(result.penetration_mm == 0.0)
}

///|
test "separated boxes report a positive clearance gap" {
  let a = unit_box(5.0)
  let b = translated_box(a, 12.0)
  let result = @collision.classify_obb_pair(a, b)
  assert_true(result.kind is @collision.CollisionKind::Clearance)
  assert_true((result.separation_mm - 2.0).abs() < 1.0e-9)
}

///|
test "one millimetre of envelope overlap is a collision" {
  let a = unit_box(5.0)
  let b = translated_box(a, 9.0)
  let result = @collision.classify_obb_pair(a, b)
  assert_true(result.kind is @collision.CollisionKind::Collision)
  assert_true((result.penetration_mm - 1.0).abs() < 1.0e-9)
}

///|
test "narrow phase rejects an AABB false positive" {
  let a : @collision.Obb = @collision.Obb::{
    center: (5.0, 0.0, 0.0),
    half_extents: (5.0, 0.4, 0.4),
    axes: ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
  }
  let c = 0.7071067811865476
  let b : @collision.Obb = @collision.Obb::{
    center: (12.5, 1.0, 0.0),
    half_extents: (5.0, 0.4, 0.4),
    axes: ((c, c, 0.0), (-c, c, 0.0), (0.0, 0.0, 1.0)),
  }
  // The axis-aligned broad phases overlap, but the rotated bars are separated
  // along the second bar's face normal.
  assert_true(a.aabb().overlaps(b.aabb(), 0.0))
  let result = @collision.classify_obb_pair(a, b)
  assert_true(result.kind is @collision.CollisionKind::Clearance)
  assert_true(result.separation_mm > 0.3)
}

///|
test "OBB from placement applies rotation and translation" {
  let placement = @common.Placement::at(10.0, 20.0, 30.0, rz=90.0)
  let obb = @collision.Obb::from_placement(
    placement,
    (-1.0, 1.0, -2.0, 2.0, 0.0, 4.0),
  )
  let box = obb.aabb()
  // Local X half-extent 1 maps onto world Y; local Y half-extent 2 maps onto
  // world X; local Z half-extent 2 maps onto world Z.
  assert_true((box.min_pt.0 - 8.0).abs() < 1.0e-9)
  assert_true((box.max_pt.0 - 12.0).abs() < 1.0e-9)
  assert_true((box.min_pt.1 - 19.0).abs() < 1.0e-9)
  assert_true((box.max_pt.1 - 21.0).abs() < 1.0e-9)
  assert_true((box.min_pt.2 - 30.0).abs() < 1.0e-9)
  assert_true((box.max_pt.2 - 34.0).abs() < 1.0e-9)
}

///|
test "declared interference fit is classified separately" {
  let a : @collision.PlacedShape = @collision.PlacedShape::{
    instance_name: "hub",
    layer_name: "body",
    obb: unit_box(5.0),
  }
  let b : @collision.PlacedShape = @collision.PlacedShape::{
    instance_name: "shaft",
    layer_name: "body",
    obb: translated_box(unit_box(5.0), 9.0),
  }
  let plain = @collision.pair_reports([a, b])
  assert_eq(plain.length(), 1)
  assert_true(plain[0].kind is @collision.CollisionKind::Collision)
  let policy = @collision.ContactPolicy::none().permit("hub", "shaft")
  let declared = @collision.pair_reports([a, b], policy~)
  assert_eq(declared.length(), 1)
  assert_true(declared[0].kind is @collision.CollisionKind::InterferenceFit)
  assert_true(declared[0].is_interference_fit())
  assert_true(declared[0].penetration_mm > 0.0)
}
