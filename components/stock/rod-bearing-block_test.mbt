///|
fn sc8uu_test_part() -> @common.Component {
  match @stock.sc8uu_bearing_block() {
    Ok(part) => part
    Err(e) => abort(e.message())
  }
}

///|
test "SC8UU bearing block envelope and both mating interfaces" {
  let part = sc8uu_test_part()
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, -17.0))
  assert_true(stock_close(x1, 17.0))
  assert_true(stock_close(y0, -15.0))
  assert_true(stock_close(y1, 15.0))
  assert_true(stock_close(z0, 0.0))
  assert_true(stock_close(z1, 22.0))
  assert_eq(part.layers().length(), 1)
  let seat = match part.connector("bearing-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(seat.diameter_mm.unwrap(), 15.0))
  assert_true(stock_close(seat.depth_mm.unwrap(), 30.0))
  assert_true(seat.fit is @cad.Fit::Press)
  assert_true(seat.axis == (0.0, 1.0, 0.0))
  let rod = match part.connector("rod-axis") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(rod.diameter_mm.unwrap(), 8.0))
  for name in ["mount-hole-1", "mount-hole-2", "mount-hole-3", "mount-hole-4"] {
    let hole = match part.connector(name) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_true(stock_close(hole.diameter_mm.unwrap(), 3.3))
    assert_true(hole.fit is @cad.Fit::Free)
  }
}

///|
test "SC8UU nominal volume is independent of the implementation" {
  let part = sc8uu_test_part()
  let corner_radius = 2.0
  let outline_area = 34.0 * 22.0 -
    (4.0 - 3.141592653589793) * corner_radius * corner_radius
  let expected = outline_area * 30.0 -
    3.141592653589793 * 7.5 * 7.5 * 30.0 -
    4.0 * 3.141592653589793 * 1.65 * 1.65 * 22.0
  assert_true(stock_close(expected, 16282.890747550957))
  assert_true(part.features().modeled.contains("bearing-seat"))
  assert_true(
    part.features().modeled.contains("bearing-parallel-corner-rounds"),
  )
  assert_true(part.features().modeled.contains("four-mounting-holes"))
}

///|
test "rod bearing block validates dimensions and interface separation" {
  assert_true(
    @stock.rod_bearing_block(0.0, 30.0, 22.0, 15.0, 8.0, 3.3, 24.0, 18.0)
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(
      34.0,
      30.0,
      22.0,
      15.0,
      8.0,
      3.3,
      24.0,
      18.0,
      corner_radius_mm=18.0,
    )
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(34.0, 30.0, 12.0, 15.0, 8.0, 3.3, 24.0, 18.0)
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(34.0, 30.0, 22.0, 15.0, 8.0, 3.3, 12.0, 18.0)
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(34.0, 30.0, 22.0, 15.0, 8.0, 3.3, 2.0, 18.0)
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(34.0, 30.0, 22.0, 15.0, 16.0, 3.3, 24.0, 18.0)
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(
      34.0,
      30.0,
      22.0,
      15.0,
      14.0,
      3.3,
      24.0,
      18.0,
      bearing_diametral_clearance_mm=-2.0,
    )
    is Err(_),
  )
  assert_true(
    @stock.rod_bearing_block(
      34.0,
      30.0,
      22.0,
      15.0,
      8.0,
      3.3,
      24.0,
      18.0,
      bearing_diametral_clearance_mm=-16.0,
    )
    is Err(_),
  )
}

///|
test "rod bearing block keeps fit intent separate from nominal tolerance" {
  let part = match
    @stock.rod_bearing_block(
      34.0,
      30.0,
      22.0,
      15.0,
      8.0,
      3.3,
      24.0,
      18.0,
      bearing_diametral_clearance_mm=0.2,
      bearing_fit=@cad.Fit::Free,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let seat = match part.connector("bearing-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(seat.diameter_mm.unwrap(), 15.2))
  assert_true(seat.fit is @cad.Fit::Free)
}
