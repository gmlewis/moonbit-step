///|
/// makerpipe_entry_from builds a catalogue entry from a Maker Pipe component.
fn makerpipe_entry_from(
  component : @common.Component,
  parameters : Array[String],
) -> CatalogEntry {
  entry_from_component(component, parameters, [
    "Simplified", "Detailed", "FullyModeled",
  ])
}

///|
/// push_makerpipe_entry pushes the entry when the builder succeeds.
fn push_makerpipe_entry(
  entries : Array[CatalogEntry],
  result : Result[@common.Component, @common.SpecError],
  parameters : Array[String],
) -> Unit {
  match result {
    Ok(component) => entries.push(makerpipe_entry_from(component, parameters))
    Err(_) => ()
  }
}

///|
/// makerpipe_catalog returns the Maker Pipe-compatible structural connectors and
/// accessories.
pub fn makerpipe_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let structural = ["size", "part", "angle", "branches"]
  for size_name in @makerpipe.makerpipe_trade_sizes() {
    let size = match @makerpipe.makerpipe_size(size_name) {
      Ok(s) => s
      Err(_) => continue
    }
    push_makerpipe_entry(entries, @makerpipe.tee(size), structural)
    push_makerpipe_entry(entries, @makerpipe.elbow_45(size), structural)
    push_makerpipe_entry(entries, @makerpipe.elbow_90(size), structural)
    push_makerpipe_entry(entries, @makerpipe.elbow_135(size), structural)
    push_makerpipe_entry(entries, @makerpipe.straight_180(size), structural)
    push_makerpipe_entry(entries, @makerpipe.four_way(size), structural)
    push_makerpipe_entry(entries, @makerpipe.five_way(size), structural)
    push_makerpipe_entry(entries, @makerpipe.coupling(size), structural)
    push_makerpipe_entry(entries, @makerpipe.flange(size), structural)
    push_makerpipe_entry(
      entries,
      @makerpipe.adjustable_hinge(size, 30.0),
      structural,
    )
    push_makerpipe_entry(
      entries,
      @makerpipe.adjustable_180(size, 0.0, 45.0),
      structural,
    )
    push_makerpipe_entry(
      entries,
      @makerpipe.adjustable_flange(size, 30.0),
      structural,
    )
  }
  push_makerpipe_entry(entries, @makerpipe.top_rail_tee(), ["size", "part"])
  let accessory = ["trade"]
  for trade in ["1/2", "3/4", "1"] {
    push_makerpipe_entry(entries, @makerpipe.end_cap(trade), accessory)
    push_makerpipe_entry(entries, @makerpipe.rubber_foot(trade), accessory)
    push_makerpipe_entry(entries, @makerpipe.one_hole_strap(trade), accessory)
    push_makerpipe_entry(entries, @makerpipe.two_hole_strap(trade), accessory)
    push_makerpipe_entry(entries, @makerpipe.mounting_strap(trade), accessory)
    push_makerpipe_entry(entries, @makerpipe.cross_over_clamp(trade), accessory)
  }
  push_makerpipe_entry(entries, @makerpipe.adapter_shim("1/2", "3/4"), [
    "from", "to",
  ])
  push_makerpipe_entry(entries, @makerpipe.adapter_shim("3/4", "1"), [
    "from", "to",
  ])
  push_makerpipe_entry(entries, @makerpipe.pipe_tube_shim(25.0, 28.0), [
    "inner", "outer", "length",
  ])
  push_makerpipe_entry(entries, @makerpipe.threaded_insert("3/4", "1/4-20"), [
    "trade", "thread", "lip",
  ])
  push_makerpipe_entry(entries, @makerpipe.threaded_insert("1", "3/8-16"), [
    "trade", "thread", "lip",
  ])
  push_makerpipe_entry(entries, @makerpipe.telescoping_clamp(), [
    "outer", "inner",
  ])
  push_makerpipe_entry(entries, @makerpipe.barrel_hinge(), [
    "length", "diameter", "pin",
  ])
  entries
}
