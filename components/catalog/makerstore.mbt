///|
/// makerstore_catalog returns catalogue entries for the Maker Store USA parts
/// that are reconstructed in this library, each built from the real component
/// so its provenance and feature record cannot drift.
///
/// Covered families: the `PLATE-40X40L` / `PLATE-40X80L` L plates (calibrated to
/// the published drawing), the `SHIM-SPAC` metric aluminum spacers, the
/// 20-series `HARD-TNUT-SLIDING` hex T-nuts, the 40-series
/// `HARD-40S-TNUT-STEEL-SLID-18` sliding blocks, the gusseted V-Slot corner
/// brackets, and the `BEAR-F` thrust bearings.
pub fn makerstore_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let l_plate_params = [
    "leg_a", "leg_b", "width", "thickness", "hole_diameter", "pitch",
  ]
  match
    @mechanisms.makerstore_l_plate(
      leg_a_mm=40.0,
      leg_b_mm=40.0,
      width_mm=40.0,
      thickness_mm=3.0,
      hole_diameter_mm=5.0,
      pitch_mm=10.0,
    ) {
    Ok(c) => entries.push(entry_from_component(c, l_plate_params, ["Detailed"]))
    Err(_) => ()
  }
  match
    @mechanisms.makerstore_l_plate(
      leg_a_mm=80.0,
      leg_b_mm=40.0,
      width_mm=40.0,
      thickness_mm=3.0,
      hole_diameter_mm=5.0,
      pitch_mm=10.0,
    ) {
    Ok(c) => entries.push(entry_from_component(c, l_plate_params, ["Detailed"]))
    Err(_) => ()
  }
  let spacer_params = ["outer", "inner", "length"]
  for length in [3.0, 6.0, 6.5, 9.0, 10.0, 20.0, 30.0, 35.0, 40.0] {
    match @motion.makerstore_aluminum_spacer(length_mm=length) {
      Ok(c) =>
        entries.push(entry_from_component(c, spacer_params, ["Detailed"]))
      Err(_) => ()
    }
  }
  let tnut_params = ["thread", "slot_width", "thickness", "across_flats"]
  for thread in ["M3", "M4", "M5"] {
    match @fasteners.makerstore_hex_tnut(thread) {
      Ok(c) => entries.push(entry_from_component(c, tnut_params, ["Detailed"]))
      Err(_) => ()
    }
  }
  let slider_params = ["thread", "slot_width", "thickness", "length"]
  for thread in ["M4", "M5", "M6", "M8"] {
    match @fasteners.makerstore_sliding_tnut(thread) {
      Ok(c) =>
        entries.push(entry_from_component(c, slider_params, ["Detailed"]))
      Err(_) => ()
    }
  }
  let bracket_params = [
    "leg", "width", "thickness", "gusset", "slot_width", "slot_length", "slot_shift",
  ]
  match @profiles.makerstore_corner_bracket(leg_mm=20.0) {
    Ok(c) => entries.push(entry_from_component(c, bracket_params, ["Detailed"]))
    Err(_) => ()
  }
  match @profiles.makerstore_corner_bracket(leg_mm=40.0) {
    Ok(c) => entries.push(entry_from_component(c, bracket_params, ["Detailed"]))
    Err(_) => ()
  }
  let thrust_params = ["designation", "bore", "outer_diameter", "height"]
  for designation in @motion.thrust_bearing_designations() {
    match @motion.thrust_bearing_size(designation) {
      Ok(size) =>
        match @motion.thrust_bearing(size) {
          Ok(c) =>
            entries.push(entry_from_component(c, thrust_params, ["Detailed"]))
          Err(_) => ()
        }
      Err(_) => ()
    }
  }
  entries
}
