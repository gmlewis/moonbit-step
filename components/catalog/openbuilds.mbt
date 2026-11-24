///|
/// openbuilds_catalog returns catalogue entries for the OpenBuilds parts
/// reconstructed in this library (the C-Beam gantry plate, SKU 970).
pub fn openbuilds_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  match @profiles.openbuilds_cbeam_gantry_plate() {
    Ok(c) =>
      entries.push(
        entry_from_component(c, ["size", "thickness", "hole"], ["Detailed"]),
      )
    Err(_) => ()
  }
  entries
}
