///|
fn heat_boss_part() -> @common.Component {
  match @stock.heat_set_boss_m3x4() {
    Ok(part) => part
    Err(e) => abort(e.message())
  }
}

///|
test "M3 heat-set boss envelope and both mating interfaces" {
  let part = heat_boss_part()
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, -3.8))
  assert_true(stock_close(x1, 3.8))
  assert_true(stock_close(y0, -3.8))
  assert_true(stock_close(y1, 3.8))
  assert_true(stock_close(z0, 0.0))
  assert_true(stock_close(z1, 8.0))
  assert_eq(part.layers().length(), 1)
  let pocket = match part.connector("insert-pocket") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(pocket.diameter_mm.unwrap(), 4.4))
  assert_true(stock_close(pocket.depth_mm.unwrap(), 5.0))
  assert_true(pocket.axis == (0.0, 0.0, -1.0))
  assert_true(pocket.fit is @cad.Fit::Nominal)
  let clearance = match part.connector("screw-clearance") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(clearance.diameter_mm.unwrap(), 3.4))
  assert_true(stock_close(clearance.depth_mm.unwrap(), 8.0))
  assert_true(clearance.axis == (0.0, 0.0, 1.0))
  assert_true(clearance.fit is @cad.Fit::Free)
  for name in ["boss-base", "boss-top", "outer-seat"] {
    assert_true(has_stock_connector(part, name))
  }
}

///|
test "M3 heat-set boss volume is exact" {
  let part = heat_boss_part()
  let pi = 3.141592653589793
  let expected = pi * (3.8 * 3.8 * 8.0 - 2.2 * 2.2 * 5.0 - 1.7 * 1.7 * 3.0)
  assert_true(stock_close(expected, 259.65263281919636))
  let actual = match part.layers()[0].shape.analysis_volume() {
    Ok(volume) => volume
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(actual, expected))
  let inventory = part.layers()[0].shape.surface_inventory()
  assert_eq(inventory.cylinder, 3)
  assert_eq(inventory.plane, 3)
  assert_true(part.features().modeled.contains("insert-pocket"))
  assert_true(part.features().modeled.contains("screw-clearance-bore"))
}

///|
test "heat-set boss validates pocket and clearance geometry" {
  assert_true(@stock.heat_set_boss(0.0, 8.0, 4.4, 5.0, 3.4) is Err(_))
  assert_true(@stock.heat_set_boss(4.0, 8.0, 4.4, 5.0, 3.4) is Err(_))
  assert_true(@stock.heat_set_boss(7.6, 8.0, 4.4, 8.0, 3.4) is Err(_))
  assert_true(@stock.heat_set_boss(7.6, 8.0, 4.4, 5.0, 4.4) is Err(_))
  assert_true(
    @stock.heat_set_boss(
      7.6,
      8.0,
      4.4,
      5.0,
      3.4,
      insert_diametral_clearance_mm=-1.0,
    )
    is Err(_),
  )
  assert_true(@stock.heat_set_boss(7.6, 8.0, 4.4, 0.0, 3.4) is Err(_))
}

///|
test "heat-set boss keeps insert fit intent separate from clearance" {
  let part = match
    @stock.heat_set_boss(
      7.6,
      8.0,
      4.4,
      5.0,
      3.4,
      insert_diametral_clearance_mm=0.2,
      insert_fit=@cad.Fit::Free,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pocket = match part.connector("insert-pocket") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(pocket.diameter_mm.unwrap(), 4.6))
  assert_true(pocket.fit is @cad.Fit::Free)
}
