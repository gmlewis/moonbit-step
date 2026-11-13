///|
/// DIN7349Size carries the DIN 7349 thick flat-washer dimensions for one
/// nominal size: inner diameter `d1`, outer diameter `d2`, and thickness `s`.
///
/// DIN 7349 is the heavy-pattern thick washer; the inner diameters clear the
/// DIN 1481 clamping-sleeve sizes.
pub(all) struct DIN7349Size {
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  thickness_mm : Double
}

///|
/// din7349_size returns the DIN 7349 thick-washer dimensions for one size.
pub fn din7349_size(
  size : MetricSize,
) -> Result[DIN7349Size, @common.SpecError] {
  let dims = match size {
    M3 => (3.2, 9.0, 1.0)
    M4 => (4.3, 12.0, 1.6)
    M5 => (5.3, 15.0, 2.0)
    M6 => (6.4, 17.0, 3.0)
    M8 => (8.4, 21.0, 4.0)
    M10 => (10.5, 25.0, 4.0)
    M12 => (13.0, 30.0, 6.0)
    M16 => (17.0, 40.0, 6.0)
    M20 => (21.0, 44.0, 8.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "DIN 7349 does not carry size " + size.designation(),
        ),
      )
  }
  let (d1, d2, s) = dims
  Ok({ size, inner_diameter_mm: d1, outer_diameter_mm: d2, thickness_mm: s, })
}

///|
/// DIN7349Spec is a validated DIN 7349 thick-washer specification.
pub(all) struct DIN7349Spec {
  size_dims : DIN7349Size
}

///|
/// din7349_spec validates a metric size for DIN 7349 thick washers.
pub fn din7349_spec(
  size : MetricSize,
) -> Result[DIN7349Spec, @common.SpecError] {
  match din7349_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// DIN7349Spec::size returns the nominal size.
pub fn DIN7349Spec::size(self : DIN7349Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN7349Spec::designation returns the standard part designation.
pub fn DIN7349Spec::designation(self : DIN7349Spec) -> String {
  "DIN 7349 - \{self.size_dims.size.designation()}"
}

///|
/// DIN7349Spec::standard returns the exact standard used.
pub fn DIN7349Spec::standard() -> String {
  "DIN 7349"
}

///|
/// DIN7349Spec::source returns the dimensional provenance note.
pub fn DIN7349Spec::source() -> String {
  "DIN 7349 thick flat washer, heavy pattern; d1, d2, and s from the DIN 7349 table"
}

///|
/// DIN7349Spec::metadata builds component metadata for this specification.
pub fn DIN7349Spec::metadata(self : DIN7349Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN7349Spec::standard(),
    family="thick flat washer, heavy pattern",
    size=self.size_dims.size.designation(),
    source=DIN7349Spec::source(),
  )
}
