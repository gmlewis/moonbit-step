///|
/// DIN125Size carries the DIN 125 A plain-washer dimensions for one nominal
/// size: inner diameter `d1`, outer diameter `d2`, and reference thickness `h`.
///
/// For the modeled sizes DIN 125 A is dimensionally identical to ISO 7089
/// (normal series, product grade A), so the verified ISO 7089 table is reused.
/// The M8 reference thickness is the ISO 7089 h_max of 1.8 mm (nominal 1.6,
/// limits 1.4..1.8), matching the downloaded DIN 125 A M8 reference within
/// the standard.
pub(all) struct DIN125Size {
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  thickness_mm : Double
}

///|
/// DIN 125 A / ISO 7089 normal-series M8 washers specify h = 1.6 mm with
/// limits 1.4..1.8 mm. The downloaded DIN 125 A M8 reference is 1.8 mm
/// (h_max), so the reference thickness is chosen at the upper ISO limit.
let din125_m8_reference_thickness_mm : Double = 1.8

///|
/// din125_size returns the DIN 125 A dimensions for one metric size.
pub fn din125_size(size : MetricSize) -> Result[DIN125Size, @common.SpecError] {
  match iso7089_size(size) {
    Err(e) => Err(e)
    Ok(d) => {
      let thickness_mm = match size {
        M8 => din125_m8_reference_thickness_mm
        _ => d.thickness_mm
      }
      Ok({
        size,
        inner_diameter_mm: d.inner_diameter_mm,
        outer_diameter_mm: d.outer_diameter_mm,
        thickness_mm,
      })
    }
  }
}

///|
/// DIN125Spec is a validated DIN 125 A plain-washer specification.
pub(all) struct DIN125Spec {
  size_dims : DIN125Size
}

///|
/// din125_spec validates a metric size for DIN 125 A washers.
pub fn din125_spec(size : MetricSize) -> Result[DIN125Spec, @common.SpecError] {
  match din125_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// DIN125Spec::size returns the nominal size.
pub fn DIN125Spec::size(self : DIN125Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN125Spec::designation returns the standard part designation.
pub fn DIN125Spec::designation(self : DIN125Spec) -> String {
  "DIN 125 A - \{self.size_dims.size.designation()}"
}

///|
/// DIN125Spec::standard returns the exact standard used.
pub fn DIN125Spec::standard() -> String {
  "DIN 125 A"
}

///|
/// DIN125Spec::source returns the dimensional provenance note.
pub fn DIN125Spec::source() -> String {
  "DIN 125 A-series plain washer; dimensions equivalent to ISO 7089 for the modeled sizes, with the M8 reference thickness at the ISO 7089 h_max (1.8 mm); see components/DATA_SOURCES.md"
}

///|
/// DIN125Spec::metadata builds component metadata for this specification.
pub fn DIN125Spec::metadata(self : DIN125Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN125Spec::standard(),
    family="plain washer, normal series (DIN 125 A)",
    size=self.size_dims.size.designation(),
    source=DIN125Spec::source(),
  )
}
