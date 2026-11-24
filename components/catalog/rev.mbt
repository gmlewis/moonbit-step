///|
/// rev_catalog returns catalogue entries for the REV DUO 15 mm extrusions and
/// 45 mm U-channels, built from the real components.
pub fn rev_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for length in [120.0, 225.0, 420.0, 1000.0] {
    match @profiles.rev_15mm_extrusion(length_mm=length) {
      Ok(c) => entries.push(entry_from_component(c, ["length"], ["Detailed"]))
      Err(_) => ()
    }
  }
  for
    length in [
      24.0, 56.0, 88.0, 152.0, 248.0, 312.0, 376.0, 408.0, 440.0, 1000.0,
    ] {
    match @profiles.rev_45mm_uchannel(length_mm=length) {
      Ok(c) => entries.push(entry_from_component(c, ["length"], ["Detailed"]))
      Err(_) => ()
    }
  }
  entries
}
