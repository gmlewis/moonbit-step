///|
/// The goBILDA® build system is metric and pattern based: 4 mm through holes on
/// an 8 mm grid, with 14 mm bearing holes spaced every 24 mm down most
/// structural parts. These named constants keep the pattern in one place.
///
/// Source: https://www.gobilda.com/pattern (4 mm holes on an 8 mm grid; 14 mm
/// bearing holes every 24 mm; 45-degree "clocked" slots; M4 hardware).
pub let gobilda_hole_diameter_mm : Double = 4.0

///|
/// The goBILDA grid pitch, in millimetres.
pub let gobilda_grid_mm : Double = 8.0

///|
/// The goBILDA bearing-hole diameter, in millimetres.
pub let gobilda_bearing_hole_mm : Double = 14.0

///|
/// The goBILDA bearing-hole pitch (down most structural parts), in millimetres.
pub let gobilda_bearing_pitch_mm : Double = 24.0

///|
/// The goBILDA aluminium sheet thickness, in millimetres.
pub let gobilda_sheet_thickness_mm : Double = 2.5

///|
/// gobilda_grid_positions returns `count` hole centres centred on zero at the
/// goBILDA 8 mm grid pitch.
///
/// A plate with `count` holes along an axis spans `count * 8` mm with one
/// half-pitch (4 mm) margin at each end, matching the goBILDA naming (a 5-hole
/// plate is 40 mm wide, an 11-hole plate 88 mm).
pub fn gobilda_grid_positions(count : Int32) -> Array[Double] {
  let mid = (count - 1).to_double() / 2.0
  let out : Array[Double] = []
  for i in 0..<count {
    out.push((i.to_double() - mid) * gobilda_grid_mm)
  }
  out
}
