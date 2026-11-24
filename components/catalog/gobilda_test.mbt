///|
test "goBILDA catalogue has grid plates and U-channels" {
  let entries = @catalog.gobilda_catalog()
  // 9 grid-plate bundle sizes + 4 U-channel lengths + 4 square-beam lengths.
  assert_eq(entries.length(), 17)
  for entry in entries {
    assert_true(entry.provenance.contains("gobilda.com"))
  }
  let plate = match
    @catalog.lookup(entries, "goBILDA Grid Plate 5x5 (40 x 40 x 2.5)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(plate.family == "goBILDA grid plate")
  assert_true(plate.features.has_modeled("through-holes"))
  assert_true(plate.supported_parameters.any(fn(p) { p == "cols" }))
  let channel = match
    @catalog.lookup(entries, "goBILDA U-channel 8 hole (216 mm)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(channel.family == "goBILDA U-channel")
  assert_true(channel.features.has_modeled("14mm-bearing-holes"))
  assert_true(channel.supported_parameters.any(fn(p) { p == "holes" }))
  let beam = match
    @catalog.lookup(entries, "goBILDA square beam 4 hole (32 mm)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(beam.family == "goBILDA square beam")
  assert_true(beam.features.has_modeled("crossing-x-holes"))
}
