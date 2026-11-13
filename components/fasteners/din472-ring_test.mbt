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
test "DIN 472 ring rejects unsupported and invalid input" {
  assert_true(@fasteners.din472_ring(10.0) is Err(_))
  assert_true(@fasteners.din472_ring(0.0) is Err(_))
  assert_true(@fasteners.din472_outline(15.0) is Err(_))
}
