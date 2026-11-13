///|
test "connector sidecar lists every connector origin and axis" {
  let component = @common.Component::new(
      name="sidecar-demo",
      metadata=@common.Metadata::new(designation="sidecar demo"),
    )
    .add_layer(@cad.Cuboid::new(10.0, 10.0, 4.0), name="body")
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(1.0, 2.0, 3.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=5.0,
        depth_mm=4.0,
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face",
        placement=@common.Placement::translation(-1.0, 0.0, 2.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=10.0,
      ),
    )
  let text = component.connector_sidecar()
  let rows : Array[StringView] = text
    .split("\n")
    .filter(fn(line) { line != "" && !line.contains("#") })
    .collect()
  assert_eq(rows.length(), 2)
  let bore : Array[StringView] = rows[0].split("\t").collect()
  assert_eq(bore[0].to_owned(), "bore")
  assert_eq(bore[1].to_owned(), "1")
  assert_eq(bore[2].to_owned(), "2")
  assert_eq(bore[3].to_owned(), "3")
  // Primary axis is +Z; the secondary axis stays on global +X.
  assert_eq(bore[4].to_owned(), "0")
  assert_eq(bore[5].to_owned(), "0")
  assert_eq(bore[6].to_owned(), "1")
  assert_eq(bore[7].to_owned(), "1")
  assert_eq(bore[8].to_owned(), "0")
  assert_eq(bore[9].to_owned(), "0")
  assert_eq(bore[10].to_owned(), "cylindrical-bore")
  assert_eq(bore[11].to_owned(), "female")
  assert_eq(bore[12].to_owned(), "5")
  assert_eq(bore[13].to_owned(), "4")
  let face : Array[StringView] = rows[1].split("\t").collect()
  assert_eq(face[0].to_owned(), "face")
  assert_eq(face[4].to_owned(), "1")
  assert_eq(face[7].to_owned(), "0")
  assert_eq(face[8].to_owned(), "1")
  assert_eq(face[9].to_owned(), "0")
  assert_eq(face[10].to_owned(), "plane-face")
}

///|
test "connector sidecar does not change exported geometry" {
  let base = @common.Component::new(
    name="sidecar-geometry",
    metadata=@common.Metadata::new(designation="sidecar geometry"),
  ).add_layer(@cad.Cuboid::new(8.0, 6.0, 2.0), name="body")
  let with_connector = base.with_connector_unchecked(
    @common.MateConnector::new(
      "face-top",
      placement=@common.Placement::translation(0.0, 0.0, 2.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=8.0,
    ),
  )
  let a = base.bounding_box()
  let b = with_connector.bounding_box()
  assert_true(a.0 == b.0 && a.1 == b.1)
  assert_true(a.2 == b.2 && a.3 == b.3)
  assert_true(a.4 == b.4 && a.5 == b.5)
  assert_eq(base.layers().length(), with_connector.layers().length())
  assert_true(with_connector.connector_sidecar().contains("face-top"))
}

///|
test "connector sidecar preserves an intentional twist" {
  let component = @common.Component::new(
    name="twisted",
    metadata=@common.Metadata::new(designation="twisted"),
  ).with_connector_unchecked(
    @common.MateConnector::new(
      "keyed",
      placement=@common.Placement::rotation_z(45.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
    ),
  )
  let rows : Array[StringView] = component
    .connector_sidecar()
    .split("\n")
    .filter(fn(line) { line != "" && !line.contains("#") })
    .collect()
  let cols : Array[StringView] = rows[0].split("\t").collect()
  // A deliberate 45-degree placement keeps its rotated secondary axis.
  let xx = @string.parse_double(cols[7].to_owned()) catch {
    _ => abort("bad x")
  }
  let xy = @string.parse_double(cols[8].to_owned()) catch {
    _ => abort("bad y")
  }
  assert_true((xx - 0.7071067811865476).abs() < 1.0e-9)
  assert_true((xy - 0.7071067811865476).abs() < 1.0e-9)
}
