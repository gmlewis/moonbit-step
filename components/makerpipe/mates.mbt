///|
/// unit3 normalizes a 3-vector, returning +Z for a zero vector.
fn unit3(v : @cad.Vec3) -> @cad.Vec3 {
  let (x, y, z) = v
  let len = (x * x + y * y + z * z).sqrt()
  if len < @step.TOL_1E12 {
    (0.0, 0.0, 1.0)
  } else {
    (x / len, y / len, z / len)
  }
}

///|
/// frame_z_along returns a rotation that maps local +Z to `axis`.
///
/// This is used for a socket tube built along +Z: the tube grows from its seat
/// toward the mouth along the branch axis.
fn frame_z_along(axis : @cad.Vec3) -> @common.Placement {
  let (x, y, z) = unit3(axis)
  let planar = (x * x + y * y).sqrt()
  if planar < @step.TOL_1E12 {
    if z >= 0.0 {
      @common.Placement::identity()
    } else {
      @common.Placement::rotation_x(180.0)
    }
  } else {
    let clamped = if z > 1.0 { 1.0 } else if z < -1.0 { -1.0 } else { z }
    let angle = @math.acos(clamped)
    @common.Placement::rotation_axis_angle(
      (-y / planar, x / planar, 0.0),
      angle,
    )
  }
}

///|
/// tube_frame places a +Z tube so its `z = 0` end is at `seat` and its axis
/// runs along `axis_out`.
fn tube_frame(seat : @cad.Vec3, axis_out : @cad.Vec3) -> @common.Placement {
  let (x, y, z) = seat
  @common.Placement::compose(
    @common.Placement::translation(x, y, z),
    frame_z_along(axis_out),
  )
}

///|
/// socket_frame places a socket mate.
///
/// The bore axis points out of the mouth (`axis_out`), per
/// `MateKind::CylindricalBore`, while the placement's +Z points **into** the
/// socket. `snap_connectors` aligns placement frames, and a pipe end's body
/// extends along -placement-Z, so this makes a snapped pipe extend outward
/// through the mouth with no caller offset.
fn socket_frame(seat : @cad.Vec3, axis_out : @cad.Vec3) -> @common.Placement {
  let (x, y, z) = axis_out
  tube_frame(seat, (-x, -y, -z))
}

///|
/// frame_x_along_xz returns a rotation about +Y that maps local +X to an axis
/// in the XZ plane. It is used for the flat hinge straps, whose local +Y must
/// stay the pin axis.
fn frame_x_along_xz(axis : @cad.Vec3) -> @common.Placement {
  let (x, _, z) = unit3(axis)
  let angle_deg = @math.atan2(z, x) * 180.0 / @math.PI
  @common.Placement::rotation_y(-angle_deg)
}

///|
/// frame_x_to_y_z_to_x returns the 120 degree rotation about (1, 1, 1).
///
/// It maps local +X to +Y, +Y to +Z, and +Z to +X. The T run sleeve is drawn
/// in the XY plane and extruded along +Z; this rotation turns it into a sleeve
/// along +X whose profile x-axis is +Y and profile y-axis is +Z.
fn frame_x_to_y_z_to_x() -> @common.Placement {
  @common.Placement::rotation_axis_angle((1.0, 1.0, 1.0), 2.0 * @math.PI / 3.0)
}
