///|
test "Maker Store catalogue covers the delivered parts with provenance" {
  let entries = @catalog.makerstore_catalog()
  // 2 L plates + 9 spacers + 3 hex T-nuts + 4 sliding blocks + 2 brackets +
  // 4 thrust bearings.
  assert_eq(entries.length(), 24)
  for entry in entries {
    assert_true(entry.provenance.contains("makerstore.cc"))
    assert_true(entry.supported_parameters.length() > 0)
  }
  let plate = match
    @catalog.lookup(
      entries, "Maker Store 40x40 L Plate / Bracket (PLATE-40X40L)",
    ) {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(plate.provenance.contains("PLATE-40X40L"))
  assert_true(plate.features.has_modeled("through-bolt-holes"))
  assert_true(plate.supported_parameters.any(fn(p) { p == "pitch" }))
}

///|
test "full catalogue looks up a Maker Store part by designation" {
  let entries = @catalog.full_catalog()
  let spacer = match
    @catalog.lookup(
      entries, "Maker Store aluminum spacer OD 10 / ID 5 x 10 (SHIM-SPAC)",
    ) {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(spacer.family == "Maker Store aluminum spacer")
  assert_true(spacer.provenance.contains("SHIM-SPAC"))
}
