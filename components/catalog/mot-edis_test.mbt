///|
test "MotEDis catalogue has profiles and a T-nut" {
  let entries = @catalog.mot_edis_catalog()
  // 6 forty-series lengths + one 20 + one 30 + one slot-8 T-nut.
  assert_eq(entries.length(), 9)
  let p20 = match
    @catalog.lookup(entries, "MotEDis 20x20 I-type slot 5 (500 mm)") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(p20.family == "metric T-slot extrusion")
  assert_true(p20.provenance.contains("motedis.com"))
  let tnut = match @catalog.lookup(entries, "MotEDis T-nut I-type slot 8 M5") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(tnut.family == "metric T-slot T-nut")
  assert_true(tnut.features.has_modeled("tap-drill-bore"))
}
