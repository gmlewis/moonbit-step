///|
/// IsoWasherSeries selects the ISO 709x plain-washer series.
///
/// ISO 7091 is the class C normal series (DIN 126), ISO 7092 the small series
/// (DIN 433), and ISO 7093 the large series (DIN 9021). ISO 7090 is the
/// chamfered normal series; the verified table is dimensionally the ISO 7089
/// normal series (the downloaded M3 reference is a sharp annulus).
pub(all) enum IsoWasherSeries {
  Iso7090
  Iso7091ClassC
  Iso7092
  Iso7093
}

///|
/// ISO709xSize carries one plain-washer size: inner diameter `d1`, outer
/// diameter `d2`, and thickness `h`.
pub(all) struct ISO709xSize {
  series : IsoWasherSeries
  size : MetricSize
  inner_diameter_mm : Double
  outer_diameter_mm : Double
  thickness_mm : Double
}

///|
/// iso709x_size returns the verified dimensions for one series and size.
///
/// Values are the ISO 7091 class C, ISO 7092 (DIN 433), ISO 7093 (DIN 9021)
/// and ISO 7090 tables.
pub fn iso709x_size(
  series : IsoWasherSeries,
  size : MetricSize,
) -> Result[ISO709xSize, @common.SpecError] {
  let dims = match series {
    Iso7090 =>
      match size {
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
    Iso7091ClassC =>
      match size {
        M2 => (2.4, 5.0, 0.3)
        M2_5 => (2.9, 6.0, 0.5)
        M3 => (3.4, 7.0, 0.5)
        M4 => (4.5, 9.0, 0.8)
        M5 => (5.5, 10.0, 1.0)
        M6 => (6.6, 12.0, 1.6)
        M8 => (9.0, 16.0, 1.6)
        M10 => (11.0, 20.0, 2.0)
        M12 => (13.5, 24.0, 2.5)
        M16 => (17.5, 30.0, 3.0)
        M20 => (22.0, 37.0, 3.0)
      }
    Iso7092 =>
      match size {
        M2_5 => (2.7, 5.0, 0.5)
        M3 => (3.2, 6.0, 0.5)
        M4 => (4.3, 8.0, 0.5)
        M5 => (5.3, 9.0, 1.0)
        M6 => (6.4, 11.0, 1.6)
        M8 => (8.4, 15.0, 1.6)
        M10 => (10.5, 18.0, 2.0)
        M12 => (13.0, 20.0, 2.5)
        M16 => (17.0, 28.0, 2.5)
        M20 => (21.0, 34.0, 3.0)
        _ => return Err(@common.SpecError::InvalidSize(size.designation()))
      }
    Iso7093 =>
      match size {
        M2 => (2.2, 6.0, 0.8)
        M2_5 => (2.7, 8.0, 0.8)
        M3 => (3.2, 9.0, 0.8)
        M4 => (4.3, 12.0, 1.0)
        M5 => (5.3, 15.0, 1.2)
        M6 => (6.4, 18.0, 1.6)
        M8 => (8.4, 24.0, 2.0)
        M10 => (10.5, 30.0, 2.5)
        M12 => (13.0, 37.0, 3.0)
        M16 => (17.0, 50.0, 3.0)
        M20 => (21.0, 60.0, 4.0)
      }
  }
  let (d1, d2, h) = dims
  if d1 >= d2 || h <= 0.0 {
    return Err(@common.SpecError::InvalidSize(size.designation()))
  }
  Ok({
    series,
    size,
    inner_diameter_mm: d1,
    outer_diameter_mm: d2,
    thickness_mm: h,
  })
}

///|
/// iso709x_standard returns the standard designation for a series.
pub fn iso709x_standard(series : IsoWasherSeries) -> String {
  match series {
    Iso7090 => "ISO 7090:2000"
    Iso7091ClassC => "ISO 7091:2000"
    Iso7092 => "ISO 7092:2000"
    Iso7093 => "ISO 7093-1:2000"
  }
}

///|
/// iso709x_family returns the human-readable series name.
pub fn iso709x_family(series : IsoWasherSeries) -> String {
  match series {
    Iso7090 => "plain washer, chamfered, normal series"
    Iso7091ClassC => "plain washer, class C, normal series"
    Iso7092 => "plain washer, small series"
    Iso7093 => "plain washer, large series"
  }
}

///|
/// iso709x_prefix returns the component-name stem.
pub fn iso709x_prefix(series : IsoWasherSeries) -> String {
  match series {
    Iso7090 => "ISO7090"
    Iso7091ClassC => "ISO7091"
    Iso7092 => "ISO7092"
    Iso7093 => "ISO7093"
  }
}

///|
/// iso709x_metadata builds component metadata for one washer.
pub fn iso709x_metadata(dims : ISO709xSize) -> @common.Metadata {
  let label = iso709x_standard(dims.series)
  @common.Metadata::new(
    designation="\{iso709x_prefix(dims.series)}-\{dims.size.designation()}",
    standard=label,
    family=iso709x_family(dims.series),
    size=dims.size.designation(),
    source=label + " plain washer dimensions (d1, d2, h)",
  )
}
