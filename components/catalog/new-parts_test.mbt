///|
test "Hiwin catalogue resolutions" {
  let entries = @catalog.hiwin_catalog()
  // 2 rail sizes x 7 lengths + 2 carriage sizes.
  assert_eq(entries.length(), 16)
  let rail = match
    @catalog.lookup(entries, "Hiwin HGR15 linear guideway rail (400 mm)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(rail.family == "Hiwin HGR rail")
  assert_true(rail.supported_parameters.any(fn(p) { p == "length" }))
  let block = match
    @catalog.lookup(entries, "Hiwin HGH20CA linear guideway carriage") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(block.family == "Hiwin HGH carriage")
  for entry in entries {
    assert_true(entry.provenance.contains("hiwin.com"))
  }
}

///|
test "MotEDis B-type and low-profile screw catalogue resolutions" {
  let b_entries = @catalog.mot_edis_b_catalog()
  assert_eq(b_entries.length(), 15)
  let profile = match
    @catalog.lookup(b_entries, "MotEDis B-type 40x40 profile (500 mm)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(profile.family == "MotEDis B-type profile")
  let mut found : @catalog.CatalogEntry? = None
  for entry in @catalog.fastener_catalog() {
    if entry.family == "Maker Store M5 low-profile screw" {
      found = Some(entry)
    }
  }
  let screw = match found {
    Some(e) => e
    None => abort("no Maker Store low-profile screw in the fastener catalogue")
  }
  assert_true(screw.supported_parameters.any(fn(p) { p == "length" }))
}
