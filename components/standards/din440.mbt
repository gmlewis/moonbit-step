///|
/// DIN440Size carries the DIN 440 V large-washer dimensions for one nominal
/// size: outer diameter `d2`, square-hole side `a`, and thickness `s`.
///
/// DIN 440 R has a round hole; DIN 440 V has the square hole modeled here.
/// The downloaded references are the square-hole V form. See
/// `components/DATA_SOURCES.md`.
pub(all) struct DIN440Size {
  size : MetricSize
  outer_diameter_mm : Double
  square_side_mm : Double
  thickness_mm : Double
}

///|
/// din440_size returns the DIN 440 V dimensions for one size.
pub fn din440_size(size : MetricSize) -> Result[DIN440Size, @common.SpecError] {
  let dims = match size {
    M5 => (18.0, 5.5, 2.0)
    M6 => (22.0, 6.6, 2.0)
    M8 => (28.0, 9.0, 3.0)
    M10 => (34.0, 11.0, 3.0)
    M12 => (44.0, 13.5, 4.0)
    M16 => (56.0, 17.5, 5.0)
    M20 => (72.0, 22.0, 6.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "DIN 440 V does not carry size " + size.designation(),
        ),
      )
  }
  let (d2, a, s) = dims
  Ok({ size, outer_diameter_mm: d2, square_side_mm: a, thickness_mm: s, })
}

///|
/// DIN440Spec is a validated DIN 440 V large-washer specification.
pub(all) struct DIN440Spec {
  size_dims : DIN440Size
}

///|
/// din440_spec validates a metric size for DIN 440 V large washers.
pub fn din440_spec(size : MetricSize) -> Result[DIN440Spec, @common.SpecError] {
  match din440_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// DIN440Spec::size returns the nominal size.
pub fn DIN440Spec::size(self : DIN440Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN440Spec::designation returns the standard part designation.
pub fn DIN440Spec::designation(self : DIN440Spec) -> String {
  "DIN 440 V - \{self.size_dims.size.designation()}"
}

///|
/// DIN440Spec::standard returns the exact standard used.
pub fn DIN440Spec::standard() -> String {
  "DIN 440 V"
}

///|
/// DIN440Spec::source returns the dimensional provenance note.
pub fn DIN440Spec::source() -> String {
  "DIN 440 V large washer with square hole; d2, square side a, and thickness s from the DIN 440 V table, see components/DATA_SOURCES.md"
}

///|
/// DIN440Spec::metadata builds component metadata for this specification.
pub fn DIN440Spec::metadata(self : DIN440Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN440Spec::standard(),
    family="large washer, square hole (timber construction)",
    size=self.size_dims.size.designation(),
    source=DIN440Spec::source(),
  )
}
