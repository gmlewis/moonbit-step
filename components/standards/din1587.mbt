///|
/// DIN1587Size carries the verified DIN 1587 hexagon domed cap nut
/// dimensions: width across flats `s`, width across corners `e`, cap diameter
/// `dk`, overall height `h`, and hexagon body height `m`.
pub(all) struct DIN1587Size {
  size : MetricSize
  thread : ThreadSpec
  width_across_flats_mm : Double
  across_corners_mm : Double
  dome_diameter_mm : Double
  overall_height_mm : Double
  body_height_mm : Double
}

///|
/// din1587_size returns the verified DIN 1587 dimensions for one metric size.
///
/// DIN 1587 begins at M4. The `m` values below are the DIN 1587 body heights
/// (the older DIN 934 series), which differ from ISO 4032:2023 from M5 upward.
pub fn din1587_size(
  size : MetricSize,
) -> Result[DIN1587Size, @common.SpecError] {
  // (s, e, dk, h, m) in mm.
  let dims = match size {
    M4 => (7.0, 7.66, 6.5, 8.0, 3.2)
    M5 => (8.0, 8.79, 7.5, 10.0, 4.0)
    M6 => (10.0, 11.05, 9.5, 12.0, 5.0)
    M8 => (13.0, 14.38, 12.5, 15.0, 6.5)
    M10 => (16.0, 17.77, 15.0, 18.0, 8.8)
    M12 => (18.0, 20.03, 17.0, 22.0, 10.0)
    M16 => (24.0, 26.75, 23.0, 28.0, 13.0)
    M20 => (30.0, 33.53, 28.0, 34.0, 16.0)
    _ => return Err(@common.SpecError::InvalidSize(size.designation()))
  }
  let (s, e, dk, h, m) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    width_across_flats_mm: s,
    across_corners_mm: e,
    dome_diameter_mm: dk,
    overall_height_mm: h,
    body_height_mm: m,
  })
}

///|
/// DIN1587Spec is a validated DIN 1587 cap nut specification.
///
/// `clearance_mm` is a radial clearance added to the modelled thread envelope;
/// it is not a tolerance class. Use 0 for nominal geometry.
pub(all) struct DIN1587Spec {
  size_dims : DIN1587Size
  clearance_mm : Double
}

///|
/// din1587_spec validates a metric size for DIN 1587 cap nuts.
pub fn din1587_spec(
  size : MetricSize,
  clearance_mm~ : Double = 0.0,
) -> Result[DIN1587Spec, @common.SpecError] {
  match din1587_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match @common.require_non_negative("cap nut clearance", clearance_mm) {
        Err(e) => Err(e)
        Ok(_) => Ok({ size_dims: dims, clearance_mm, })
      }
  }
}

///|
/// DIN1587Spec::thread returns the thread specification.
pub fn DIN1587Spec::thread(self : DIN1587Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// DIN1587Spec::size returns the nominal size.
pub fn DIN1587Spec::size(self : DIN1587Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN1587Spec::designation returns the standard part designation.
pub fn DIN1587Spec::designation(self : DIN1587Spec) -> String {
  "DIN 1587 - \{self.size_dims.size.designation()}"
}

///|
/// DIN1587Spec::standard returns the exact standard used.
pub fn DIN1587Spec::standard() -> String {
  "DIN 1587"
}

///|
/// DIN1587Spec::source returns the dimensional provenance note.
pub fn DIN1587Spec::source() -> String {
  "DIN 1587 hexagon domed cap nut table (s, e, dk, h, m); nominal values, see components/DATA_SOURCES.md"
}

///|
/// DIN1587Spec::metadata builds component metadata for this specification.
pub fn DIN1587Spec::metadata(self : DIN1587Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN1587Spec::standard(),
    family="hexagon domed cap nut",
    size=self.size_dims.size.designation(),
    source=DIN1587Spec::source(),
  )
}
