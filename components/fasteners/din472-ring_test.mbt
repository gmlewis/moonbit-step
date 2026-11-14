///|
fn d472_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn d472_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn d472_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  for connector in part.connectors() {
    if connector.name == name {
      return connector
    }
  }
  abort("missing connector " + name)
}

///|
test "DIN 472 table carries the internal-ring dimensions" {
  let s20 = match @standards.din472_size(20.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(d472_close(s20.thickness_mm, 1.0, 1.0e-12))
  assert_true(d472_close(s20.free_outer_diameter_mm, 21.5, 1.0e-12))
  assert_true(d472_close(s20.lug_width_mm, 4.2, 1.0e-12))
  assert_true(d472_close(s20.ring_width_mm, 2.3, 1.0e-12))
  assert_true(d472_close(s20.lug_hole_mm, 2.0, 1.0e-12))
  assert_true(d472_close(s20.groove_diameter_mm, 21.0, 1.0e-12))
  assert_true(d472_close(s20.groove_width_mm, 1.1, 1.0e-12))
  assert_true(d472_close(s20.groove_depth_mm, 0.5, 1.0e-12))
  assert_true(d472_close(s20.edge_margin_mm, 1.5, 1.0e-12))
  assert_eq(s20.designation(), "DIN 472 - 20")
  // A small and a large row cross-check the table ends.
  let s8 = match @standards.din472_size(8.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(d472_close(s8.thickness_mm, 0.8, 1.0e-12))
  assert_true(d472_close(s8.free_outer_diameter_mm, 8.7, 1.0e-12))
  assert_true(d472_close(s8.groove_diameter_mm, 8.4, 1.0e-12))
  let s40 = match @standards.din472_size(40.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(d472_close(s40.thickness_mm, 1.8, 1.0e-12))
  assert_true(d472_close(s40.free_outer_diameter_mm, 43.5, 1.0e-12))
  assert_true(d472_close(s40.groove_diameter_mm, 42.5, 1.0e-12))
  // Unsupported sizes and odd bores are rejected.
  assert_true(@standards.din472_size(11.0) is Err(_))
  assert_true(@standards.din472_size(42.0) is Err(_))
}

///|
test "DIN 472 20 mm ring matches the reference envelope" {
  let part = d472_ok(@fasteners.din472_ring(20.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  // Lugs toward +X: the across-lugs span is the X extent.
  assert_true(d472_close(x1 - x0, 21.477, 0.02))
  assert_true(d472_close(y1 - y0, 21.5, 0.02))
  assert_true(d472_close(z0, 0.0, 1.0e-9))
  assert_true(d472_close(z1, 1.0, 1.0e-9))
  assert_eq(part.layers().length(), 1)
  let layer = part.layers()[0]
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(d472_close(volume, 158.73, 0.3))
  let inventory = layer.shape.surface_inventory()
  assert_true(inventory.plane >= 4)
  assert_true(inventory.cylinder >= 6)
}

///|
test "DIN 472 connectors cover faces, bore, free outer, groove, plier holes" {
  let part = d472_ok(@fasteners.din472_ring(20.0))
  for
    name in [
      "face-negative", "face-positive", "bore", "free-outer", "groove-seat", "lug-hole-1",
      "lug-hole-2",
    ] {
    let connector = d472_connector(part, name)
    if name == "bore" {
      assert_true(connector.kind is @common.MateKind::CylindricalBore)
      match connector.diameter_mm {
        Some(d) => assert_true(d472_close(d, 20.0, 1.0e-12))
        None => fail("bore connector should carry d1")
      }
    }
    if name == "free-outer" {
      match connector.diameter_mm {
        Some(d) => assert_true(d472_close(d, 21.5, 1.0e-12))
        None => fail("free-outer connector should carry d3")
      }
    }
    if name == "groove-seat" {
      assert_true(connector.kind is @common.MateKind::Datum)
      match connector.diameter_mm {
        Some(d) => assert_true(d472_close(d, 21.0, 1.0e-12))
        None => fail("groove-seat should carry d2")
      }
      match connector.depth_mm {
        Some(d) => assert_true(d472_close(d, 1.1, 1.0e-12))
        None => fail("groove-seat should carry m")
      }
    }
    if name == "lug-hole-1" || name == "lug-hole-2" {
      match connector.diameter_mm {
        Some(d) => assert_true(d472_close(d, 2.0, 1.0e-12))
        None => fail("plier hole should carry d5")
      }
    }
  }
}

///|
test "DIN 472 12 mm ring matches the reference envelope" {
  let part = d472_ok(@fasteners.din472_ring(12.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  // Lugs toward +X: the across-lugs span is the X extent.
  assert_true(d472_close(x1 - x0, 12.979, 0.02))
  assert_true(d472_close(y1 - y0, 13.0, 0.02))
  assert_true(d472_close(z0, 0.0, 1.0e-9))
  assert_true(d472_close(z1, 1.0, 1.0e-9))
  assert_eq(part.layers().length(), 1)
  let layer = part.layers()[0]
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(d472_close(volume, 68.09, 0.3))
  let inventory = layer.shape.surface_inventory()
  assert_true(inventory.plane >= 4)
  assert_true(inventory.cylinder >= 6)
}

///|
test "DIN 472 12 mm ring carries the table's lug-hole diameter" {
  let part = d472_ok(@fasteners.din472_ring(12.0))
  for name in ["lug-hole-1", "lug-hole-2"] {
    let connector = d472_connector(part, name)
    match connector.diameter_mm {
      Some(d) => assert_true(d472_close(d, 1.5, 1.0e-12))
      None => fail("plier hole should carry d5")
    }
  }
}

///|
test "DIN 472 ring rejects sizes outside its table" {
  assert_true(@fasteners.din472_ring(0.0) is Err(_))
  assert_true(@fasteners.din472_outline(0.0) is Err(_))
  // Odd bores and bores above 40 mm are not DIN 472 table rows.
  assert_true(@fasteners.din472_ring(9.0) is Err(_))
  assert_true(@fasteners.din472_ring(42.0) is Err(_))
  for size in [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 40.0] {
    assert_true(@fasteners.din472_outline(size) is Ok(_))
  }
}

///|
test "DIN 472 parametric outlines cover every table size" {
  let table_sizes : Array[Double] = [
    8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0, 32.0,
    34.0, 36.0, 38.0, 40.0,
  ]
  for size in table_sizes {
    assert_true(@standards.din472_size(size) is Ok(_))
    assert_true(@fasteners.din472_outline(size) is Ok(_))
    let part = d472_ok(@fasteners.din472_ring(size))
    assert_eq(part.layers().length(), 1)
  }
}

///|
test "DIN 472 parametric envelopes follow the standard dimensions" {
  // y extent is the free outside diameter d3 and z is the thickness s; the
  // x extent is the across-lug span, which the parametric construction
  // reproduces consistently with the measured neighbours.
  let cases : Array[(Double, Double, Double, Double)] = [
    (8.0, 8.2793, 8.7, 0.8),
    (22.0, 23.2755, 23.5, 1.0),
    (26.0, 27.6396, 27.9, 1.2),
    (30.0, 31.8811, 32.1, 1.2),
    (34.0, 36.2094, 36.5, 1.5),
    (36.0, 38.5381, 38.8, 1.5),
    (38.0, 40.5565, 40.8, 1.5),
  ]
  for case in cases {
    let (size, x_extent, y_extent, thickness) = case
    let part = d472_ok(@fasteners.din472_ring(size))
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    if !d472_close(x1 - x0, x_extent, 0.01) {
      fail("size \{size}: x extent \{x1 - x0} vs \{x_extent}")
    }
    assert_true(d472_close(y1 - y0, y_extent, 1.0e-6))
    assert_true(d472_close(z0, 0.0, 1.0e-6))
    assert_true(d472_close(z1 - z0, thickness, 1.0e-6))
  }
}

///|
test "DIN 472 parametrics fill the measured gaps with recorded approximations" {
  // The seven sizes without a measured outline are built from the table
  // dimensions, are sharp, carry the parametric provenance note, and record
  // the ~0.1 mm engineering approximation.
  for size in [8.0, 22.0, 26.0, 30.0, 34.0, 36.0, 38.0] {
    let part = d472_ok(@fasteners.din472_ring(size))
    assert_false(part.features().has_modeled("edge-chamfers"))
    assert_true(part.features().has_omitted("edge-breaks"))
    if !part.metadata().source.contains("parametric DIN 472 construction") {
      fail("size \{size} does not record its parametric provenance")
    }
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    assert_true(x1 - x0 > size)
    assert_true(y1 - y0 > size)
    assert_true(z1 - z0 > 0.0)
    assert_eq(part.connectors().length(), 7)
  }
}

///|
test "DIN 472 golden-frame rotation carries connector origins" {
  let part = d472_ok(@fasteners.din472_ring(10.0))
  let rotated = part.rotate_z(-90.0)
  let hole = d472_connector(rotated, "lug-hole-1")
  let (x, y, _z) = hole.placement.trans
  if !d472_close(x, 2.9405, 1.0e-4) || !d472_close(y, -2.4069, 1.0e-4) {
    fail("rotated connector origin is (\{x}, \{y})")
  }
}

///|
test "CC0 DIN 472 rings remain flat with sharp edges" {
  for size in [12.0, 20.0] {
    let part = d472_ok(@fasteners.din472_ring(size))
    assert_false(part.features().has_modeled("edge-chamfers"))
    assert_true(part.features().has_omitted("edge-breaks"))
    assert_true(part.layers()[0].shape is @cad.Shape::ExtrudedArcProfile(_))
  }
}

///|
test "additional DIN 472 outlines match envelopes and carry chamfers" {
  let cases : Array[(Double, Double, Double, Double)] = [
    (10.0, 10.227472, 10.8, 1.0),
    (14.0, 14.780321, 15.1, 1.0),
    (16.0, 17.047020, 17.3, 1.0),
    (18.0, 19.283299, 19.5, 1.0),
    (24.0, 25.693551, 25.9, 1.2),
    (28.0, 29.927963, 30.1, 1.2),
    (32.0, 34.250705, 34.4, 1.2),
    (40.0, 43.264394, 43.5, 1.75),
  ]
  for case in cases {
    let (size, x_extent, y_extent, thickness) = case
    let part = d472_ok(@fasteners.din472_ring(size))
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    if !d472_close(x1 - x0, x_extent, 0.02) {
      fail(
        "size \{size}: x extent \{x1 - x0} vs \{x_extent}; bbox [\{x0}, \{x1}] [\{y0}, \{y1}]",
      )
    }
    assert_true(d472_close(y1 - y0, y_extent, 0.02))
    assert_true(d472_close(z0, 0.0, 1.0e-6))
    assert_true(d472_close(z1 - z0, thickness, 0.02))
    assert_true(part.features().has_modeled("edge-chamfers"))
    assert_true(part.layers()[0].shape is @cad.Shape::Chamfer(_))
    if !part.metadata().source.contains("CC BY-SA 4.0") {
      fail("size \{size} does not record its CC BY-SA outline provenance")
    }
  }
}
