///|
/// gobilda_u_channel builds a goBILDA 1120-series U-channel as a single, exact
/// B-rep: the U-section is authored as one base plate plus two leg plates, each
/// with its full hole pattern as analytic profile holes, and the three plates
/// are fused by the CAD engine (`union_all` + the evaluated export).
///
/// Frame: the channel opens along +Z. The base spans `x = -24 .. 24`,
/// `y = -length/2 .. length/2`, `z = 0 .. 2.5`; the legs rise from `z = 0` to
/// `z = 48`, giving the published **48 x 48 mm** outside, **43 mm** inside and
/// **2.5 mm** wall. The length follows `1120-00NN-LLLL`: `(holes + 1) * 24 mm`
/// (8 holes = 216 mm) unless `length_mm` is supplied.
///
/// Every measured feature of the vendor part is present on both the base and
/// the legs, because the goBILDA stamping repeats one pattern on all three
/// faces (measured from `1120-0008-0216.STEP`):
///
/// - 4 mm holes on the 8 mm grid in the `x = +/- 8, +/- 16` columns;
/// - 14 mm bearing holes on the centre line at each interior 24 mm station,
///   with the grid holes that would break into a bearing seat omitted;
/// - 45-degree "clocked" hole pairs on a 6*sqrt(2) mm diagonal around every
///   station, each pair merging with its nearest grid hole (authored as one
///   exact union loop);
/// - short obround slots between stations on the centre line, their cap
///   centres `12 - 8*sqrt(2)` mm either side of the interval centre;
/// - long obround slots at every station, spanning `8*sqrt(2) .. 16 mm` on
///   each side, whose outer cap is the `x = +/- 16` grid hole.
///
/// The vendor STEP has no cylindrical corner faces along the bend, so the
/// U-section is a clean extruded profile with sharp internal corners; the
/// measured reference volume is 53 320.47 mm3 for the 8-hole 216 mm part.
///
/// Source: https://www.gobilda.com/1120-series-u-channel (48 x 48 x 2.5 mm,
/// 4 mm holes on an 8 mm grid, 14 mm bearing holes on a 24 mm pitch,
/// 45-degree clocked slots; vendor STEP 1120-0008-0216 measured clean-room).
pub fn gobilda_u_channel(
  holes~ : Int32 = 8,
  length_mm? : Double,
  thickness_mm~ : Double = gobilda_sheet_thickness_mm,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if holes < 1 {
    return Err(
      @common.InvalidParameter(
        "goBILDA U-channel needs at least one bearing hole",
      ),
    )
  }
  match @common.require_positive("goBILDA U-channel thickness", thickness_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let length = match length_mm {
    Some(value) =>
      match @common.require_positive("goBILDA U-channel length", value) {
        Err(e) => return Err(e)
        Ok(_) => value
      }
    None => (holes.to_double() + 1.0) * gobilda_bearing_pitch_mm
  }
  if length < 2.0 * gobilda_bearing_pitch_mm {
    return Err(
      @common.InvalidDimension(
        "goBILDA U-channel is too short for its bearing holes",
      ),
    )
  }
  let half_len = length / 2.0
  let half_width = gobilda_channel_width_mm / 2.0
  let inner_half = half_width - thickness_mm
  // The pattern is identical on the base (x, y) and on the legs (height, y);
  // the legs are the same loops shifted across their local plate.
  let pattern = gobilda_u_channel_pattern(length)
  let base = @cad.ExtrudedArcProfile::new(
      gobilda_rect_loop_xy(-half_width, -half_len, half_width, half_len),
      thickness_mm,
      holes=pattern,
    )
    .as_shape()
    .with_name("base")
  let leg_profile_height = gobilda_channel_height_mm
  let leg_loops = @common.translate_loops(
    pattern,
    -leg_profile_height / 2.0,
    0.0,
  )
  let leg = @cad.ExtrudedArcProfile::new(
      gobilda_rect_loop_xy(-leg_profile_height, -half_len, 0.0, half_len),
      thickness_mm,
      holes=leg_loops,
    )
    .as_shape()
    .with_name("leg")
    .rotate_y(90.0)
  let body = @cad.union_all(
    [base, leg.translate(x=inner_half), leg.translate(x=-half_width)],
    name="u-channel",
  )
  let features = @common.FeatureRecord::new(
    modeled=[
      "u-section", "base-grid-holes", "leg-grid-holes", "14mm-bearing-holes", "clocked-diagonal-holes",
      "short-centre-slots", "long-station-slots",
    ],
    approximated=[],
    omitted=[],
  )
  let name = "gobilda-u-channel-\{holes}-hole"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="goBILDA U-channel \{holes} hole (\{@cad.fmt_double(length, None)} mm)",
      standard="goBILDA 8 mm pattern",
      family="goBILDA U-channel",
      size="\{holes}-hole",
      length_mm=length,
      material="aluminium, clear anodized",
      source="https://www.gobilda.com/1120-series-u-channel | 48 x 48 x 2.5 mm U-section (43 mm inside) | 4 mm holes on an 8 mm grid, 14 mm bearing holes on a 24 mm pitch, 45-degree clocked holes and slots | length (holes+1)x24 mm",
    ),
    description="goBILDA 1120-series U-channel: exact 48 x 48 x 2.5 mm U-section with the full measured base and leg patterns (8 mm grid, 14 mm bearings, 45-degree clocked holes, short centre slots and long station slots).",
    features~,
  ).add_layer(body.shape_intent(), name="body", color~)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-outer",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * half_width,
        description="base outer face; outward normal is -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-inner",
        placement=@common.Placement::translation(0.0, 0.0, thickness_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * inner_half,
        description="base inner face; outward normal is +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, -half_len, 0.0),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * half_width,
        description="-Y end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, half_len, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * half_width,
        description="+Y end face",
      ),
    )
  let mut index = 0
  for station in gobilda_u_channel_stations(length) {
    index += 1
    out = out
      .with_connector_unchecked(
        @common.MateConnector::new(
          "bearing-hole-\{index}",
          placement=@common.Placement::translation(0.0, station, 0.0),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=gobilda_bearing_hole_mm,
          depth_mm=thickness_mm,
          description="14 mm bearing seat through the base",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "leg-hole-left-\{index}",
          placement=@common.Placement::translation(
            -half_width,
            station,
            gobilda_channel_height_mm / 2.0,
          ),
          axis=(-1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=gobilda_bearing_hole_mm,
          depth_mm=thickness_mm,
          description="14 mm bearing seat through the -X leg",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "leg-hole-right-\{index}",
          placement=@common.Placement::translation(
            half_width,
            station,
            gobilda_channel_height_mm / 2.0,
          ),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=gobilda_bearing_hole_mm,
          depth_mm=thickness_mm,
          description="14 mm bearing seat through the +X leg",
        ),
      )
  }
  Ok(out)
}

///|
/// gobilda_rect_loop_xy returns a counter-clockwise rectangular loop.
fn gobilda_rect_loop_xy(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, y0), (x1, y0)),
    @cad.SegmentLine((x1, y0), (x1, y1)),
    @cad.SegmentLine((x1, y1), (x0, y1)),
    @cad.SegmentLine((x0, y1), (x0, y0)),
  ]
}

///|
/// gobilda_u_channel_stations returns the interior bearing-hole centres, in
/// millimetres from the channel centre.
fn gobilda_u_channel_stations(length_mm : Double) -> Array[Double] {
  let half = length_mm / 2.0
  let stations : Array[Double] = []
  let count = (length_mm / gobilda_bearing_pitch_mm).to_int()
  for k in 1..<count {
    stations.push(-half + gobilda_bearing_pitch_mm * k.to_double())
  }
  stations
}

///|
/// gobilda_u_channel_pattern returns the measured goBILDA plate pattern as
/// hole loops in pattern coordinates: `a` is the cross axis (the base's X or
/// the legs' height) and `b` runs along the part. The same loops serve the
/// base and both legs.
fn gobilda_u_channel_pattern(
  length_mm : Double,
) -> Array[Array[@cad.ProfileSegment]] {
  let half = length_mm / 2.0
  let pitch = gobilda_bearing_pitch_mm
  let grid = gobilda_grid_mm
  let radius = gobilda_hole_diameter_mm / 2.0
  let bearing_radius = gobilda_bearing_hole_mm / 2.0
  let intervals = (length_mm / pitch).to_int()
  let loops : Array[Array[@cad.ProfileSegment]] = []
  // 45-degree clocked pairs around every station; each merges with the grid
  // hole one grid step toward it, so the pair is authored as one union loop
  // and that grid hole is not emitted separately.
  let consumed : Array[(Double, Double)] = []
  for k in 0..<(intervals + 1) {
    let station = -half + pitch * k.to_double()
    for da in [gobilda_diagonal_offset_mm, -gobilda_diagonal_offset_mm] {
      for db in [gobilda_diagonal_offset_mm, -gobilda_diagonal_offset_mm] {
        let b = station + db
        if b > -half && b < half {
          let ga = if da > 0.0 { grid } else { -grid }
          let gb = station + (if db > 0.0 { grid } else { -grid })
          consumed.push((ga, gb))
          loops.push(@common.disc_pair_loop((ga, gb), (da, b), radius))
        }
      }
    }
  }
  // Grid columns. The 8 mm columns drop the holes that would break into a
  // bearing seat; the 16 mm columns drop the holes absorbed by a long slot.
  for a in [-2.0 * grid, -grid, grid, 2.0 * grid] {
    let row_count = (length_mm / grid).to_int() - 1
    for i in 0..<row_count {
      let b = -half + grid * (i.to_double() + 1.0)
      let station_index = (b + half) / pitch
      let on_station = (station_index - station_index.round()).abs() <
        gobilda_station_eps
      // The 8 mm columns drop the holes that meet a bearing seat; the 16 mm
      // columns drop the holes that the long slot already covers.
      if on_station {
        continue
      }
      let mut absorbed = false
      for centre in consumed {
        if (a - centre.0).abs() < gobilda_station_eps &&
          (b - centre.1).abs() < gobilda_station_eps {
          absorbed = true
        }
      }
      if !absorbed {
        loops.push(@common.circle_loop(a, b, radius))
      }
    }
  }
  // 14 mm bearing seats at interior stations.
  for station in gobilda_u_channel_stations(length_mm) {
    loops.push(@common.circle_loop(0.0, station, bearing_radius))
  }
  // Short obround slots on the centre line between stations.
  for k in 0..<intervals {
    let centre = -half + pitch * k.to_double() + pitch / 2.0
    loops.push(
      @common.obround_loop(
        0.0, centre, 0.0, 1.0, gobilda_slot_cap_offset_mm, radius,
      ),
    )
  }
  // Long slots through each station, outward to the 16 mm grid holes.
  for station in gobilda_u_channel_stations(length_mm) {
    let centre_abs = (gobilda_slot_inner_offset_mm + 2.0 * grid) / 2.0
    let half_span = (2.0 * grid - gobilda_slot_inner_offset_mm) / 2.0
    loops.push(
      @common.obround_loop(centre_abs, station, 1.0, 0.0, half_span, radius),
    )
    loops.push(
      @common.obround_loop(-centre_abs, station, 1.0, 0.0, half_span, radius),
    )
  }
  loops
}

///|
/// gobilda_u_channel_family exposes the goBILDA U-channel as a validated design
/// family with one preset per published bearing-hole count.
pub fn gobilda_u_channel_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="holes",
      default_mm=8.0,
      min_mm=1.0,
      max_mm=49.0,
      unit="count",
      description="bearing-hole count (length = (holes+1) x 24 mm)",
    ),
    @common.ParamSpec::new(
      name="thickness",
      default_mm=gobilda_sheet_thickness_mm,
      min_mm=1.0,
      max_mm=6.0,
      description="wall thickness",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="gobilda-u-channel",
      specs~,
      description="goBILDA 1120-series U-channels with the measured 8 mm pattern.",
      build=fn(parameters) {
        let holes = match parameters.get("holes") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let thickness = match parameters.get("thickness") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        gobilda_u_channel(holes=holes.to_int(), thickness_mm=thickness)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for
    count in [
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 21, 25, 29,
      33, 37, 41, 45, 49,
    ] {
    let name = "\{count}-hole"
    out = match out.with_variant(name, [("holes", count.to_double())]) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
