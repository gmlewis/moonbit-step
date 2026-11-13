///|
/// ISO4035Size carries the ISO 4035 thin hexagon nut dimensions: width across
/// flats `s` and nut height `m`.
pub(all) struct ISO4035Size {
  size : MetricSize
  thread : ThreadSpec
  width_across_flats_mm : Double
  height_mm : Double
}

///|
/// iso4035_size returns the ISO 4035 dimensions for one metric size.
pub fn iso4035_size(
  size : MetricSize,
) -> Result[ISO4035Size, @common.SpecError] {
  let dims = match size {
    M2 => (4.0, 1.2)
    M2_5 => (5.0, 1.6)
    M3 => (5.5, 1.8)
    M4 => (7.0, 2.2)
    M5 => (8.0, 2.7)
    M6 => (10.0, 3.2)
    M8 => (13.0, 4.0)
    M10 => (16.0, 5.0)
    M12 => (18.0, 6.0)
    M16 => (24.0, 8.0)
    M20 => (30.0, 10.0)
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
/// ISO4035Spec is a validated thin-nut specification.
///
/// `clearance_mm` is a radial clearance added to the modelled thread envelope;
/// it is not a tolerance class. Use 0 for nominal geometry.
pub(all) struct ISO4035Spec {
  size_dims : ISO4035Size
  clearance_mm : Double
}

///|
/// iso4035_spec validates a metric size for ISO 4035 thin nuts.
pub fn iso4035_spec(
  size : MetricSize,
  clearance_mm~ : Double = 0.0,
) -> Result[ISO4035Spec, @common.SpecError] {
  match iso4035_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match @common.require_non_negative("thin nut clearance", clearance_mm) {
        Err(e) => Err(e)
        Ok(_) => Ok({ size_dims: dims, clearance_mm, })
      }
  }
}

///|
/// ISO4035Spec::thread returns the thread specification.
pub fn ISO4035Spec::thread(self : ISO4035Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO4035Spec::size returns the nominal size.
pub fn ISO4035Spec::size(self : ISO4035Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// ISO4035Spec::designation returns the standard part designation.
pub fn ISO4035Spec::designation(self : ISO4035Spec) -> String {
  "ISO 4035 - \{self.size_dims.size.designation()}"
}

///|
/// ISO4035Spec::standard returns the exact standard used.
pub fn ISO4035Spec::standard() -> String {
  "ISO 4035:2012"
}

///|
/// ISO4035Spec::source returns the dimensional provenance note.
pub fn ISO4035Spec::source() -> String {
  "ISO 4035:2012 thin hexagon nut table; nominal s and m values"
}

///|
/// ISO4035Spec::metadata builds component metadata for this specification.
pub fn ISO4035Spec::metadata(self : ISO4035Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO4035Spec::standard(),
    family="thin hexagon nut",
    size=self.size_dims.size.designation(),
    source=ISO4035Spec::source(),
  )
}
