///|
/// DIN472Size carries the DIN 472 internal retaining-ring dimensions for one
/// nominal bore diameter.
///
/// Values are millimetres:
///
/// - `bore_diameter_mm` (d1): nominal bore size the ring seats in
/// - `thickness_mm` (s): axial ring thickness
/// - `free_outer_diameter_mm` (d3): unstressed outside diameter
/// - `lug_width_mm` (a): maximum radial width of the eye
/// - `ring_width_mm` (b): radial width opposite the opening
/// - `lug_hole_mm` (d5): plier-hole diameter
/// - `groove_diameter_mm` (d2), `groove_width_mm` (m), `groove_depth_mm` (t),
///   `edge_margin_mm` (n): bore-groove interface
///
/// The table is the DIN 472 normal series. It is cross-checked between the
/// Aspen Fasteners DIN 472 dimension sheet (primary), the Stpektas DIN 472
/// table (independent cross-check for d1 = 8 to 19), and the Xem Studio
/// DIN 472 dimension sheet (CC BY 4.0). Source roundings differ by one
/// hundredth of a millimetre in a few cells (for example s and m for
/// d1 = 40); the Aspen values are used and the difference is immaterial to the
/// groove fit.
///
/// The free-state outline between the back and the lugs is not dimensioned by
/// DIN 472. `@fasteners.din472_ring` uses a licensed measured outline where one
/// exists and otherwise derives the outline parametrically from the table
/// dimensions, so every row here builds.
pub(all) struct DIN472Size {
  bore_diameter_mm : Double
  thickness_mm : Double
  free_outer_diameter_mm : Double
  lug_width_mm : Double
  ring_width_mm : Double
  lug_hole_mm : Double
  groove_diameter_mm : Double
  groove_width_mm : Double
  groove_depth_mm : Double
  edge_margin_mm : Double
}

///|
/// din472_row returns the raw DIN 472 row for one bore diameter:
/// `(s, d3, a, b, d5, d2, m, t, n)`.
fn din472_row(bore_mm : Double) -> Array[Double]? {
  let rows : Array[(Double, Array[Double])] = [
    (8.0, [0.8, 8.7, 2.4, 1.1, 1.0, 8.4, 0.9, 0.2, 0.6]),
    (10.0, [1.0, 10.8, 3.2, 1.4, 1.2, 10.4, 1.1, 0.2, 0.6]),
    (12.0, [1.0, 13.0, 3.4, 1.7, 1.5, 12.5, 1.1, 0.3, 0.8]),
    (14.0, [1.0, 15.1, 3.7, 1.9, 1.7, 14.6, 1.1, 0.3, 0.9]),
    (16.0, [1.0, 17.3, 3.8, 2.0, 1.7, 16.8, 1.1, 0.4, 1.2]),
    (18.0, [1.0, 19.5, 4.1, 2.2, 2.0, 19.0, 1.1, 0.5, 1.5]),
    (20.0, [1.0, 21.5, 4.2, 2.3, 2.0, 21.0, 1.1, 0.5, 1.5]),
    (22.0, [1.0, 23.5, 4.2, 2.5, 2.0, 23.0, 1.1, 0.5, 1.5]),
    (24.0, [1.2, 25.9, 4.4, 2.6, 2.0, 25.2, 1.3, 0.6, 1.8]),
    (26.0, [1.2, 27.9, 4.7, 2.8, 2.0, 27.2, 1.3, 0.6, 1.8]),
    (28.0, [1.2, 30.1, 4.8, 2.9, 2.0, 29.4, 1.3, 0.7, 2.1]),
    (30.0, [1.2, 32.1, 4.8, 3.0, 2.0, 31.4, 1.3, 0.7, 2.1]),
    (32.0, [1.2, 34.4, 5.4, 3.2, 2.5, 33.7, 1.3, 0.9, 2.6]),
    (34.0, [1.5, 36.5, 5.4, 3.3, 2.5, 35.7, 1.6, 0.9, 2.6]),
    (36.0, [1.5, 38.8, 5.4, 3.5, 2.5, 38.0, 1.6, 1.0, 3.0]),
    (38.0, [1.5, 40.8, 5.5, 3.7, 2.5, 40.0, 1.6, 1.0, 3.0]),
    (40.0, [1.8, 43.5, 5.8, 3.9, 2.5, 42.5, 1.9, 1.3, 3.8]),
  ]
  for row in rows {
    let (size, values) = row
    if (size - bore_mm).abs() < 1.0e-9 {
      return Some(values)
    }
  }
  None
}

///|
/// din472_size returns the DIN 472 dimensions for a nominal bore diameter in
/// millimetres.
pub fn din472_size(bore_mm : Double) -> Result[DIN472Size, @common.SpecError] {
  match din472_row(bore_mm) {
    None =>
      Err(
        @common.SpecError::InvalidSize(
          "DIN 472 does not carry a \{bore_mm} mm bore in this table (8 to 40 mm, even sizes)",
        ),
      )
    Some(values) => {
      let s = values[0]
      let d3 = values[1]
      let a = values[2]
      let b = values[3]
      let d5 = values[4]
      let d2 = values[5]
      let m = values[6]
      let t = values[7]
      let n = values[8]
      Ok({
        bore_diameter_mm: bore_mm,
        thickness_mm: s,
        free_outer_diameter_mm: d3,
        lug_width_mm: a,
        ring_width_mm: b,
        lug_hole_mm: d5,
        groove_diameter_mm: d2,
        groove_width_mm: m,
        groove_depth_mm: t,
        edge_margin_mm: n,
      })
    }
  }
}

///|
/// DIN472Size::designation returns the standard part designation.
pub fn DIN472Size::designation(self : DIN472Size) -> String {
  "DIN 472 - \{self.bore_diameter_mm.to_string()}"
}

///|
/// DIN472Size::standard returns the exact standard used.
pub fn DIN472Size::standard() -> String {
  "DIN 472 (internal, for bores)"
}

///|
/// DIN472Size::source returns the dimensional provenance note.
pub fn DIN472Size::source() -> String {
  "DIN 472 normal series; cross-checked between the Aspen Fasteners DIN 472 dimension sheet, the Stpektas DIN 472 table, and the Xem Studio DIN 472 dimension sheet (CC BY 4.0)."
}
