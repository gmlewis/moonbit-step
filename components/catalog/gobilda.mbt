///|
/// gobilda_catalog returns catalogue entries for the goBILDA grid plates,
/// 1120-series U-channels, and 1106-series square beams, built from the real
/// components so provenance and feature records cannot drift.
///
/// The plate sizes match the goBILDA 1116 Series Grid Plate Bundle (3x5 through
/// 11x29); a plate named `cols x rows` is `cols * 8` by `rows * 8` mm. A channel's
/// length is `(holes + 1) * 24` mm.
pub fn gobilda_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let parameters = ["cols", "rows", "thickness"]
  let sizes : Array[(Int32, Int32)] = [
    (3, 5),
    (5, 5),
    (5, 7),
    (5, 9),
    (5, 11),
    (5, 17),
    (7, 7),
    (7, 11),
    (11, 29),
  ]
  for entry in sizes {
    let (cols, rows) = entry
    match @gobilda.gobilda_grid_plate(cols~, rows~) {
      Ok(c) => entries.push(entry_from_component(c, parameters, ["Detailed"]))
      Err(_) => ()
    }
  }
  let channel_parameters = ["holes", "thickness"]
  let channel_holes : Array[Int32] = [1, 4, 8, 13]
  for holes in channel_holes {
    match @gobilda.gobilda_u_channel(holes~) {
      Ok(c) =>
        entries.push(entry_from_component(c, channel_parameters, ["Detailed"]))
      Err(_) => ()
    }
  }
  let beam_parameters = ["holes"]
  let beam_holes : Array[Int32] = [2, 4, 8, 16]
  for holes in beam_holes {
    match @gobilda.gobilda_square_beam(holes~) {
      Ok(c) =>
        entries.push(entry_from_component(c, beam_parameters, ["Detailed"]))
      Err(_) => ()
    }
  }
  entries
}
