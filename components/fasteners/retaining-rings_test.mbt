///|
fn rr_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn rr_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn rr_connector(
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
test "DIN 471 table carries the type A dimensions" {
  let s20 = match @standards.din471_size(20.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(rr_close(s20.thickness_mm, 1.2, 1.0e-12))
  assert_true(rr_close(s20.free_inner_diameter_mm, 18.5, 1.0e-12))
  assert_true(rr_close(s20.lug_width_mm, 4.0, 1.0e-12))
  assert_true(rr_close(s20.ring_width_mm, 2.6, 1.0e-12))
  assert_true(rr_close(s20.lug_hole_mm, 2.0, 1.0e-12))
  assert_true(rr_close(s20.groove_diameter_mm, 19.0, 1.0e-12))
  assert_true(rr_close(s20.groove_width_mm, 1.3, 1.0e-12))
  assert_true(rr_close(s20.groove_depth_mm, 0.5, 1.0e-12))
  assert_true(rr_close(s20.edge_margin_mm, 1.5, 1.0e-12))
  assert_eq(s20.designation(), "DIN 471 - A 20")
  // Unsupported sizes and non-even sizes are rejected.
  assert_true(@standards.din471_size(11.0) is Err(_))
  assert_true(@standards.din471_size(36.0) is Err(_))
}

///|
test "DIN 471 A20 ring matches the reference envelope" {
  let part = rr_ok(@fasteners.din471_ring(20.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(rr_close(x1 - x0, 25.2, 0.01))
  assert_true(rr_close(y1 - y0, 22.8, 0.01))
  assert_true(rr_close(z0, 0.0, 1.0e-9))
  assert_true(rr_close(z1, 1.2, 1.0e-9))
  assert_eq(part.layers().length(), 1)
  let layer = part.layers()[0]
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // The reference model's planar face area is 155.5462 mm^2; x 1.2 mm.
  assert_true(rr_close(volume, 186.656, 0.01))
  // One solid, both lug holes present.
  let inventory = layer.shape.surface_inventory()
  assert_true(inventory.plane >= 6)
  assert_true(inventory.cylinder >= 8)
}

///|
test "DIN 471 connectors cover faces, bore, groove, and plier holes" {
  let part = rr_ok(@fasteners.din471_ring(20.0))
  for
    name in [
      "face-negative", "face-positive", "bore", "groove-seat", "lug-hole-1", "lug-hole-2",
    ] {
    let connector = rr_connector(part, name)
    if name == "bore" {
      match connector.diameter_mm {
        Some(d) => assert_true(rr_close(d, 18.5, 1.0e-12))
        None => fail("bore connector should carry d3")
      }
    }
    if name == "groove-seat" {
      assert_true(connector.kind is @common.MateKind::Datum)
      match connector.diameter_mm {
        Some(d) => assert_true(rr_close(d, 19.0, 1.0e-12))
        None => fail("groove-seat should carry d2")
      }
    }
    if name == "lug-hole-1" || name == "lug-hole-2" {
      match connector.diameter_mm {
        Some(d) => assert_true(rr_close(d, 2.0, 1.0e-12))
        None => fail("plier hole should carry d5")
      }
    }
  }
}

///|
test "DIN 471 every supported size builds one solid" {
  let expected : Array[(Double, Double, Double, Double)] = [
    // (d1, x extent, y extent, volume)
    (10.0, 14.54, 12.3, 61.51),
    (12.0, 16.06, 14.0, 67.607),
    (14.0, 18.5, 16.4, 94.503),
    (16.0, 20.6, 18.34, 109.016),
    (18.0, 22.9, 20.5, 155.24),
    (20.0, 25.2, 22.8, 186.656),
    (22.0, 27.6, 25.2, 224.354),
    (24.0, 29.58, 27.14, 259.605),
    (26.0, 31.8, 29.3, 286.417),
    (28.0, 33.8, 31.1, 396.391),
    (30.0, 36.6, 33.89, 481.918),
    (32.0, 38.34, 35.57, 518.566),
    (34.0, 40.79, 37.92, 571.631),
  ]
  for row in expected {
    let (size, ex, ey, vol) = row
    let part = rr_ok(@fasteners.din471_ring(size))
    let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
    assert_true(rr_close(x1 - x0, ex, 0.02))
    assert_true(rr_close(y1 - y0, ey, 0.02))
    let layer = part.layers()[0]
    let volume = match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
    assert_true(rr_close(volume, vol, 0.05))
  }
}

///|
test "DIN 471 ring rejects unsupported and invalid input" {
  assert_true(@fasteners.din471_ring(11.0) is Err(_))
  assert_true(@fasteners.din471_ring(0.0) is Err(_))
  assert_true(@fasteners.din471_outline(15.0) is Err(_))
}
