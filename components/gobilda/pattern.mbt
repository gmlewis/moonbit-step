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
/// The goBILDA U-channel outside width and height, in millimetres.
pub let gobilda_channel_width_mm : Double = 48.0

///|
pub let gobilda_channel_height_mm : Double = 48.0

///|
/// sqrt(2), named so the measured 45-degree pattern offsets stay exact.
pub let gobilda_sqrt2 : Double = 2.0.sqrt()

///|
/// The measured 45-degree "clocked" hole offset from a station, in millimetres
/// (6*sqrt(2), i.e. a 12 mm diagonal).
pub let gobilda_diagonal_offset_mm : Double = 6.0 * gobilda_sqrt2

///|
/// The measured inner cap centre of a long station slot, in millimetres from
/// the centre line (8*sqrt(2)).
pub let gobilda_slot_inner_offset_mm : Double = 8.0 * gobilda_sqrt2

///|
/// The measured half-distance between the cap centres of a short centre slot,
/// in millimetres (12 - 8*sqrt(2), measured from the vendor STEP).
pub let gobilda_slot_cap_offset_mm : Double = 12.0 -
  gobilda_slot_inner_offset_mm

///|
/// Tolerance used when matching a grid row to a 24 mm bearing station.
let gobilda_station_eps : Double = 1.0e-9

///|
/// The tap drill that precedes an M4 x 0.7 thread, in millimetres.
pub let gobilda_m4_tap_drill_mm : Double = 3.3

///|
/// The published depth of the M4 x 0.7 end taps in structural parts, in
/// millimetres.
pub let gobilda_end_tap_depth_mm : Double = 10.0

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
