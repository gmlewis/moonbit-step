///|
/// DIN557Size carries the verified DIN 557 square nut dimensions: width
/// across flats `s`, width across corners `e`, and nut height `m`.
pub(all) struct DIN557Size {
  size : MetricSize
  thread : ThreadSpec
  width_across_flats_mm : Double
  across_corners_mm : Double
  height_mm : Double
}

///|
/// din557_size returns the verified DIN 557 dimensions for one metric size.
///
/// The DIN 557 table begins at M5. DIN 557 chamfers one face only; the square
/// nut builder follows that.
pub fn din557_size(size : MetricSize) -> Result[DIN557Size, @common.SpecError] {
  // (s, e, m) in mm.
  let dims = match size {
    M5 => (8.0, 11.3, 4.0)
    M6 => (10.0, 14.1, 5.0)
    M8 => (13.0, 18.4, 6.5)
    M10 => (16.0, 22.6, 8.0)
    M12 => (18.0, 25.4, 10.0)
    M16 => (24.0, 33.9, 13.0)
    _ => return Err(@common.SpecError::InvalidSize(size.designation()))
  }
  let (s, e, m) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    width_across_flats_mm: s,
    across_corners_mm: e,
    height_mm: m,
  })
}

///|
/// DIN557Spec is a validated DIN 557 square nut specification.
///
/// `clearance_mm` is a radial clearance added to the modelled thread envelope;
/// it is not a tolerance class. Use 0 for nominal geometry.
pub(all) struct DIN557Spec {
  size_dims : DIN557Size
  clearance_mm : Double
}

///|
/// din557_spec validates a metric size for DIN 557 square nuts.
pub fn din557_spec(
  size : MetricSize,
  clearance_mm~ : Double = 0.0,
) -> Result[DIN557Spec, @common.SpecError] {
  match din557_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match @common.require_non_negative("square nut clearance", clearance_mm) {
        Err(e) => Err(e)
        Ok(_) => Ok({ size_dims: dims, clearance_mm, })
      }
  }
}

///|
/// DIN557Spec::thread returns the thread specification.
pub fn DIN557Spec::thread(self : DIN557Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// DIN557Spec::size returns the nominal size.
pub fn DIN557Spec::size(self : DIN557Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN557Spec::designation returns the standard part designation.
pub fn DIN557Spec::designation(self : DIN557Spec) -> String {
  "DIN 557 - \{self.size_dims.size.designation()}"
}

///|
/// DIN557Spec::standard returns the exact standard used.
pub fn DIN557Spec::standard() -> String {
  "DIN 557"
}

///|
/// DIN557Spec::source returns the dimensional provenance note.
pub fn DIN557Spec::source() -> String {
  "DIN 557 square nut table (s, e, m); nominal values"
}

///|
/// DIN557Spec::metadata builds component metadata for this specification.
pub fn DIN557Spec::metadata(self : DIN557Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN557Spec::standard(),
    family="square nut",
    size=self.size_dims.size.designation(),
    source=DIN557Spec::source(),
  )
}
