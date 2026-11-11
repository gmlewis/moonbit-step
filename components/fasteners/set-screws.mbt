///|
/// din913 builds a DIN 913 hexagon socket set screw with a flat point.
///
/// The point end is at z = 0 and the screw runs along +Z. The body is one
/// closed solid of revolution (flat point, 90-degree point cone, cylindrical
/// shank) with a blind hexagonal socket. The socket uses the DIN 913 upper
/// across-flats limit so a standard hex key fits; the socket depth is the
/// reference `t`.
pub fn din913(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din913_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let d = dims.size.nominal_diameter_mm()
      let r = d / 2.0
      let point_r = dims.point_flat_diameter_mm / 2.0
      let semi_angle = dims.point_angle_deg / 2.0 * @math.PI / 180.0
      let cone_h = (r - point_r) / @math.tan(semi_angle)
      let floor_z = spec.length_mm - dims.socket_depth_mm
      if point_r <= 0.0 || point_r >= r || cone_h <= 0.0 || floor_z <= cone_h {
        return Err(
          @common.SpecError::InvalidDimension(
            "DIN 913 point or socket depth does not fit the requested length",
          ),
        )
      }
      let body = @cad.RevolvedProfile::polyline([
        (0.0, 0.0),
        (point_r, 0.0),
        (r, cone_h),
        (r, spec.length_mm),
        (0.0, spec.length_mm),
      ])
      let socket = @cad.SocketedSolid::new(
        body,
        dims.socket_across_flats_max_mm,
        floor_z,
      )
      let policy = @common.DetailPolicy::for_level(detail)
      let thread_rep = match threads {
        Some(t) => t
        None =>
          match detail {
            @common.DetailLevel::FullyModeled =>
              @common.ThreadRepresentation::Helical
            _ => @common.ThreadRepresentation::None
          }
      }
      let threaded = thread_rep is @common.ThreadRepresentation::Helical
      let modeled = if threaded {
        [
          "body", "point-flat", "point-cone", "outer-cylinder", "hex-socket", "helical-thread",
        ]
      } else {
        ["body", "point-flat", "point-cone", "outer-cylinder", "hex-socket"]
      }
      let omitted = if threaded {
        [
          @common.Omission::new(
            feature="socket-lead-in",
            reason="DIN 913 does not specify a socket lead-in; the sharp socket edge is modeled",
          ),
        ]
      } else {
        [
          @common.Omission::new(
            feature="thread",
            reason="plain envelope at Simplified/Detailed; the fully modeled level adds the ISO 68-1 helical ridge",
          ),
          @common.Omission::new(
            feature="socket-lead-in",
            reason="DIN 913 does not specify a socket lead-in; the sharp socket edge is modeled",
          ),
        ]
      }
      let mut component = @common.Component::new(
        name="DIN913-\{dims.size.designation()}x\{format_length(spec.length_mm)}",
        metadata=spec.metadata(),
        description="Single closed solid: a solid of revolution (flat point, 90-degree point cone, cylindrical shank) with a blind hexagonal socket cut into the top; six planar socket walls and a planar hexagonal floor bound the pocket. The socket uses the DIN 913 upper across-flats limit.",
        features=@common.FeatureRecord::new(modeled~, omitted~),
      ).add_layer(socket.as_shape(), name="body", color~)
      if threaded {
        match
          external_thread_ridge(
            dims.thread,
            spec.length_mm - cone_h,
            segments_per_turn=policy.segments_per_turn,
          ) {
          Some(ridge) =>
            component = component.add_layer(
              ridge,
              name="helical-thread",
              color~,
              placement=@common.Placement::translation(0.0, 0.0, cone_h),
            )
          None => ()
        }
      }
      Ok(component)
    }
  }
}
