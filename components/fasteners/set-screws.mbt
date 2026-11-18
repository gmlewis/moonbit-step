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
/// Detailed DIN 916 cup-point geometry measured from the reference family:
/// - cup rim radius = 0.548 r (so the 59 deg semi-angle cup cone meets the
///   45 deg outer bevel at the cup edge),
/// - socket-end outer chamfer = 55 deg semi-angle reducing the outer radius by
///   0.10 d,
/// - socket countersink = 45 deg semi-angle, drill floor = 60 deg semi-angle.
const CUP_POINT_DETAILED_RIM_RATIO : Double = 0.548

///|
const CUP_POINT_CUP_CONE_HALF_ANGLE_DEG : Double = 59.0

///|
const CUP_POINT_TOP_CHAMFER_DR_RATIO : Double = 0.10

///|
const CUP_POINT_TOP_CHAMFER_HALF_ANGLE_DEG : Double = 55.0

///|
const CUP_POINT_SOCKET_RIM_ANGLE_DEG : Double = 45.0

///|
const CUP_POINT_SOCKET_FLOOR_ANGLE_DEG : Double = 60.0

///|
/// din916_cup_point_set_screw builds a DIN 916 hexagon socket set screw with a
/// cup point.
///
/// The point end is at z = 0 and the socket end at z = L. At `Simplified` detail
/// the body is a plain nominal cylinder with a cylindrical cup recess and a
/// flat-bottomed hexagonal socket. At `Detailed` and above the point carries a
/// 118-degree (59-degree semi-angle) conical cup recess and a 45-degree outer
/// point bevel, the socket end carries a 55-degree outer chamfer, and the hex
/// socket is bounded by a 45-degree countersink and a 120-degree (60-degree
/// semi-angle) drill point. At `FullyModeled` (or `threads=Helical`) the core
/// uses the ISO 68-1 minor diameter with an external helical thread ridge.
pub fn din916_cup_point_set_screw(
  size : @standards.MetricSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  orient_to_reference~ : Bool = false,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @standards.din916_spec(size, length_mm) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let d = dims.size.nominal_diameter_mm()
      let r = d / 2.0
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
      let outer_r = if threaded {
        external_thread_root_radius_mm(dims.thread)
      } else {
        r
      }
      let detailed = policy.include_small_features
      let short_socket = cup_point_round(
        CUP_POINT_SOCKET_SHORT_FRACTION * spec.length_mm,
      )
      let socket_depth = if dims.socket_depth_mm < short_socket {
        dims.socket_depth_mm
      } else {
        short_socket
      }
      let floor_z = spec.length_mm - socket_depth
      let cup_r = if detailed {
        CUP_POINT_DETAILED_RIM_RATIO * r
      } else {
        CUP_POINT_CUP_DIAMETER_RATIO * d / 2.0
      }
      let cup_depth = if detailed {
        cup_r / @math.tan(CUP_POINT_CUP_CONE_HALF_ANGLE_DEG * @math.PI / 180.0)
      } else {
        let cup_by_diameter = CUP_POINT_CUP_DEPTH_RATIO * d
        let cup_by_length = CUP_POINT_CUP_DEPTH_LENGTH_RATIO * spec.length_mm
        if cup_by_diameter < cup_by_length {
          cup_by_diameter
        } else {
          cup_by_length
        }
      }
      let point_bevel_h = if detailed { outer_r - cup_r } else { 0.0 }
      let r_corner = dims.socket_across_flats_mm / Double::sqrt(3.0)
      let top_chamfer_dr = if detailed {
        let nominal_dr = CUP_POINT_TOP_CHAMFER_DR_RATIO * d
        let max_dr = (outer_r - r_corner) * 0.25
        if outer_r - nominal_dr > r_corner + 0.02 {
          nominal_dr
        } else if max_dr > 0.02 {
          max_dr
        } else {
          0.0
        }
      } else {
        0.0
      }
      let top_chamfer_h = top_chamfer_dr /
        @math.tan(CUP_POINT_TOP_CHAMFER_HALF_ANGLE_DEG * @math.PI / 180.0)
      let r_top = outer_r - top_chamfer_dr
      let drill_cone_h = dims.socket_across_flats_mm /
        2.0 /
        @math.tan(CUP_POINT_SOCKET_FLOOR_ANGLE_DEG * @math.PI / 180.0)
      let socket_floor_z = if detailed {
        floor_z - drill_cone_h
      } else {
        floor_z
      }
      if cup_depth <= 0.0 ||
        cup_r <= 0.0 ||
        cup_r >= outer_r ||
        socket_depth <= 0.0 ||
        socket_floor_z <= cup_depth ||
        point_bevel_h + top_chamfer_h >= spec.length_mm {
        return Err(
          @common.SpecError::InvalidDimension(
            "DIN 916 cup or socket does not fit the requested length",
          ),
        )
      }
      let pts : Array[@cad.Vec2] = if detailed {
        let arr : Array[@cad.Vec2] = [
          (0.0, cup_depth),
          (cup_r, 0.0),
          (outer_r, point_bevel_h),
        ]
        if top_chamfer_dr > 0.0 && top_chamfer_h > 0.0 {
          arr.push((outer_r, spec.length_mm - top_chamfer_h))
          arr.push((r_top, spec.length_mm))
        } else {
          arr.push((outer_r, spec.length_mm))
        }
        arr.push((0.0, spec.length_mm))
        arr
      } else {
        [
          (0.0, cup_depth),
          (cup_r, cup_depth),
          (cup_r, 0.0),
          (outer_r, 0.0),
          (outer_r, spec.length_mm),
          (0.0, spec.length_mm),
        ]
      }
      let body = @cad.RevolvedProfile::polyline(pts)
      let rim_apex = spec.length_mm -
        r_corner / @math.tan(CUP_POINT_SOCKET_RIM_ANGLE_DEG * @math.PI / 180.0)
      let use_conical_socket = detailed &&
        r_top > r_corner + 0.01 &&
        socket_floor_z < rim_apex - 0.01
      let socket = if use_conical_socket {
        @cad.SocketedSolid::new(
          body,
          dims.socket_across_flats_mm,
          socket_floor_z,
          conical=true,
          rim_angle_deg=CUP_POINT_SOCKET_RIM_ANGLE_DEG,
          floor_angle_deg=CUP_POINT_SOCKET_FLOOR_ANGLE_DEG,
        )
      } else {
        @cad.SocketedSolid::new(body, dims.socket_across_flats_mm, floor_z)
      }
      let modeled = if detailed {
        [
          "body", "cup-point-cone", "cup-point-bevel", "outer-chamfer", "outer-cylinder",
          "hex-socket", "socket-lead-in", "socket-drill-cone",
        ]
      } else {
        ["body", "cup-point", "outer-cylinder", "hex-socket"]
      }
      if threaded {
        modeled.push("helical-thread")
      }
      let omitted = if threaded {
        if detailed {
          []
        } else {
          [
            @common.Omission::new(
              feature="socket-lead-in",
              reason="Simplified mode models the sharp socket edge without countersink or chamfer",
            ),
          ]
        }
      } else {
        let items = [
          @common.Omission::new(
            feature="thread",
            reason="plain envelope at Simplified/Detailed; FullyModeled adds the ISO 68-1 helical ridge",
          ),
        ]
        if !detailed {
          items.push(
            @common.Omission::new(
              feature="socket-lead-in",
              reason="Simplified mode models the sharp socket edge without countersink or chamfer",
            ),
          )
        }
        items
      }
      let features = @common.FeatureRecord::new(
        modeled~,
        approximated=[],
        omitted~,
      )
      let mut component = @common.Component::new(
        name="DIN916-\{dims.size.designation()}x\{format_length(spec.length_mm)}",
        metadata=spec.metadata(),
        description=if detailed {
          "Hexagon socket set screw with a cup point: one closed solid with a 118-degree conical cup recess, 45-degree point bevel, 55-degree socket-end outer chamfer, and a blind hexagonal socket with 45-degree countersink and 120-degree conical drill point." +
          thread_note(thread_rep)
        } else {
          "Hexagon socket set screw with a cup point: one closed solid with a cylindrical shank, a blind cylindrical cup recess in the point, and a blind hexagonal socket in the top face." +
          thread_note(thread_rep)
        },
        features~,
      ).add_layer(socket.as_shape(), name="body", color~)
      if threaded {
        let thread_span = spec.length_mm - point_bevel_h - top_chamfer_h
        match
          external_thread_ridge(
            dims.thread,
            thread_span,
            segments_per_turn=policy.segments_per_turn,
          ) {
          Some(ridge) =>
            component = component.add_layer(
              ridge,
              name="helical-thread",
              color~,
              placement=@common.Placement::translation(0.0, 0.0, point_bevel_h),
            )
          None => ()
        }
      }
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
