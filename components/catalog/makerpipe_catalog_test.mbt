///|
test "Maker Pipe catalogue covers connectors and accessories" {
  let entries = @catalog.makerpipe_catalog()
  assert_true(entries.length() >= 40)
  let tee = match
    @catalog.lookup(entries, "Maker Pipe-compatible T connector 3/4 in EMT") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(tee.family.contains("Maker Pipe"))
  assert_true(tee.features.modeled.contains("run-sleeve"))
  assert_true(tee.provenance.contains("T drawing"))
  let shim = match
    @catalog.lookup(
      entries, "Maker Pipe-compatible adapter shim 3/4 in EMT to 1 in socket",
    ) {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(shim.family == "adapter shim")
  assert_true(shim.size == "3/4->1")
  assert_true(shim.features.modeled.contains("c-sleeve"))
  let strap = match
    @catalog.lookup(
      entries, "Maker Pipe-compatible two-hole EMT strap 3/4 in EMT",
    ) {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(strap.features.modeled.contains("two-mounting-holes"))
}

///|
test "Maker Pipe entries are part of the full catalogue" {
  let full = @catalog.full_catalog()
  let matches = @catalog.query(full, family="adapter shim")
  assert_true(matches.length() >= 2)
}
