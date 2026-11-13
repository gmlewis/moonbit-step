///|
/// ISO4762Size carries the ISO 4762 hexagon socket head cap screw dimensions
/// for one nominal size.
///
/// Dimensions follow ISO 4762:2004 for the head and socket; `dk` is the
/// maximum head diameter, `k` the head height, `s` the socket width across
/// flats, and `t` the minimum socket depth. Length limits are the practical
/// range implemented and tested here, not every preferred length in the
/// standard.
pub(all) struct ISO4762Size {
  size : MetricSize
  thread : ThreadSpec
  head_diameter_mm : Double
  head_height_mm : Double
  socket_across_flats_mm : Double
  /// Upper ISO limit of the socket width across flats (nominal + tolerance).
  socket_across_flats_max_mm : Double
  socket_depth_mm : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// iso4762_size returns the verified dimensions for one metric size.
pub fn iso4762_size(
  size : MetricSize,
) -> Result[ISO4762Size, @common.SpecError] {
  let dims = match size {
    M2 => (3.8, 2.0, 1.5, 1.58, 1.0, 3.0, 30.0)
    M2_5 => (4.5, 2.5, 2.0, 2.08, 1.1, 4.0, 40.0)
    M3 => (5.5, 3.0, 2.5, 2.58, 1.3, 5.0, 60.0)
    M4 => (7.0, 4.0, 3.0, 3.08, 2.0, 6.0, 80.0)
    M5 => (8.5, 5.0, 4.0, 4.095, 2.5, 8.0, 100.0)
    M6 => (10.0, 6.0, 5.0, 5.14, 3.0, 10.0, 120.0)
    M8 => (13.0, 8.0, 6.0, 6.14, 4.0, 12.0, 150.0)
    M10 => (16.0, 10.0, 8.0, 8.175, 5.0, 16.0, 200.0)
    M12 => (18.0, 12.0, 10.0, 10.175, 6.0, 20.0, 200.0)
    M16 => (24.0, 16.0, 14.0, 14.212, 8.0, 25.0, 200.0)
    M20 => (30.0, 20.0, 17.0, 17.23, 10.0, 30.0, 200.0)
  }
  let (dk, k, s, s_max, t, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    head_diameter_mm: dk,
    head_height_mm: k,
    socket_across_flats_mm: s,
    socket_across_flats_max_mm: s_max,
    socket_depth_mm: t,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// ISO4762Spec is a validated socket head cap screw specification.
pub(all) struct ISO4762Spec {
  size_dims : ISO4762Size
  length_mm : Double
  thread_length_mm : Double
  fully_threaded : Bool
}

///|
/// iso4762_spec validates a size and length and computes the threaded length.
pub fn iso4762_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[ISO4762Spec, @common.SpecError] {
  match iso4762_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "ISO 4762 length",
          length_mm,
          dims.min_length_mm,
          dims.max_length_mm,
        ) {
        Err(e) => Err(e)
        Ok(_) => {
          let d = dims.thread.nominal_diameter_mm
          let b = if length_mm <= 125.0 {
            2.0 * d + 6.0
          } else if length_mm <= 200.0 {
            2.0 * d + 12.0
          } else {
            2.0 * d + 25.0
          }
          let fully_threaded = length_mm <= b
          let thread_length = if fully_threaded { length_mm } else { b }
          Ok({
            size_dims: dims,
            length_mm,
            thread_length_mm: thread_length,
            fully_threaded,
          })
        }
      }
  }
}

///|
/// ISO4762Spec::thread returns the thread specification.
pub fn ISO4762Spec::thread(self : ISO4762Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO4762Spec::size returns the nominal size.
pub fn ISO4762Spec::size(self : ISO4762Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// ISO4762Spec::designation returns the standard part designation.
pub fn ISO4762Spec::designation(self : ISO4762Spec) -> String {
  "ISO 4762 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
/// ISO4762Spec::standard returns the exact standard and revision used.
pub fn ISO4762Spec::standard() -> String {
  "ISO 4762:2004"
}

///|
/// ISO4762Spec::source returns the dimensional provenance note.
pub fn ISO4762Spec::source() -> String {
  "ISO 4762:2004 head/socket table; nominal values"
}

///|
/// ISO4762Spec::metadata builds component metadata for this specification.
pub fn ISO4762Spec::metadata(self : ISO4762Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO4762Spec::standard(),
    family="hexagon socket head cap screw",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=ISO4762Spec::source(),
  )
}
