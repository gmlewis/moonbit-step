///|
/// DIN471Size carries the DIN 471 type A external retaining-ring dimensions
/// for one nominal shaft diameter.
///
/// The table is the standard's normal-type A series. Values are millimetres:
///
/// - `shaft_diameter_mm` (d1): nominal shaft size
/// - `thickness_mm` (s): axial ring thickness
/// - `free_inner_diameter_mm` (d3): unstressed inside diameter
/// - `lug_width_mm` (a): maximum radial width of the eye
/// - `ring_width_mm` (b): radial width opposite the opening
/// - `lug_hole_mm` (d5): plier-hole diameter
/// - `groove_diameter_mm` (d2), `groove_width_mm` (m), `groove_depth_mm` (t),
///   `edge_margin_mm` (n): shaft-groove interface
///
/// The table is cross-checked between the Xem Studio DIN 471 dimension sheet
/// (CC BY 4.0) and an independent DIN 471 type A datasheet. Manufacturer
/// choice affects d5 in some sizes; the values here are the common series.
pub(all) struct DIN471Size {
  shaft_diameter_mm : Double
  thickness_mm : Double
  free_inner_diameter_mm : Double
  lug_width_mm : Double
  ring_width_mm : Double
  lug_hole_mm : Double
  groove_diameter_mm : Double
  groove_width_mm : Double
  groove_depth_mm : Double
  edge_margin_mm : Double
}

///|
/// din471_row returns the raw DIN 471 type A row for one shaft diameter:
/// `(s, d3, a, b, d5, d2, m, t, n)`.
fn din471_row(shaft_mm : Double) -> Array[Double]? {
  let rows : Array[(Double, Array[Double])] = [
    (10.0, [1.0, 9.3, 3.3, 1.8, 1.5, 9.6, 1.1, 0.2, 0.6]),
    (12.0, [1.0, 11.0, 3.3, 1.8, 1.7, 11.5, 1.1, 0.25, 0.8]),
    (14.0, [1.0, 12.9, 3.5, 2.1, 1.7, 13.4, 1.1, 0.3, 0.9]),
    (16.0, [1.0, 14.7, 3.7, 2.2, 1.7, 15.2, 1.1, 0.4, 1.2]),
    (18.0, [1.2, 16.5, 3.9, 2.4, 2.0, 17.0, 1.3, 0.5, 1.5]),
    (20.0, [1.2, 18.5, 4.0, 2.6, 2.0, 19.0, 1.3, 0.5, 1.5]),
    (22.0, [1.2, 20.5, 4.2, 2.8, 2.0, 21.0, 1.3, 0.5, 1.5]),
    (24.0, [1.2, 22.2, 4.4, 3.0, 2.0, 22.9, 1.3, 0.55, 1.7]),
    (26.0, [1.2, 24.2, 4.5, 3.1, 2.0, 24.9, 1.3, 0.55, 1.7]),
    (28.0, [1.5, 25.9, 4.7, 3.2, 2.0, 26.6, 1.6, 0.7, 2.1]),
    (30.0, [1.5, 27.9, 5.0, 3.5, 2.0, 28.6, 1.6, 0.7, 2.1]),
    (32.0, [1.5, 29.6, 5.2, 3.6, 2.5, 30.3, 1.6, 0.85, 2.6]),
    (34.0, [1.5, 31.5, 5.4, 3.8, 2.5, 32.3, 1.6, 0.85, 2.6]),
  ]
  for row in rows {
    let (size, values) = row
    if (size - shaft_mm).abs() < 1.0e-9 {
      return Some(values)
    }
  }
  None
}

///|
/// din471_size returns the DIN 471 type A dimensions for a nominal shaft
/// diameter in millimetres.
pub fn din471_size(shaft_mm : Double) -> Result[DIN471Size, @common.SpecError] {
  match din471_row(shaft_mm) {
    None =>
      Err(
        @common.SpecError::InvalidSize(
          "DIN 471 type A does not carry a \{shaft_mm} mm shaft in this table (10 to 34 mm even sizes)",
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
        shaft_diameter_mm: shaft_mm,
        thickness_mm: s,
        free_inner_diameter_mm: d3,
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
/// DIN471Size::designation returns the standard part designation.
pub fn DIN471Size::designation(self : DIN471Size) -> String {
  "DIN 471 - A \{self.shaft_diameter_mm.to_string()}"
}

///|
/// DIN471Size::standard returns the exact standard used.
pub fn DIN471Size::standard() -> String {
  "DIN 471 type A (external, for shafts)"
}

///|
/// DIN471Size::source returns the dimensional provenance note.
pub fn DIN471Size::source() -> String {
  "DIN 471 type A normal series; cross-checked between the Xem Studio DIN 471 dimension sheet (CC BY 4.0) and an independent DIN 471 type A datasheet."
}
