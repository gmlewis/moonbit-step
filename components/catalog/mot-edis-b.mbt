///|
/// mot_edis_b_catalog returns catalogue entries for the measured MotEDis
/// B-type sections, built from the real components.
pub fn mot_edis_b_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for series in ["20", "30", "40"] {
    for length in [100.0, 250.0, 500.0, 1000.0, 1980.0] {
      match @profiles.mot_edis_b_profile_of(series, length_mm=length) {
        Ok(c) => entries.push(entry_from_component(c, ["length"], ["Detailed"]))
        Err(_) => ()
      }
    }
  }
  entries
}
