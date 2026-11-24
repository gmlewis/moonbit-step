///|
/// gobilda_catalog returns catalogue entries for the goBILDA grid plates,
/// built from the real component so provenance and feature records cannot drift.
///
/// The sizes match the goBILDA 1116 Series Grid Plate Bundle (3x5 through
/// 11x29); a plate named `cols x rows` is `cols * 8` by `rows * 8` mm.
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
  entries
}
