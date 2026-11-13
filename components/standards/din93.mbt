///|
/// DIN93Size carries the DIN 93 tab-washer dimensions for one nominal size:
/// inner diameter `d1`, outside diameter `d2`, tab width `b`, tab length `l`
/// (from the washer axis to the tab end), and thickness `s`.
///
/// The tab-to-washer transition is not in the basic table; the builder places
/// the transition center at `l / 2 + 2` mm and derives the tangent fillet
/// radius from that, matching the downloaded references.
pub(all) struct DIN93Size {
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  tab_width_mm : Double
  tab_length_mm : Double
  thickness_mm : Double
}

///|
/// din93_size returns the DIN 93 tab-washer dimensions for one size.
pub fn din93_size(size : MetricSize) -> Result[DIN93Size, @common.SpecError] {
  let dims = match size {
    M4 => (4.3, 14.0, 5.0, 14.0, 0.38)
    M5 => (5.3, 17.0, 6.0, 16.0, 0.5)
    M6 => (6.4, 19.0, 7.0, 18.0, 0.5)
    M8 => (8.4, 22.0, 8.0, 20.0, 0.75)
    M10 => (10.5, 26.0, 16.0, 22.0, 0.75)
    M12 => (13.0, 30.0, 12.0, 28.0, 1.0)
    M16 => (17.0, 36.0, 15.0, 32.0, 1.0)
    M20 => (21.0, 42.0, 18.0, 36.0, 1.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "DIN 93 does not carry size " + size.designation(),
        ),
      )
  }
  let (d1, d2, b, l, s) = dims
  Ok({
    size,
    inner_diameter_mm: d1,
    outer_diameter_mm: d2,
    tab_width_mm: b,
    tab_length_mm: l,
    thickness_mm: s,
  })
}

///|
/// DIN93Spec is a validated DIN 93 tab-washer specification.
pub(all) struct DIN93Spec {
  size_dims : DIN93Size
}

///|
/// din93_spec validates a metric size for DIN 93 tab washers.
pub fn din93_spec(size : MetricSize) -> Result[DIN93Spec, @common.SpecError] {
  match din93_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// DIN93Spec::size returns the nominal size.
pub fn DIN93Spec::size(self : DIN93Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN93Spec::designation returns the standard part designation.
pub fn DIN93Spec::designation(self : DIN93Spec) -> String {
  "DIN 93 - \{self.size_dims.size.designation()}"
}

///|
/// DIN93Spec::standard returns the exact standard used.
pub fn DIN93Spec::standard() -> String {
  "DIN 93"
}

///|
/// DIN93Spec::source returns the dimensional provenance note.
pub fn DIN93Spec::source() -> String {
  "DIN 93 tab washer with long tab; d1, d2, b, l, and s from the DIN 93 table; transition center at l/2 + 2 mm"
}

///|
/// DIN93Spec::metadata builds component metadata for this specification.
pub fn DIN93Spec::metadata(self : DIN93Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN93Spec::standard(),
    family="tab washer with long tab",
    size=self.size_dims.size.designation(),
    source=DIN93Spec::source(),
  )
}
