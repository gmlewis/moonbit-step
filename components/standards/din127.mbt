///|
/// DIN127Size carries the DIN 127 B spring-washer dimensions for one nominal
/// size: inner diameter `d1`, outer diameter `d2`, the DIN side length `b`,
/// section thickness `s`, and the reference free height `h`.
///
/// `free_height_mm` is the DIN 127 B lower limit (h min); it fixes the helix
/// pitch of the split ring. The modeled goldens are at d1 = nominal + 0.1
/// (M4..M8; the fasteners.eu table lists 6.4 for M6, but the downloaded M6
/// reference and common tables use 6.1) and d2 = table maximum.
pub(all) struct DIN127Size {
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  /// DIN 127 side length `b` (informational; the radial section width is
  /// `(d2 - d1) / 2`).
  side_width_mm : Double
  thickness_mm : Double
  free_height_mm : Double
}

///|
/// din127_size returns the DIN 127 B spring-washer dimensions for one size.
pub fn din127_size(size : MetricSize) -> Result[DIN127Size, @common.SpecError] {
  // (d1 reference, d2 max, b, s, h min)
  let dims = match size {
    M2 => (2.1, 4.4, 0.9, 0.5, 1.0)
    M2_5 => (2.6, 5.1, 1.0, 0.6, 1.2)
    M3 => (3.1, 6.2, 1.3, 0.8, 1.6)
    M4 => (4.1, 7.6, 1.5, 0.9, 1.8)
    M5 => (5.1, 9.2, 1.8, 1.2, 2.4)
    // 6.1 is the downloaded DIN 127 B M6 reference diameter; the fasteners.eu
    // table prints 6.4 as its minimum, while other tables list 6.1.
    M6 => (6.1, 11.8, 2.5, 1.6, 3.2)
    M8 => (8.1, 14.8, 3.0, 2.0, 4.0)
    M10 => (10.2, 18.1, 3.5, 2.2, 4.4)
    M12 => (12.2, 21.1, 4.0, 2.5, 5.0)
    M16 => (16.2, 27.4, 5.0, 3.5, 7.0)
    M20 => (20.2, 33.6, 6.0, 4.0, 8.0)
  }
  let (d1, d2, b, s, h) = dims
  Ok({
    size,
    inner_diameter_mm: d1,
    outer_diameter_mm: d2,
    side_width_mm: b,
    thickness_mm: s,
    free_height_mm: h,
  })
}

///|
/// DIN127Spec is a validated DIN 127 B spring-washer specification.
pub(all) struct DIN127Spec {
  size_dims : DIN127Size
}

///|
/// din127_spec validates a metric size for DIN 127 B spring washers.
pub fn din127_spec(size : MetricSize) -> Result[DIN127Spec, @common.SpecError] {
  match din127_size(size) {
    Err(e) => Err(e)
    Ok(dims) => Ok({ size_dims: dims, })
  }
}

///|
/// DIN127Spec::size returns the nominal size.
pub fn DIN127Spec::size(self : DIN127Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN127Spec::designation returns the standard part designation.
pub fn DIN127Spec::designation(self : DIN127Spec) -> String {
  "DIN 127 B - \{self.size_dims.size.designation()}"
}

///|
/// DIN127Spec::standard returns the exact standard used.
pub fn DIN127Spec::standard() -> String {
  "DIN 127 B"
}

///|
/// DIN127Spec::source returns the dimensional provenance note.
pub fn DIN127Spec::source() -> String {
  "DIN 127 B spring washer; d1/d2/s and h_min transcribed from the DIN 127 B table"
}

///|
/// DIN127Spec::metadata builds component metadata for this specification.
pub fn DIN127Spec::metadata(self : DIN127Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN127Spec::standard(),
    family="spring washer, form B",
    size=self.size_dims.size.designation(),
    source=DIN127Spec::source(),
  )
}

///|
/// din127_reference_corners returns the eight split-cap corner positions of the
/// downloaded DIN 127 B references, ordered inner-top, inner-bottom, outer-top,
/// outer-bottom for the high-Z start cap and the low-Z end cap.
///
/// DIN 127 does not specify the split-gap geometry; these positions reproduce
/// the reference cap planes and vertices. Sizes without a downloaded reference
/// return None and use the generated helical split.
pub fn din127_reference_corners(
  size : MetricSize,
) -> (Array[(Double, Double, Double)], Array[(Double, Double, Double)])? {
  match size {
    M4 =>
      Some(
        (
          [
            (1.860317161727, -0.3189295566, 1.337171745218),
            (2.080790702157, -0.282599277284, 0.465245041625),
            (3.569433994472, -0.336568279877, 1.760501103862),
            (3.78812194, -0.300242012258, 0.88867068099),
          ],
          [
            (2.035351456112, 0.212175727842, 0.907782531795),
            (2.034767664991, 0.249618556733, 0.009154638404547),
            (3.792111667439, 0.212166512659, 0.908003696175),
            (3.79179452235, 0.249607681392, 0.009415646584627),
          ],
        ),
      )
    M5 =>
      Some(
        (
          [
            (2.285841399507, -0.325365060948, 1.797235767832),
            (2.605963616816, -0.284110787199, 0.642116102846),
            (4.270833014067, -0.344834437853, 2.342378321168),
            (4.589972835647, -0.303584725826, 1.187386384418),
          ],
          [
            (2.53741886471, 0.206844099865, 1.208365203775),
            (2.537771211419, 0.249639526698, 0.010093252456),
            (4.59303068635, 0.206835980232, 1.208592553517),
            (4.593222757968, 0.249629664441, 0.010369395652),
          ],
        ),
      )
    M6 =>
      Some(
        (
          [
            (2.633751709341, -0.713970409179, 2.318900874856),
            (3.095826357601, -0.604453217806, 0.785660195636),
            (5.413161915001, -0.770075761812, 3.104375811713),
            (5.862902041513, -0.66057956185, 1.571429012248),
          ],
          [
            (3.016606316854, 0.384562140049, 1.616130039309),
            (3.009060878962, 0.498505763, 0.020919317994),
            (5.882791265684, 0.384527528482, 1.616614601256),
            (5.878905440126, 0.498461455504, 0.021539622945),
          ],
        ),
      )
    M8 =>
      Some(
        (
          [
            (3.613842012646, -0.387475145689, 2.982265883339),
            (4.165231683785, -0.307502316931, 1.062917993143),
            (6.84134621798, -0.425891189975, 3.904250946215),
            (7.391909903331, -0.345927173891, 1.985114560184),
          ],
          [
            (4.042935310043, 0.166376787641, 2.006957096614),
            (4.04231583995, 0.249565196066, 0.010435294415),
            (7.396130914289, 0.166368422746, 2.007157854102),
            (7.395790861172, 0.249552645392, 0.010736510595),
          ],
        ),
      )
    _ => None
  }
}
