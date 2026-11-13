///|
fn stock_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
test "EN 10056 40x40x4 angle envelope and section" {
  let section = @stock.en10056_equal_angle_40x40x4()
  let part = match @stock.angle_bar(section, 50.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, 0.0))
  assert_true(stock_close(x1, 40.0))
  assert_true(stock_close(y0, 0.0))
  assert_true(stock_close(y1, 40.0))
  assert_true(stock_close(z0, 0.0))
  assert_true(stock_close(z1, 50.0))
  assert_eq(part.layers().length(), 1)
  assert_true(part.features().modeled.contains("toe-radii"))
  assert_true(part.features().approximated.length() > 0)
}

///|
test "angle section validation" {
  assert_true(
    @stock.angle_section(
      leg_a_mm=40.0,
      leg_b_mm=40.0,
      thickness_mm=40.0,
      root_radius_mm=6.0,
      toe_radius_mm=3.0,
    )
    is Err(_),
  )
  assert_true(
    @stock.angle_section(
      leg_a_mm=40.0,
      leg_b_mm=40.0,
      thickness_mm=4.0,
      root_radius_mm=6.0,
      toe_radius_mm=4.0,
    )
    is Err(_),
  )
  assert_true(
    @stock.angle_section(
      leg_a_mm=10.0,
      leg_b_mm=10.0,
      thickness_mm=4.0,
      root_radius_mm=6.0,
      toe_radius_mm=2.0,
    )
    is Err(_),
  )
  assert_true(
    @stock.angle_bar(@stock.en10056_equal_angle_40x40x4(), 0.0) is Err(_),
  )
}

///|
test "plate blank is centered on z" {
  let part = match @stock.plate(50.0, 50.0, 3.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, -25.0))
  assert_true(stock_close(x1, 25.0))
  assert_true(stock_close(y0, -25.0))
  assert_true(stock_close(y1, 25.0))
  assert_true(stock_close(z0, -1.5))
  assert_true(stock_close(z1, 1.5))
  assert_eq(part.layers().length(), 1)
}

///|
test "plate holes are through holes and are validated" {
  let holes : Array[@stock.PlateHole] = [
    @stock.PlateHole::{ x_mm: -10.0, y_mm: 0.0, diameter_mm: 3.4, },
    @stock.PlateHole::{ x_mm: 10.0, y_mm: 0.0, diameter_mm: 3.4, },
  ]
  let part = match @stock.plate(50.0, 50.0, 5.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (_x0, _x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(z0, -2.5))
  assert_true(stock_close(z1, 2.5))
  assert_eq(part.features().approximated.length(), 2)

  let outside : Array[@stock.PlateHole] = [
    @stock.PlateHole::{ x_mm: 25.0, y_mm: 0.0, diameter_mm: 3.4, },
  ]
  assert_true(@stock.plate(50.0, 50.0, 5.0, holes=outside) is Err(_))
  let overlapping : Array[@stock.PlateHole] = [
    @stock.PlateHole::{ x_mm: 0.0, y_mm: 0.0, diameter_mm: 10.0, },
    @stock.PlateHole::{ x_mm: 5.0, y_mm: 0.0, diameter_mm: 10.0, },
  ]
  assert_true(@stock.plate(50.0, 50.0, 5.0, holes=overlapping) is Err(_))
}
