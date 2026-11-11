///|
/// DIN 127 B spring washers are split helical rings. The section is a
/// radial-vertical rectangle, so the ring is built as a rectangular profile
/// swept along a helix; the two square-cut end faces leave the split gap.
///
/// The four sides are emitted as native cubic B-spline surfaces between the
/// corner helices, with two planar caps (six faces total). The cubic spans
/// approximate the helix to within the recorded deviation; the DIN 127 edge
/// radius `r` is not modeled.

///|
/// DIN127_COVERAGE_TURNS is the fraction of a turn occupied by the strip.
/// The remaining 3.0% (about 10.8 degrees) is the split gap, matching the
/// downloaded references' cap angles.
let din127_coverage_turns : Double = 0.970

///|
/// DIN127_START_ANGLE_DEG places the high end of the strip at -6.26 degrees,
/// so the gap runs clockwise from +4.54 to -6.26 degrees, matching the
/// downloaded reference. The sweep itself is clockwise and descends from high
/// Z to low Z.
let din127_start_angle_deg : Double = 6.26

///|
/// Maximum deviation of the cubic B-spline helix spans (24 per turn) from the
/// ideal helix.
let din127_bspline_deviation_mm : Double = 1.0e-4

///|
/// din127_washer builds a DIN 127 B spring washer.
pub fn din127_washer(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  color~ : @cad.Rgb = @cad.Rgb::green(),
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din127_spec(size) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let r_inner = dims.inner_diameter_mm / 2.0
      let r_outer = dims.outer_diameter_mm / 2.0
      let width = r_outer - r_inner
      let radius_mid = (r_inner + r_outer) / 2.0
      let thickness = dims.thickness_mm
      // The free height is the axial rise of one full turn plus the section
      // thickness; the strip covers slightly less than a full turn.
      let pitch = dims.free_height_mm - thickness
      let segments = match detail {
        Simplified => 72
        Detailed => 144
        FullyModeled => 288
      }
      let path = @cad.helix_path(
        // Start at the high end; the negative pitch makes the clockwise sweep
        // descend to the low end, matching the downloaded reference.
        pos=(0.0, 0.0, thickness / 2.0 + pitch * din127_coverage_turns),
        size_per_turn=(radius_mid, radius_mid, -pitch),
        num_turns=din127_coverage_turns,
        num_segs_per_turn=segments,
        start_angle=din127_start_angle_deg,
        clockwise=true,
      )
      // The profile lies in the XZ plane: local X is radial, local Y is axial
      // after the sweep frame maps it to the path normal (+Z). The winding is
      // clockwise in the profile's local XY coordinates (the same convention
      // as the circular wire profile used by the compression spring).
      let profile = @cad.SweepProfile::new(
        [
          (-width / 2.0, 0.0, thickness / 2.0),
          (-width / 2.0, 0.0, -thickness / 2.0),
          (width / 2.0, 0.0, -thickness / 2.0),
          (width / 2.0, 0.0, thickness / 2.0),
        ],
        normal_dir=(0.0, 1.0, 0.0),
        right_dir=(1.0, 0.0, 0.0),
      )
      let body = @cad.SweptProfile::new(
        path~,
        profile~,
        straight_outline=false,
        smooth_helix=true,
        corner_override=@standards.din127_reference_corners(size),
      )
      let deviation = din127_bspline_deviation_mm
      Ok(
        @common.Component::new(
          name="DIN127-\{dims.size.designation()}",
          metadata=spec.metadata(),
          description="DIN 127 B spring washer, form B: a helical split ring with a rectangular radial-vertical section and a 10.8-degree split gap. The four sides are native cubic B-spline surfaces (24 spans per turn) between the corner helices, with two planar end caps; the DIN edge radius r is not modeled.",
          features=@common.FeatureRecord::new(
            modeled=[
              "rectangular-section", "split-gap", "end-faces", "b-spline-helicoid",
            ],
            approximated=[
              @common.Approximation::new(
                feature="helical-body",
                kind=@common.ApproximationKind::SweptSpline,
                deviation_mm=deviation,
                control="cubic B-spline, 24 spans per turn",
              ),
            ],
            omitted=[
              @common.Omission::new(
                feature="edge-radius",
                reason="DIN 127 B specifies an edge radius r; the square-cut section is the nominal representation and no edge radius is modeled",
              ),
            ],
          ),
        ).add_layer(body, name="body", color~),
      )
    }
  }
}
