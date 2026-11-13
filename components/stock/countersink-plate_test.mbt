///|
test "countersunk plate builds exact conical seats" {
  let holes : Array[@stock.CountersunkHole] = [
    @stock.CountersunkHole::{
      x_mm: -12.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 9.0,
      countersink_depth_mm: 2.0,
    },
    @stock.CountersunkHole::{
      x_mm: 12.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 9.0,
      countersink_depth_mm: 2.0,
    },
  ]
  let part = match @stock.plate_with_countersinks(50.0, 40.0, 8.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 50.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 40.0).abs() < 1.0e-6)
  assert_true((z0 + 4.0).abs() < 1.0e-6)
  assert_true((z1 - 4.0).abs() < 1.0e-6)
  assert_true(part.layers().length() == 4)
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true((volume - 15546.563).abs() < 0.2)
  for
    name in [
      "face-top", "face-bottom", "hole-1", "hole-2", "countersink-1", "countersink-2",
    ] {
    if !has_stock_connector(part, name) {
      abort("countersunk plate is missing connector " + name)
    }
  }
  let seat = match part.connector("countersink-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  match seat.diameter_mm {
    Some(d) => assert_true((d - 9.0).abs() < 1.0e-9)
    None => fail("expected the countersink diameter")
  }
  match seat.depth_mm {
    Some(d) => assert_true((d - 2.0).abs() < 1.0e-9)
    None => fail("expected the countersink depth")
  }
}

///|
test "countersunk plate supports a 90 degree seat" {
  let holes : Array[@stock.CountersunkHole] = [
    @stock.CountersunkHole::{
      x_mm: 0.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 11.5,
      countersink_depth_mm: 3.0,
    },
  ]
  let part = match @stock.plate_with_countersinks(30.0, 30.0, 8.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(part.layers().length() == 3)
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  let rt = 5.5 / 2.0
  let rc = 11.5 / 2.0
  let expected = (30.0 * 30.0 - 3.141592653589793 * rt * rt) * 5.0 +
    (30.0 * 30.0 - 3.141592653589793 * rc * rc) * 3.0 +
    3.141592653589793 / 3.0 * (2.0 * rc + rt) * (rc - rt) * 3.0
  assert_true((volume - expected).abs() < 0.2)
}

///|
test "countersunk plate rejects invalid seats" {
  let small : Array[@stock.CountersunkHole] = [
    @stock.CountersunkHole::{
      x_mm: 0.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 4.0,
      countersink_depth_mm: 2.0,
    },
  ]
  assert_true(
    @stock.plate_with_countersinks(50.0, 40.0, 8.0, holes=small) is Err(_),
  )
  let through : Array[@stock.CountersunkHole] = [
    @stock.CountersunkHole::{
      x_mm: 0.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 9.0,
      countersink_depth_mm: 8.0,
    },
  ]
  assert_true(
    @stock.plate_with_countersinks(50.0, 40.0, 8.0, holes=through) is Err(_),
  )
  let empty : Array[@stock.CountersunkHole] = []
  assert_true(
    @stock.plate_with_countersinks(50.0, 40.0, 8.0, holes=empty) is Err(_),
  )
  let mixed : Array[@stock.CountersunkHole] = [
    @stock.CountersunkHole::{
      x_mm: -10.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 9.0,
      countersink_depth_mm: 2.0,
    },
    @stock.CountersunkHole::{
      x_mm: 10.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      countersink_diameter_mm: 9.0,
      countersink_depth_mm: 3.0,
    },
  ]
  assert_true(
    @stock.plate_with_countersinks(60.0, 40.0, 8.0, holes=mixed) is Err(_),
  )
}

///|
test "tube-to-V-Slot bracket carries a tube and two T-nut slots" {
  let result = @stock.tube_to_vslot_bracket(
    17.9324, 0.5, 60.0, 40.0, 5.0, 40.0, 10.0, 5.5,
  )
  let part = match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 60.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 40.0).abs() < 1.0e-6)
  assert_true((z0 + 2.5).abs() < 1.0e-6)
  assert_true((z1 - 2.5).abs() < 1.0e-6)
  for name in ["face-top", "face-bottom", "tube-bore", "slot-1", "slot-2"] {
    if !has_stock_connector(part, name) {
      abort("tube-to-V-Slot bracket is missing connector " + name)
    }
  }
  let bore = match part.connector("tube-bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  match bore.diameter_mm {
    Some(d) => assert_true((d - 18.4324).abs() < 1.0e-9)
    None => fail("expected the tube bore diameter")
  }
}

///|
test "tube-to-V-Slot bracket rejects impossible slot pitches" {
  assert_true(
    @stock.tube_to_vslot_bracket(17.9324, 0.5, 60.0, 40.0, 5.0, 80.0, 10.0, 5.5)
    is Err(_),
  )
  assert_true(
    @stock.tube_to_vslot_bracket(17.9324, 0.5, 20.0, 20.0, 5.0, 10.0, 10.0, 5.5)
    is Err(_),
  )
}
