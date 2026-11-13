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

///|
fn ok_stock(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "every public stock builder family exposes a connector" {
  let builders : Array[(@common.Component, String)] = [
    (
      ok_stock(@stock.tube_mount_plate(12.0, 0.3, 40.0, 30.0, 5.0, 5.5, 25.0)),
      "tube-bore",
    ),
    (
      ok_stock(@stock.vslot_joining_plate(60.0, 20.0, 3.0, 20.0, 10.0, 5.5)),
      "slot-1",
    ),
    (ok_stock(@stock.plate(40.0, 30.0, 5.0)), "face-top"),
    (
      ok_stock(@stock.angle_bar(@stock.en10056_equal_angle_40x40x4(), 50.0)),
      "face-outer-x",
    ),
    (
      ok_stock(
        @stock.plate_with_counterbores(50.0, 40.0, 8.0, holes=[
          @stock.CounterboredHole::{
            x_mm: 0.0,
            y_mm: 0.0,
            through_diameter_mm: 5.5,
            counterbore_diameter_mm: 9.0,
            counterbore_depth_mm: 2.0,
          },
        ]),
      ),
      "counterbore-1",
    ),
    (
      ok_stock(@stock.bearing_plate(22.0, 0.1, 50.0, 40.0, 6.0, 5.5, 30.0)),
      "bearing-seat",
    ),
    (
      ok_stock(
        @stock.plate_with_countersinks(50.0, 40.0, 8.0, holes=[
          @stock.CountersunkHole::{
            x_mm: 0.0,
            y_mm: 0.0,
            through_diameter_mm: 5.5,
            countersink_diameter_mm: 9.0,
            countersink_depth_mm: 2.0,
          },
        ]),
      ),
      "countersink-1",
    ),
    (
      ok_stock(
        @stock.tube_to_vslot_bracket(
          17.9324, 0.5, 60.0, 40.0, 5.0, 40.0, 10.0, 5.5,
        ),
      ),
      "tube-bore",
    ),
  ]
  for entry in builders {
    let (part, expected) = entry
    if part.connectors().length() == 0 {
      abort("builder produced no connector: " + part.name())
    }
    if !has_stock_connector(part, expected) {
      abort("builder " + part.name() + " is missing connector " + expected)
    }
  }
}

///|
test "counterbored plate builds a real stepped bore" {
  let holes : Array[@stock.CounterboredHole] = [
    @stock.CounterboredHole::{
      x_mm: -12.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      counterbore_diameter_mm: 9.0,
      counterbore_depth_mm: 4.0,
    },
    @stock.CounterboredHole::{
      x_mm: 12.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      counterbore_diameter_mm: 9.0,
      counterbore_depth_mm: 4.0,
    },
  ]
  let part = match @stock.plate_with_counterbores(50.0, 40.0, 8.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 50.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 40.0).abs() < 1.0e-6)
  assert_true((z0 + 4.0).abs() < 1.0e-6)
  assert_true((z1 - 4.0).abs() < 1.0e-6)
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true((volume - 15300.996).abs() < 0.2)
  for
    name in [
      "face-top", "face-bottom", "hole-1", "hole-2", "counterbore-1", "counterbore-2",
    ] {
    if !has_stock_connector(part, name) {
      abort("counterbored plate is missing connector " + name)
    }
  }
}

///|
test "counterbored plate rejects invalid counterbores" {
  let small : Array[@stock.CounterboredHole] = [
    @stock.CounterboredHole::{
      x_mm: 0.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      counterbore_diameter_mm: 4.0,
      counterbore_depth_mm: 2.0,
    },
  ]
  assert_true(
    @stock.plate_with_counterbores(50.0, 40.0, 8.0, holes=small) is Err(_),
  )
  let through : Array[@stock.CounterboredHole] = [
    @stock.CounterboredHole::{
      x_mm: 0.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      counterbore_diameter_mm: 9.0,
      counterbore_depth_mm: 8.0,
    },
  ]
  assert_true(
    @stock.plate_with_counterbores(50.0, 40.0, 8.0, holes=through) is Err(_),
  )
  let empty : Array[@stock.CounterboredHole] = []
  assert_true(
    @stock.plate_with_counterbores(50.0, 40.0, 8.0, holes=empty) is Err(_),
  )
}

///|
test "bearing plate records the declared seat fit" {
  let part = match @stock.bearing_plate(22.0, 0.1, 50.0, 40.0, 6.0, 5.5, 30.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 50.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 40.0).abs() < 1.0e-6)
  assert_true((z0 + 3.0).abs() < 1.0e-6)
  assert_true((z1 - 3.0).abs() < 1.0e-6)
  let seat = match part.connector("bearing-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  match seat.diameter_mm {
    Some(d) => assert_true((d - 22.1).abs() < 1.0e-9)
    None => fail("expected the bearing seat diameter")
  }
  assert_true(seat.fit is @cad.Fit::Free)
  assert_true(
    match part.connector("bolt-hole-1") {
      Ok(c) => c.fit is @cad.Fit::Free
      Err(e) => abort(e.message())
    },
  )
  let press = match
    @stock.bearing_plate(22.0, -0.1, 50.0, 40.0, 6.0, 5.5, 30.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  match press.connector("bearing-seat") {
    Ok(c) => assert_true(c.fit is @cad.Fit::Press)
    Err(e) => abort(e.message())
  }
}

///|
test "bearing plate rejects overlapping and out-of-plate holes" {
  assert_true(
    @stock.bearing_plate(22.0, 0.1, 50.0, 40.0, 6.0, 5.5, 20.0) is Err(_),
  )
  assert_true(
    @stock.bearing_plate(22.0, -22.0, 50.0, 40.0, 6.0, 5.5, 30.0) is Err(_),
  )
  assert_true(
    @stock.bearing_plate(22.0, 0.1, 30.0, 40.0, 6.0, 5.5, 30.0) is Err(_),
  )
}
