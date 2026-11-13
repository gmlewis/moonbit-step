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
  // Circular holes compile to analytic cylinders, so there is no polyline
  // approximation to report.
  assert_eq(part.features().approximated.length(), 0)
  assert_eq(part.layers().length(), 1)
  let inventory = part.layers()[0].shape.surface_inventory()
  // Six planar faces (four sides and two caps) and four arcs per hole. The
  // STEP compiler merges each full circle into one analytic cylinder.
  assert_eq(inventory.plane, 6)
  assert_eq(inventory.cylinder, 8)

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

///|
test "plate slots are analytic obround through cuts" {
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
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // Four outer sides, two caps, two straight slot walls per slot, and one
  // analytic cylinder per semicircular slot end.
  assert_eq(inventory.plane, 10)
  assert_eq(inventory.cylinder, 4)
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let slot_area = (10.0 - 5.5) * 5.5 + 3.141592653589793 * 2.75 * 2.75
  let expected = (60.0 * 20.0 - 2.0 * slot_area) * 3.0
  assert_true(stock_close(volume, expected))
  let outside : Array[@stock.PlateSlot] = [
    @stock.PlateSlot::{ x_mm: 30.0, y_mm: 0.0, length_mm: 10.0, width_mm: 5.5, },
  ]
  assert_true(@stock.plate(60.0, 20.0, 3.0, slots=outside) is Err(_))
  let overlapping : Array[@stock.PlateSlot] = [
    @stock.PlateSlot::{ x_mm: 0.0, y_mm: 0.0, length_mm: 20.0, width_mm: 5.5, },
    @stock.PlateSlot::{ x_mm: 5.0, y_mm: 0.0, length_mm: 20.0, width_mm: 5.5, },
  ]
  assert_true(@stock.plate(60.0, 20.0, 3.0, slots=overlapping) is Err(_))
}

///|
test "tube mount plate has both mating interfaces and explicit clearance" {
  let part = match
    @stock.tube_mount_plate(17.93, 0.5, 60.0, 40.0, 5.0, 5.5, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, -30.0))
  assert_true(stock_close(x1, 30.0))
  assert_true(stock_close(y0, -20.0))
  assert_true(stock_close(y1, 20.0))
  assert_true(stock_close(z0, -2.5))
  assert_true(stock_close(z1, 2.5))
  // Tube bore = tube OD + declared clearance.
  let tube = match part.connector("tube-bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(tube.diameter_mm.unwrap(), 18.43))
  let bolt = match part.connector("bolt-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(stock_close(bolt.diameter_mm.unwrap(), 5.5))
  // The plate itself has six planar faces and twelve hole arcs.
  let inventory = part.layers()[0].shape.surface_inventory()
  assert_eq(inventory.plane, 6)
  assert_eq(inventory.cylinder, 12)
}

///|
test "tube mount plate rejects a tube that does not fit" {
  assert_true(
    @stock.tube_mount_plate(50.0, 0.5, 40.0, 40.0, 5.0, 5.5, 20.0) is Err(_),
  )
}

///|
test "V-Slot joining plate exposes two slots and a mounting face" {
  let part = match
    @stock.vslot_joining_plate(60.0, 20.0, 3.0, 20.0, 10.0, 5.5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, -30.0))
  assert_true(stock_close(x1, 30.0))
  assert_true(stock_close(z0, -1.5))
  assert_true(stock_close(z1, 1.5))
  let names = part.connectors().map(fn(c) { c.name })
  assert_true(names.any(fn(n) { n == "slot-1" }))
  assert_true(names.any(fn(n) { n == "slot-2" }))
  assert_true(names.any(fn(n) { n == "face-top" }))
  assert_true(names.any(fn(n) { n == "face-bottom" }))
}
