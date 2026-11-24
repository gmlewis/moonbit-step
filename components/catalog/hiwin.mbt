///|
/// hiwin_catalog returns catalogue entries for the Hiwin HGR rails and HGH
/// carriages, built from the real components so provenance cannot drift.
pub fn hiwin_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let rail_lengths = [160.0, 220.0, 340.0, 400.0, 460.0, 640.0, 1000.0]
  for size in ["HGR15", "HGR20"] {
    for length in rail_lengths {
      match @mechanisms.hiwin_hgr_rail(size~, length_mm=length) {
        Ok(c) => entries.push(entry_from_component(c, ["length"], ["Detailed"]))
        Err(_) => ()
      }
    }
  }
  for size in ["HGH15CA", "HGH20CA"] {
    match @mechanisms.hiwin_hgh_block(size~) {
      Ok(c) => entries.push(entry_from_component(c, [], ["Detailed"]))
      Err(_) => ()
    }
  }
  entries
}
