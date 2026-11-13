///|
fn mate_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn mate_close_vec(a : @cad.Vec3, b : @cad.Vec3) -> Bool {
  mate_close(a.0, b.0) && mate_close(a.1, b.1) && mate_close(a.2, b.2)
}

///|
fn mate_close_point(a : @cad.Vec3, b : @cad.Vec3) -> Bool {
  let p = (1.0e-6, 1.0e-6, 1.0e-6)
  (a.0 - b.0).abs() < p.0 && (a.1 - b.1).abs() < p.1 && (a.2 - b.2).abs() < p.2
}

///|
fn mate_close_placement(a : @common.Placement, b : @common.Placement) -> Bool {
  let points : Array[@cad.Vec3] = [
    (0.0, 0.0, 0.0),
    (1.0, 0.0, 0.0),
    (0.0, 2.0, 0.0),
    (0.0, 0.0, 3.0),
  ]
  for p in points {
    if !mate_close_point(a.apply_point(p), b.apply_point(p)) {
      return false
    }
  }
  true
}

///|
test "matrix3x3 and placement expose structural equality and debug" {
  let a = @cad.Matrix3x3::{
    m00: 1.0,
    m01: 0.0,
    m02: 0.0,
    m10: 0.0,
    m11: 1.0,
    m12: 0.0,
    m20: 0.0,
    m21: 0.0,
    m22: 1.0,
  }
  assert_true(a == a)
  let p = @common.Placement::at(1.0, 2.0, 3.0, rz=30.0)
  assert_true(p == @common.Placement::at(1.0, 2.0, 3.0, rz=30.0))
  assert_false(p == @common.Placement::identity())
}

///|
test "rotation about an axis matches rotation_z for a z axis" {
  let by_axis = @common.Placement::rotation_axis_angle(
    (0.0, 0.0, 1.0),
    @math.PI / 2.0,
  )
  let by_euler = @common.Placement::rotation_z(90.0)
  assert_true(mate_close_placement(by_axis, by_euler))
  let zero = @common.Placement::rotation_axis_angle((0.0, 0.0, 0.0), 1.0)
  assert_true(mate_close_placement(zero, @common.Placement::identity()))
}

///|
test "mate connector normalizes its axis" {
  let c = @common.MateConnector::new("shaft", axis=(0.0, 0.0, 5.0))
  assert_true(mate_close_vec(c.axis, (0.0, 0.0, 1.0)))
  assert_true(c.kind is @common.MateKind::Datum)
  assert_true(c.gender is @common.MateGender::Neutral)
  assert_true(c.fit is @cad.Fit::Nominal)
}

///|
test "mate connector validate rejects structural defects" {
  let empty = @common.MateConnector::new("")
  assert_true(empty.validate() is Err(_))
  let whitespace = @common.MateConnector::new("bad name")
  assert_true(whitespace.validate() is Err(_))
  let zero_axis = @common.MateConnector::new("c", axis=(0.0, 0.0, 0.0))
  assert_true(zero_axis.validate() is Err(_))
  let nan_frame = @common.MateConnector::new(
    "c",
    placement=@common.Placement::translation(0.0 / 0.0, 0.0, 0.0),
  )
  assert_true(nan_frame.validate() is Err(_))
  let negative_diameter = @common.MateConnector::new("c", diameter_mm=-1.0)
  assert_true(negative_diameter.validate() is Err(_))
  let negative_depth = @common.MateConnector::new("c", depth_mm=-1.0)
  assert_true(negative_depth.validate() is Err(_))
}

///|
test "mate connector validate enforces kind and gender coherence" {
  let bore_male = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Male,
    diameter_mm=5.0,
  )
  assert_true(bore_male.validate() is Err(_))
  let shaft_female = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::CylindricalShaft,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
  )
  assert_true(shaft_female.validate() is Err(_))
  let plane_male = @common.MateConnector::new(
    "face",
    kind=@common.MateKind::PlaneFace,
    gender=@common.MateGender::Male,
  )
  assert_true(plane_male.validate() is Err(_))
  let bore_female = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
  )
  assert_true(bore_female.validate() is Ok(_))
}

///|
test "mate connector millimetre and metre round-trips" {
  let mm = @common.MateConnector::from_mm_deg(
    "a",
    x=10.0,
    y=-2.5,
    z=3.0,
    rx_deg=10.0,
    ry_deg=-20.0,
    rz_deg=30.0,
    axis=(0.0, 1.0, 0.0),
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=6.0,
    depth_mm=8.0,
  )
  assert_true(mate_close(mm.placement.trans.0, 10.0))
  assert_true(mate_close_vec(mm.axis, (0.0, 1.0, 0.0)))
  match mm.diameter_mm {
    Some(d) => assert_true(mate_close(d, 6.0))
    None => fail("expected diameter")
  }
  let (xyz_m, rpy_rad) = mm.to_m_rad()
  assert_true(mate_close_vec(xyz_m, (0.01, -0.0025, 0.003)))
  let back = @common.MateConnector::from_m_rad(
    "a",
    xyz_m,
    rpy_rad,
    axis=(0.0, 1.0, 0.0),
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=6.0,
    depth_mm=8.0,
  )
  assert_true(mate_close_placement(back.placement, mm.placement))
  assert_true(mate_close_vec(back.axis, mm.axis))
}

///|
test "snap connectors applies offset along the parent axis" {
  let (origin, axis) = @common.snap_connectors(
    @common.MateConnector::new("p"),
    @common.MateConnector::new("c"),
    offset_mm=0.1,
  )
  assert_true(mate_close_vec(origin.trans, (0.0, 0.0, 0.1)))
  assert_true(mate_close_vec(axis, (0.0, 0.0, 1.0)))
}

///|
test "snap connectors inverts the child frame" {
  let (origin, axis) = @common.snap_connectors(
    @common.MateConnector::new("p"),
    @common.MateConnector::from_mm_deg("c", z=100.0),
  )
  assert_true(mate_close_vec(origin.trans, (0.0, 0.0, -100.0)))
  assert_true(mate_close_vec(axis, (0.0, 0.0, 1.0)))
}

///|
test "snap connectors supports twist and axis flip" {
  let (origin, axis) = @common.snap_connectors(
    @common.MateConnector::new("p"),
    @common.MateConnector::new("c"),
    offset_mm=0.2,
    twist_rad=@math.PI / 2.0,
    flip_axis=true,
  )
  assert_true(mate_close_vec(origin.trans, (0.0, 0.0, 0.2)))
  assert_true(mate_close_vec(axis, (0.0, 0.0, -1.0)))
  assert_true(
    mate_close_point(origin.apply_point((1.0, 0.0, 0.0)), (0.0, 1.0, 0.2)),
  )
}

///|
test "mate connector transformed composes the parent frame" {
  let c = @common.MateConnector::from_mm_deg("m", x=1.0, axis=(0.0, 0.0, 1.0))
  let parent = @common.Placement::at(10.0, 0.0, 0.0, rz=90.0)
  let placed = c.transformed(parent)
  assert_true(mate_close_vec(placed.placement.trans, (10.0, 1.0, 0.0)))
  assert_true(mate_close_vec(placed.axis, (0.0, 0.0, 1.0)))
  let sideways = @common.MateConnector::new("s", axis=(1.0, 0.0, 0.0))
  let rotated = sideways.transformed(@common.Placement::rotation_z(90.0))
  assert_true(mate_close_vec(rotated.axis, (0.0, 1.0, 0.0)))
}

///|
test "component stores connectors without changing geometry" {
  let base = @common.Component::new(
    name="part",
    metadata=@common.Metadata::new(designation="PART"),
  ).add_layer(@cad.Cuboid::new(10.0, 20.0, 30.0), name="body")
  let connector = @common.MateConnector::from_mm_deg(
    "mount",
    z=30.0,
    kind=@common.MateKind::PlaneFace,
    description="top face",
  )
  let with_connector = match base.with_connector(connector) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(base.connectors().length(), 0)
  assert_eq(with_connector.connectors().length(), 1)
  let (x0, x1, y0, y1, z0, z1) = base.bounding_box()
  let (a0, a1, b0, b1, c0, c1) = with_connector.bounding_box()
  assert_true(mate_close(x0, a0) && mate_close(x1, a1))
  assert_true(mate_close(y0, b0) && mate_close(y1, b1))
  assert_true(mate_close(z0, c0) && mate_close(z1, c1))
  assert_eq(base.to_step(), with_connector.to_step())
  let found = match with_connector.connector("mount") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(found.name, "mount")
}

///|
test "component rejects duplicate and unknown connector names" {
  let base = @common.Component::new(
    name="part",
    metadata=@common.Metadata::new(designation="PART"),
  )
  let first = @common.MateConnector::new("mount")
  let once = match base.with_connector(first) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let duplicate = once.with_connector(@common.MateConnector::new("mount"))
  match duplicate {
    Err(@common.MateError::DuplicateConnector(name)) => assert_eq(name, "mount")
    _ => fail("expected duplicate connector error")
  }
  match once.connector("nope") {
    Err(@common.MateError::UnknownConnector(name)) => assert_eq(name, "nope")
    _ => fail("expected unknown connector error")
  }
  let invalid = once.with_connector(@common.MateConnector::new("bad name"))
  assert_true(invalid is Err(_))
}

///|
test "component rebase to connector leaves geometry and layer count intact" {
  let connector = @common.MateConnector::from_mm_deg(
    "mount",
    x=100.0,
    z=10.0,
    rx_deg=90.0,
    kind=@common.MateKind::Datum,
  )
  let component = match
    @common.Component::new(
      name="part",
      metadata=@common.Metadata::new(designation="PART"),
    )
    .add_layer(@cad.Cuboid::new(10.0, 20.0, 30.0), name="body")
    .with_connector(connector) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let rebased = match component.rebase_to_connector("mount") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(rebased.layers().length(), component.layers().length())
  let original_layers = component.layers()
  let rebased_layers = rebased.layers()
  for i in 0..<original_layers.length() {
    let world_before = original_layers[i].placement
    let world_after = rebased_layers[i].placement
    let rebuilt = @common.Placement::compose(connector.placement, world_after)
    assert_true(mate_close_placement(world_before, rebuilt))
  }
  let placed = match rebased.connector("mount") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(
    mate_close_placement(placed.placement, @common.Placement::identity()),
  )
}

///|
test "mate pair validate rejects mismatches with typed errors" {
  let pair = @common.MatePair::new(parent="bore", child="shaft")
  let bore = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
  )
  let shaft = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::CylindricalShaft,
    gender=@common.MateGender::Male,
    diameter_mm=5.0,
  )
  assert_true(pair.validate(bore, shaft) is Ok(_))
  match
    pair.validate(
      @common.MateConnector::new(
        "other",
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=5.0,
      ),
      shaft,
    ) {
    Err(@common.MatePairError::ConnectorNameMismatch(expected, found)) => {
      assert_eq(expected, "bore")
      assert_eq(found, "other")
    }
    _ => fail("expected connector name mismatch")
  }
  let plane = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::PlaneFace,
  )
  match pair.validate(bore, plane) {
    Err(@common.MatePairError::IncompatibleKind(_, _)) => ()
    _ => fail("expected incompatible kind")
  }
  let male_thread = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::Threaded,
    gender=@common.MateGender::Male,
  )
  let other_male = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::Threaded,
    gender=@common.MateGender::Male,
  )
  match
    @common.MatePair::new(parent="bore", child="shaft").validate(
      other_male, male_thread,
    ) {
    Err(@common.MatePairError::IncompatibleGender(_, _)) => ()
    _ => fail("expected incompatible gender")
  }
  let big_bore = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=6.0,
  )
  match pair.validate(big_bore, shaft) {
    Err(@common.MatePairError::DiameterMismatch(_, _)) => ()
    _ => fail("expected diameter mismatch")
  }
  let free_bore = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
    fit=@cad.Fit::Free,
  )
  let close_shaft = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::CylindricalShaft,
    gender=@common.MateGender::Male,
    diameter_mm=5.0,
    fit=@cad.Fit::Close,
  )
  match
    @common.MatePair::new(parent="bore", child="shaft").validate(
      free_bore, close_shaft,
    ) {
    Err(@common.MatePairError::FitMismatch(_)) => ()
    _ => fail("expected fit mismatch")
  }
  let nan_pair = @common.MatePair::new(
    parent="bore",
    child="shaft",
    offset_mm=0.0 / 0.0,
  )
  assert_true(nan_pair.validate(bore, shaft) is Err(_))
  let empty_pair = @common.MatePair::new(parent="", child="shaft")
  assert_true(empty_pair.validate(bore, shaft) is Err(_))
}

///|
test "mate pair resolve aligns a shaft into a bore" {
  let pair = @common.MatePair::new(
    parent="bore",
    child="shaft",
    offset_mm=5.0,
    twist_deg=90.0,
    fit=@cad.Fit::Close,
  )
  let bore = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
  )
  let shaft = @common.MateConnector::new(
    "shaft",
    axis=(0.0, 0.0, -1.0),
    kind=@common.MateKind::CylindricalShaft,
    gender=@common.MateGender::Male,
    diameter_mm=5.0,
  )
  let alignment = match pair.resolve(bore, shaft) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mate_close_vec(alignment.placement.trans, (0.0, 0.0, 5.0)))
  assert_true(
    mate_close_point(
      alignment.placement.apply_point((1.0, 0.0, 0.0)),
      (0.0, 1.0, 5.0),
    ),
  )
  assert_true(mate_close_vec(alignment.axis, (0.0, 0.0, 1.0)))
  assert_false(alignment.axis_flipped)
  assert_true(alignment.insertion_anti_parallel)
  assert_true(alignment.declared_clearance_mm() == 0.1)
  assert_true(mate_close(alignment.nominal_diameter_gap_mm(), 0.0))
}

///|
test "mate pair resolve documents an automatic anti-parallel axis flip" {
  let pair = @common.MatePair::new(parent="bore", child="shaft")
  let bore = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
  )
  let shaft = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::CylindricalShaft,
    gender=@common.MateGender::Male,
    diameter_mm=5.0,
  )
  let alignment = match pair.resolve(bore, shaft) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mate_close_vec(alignment.axis, (0.0, 0.0, -1.0)))
  assert_true(alignment.axis_flipped)
}

///|
test "mate pair resolve flips the axis on request" {
  let pair = @common.MatePair::new(parent="bore", child="shaft", flip_axis=true)
  let bore = @common.MateConnector::new(
    "bore",
    kind=@common.MateKind::CylindricalBore,
    gender=@common.MateGender::Female,
    diameter_mm=5.0,
  )
  let shaft = @common.MateConnector::new(
    "shaft",
    kind=@common.MateKind::CylindricalShaft,
    gender=@common.MateGender::Male,
    diameter_mm=5.0,
  )
  let alignment = match pair.resolve(bore, shaft) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mate_close_vec(alignment.axis, (0.0, 0.0, -1.0)))
  assert_false(alignment.axis_flipped)
}

///|
test "mate pair resolves plane faces with anti-parallel normals" {
  let pair = @common.MatePair::new(parent="top", child="bottom")
  let top = @common.MateConnector::new(
    "top",
    placement=@common.Placement::translation(0.0, 0.0, 30.0),
    kind=@common.MateKind::PlaneFace,
  )
  let bottom = @common.MateConnector::new(
    "bottom",
    axis=(0.0, 0.0, -1.0),
    kind=@common.MateKind::PlaneFace,
  )
  let alignment = match pair.resolve(top, bottom) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mate_close_vec(alignment.placement.trans, (0.0, 0.0, 30.0)))
  assert_true(mate_close_vec(alignment.axis, (0.0, 0.0, 1.0)))
  assert_true(alignment.insertion_anti_parallel)
  assert_false(alignment.axis_flipped)
}

///|
test "mate pair rejects non-finite twist" {
  let pair = @common.MatePair::new(parent="a", child="b", twist_deg=0.0 / 0.0)
  let a = @common.MateConnector::new("a")
  let b = @common.MateConnector::new("b")
  assert_true(pair.resolve(a, b) is Err(_))
}
