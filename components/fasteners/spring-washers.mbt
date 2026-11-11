///|
/// DIN 127 B spring washers are split helical rings. The section is a
/// radial-vertical rectangle, so the ring is built as a rectangular profile
/// swept along a helix; the two square-cut end faces leave the split gap.
///
/// The helix cannot be an analytic quadric surface, so the sweep is sampled
/// into chords per turn and the deviation is recorded in the feature record.
/// The DIN 127 edge radius `r` is not modeled.

///|
/// DIN127_COVERAGE_TURNS is the fraction of a turn occupied by the strip.
/// The remaining 4.5% (about 16 degrees) is the split gap.
let din127_coverage_turns : Double = 0.955

///|
/// DIN127_START_ANGLE_DEG rotates the sweep so the split gap is centered on
/// the +X axis, matching the downloaded reference orientation.
let din127_start_angle_deg : Double = 8.0

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
        pos=(0.0, 0.0, thickness / 2.0),
        size_per_turn=(radius_mid, radius_mid, pitch),
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
      let body = @cad.SweptProfile::new(path~, profile~, straight_outline=false)
      let deviation = @common.chord_deviation(r_outer, segments)
      Ok(
        @common.Component::new(
          name="DIN127-\{dims.size.designation()}",
          metadata=spec.metadata(),
          description="DIN 127 B spring washer, form B: a helical split ring with a rectangular radial-vertical section, square-cut ends, and a split gap of about 16 degrees. The helix is sampled into \{segments} chords per turn; the DIN edge radius r is not modeled.",
          features=@common.FeatureRecord::new(
            modeled=["rectangular-section", "split-gap", "end-faces"],
            approximated=[
              @common.Approximation::new(
                feature="helical-body",
                kind=@common.ApproximationKind::SweptSpline,
                deviation_mm=deviation,
                control="segments_per_turn=\{segments}",
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
