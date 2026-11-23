///|
test "hex extrusion T-nut covers M6 and M8 for 40-series slots" {
  let m6 = ok_spec(@fasteners.extrusion_tnut_spec("M6"))
  assert_true((m6.across_flats_mm - 10.0).abs() < 1.0e-6)
  assert_true((m6.thickness_mm - 5.0).abs() < 1.0e-6)
  let m8 = ok_spec(@fasteners.extrusion_tnut_spec("M8", slot_width_mm=5.0))
  assert_true((m8.across_flats_mm - 13.0).abs() < 1.0e-6)
  assert_true((m8.thickness_mm - 6.5).abs() < 1.0e-6)
  assert_true(@fasteners.extrusion_tnut_spec("M7") is Err(_))
}

///|
test "Maker Store 40-series sliding T-nut block envelope" {
  let part = ok_fastener(@fasteners.makerstore_sliding_tnut("M5"))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 10.0).abs() < 1.0e-6)
  assert_true((x1 - 10.0).abs() < 1.0e-6)
  assert_true((y0 + 9.55).abs() < 1.0e-6)
  assert_true((y1 - 9.55).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 9.1).abs() < 1.0e-6)
  for name in ["thread", "slot-engagement", "bearing-face"] {
    let mut found = false
    for connector in part.connectors() {
      if connector.name == name {
        found = true
      }
    }
    assert_true(found)
  }
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = (20.0 * 19.1 - @math.PI * 2.5 * 2.5) * 9.1
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
  assert_true(@fasteners.makerstore_sliding_tnut("M3") is Err(_))
}

///|
test "Maker Store T-nut families expose thread presets" {
  let hex = ok_spec(@fasteners.makerstore_hex_tnut_family())
  for name in ["m3", "m4", "m5"] {
    assert_true(hex.variant_names().contains(name))
  }
  let hex_m3 = ok_fastener(hex.build_variant("m3"))
  assert_true(hex_m3.metadata().size == "M3")
  let slider = ok_spec(@fasteners.makerstore_slider_tnut_family())
  for name in ["m4", "m5", "m6", "m8"] {
    assert_true(slider.variant_names().contains(name))
  }
  let _ = ok_fastener(slider.build_variant("m8"))
  assert_true(hex.build_values([("thread", 3.5)]) is Err(_))
}
