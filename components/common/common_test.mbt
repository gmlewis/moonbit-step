///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "placement identity leaves a point unchanged" {
  let p = (1.0, 2.0, 3.0)
  let q = @common.Placement::identity().apply_point(p)
  assert_true(close(q.0, 1.0))
  assert_true(close(q.1, 2.0))
  assert_true(close(q.2, 3.0))
}

///|
test "placement compose applies inner then outer" {
  let inner = @common.Placement::translation(1.0, 0.0, 0.0)
  let outer = @common.Placement::rotation_z(90.0)
  let t = @common.Placement::compose(outer, inner)
  let p = t.apply_point((0.0, 0.0, 0.0))
  assert_true(close(p.0, 0.0))
  assert_true(close(p.1, 1.0))
  assert_true(close(p.2, 0.0))
}

///|
test "placement inverse round-trips a point" {
  let t = @common.Placement::at(10.0, -2.0, 5.0, rx=10.0, ry=20.0, rz=30.0)
  let p = (3.0, 4.0, 5.0)
  let back = t.inverse().apply_point(t.apply_point(p))
  assert_true(close(back.0, p.0))
  assert_true(close(back.1, p.1))
  assert_true(close(back.2, p.2))
}

///|
test "placement euler matches the cad rotation convention" {
  let p = (2.0, 3.0, 4.0)
  let expected = @cad.rotate_point(p, 10.0, 20.0, 30.0)
  let actual = @common.Placement::rotation_deg(10.0, 20.0, 30.0).apply_point(p)
  assert_true(close(expected.0, actual.0))
  assert_true(close(expected.1, actual.1))
  assert_true(close(expected.2, actual.2))
}

///|
test "detail policy separates threads from detail" {
  let simple = @common.DetailPolicy::for_level(Simplified)
  assert_true(simple.threads is None)
  let full = @common.DetailPolicy::for_level(FullyModeled)
  assert_true(full.threads is Helical)
  assert_true(full.circle_segments > simple.circle_segments)
}

///|
test "component materialises layers with stable names and bounds" {
  let component = @common.Component::new(
      name="test-part",
      metadata=@common.Metadata::new(
        designation="TEST - 1",
        standard="TEST",
        family="test part",
        size="1",
      ),
    )
    .add_layer(
      @cad.Cuboid::new(10.0, 20.0, 30.0),
      name="body",
      color=@cad.Rgb::blue(),
    )
    .translate(x=100.0)
  let nodes = component.nodes()
  assert_eq(nodes.length(), 1)
  let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
  assert_true(close(x0, 100.0))
  assert_true(close(x1, 110.0))
  assert_true(close(y0, 0.0))
  assert_true(close(y1, 20.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 30.0))
  assert_true(component.name() == "test-part")
  assert_true(component.metadata().designation == "TEST - 1")
}

///|
test "component rotation composes with translation" {
  let component = @common.Component::new(
      name="rot",
      metadata=@common.Metadata::new(designation="ROT"),
    )
    .add_layer(@cad.Cuboid::new(10.0, 1.0, 1.0), name="bar")
    .translate(x=1.0)
    .rotate_z(90.0)
  let (x0, x1, y0, y1, _z0, _z1) = component.bounding_box()
  assert_true(close(x0, -1.0))
  assert_true(close(x1, 0.0))
  assert_true(close(y0, 1.0))
  assert_true(close(y1, 11.0))
}

///|
test "component to_step emits one manifold solid per layer" {
  let component = @common.Component::new(
      name="two-layer",
      metadata=@common.Metadata::new(designation="TWO"),
    )
    .add_layer(@cad.Cuboid::new(1.0, 1.0, 1.0), name="a")
    .add_layer(
      @cad.Cuboid::new(1.0, 1.0, 1.0),
      name="b",
      placement=@common.Placement::translation(0.0, 0.0, 2.0),
    )
  let step = component.to_step()
  assert_eq(step.split("MANIFOLD_SOLID_BREP(").count() - 1, 2)
}

///|
test "metadata summary and documentation include provenance" {
  let metadata = @common.Metadata::new(
    designation="ISO 4762 - M4 x 20",
    standard="ISO 4762:2004",
    family="socket head cap screw",
    size="M4",
    length_mm=20.0,
    source="ISO 4762 table",
  )
  assert_true(metadata.summary() == "ISO 4762 - M4 x 20")
  let doc = metadata.documentation()
  assert_true(doc.contains("ISO 4762:2004"))
  assert_true(doc.contains("M4"))
  assert_true(doc.contains("Data source"))
}

///|
test "validation rejects non-positive and non-finite dimensions" {
  assert_true(@common.require_positive("d", 1.0) is Ok(_))
  assert_true(@common.require_positive("d", 0.0) is Err(_))
  assert_true(@common.require_positive("d", -1.0) is Err(_))
  assert_true(@common.require_positive("d", 0.0 / 0.0) is Err(_))
  assert_true(@common.require_in_range("l", 5.0, 1.0, 10.0) is Ok(_))
  assert_true(@common.require_in_range("l", 11.0, 1.0, 10.0) is Err(_))
}
