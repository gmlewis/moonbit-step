///|
/// ISO4032Size carries the ISO 4032 hexagon regular nut dimensions for one
/// nominal size: width across flats `s` and nut height `m`.
pub(all) struct ISO4032Size {
  size : MetricSize
  thread : ThreadSpec
  width_across_flats_mm : Double
  height_mm : Double
}

///|
/// iso4032_size returns the verified ISO 4032 dimensions for one metric size.
pub fn iso4032_size(
  size : MetricSize,
) -> Result[ISO4032Size, @common.SpecError] {
  let dims = match size {
    M2 => (4.0, 1.6)
    M2_5 => (5.0, 2.0)
    M3 => (5.5, 2.4)
    M4 => (7.0, 3.2)
    // ISO 4032:2023 heights; these differ from the older DIN 934 values
    // from M5 upward (DIN 934: 4.0 / 5.0 / 6.5 / 8.0 / 10.0 / 13.0 / 16.0).
    M5 => (8.0, 4.7)
    M6 => (10.0, 5.2)
    M8 => (13.0, 6.8)
    M10 => (16.0, 8.4)
    M12 => (18.0, 10.8)
    M16 => (24.0, 14.8)
    M20 => (30.0, 18.0)
  }
  let (s, m) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    width_across_flats_mm: s,
    height_mm: m,
  })
}

///|
/// ISO4032Spec is a validated hexagon regular nut specification.
///
/// `clearance_mm` is a radial clearance added to the modelled thread envelope;
/// it is not an ISO tolerance class. Use 0 for nominal geometry.
pub(all) struct ISO4032Spec {
  size_dims : ISO4032Size
  clearance_mm : Double
}

///|
/// iso4032_spec validates a metric size for ISO 4032 nuts.
pub fn iso4032_spec(
  size : MetricSize,
  clearance_mm~ : Double = 0.0,
) -> Result[ISO4032Spec, @common.SpecError] {
  match iso4032_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match @common.require_non_negative("nut clearance", clearance_mm) {
        Err(e) => Err(e)
        Ok(_) => Ok({ size_dims: dims, clearance_mm, })
      }
  }
}

///|
/// ISO4032Spec::thread returns the thread specification.
pub fn ISO4032Spec::thread(self : ISO4032Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO4032Spec::size returns the nominal size.
pub fn ISO4032Spec::size(self : ISO4032Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// ISO4032Spec::designation returns the standard part designation.
pub fn ISO4032Spec::designation(self : ISO4032Spec) -> String {
  "ISO 4032 - \{self.size_dims.size.designation()}"
}

///|
/// ISO4032Spec::standard returns the exact standard and revision used.
pub fn ISO4032Spec::standard() -> String {
  "ISO 4032:2023"
}

///|
/// ISO4032Spec::source returns the dimensional provenance note.
pub fn ISO4032Spec::source() -> String {
  "ISO 4032:2023 hexagon regular nut table; nominal values, see components/DATA_SOURCES.md"
}

///|
/// ISO4032Spec::metadata builds component metadata for this specification.
pub fn ISO4032Spec::metadata(self : ISO4032Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO4032Spec::standard(),
    family="hexagon regular nut",
    size=self.size_dims.size.designation(),
    source=ISO4032Spec::source(),
  )
}
