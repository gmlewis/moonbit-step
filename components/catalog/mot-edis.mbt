///|
/// mot_edis_catalog returns catalogue entries for the MotEDis 40 x 40 I-type
/// slot-8 metric T-slot extrusion lengths, built from the real component.
pub fn mot_edis_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for length in [100.0, 250.0, 500.0, 1000.0, 1500.0, 1980.0] {
    match @profiles.mot_edis_profile(length_mm=length) {
      Ok(c) => entries.push(entry_from_component(c, ["length"], ["Detailed"]))
      Err(_) => ()
    }
  }
  entries
}
