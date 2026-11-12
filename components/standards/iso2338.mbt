///|
/// ISO2338Size carries the verified ISO 2338 dowel-pin dimensions.
///
/// ISO 2338 fixes the nominal diameter `d` and requires chamfered ends; the
/// chamfer leg is recorded as the reference 0.08 d (the downloaded reference
/// family uses 0.24 mm for d3 and 0.48 mm for d6). The reference files name a
/// half-length (`_l020` is a 40 mm model); this library follows the label and
/// the standard, so the length is the actual pin length.
pub(all) struct ISO2338Size {
  size : MetricSize
  diameter_mm : Double
  chamfer_mm : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// iso2338_size returns the verified ISO 2338 dimensions for one diameter.
pub fn iso2338_size(
  size : MetricSize,
) -> Result[ISO2338Size, @common.SpecError] {
  let d = size.nominal_diameter_mm()
  let dims = match size {
    // The reference corpus includes 60 mm pins for every diameter, so the
    // implemented range is a practical envelope (4..200 mm), not a claim about
    // the ISO preferred-length series.
    M2 => (0.16, 4.0, 200.0)
    M3 => (0.24, 4.0, 200.0)
    M4 => (0.32, 4.0, 200.0)
    M5 => (0.40, 4.0, 200.0)
    M6 => (0.48, 4.0, 200.0)
    M8 => (0.64, 4.0, 200.0)
    M10 => (0.80, 4.0, 200.0)
    M12 => (0.96, 4.0, 200.0)
    _ => return Err(@common.SpecError::InvalidSize(size.designation()))
  }
  let (c, lo, hi) = dims
  Ok({
    size,
    diameter_mm: d,
    chamfer_mm: c,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// iso2338_metadata builds component metadata for one dowel pin.
pub fn iso2338_metadata(
  dims : ISO2338Size,
  length_mm : Double,
) -> @common.Metadata {
  @common.Metadata::new(
    designation="ISO2338-\{dims.size.designation()}x\{length_mm}",
    standard="ISO 2338:1997",
    family="parallel pin, hardened",
    size=dims.size.designation(),
    length_mm~,
    source="ISO 2338:1997 parallel pin d, lengths; chamfer 0.08 d (reference family); see components/DATA_SOURCES.md",
  )
}
