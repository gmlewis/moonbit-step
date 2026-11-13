///|
fn has_stock_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "plate exposes face frames and one bore per hole" {
  let holes : Array[@stock.PlateHole] = [
    @stock.PlateHole::{ x_mm: -10.0, y_mm: 0.0, diameter_mm: 3.4, },
    @stock.PlateHole::{ x_mm: 10.0, y_mm: 0.0, diameter_mm: 3.4, },
  ]
  let part = match @stock.plate(50.0, 50.0, 5.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_stock_connector(part, "face-top"))
  assert_true(has_stock_connector(part, "face-bottom"))
  assert_true(has_stock_connector(part, "hole-1"))
  assert_true(has_stock_connector(part, "hole-2"))
}

///|
test "angle bar exposes outer faces and end datums" {
  let section = @stock.en10056_equal_angle_40x40x4()
  let part = match @stock.angle_bar(section, 50.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_stock_connector(part, "face-outer-x"))
  assert_true(has_stock_connector(part, "face-outer-y"))
  assert_true(has_stock_connector(part, "end-a"))
  assert_true(has_stock_connector(part, "end-b"))
  assert_true(has_stock_connector(part, "inner-corner"))
}

///|
test "plate exposes one connector per slot" {
  let slots : Array[@stock.PlateSlot] = [
    @stock.PlateSlot::{
      x_mm: -10.0,
      y_mm: 0.0,
      length_mm: 10.0,
      width_mm: 5.5,
    },
    @stock.PlateSlot::{ x_mm: 10.0, y_mm: 0.0, length_mm: 10.0, width_mm: 5.5, },
  ]
  let part = match @stock.plate(60.0, 20.0, 3.0, slots~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_stock_connector(part, "slot-1"))
  assert_true(has_stock_connector(part, "slot-2"))
}
