///|
fn adapter_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  match part.connector(name) {
    Ok(connector) => connector
    Err(e) => abort(e.message())
  }
}

///|
test "channel to extrusion adapter carries both hole patterns" {
  let part = match
    @stock.channel_to_extrusion_adapter(41.3, 47.6, 14.3, 20.0, 70.0, 48.0, 6.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(x0, -35.0) && stock_close(x1, 35.0))
  assert_true(stock_close(y0, -24.0) && stock_close(y1, 24.0))
  assert_true(stock_close(z0, -3.0) && stock_close(z1, 3.0))
  let ch = adapter_connector(part, "channel-hole-1")
  assert_true(stock_close(ch.placement.trans.0, -23.8))
  assert_true(stock_close(ch.placement.trans.1, 0.0))
  match ch.diameter_mm {
    Some(d) => assert_true(stock_close(d, 14.3))
    None => fail("channel hole should carry its clearance diameter")
  }
  let ext = adapter_connector(part, "extrusion-hole-1")
  assert_true(stock_close(ext.placement.trans.0, 0.0))
  assert_true(stock_close(ext.placement.trans.1, -10.0))
  match ext.diameter_mm {
    Some(d) => assert_true(stock_close(d, 5.5))
    None => fail("extrusion hole should carry its clearance diameter")
  }
  let slot = adapter_connector(part, "extrusion-slot")
  assert_true(slot.kind is @common.MateKind::Datum)
  assert_true(stock_close(slot.axis.1, 1.0))
  assert_true(part.features().modeled.contains("channel-bolt-holes"))
  assert_true(part.features().omitted.length() > 0)
}

///|
test "channel to extrusion adapter rejects impossible plates" {
  // Too narrow for the channel pattern.
  assert_true(
    @stock.channel_to_extrusion_adapter(41.3, 47.6, 14.3, 20.0, 60.0, 48.0, 6.0)
    is Err(_),
  )
  // Too short across the 41.3 mm channel width.
  assert_true(
    @stock.channel_to_extrusion_adapter(41.3, 47.6, 14.3, 20.0, 70.0, 40.0, 6.0)
    is Err(_),
  )
  // Zero thickness.
  assert_true(
    @stock.channel_to_extrusion_adapter(41.3, 47.6, 14.3, 20.0, 70.0, 48.0, 0.0)
    is Err(_),
  )
  // A 10 mm channel pitch with 14.3 mm holes puts the patterns into each other.
  assert_true(
    @stock.channel_to_extrusion_adapter(41.3, 10.0, 14.3, 10.0, 70.0, 48.0, 6.0)
    is Err(_),
  )
}

///|
test "extrusion to tube clamp has the ring, ears, base, and interfaces" {
  let part = match @stock.extrusion_to_tube_clamp(17.9324, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 4)
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(stock_close(z0, 0.0) && stock_close(z1, 20.0))
  // The 40 mm base spans X; the ears reach ro + 8 = 20.216 on +X.
  assert_true(stock_close(x0, -20.0))
  assert_true(stock_close(x1, 20.2162))
  // The ring top is ro = 12.2162; the base bottom is -17.7162.
  if !stock_close(y0, -17.7162) || !stock_close(y1, 12.2162) {
    fail("y bbox [\{y0}, \{y1}]; x [\{x0}, \{x1}]; z [\{z0}, \{z1}]")
  }
  let bore = adapter_connector(part, "tube-bore")
  match bore.diameter_mm {
    Some(d) => assert_true(stock_close(d, 18.4324))
    None => fail("tube bore should carry the tube OD plus clearance")
  }
  let bolt = adapter_connector(part, "clamp-bolt")
  assert_true(stock_close(bolt.placement.trans.0, 16.2162))
  assert_true(bolt.kind is @common.MateKind::CylindricalBore)
  let hole = adapter_connector(part, "mounting-hole-1")
  assert_true(stock_close(hole.placement.trans.0, -12.5))
  let base = adapter_connector(part, "base-face")
  assert_true(stock_close(base.placement.trans.1, -17.7162))
  assert_true(base.kind is @common.MateKind::PlaneFace)
  assert_true(part.features().modeled.contains("clamp-ears"))
  assert_true(part.features().approximated.length() > 0)
}

///|
test "extrusion to tube clamp rejects impossible geometry" {
  // Gap wider than the tube bore.
  assert_true(
    @stock.extrusion_to_tube_clamp(17.9324, 20.0, gap_mm=20.0) is Err(_),
  )
  // Base embed thicker than the ring wall.
  assert_true(
    @stock.extrusion_to_tube_clamp(17.9324, 20.0, embed_mm=3.0) is Err(_),
  )
  // Base too narrow for the T-nut holes.
  assert_true(
    @stock.extrusion_to_tube_clamp(17.9324, 20.0, base_width_mm=20.0) is Err(_),
  )
  // Cross bolt larger than the ears.
  assert_true(
    @stock.extrusion_to_tube_clamp(17.9324, 20.0, clamp_bolt_diameter_mm=10.0)
    is Err(_),
  )
  // Zero length.
  assert_true(@stock.extrusion_to_tube_clamp(17.9324, 0.0) is Err(_))
}
