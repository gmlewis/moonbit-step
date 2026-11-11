///|
/// DIN127Size carries the DIN 127 B spring-washer dimensions for one nominal
/// size: inner diameter `d1`, outer diameter `d2`, the DIN side length `b`,
/// section thickness `s`, and the reference free height `h`.
///
/// `free_height_mm` is the DIN 127 B lower limit (h min); it fixes the helix
/// pitch of the split ring. The modeled goldens are at d1 = nominal + 0.1
/// (M4..M8; the fasteners.eu table lists 6.4 for M6, but the downloaded M6
/// reference and common tables use 6.1) and d2 = table maximum. See
/// `components/DATA_SOURCES.md`.
pub(all) struct DIN127Size {
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  /// DIN 127 side length `b` (informational; the radial section width is
  /// `(d2 - d1) / 2`).
  side_width_mm : Double
  thickness_mm : Double
  free_height_mm : Double
}

///|
/// din127_size returns the DIN 127 B spring-washer dimensions for one size.
pub fn din127_size(size : MetricSize) -> Result[DIN127Size, @common.SpecError] {
  // (d1 reference, d2 max, b, s, h min)
  let dims = match size {
    M2 => (2.1, 4.4, 0.9, 0.5, 1.0)
    M2_5 => (2.6, 5.1, 1.0, 0.6, 1.2)
    M3 => (3.1, 6.2, 1.3, 0.8, 1.6)
    M4 => (4.1, 7.6, 1.5, 0.9, 1.8)
    M5 => (5.1, 9.2, 1.8, 1.2, 2.4)
    // 6.1 is the downloaded DIN 127 B M6 reference diameter; the fasteners.eu
    // table prints 6.4 as its minimum, while other tables list 6.1.
    M6 => (6.1, 11.8, 2.5, 1.6, 3.2)
    M8 => (8.1, 14.8, 3.0, 2.0, 4.0)
    M10 => (10.2, 18.1, 3.5, 2.2, 4.4)
    M12 => (12.2, 21.1, 4.0, 2.5, 5.0)
    M16 => (16.2, 27.4, 5.0, 3.5, 7.0)
    M20 => (20.2, 33.6, 6.0, 4.0, 8.0)
  }
  let (d1, d2, b, s, h) = dims
  Ok({
    size,
    inner_diameter_mm: d1,
    outer_diameter_mm: d2,
    side_width_mm: b,
    thickness_mm: s,
    free_height_mm: h,
  })
}

///|
/// DIN127Spec is a validated DIN 127 B spring-washer specification.
pub(all) struct DIN127Spec {
  size_dims : DIN127Size
}

///|
/// din127_spec validates a metric size for DIN 127 B spring washers.
pub fn din127_spec(size : MetricSize) -> Result[DIN127Spec, @common.SpecError] {
  match din127_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// DIN127Spec::size returns the nominal size.
pub fn DIN127Spec::size(self : DIN127Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN127Spec::designation returns the standard part designation.
pub fn DIN127Spec::designation(self : DIN127Spec) -> String {
  "DIN 127 B - \{self.size_dims.size.designation()}"
}

///|
/// DIN127Spec::standard returns the exact standard used.
pub fn DIN127Spec::standard() -> String {
  "DIN 127 B"
}

///|
/// DIN127Spec::source returns the dimensional provenance note.
pub fn DIN127Spec::source() -> String {
  "DIN 127 B spring washer; d1/d2/s and h_min transcribed from the DIN 127 B table, see components/DATA_SOURCES.md"
}

///|
/// DIN127Spec::metadata builds component metadata for this specification.
pub fn DIN127Spec::metadata(self : DIN127Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN127Spec::standard(),
    family="spring washer, form B",
    size=self.size_dims.size.designation(),
    source=DIN127Spec::source(),
  )
}
