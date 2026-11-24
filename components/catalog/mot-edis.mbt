///|
/// mot_edis_catalog returns catalogue entries for the MotEDis I-type metric
/// T-slot extrusions (20/30/40) and the slot-8 T-nut, built from the real
/// components.
pub fn mot_edis_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for length in [100.0, 250.0, 500.0, 1000.0, 1500.0, 1980.0] {
    match @profiles.mot_edis_profile(length_mm=length) {
      Ok(c) => entries.push(entry_from_component(c, ["length"], ["Detailed"]))
      Err(_) => ()
    }
  }
  for series in ["20", "30"] {
    match @profiles.mot_edis_section(series) {
      Ok(section) =>
        match @profiles.mot_edis_profile_of(section, length_mm=500.0) {
          Ok(c) =>
            entries.push(entry_from_component(c, ["length"], ["Detailed"]))
          Err(_) => ()
        }
      Err(_) => ()
    }
  }
  match @profiles.mot_edis_section("40") {
    Ok(section) =>
      match @profiles.mot_edis_tnut(section, thread="M5") {
        Ok(c) =>
          entries.push(
            entry_from_component(c, ["thread", "length_mm"], ["Detailed"]),
          )
        Err(_) => ()
      }
    Err(_) => ()
  }
  entries
}
