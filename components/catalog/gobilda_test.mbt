///|
test "goBILDA catalogue has the grid-plate bundle sizes" {
  let entries = @catalog.gobilda_catalog()
  assert_eq(entries.length(), 9)
  for entry in entries {
    assert_true(entry.provenance.contains("gobilda.com"))
    assert_true(entry.supported_parameters.any(fn(p) { p == "cols" }))
  }
  let plate = match
    @catalog.lookup(entries, "goBILDA Grid Plate 5x5 (40 x 40 x 2.5)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(plate.family == "goBILDA grid plate")
  assert_true(plate.features.has_modeled("through-holes"))
}
