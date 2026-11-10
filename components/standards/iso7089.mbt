///|
/// ISO7089Size carries the ISO 7089 plain washer dimensions for one nominal
/// size: inner diameter `d1`, outer diameter `d2`, and thickness `h`.
pub(all) struct ISO7089Size {
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  thickness_mm : Double
}

///|
/// iso7089_size returns the verified ISO 7089 normal-series dimensions.
pub fn iso7089_size(
  size : MetricSize,
) -> Result[ISO7089Size, @common.SpecError] {
  let dims = match size {
    M2 => (2.2, 5.0, 0.3)
    M2_5 => (2.7, 6.0, 0.5)
    M3 => (3.2, 7.0, 0.5)
    M4 => (4.3, 9.0, 0.8)
    M5 => (5.3, 10.0, 1.0)
    M6 => (6.4, 12.0, 1.6)
    M8 => (8.4, 16.0, 1.6)
    M10 => (10.5, 20.0, 2.0)
    M12 => (13.0, 24.0, 2.5)
    M16 => (17.0, 30.0, 3.0)
    M20 => (21.0, 37.0, 3.0)
  }
  let (d1, d2, h) = dims
  Ok({ size, inner_diameter_mm: d1, outer_diameter_mm: d2, thickness_mm: h, })
}

///|
/// ISO7089Spec is a validated plain washer specification.
pub(all) struct ISO7089Spec {
  size_dims : ISO7089Size
}

///|
/// iso7089_spec validates a metric size for ISO 7089 normal-series washers.
pub fn iso7089_spec(
  size : MetricSize,
) -> Result[ISO7089Spec, @common.SpecError] {
  match iso7089_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// ISO7089Spec::size returns the nominal size.
pub fn ISO7089Spec::size(self : ISO7089Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// ISO7089Spec::designation returns the standard part designation.
pub fn ISO7089Spec::designation(self : ISO7089Spec) -> String {
  "ISO 7089 - \{self.size_dims.size.designation()}"
}

///|
/// ISO7089Spec::standard returns the exact standard and revision used.
pub fn ISO7089Spec::standard() -> String {
  "ISO 7089:2000"
}

///|
/// ISO7089Spec::source returns the dimensional provenance note.
pub fn ISO7089Spec::source() -> String {
  "ISO 7089:2000 plain washer, normal series, product grade A; nominal values, see components/DATA_SOURCES.md"
}

///|
/// ISO7089Spec::metadata builds component metadata for this specification.
pub fn ISO7089Spec::metadata(self : ISO7089Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO7089Spec::standard(),
    family="plain washer, normal series",
    size=self.size_dims.size.designation(),
    source=ISO7089Spec::source(),
  )
}
