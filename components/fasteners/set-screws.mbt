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
      Ok(
        with_set_screw_connectors(
          component,
          d,
          spec.length_mm,
          point_z_mm=0.0,
          top_z_mm=spec.length_mm,
        ),
      )
    }
  }
}

///|
/// Cup-point recess proportions. The reference family uses a cup diameter of
/// 0.44 d and a cup depth of 0.25 d, reduced on short screws to 0.15 of the
/// length so the cup does not meet the socket.
const CUP_POINT_CUP_DIAMETER_RATIO : Double = 0.44

///|
const CUP_POINT_CUP_DEPTH_RATIO : Double = 0.25

///|
const CUP_POINT_CUP_DEPTH_LENGTH_RATIO : Double = 0.15

///|
/// Short screws reduce the nominal socket depth to 0.26 of the length (rounded
/// to 0.1 mm in the reference family).
const CUP_POINT_SOCKET_SHORT_FRACTION : Double = 0.26

///|
const CUP_POINT_ROUNDING_MM : Double = 0.1

///|
fn cup_point_round(value : Double) -> Double {
  (value / CUP_POINT_ROUNDING_MM).round() * CUP_POINT_ROUNDING_MM
}

///|
/// din916_cup_point_set_screw builds a DIN 916 hexagon socket set screw with a
/// cup point.
///
/// The point end is at z = 0 and the socket end at z = L. The cup is a blind
/// cylindrical recess in the point; the socket is a blind hexagonal pocket at
/// the top. The body is one closed solid of revolution (cup floor, cup wall,
/// point annulus, cylindrical shank, top cap replaced by the socket).
pub fn din916_cup_point_set_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @standards.din916_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let d = dims.size.nominal_diameter_mm()
      let r = d / 2.0
      let cup_r = CUP_POINT_CUP_DIAMETER_RATIO * d / 2.0
      let cup_by_diameter = CUP_POINT_CUP_DEPTH_RATIO * d
      let cup_by_length = CUP_POINT_CUP_DEPTH_LENGTH_RATIO * spec.length_mm
      let cup_depth = if cup_by_diameter < cup_by_length {
        cup_by_diameter
      } else {
        cup_by_length
      }
      let short_socket = cup_point_round(
        CUP_POINT_SOCKET_SHORT_FRACTION * spec.length_mm,
      )
      let socket_depth = if dims.socket_depth_mm < short_socket {
        dims.socket_depth_mm
      } else {
        short_socket
      }
      let floor_z = spec.length_mm - socket_depth
      if cup_depth <= 0.0 ||
        cup_r <= 0.0 ||
        cup_r >= r ||
        socket_depth <= 0.0 ||
        floor_z <= cup_depth {
        return Err(
          @common.SpecError::InvalidDimension(
            "DIN 916 cup or socket does not fit the requested length",
          ),
        )
      }
      let body = @cad.RevolvedProfile::polyline([
        (0.0, cup_depth),
        (cup_r, cup_depth),
        (cup_r, 0.0),
        (r, 0.0),
        (r, spec.length_mm),
        (0.0, spec.length_mm),
      ])
      let socket = @cad.SocketedSolid::new(
        body,
        dims.socket_across_flats_mm,
        floor_z,
      )
      let features = @common.FeatureRecord::new(
        modeled=["body", "cup-point", "outer-cylinder", "hex-socket"],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="thread",
            reason="plain envelope; the ISO 68-1 thread form is not modeled",
          ),
          @common.Omission::new(
            feature="socket-lead-in",
            reason="DIN 916 does not specify a socket lead-in; the sharp socket edge is modeled",
          ),
        ],
      )
      let component = @common.Component::new(
        name="DIN916-\{dims.size.designation()}x\{format_length(spec.length_mm)}",
        metadata=spec.metadata(),
        description="Hexagon socket set screw with a cup point: one closed solid with a cylindrical shank, a blind cylindrical cup recess in the point, and a blind hexagonal socket in the top face.",
        features~,
      ).add_layer(socket.as_shape(), name="body", color~)
      if orient_to_reference {
        Ok(
          with_set_screw_connectors(
            component.rotate_x(180.0).translate(z=spec.length_mm),
            d,
            spec.length_mm,
            point_z_mm=spec.length_mm,
            top_z_mm=0.0,
          ),
        )
      } else {
        Ok(
          with_set_screw_connectors(
            component,
            d,
            spec.length_mm,
            point_z_mm=0.0,
            top_z_mm=spec.length_mm,
          ),
        )
      }
    }
  }
}
