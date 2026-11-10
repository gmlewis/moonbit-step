///|
/// ISO7380Size carries the ISO 7380-1 button head hexagon socket screw
/// dimensions for one nominal size.
///
/// `d_k` is the head diameter, `k` the head height, `s` the socket width across
/// flats, and `t` the socket depth. These are nominal values transcribed from
/// commonly published dimension summaries; verify against the current standard
/// or a manufacturer drawing before manufacturing (see `DATA_SOURCES.md`).
pub(all) struct ISO7380Size {
  size : MetricSize
  thread : ThreadSpec
  head_diameter_mm : Double
  head_height_mm : Double
  socket_across_flats_mm : Double
  socket_depth_mm : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// iso7380_size returns the nominal dimensions for one metric size.
pub fn iso7380_size(
  size : MetricSize,
) -> Result[ISO7380Size, @common.SpecError] {
  let dims = match size {
    M3 => (5.7, 1.65, 2.0, 1.04, 5.0, 30.0)
    M4 => (7.6, 2.20, 2.5, 1.30, 6.0, 40.0)
    M5 => (9.5, 2.75, 3.0, 1.56, 8.0, 50.0)
    M6 => (10.5, 3.30, 4.0, 2.08, 10.0, 60.0)
    M8 => (14.0, 4.40, 5.0, 2.60, 12.0, 80.0)
    M10 => (17.5, 5.50, 6.0, 3.12, 16.0, 100.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "ISO 7380 does not carry size " + size.designation(),
        ),
      )
  }
  let (dk, k, s, t, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    head_diameter_mm: dk,
    head_height_mm: k,
    socket_across_flats_mm: s,
    socket_depth_mm: t,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// ISO7380Spec is a validated button head screw specification.
pub(all) struct ISO7380Spec {
  size_dims : ISO7380Size
  length_mm : Double
}

///|
/// iso7380_spec validates a size and length for ISO 7380-1.
pub fn iso7380_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[ISO7380Spec, @common.SpecError] {
  match iso7380_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "ISO 7380 length",
          length_mm,
          dims.min_length_mm,
          dims.max_length_mm,
        ) {
        Err(e) => Err(e)
        Ok(_) => Ok({ size_dims: dims, length_mm, })
      }
  }
}

///|
/// ISO7380Spec::size returns the nominal size.
pub fn ISO7380Spec::size(self : ISO7380Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// ISO7380Spec::thread returns the thread specification.
pub fn ISO7380Spec::thread(self : ISO7380Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO7380Spec::designation returns the standard part designation.
pub fn ISO7380Spec::designation(self : ISO7380Spec) -> String {
  "ISO 7380-1 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
/// ISO7380Spec::standard returns the exact standard used.
pub fn ISO7380Spec::standard() -> String {
  "ISO 7380-1:2022"
}

///|
/// ISO7380Spec::source returns the dimensional provenance note.
pub fn ISO7380Spec::source() -> String {
  "ISO 7380-1 button head table; nominal values transcribed from published summaries, see components/DATA_SOURCES.md"
}

///|
/// ISO7380Spec::metadata builds component metadata.
pub fn ISO7380Spec::metadata(self : ISO7380Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO7380Spec::standard(),
    family="button head hexagon socket screw",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=ISO7380Spec::source(),
  )
}
