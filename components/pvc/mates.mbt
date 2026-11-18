///|
/// unit3 normalizes a 3-vector, returning +Z for a zero vector.
fn unit3(v : @cad.Vec3) -> @cad.Vec3 {
  let (x, y, z) = v
  let len = (x * x + y * y + z * z).sqrt()
  if len < 1.0e-12 {
    (0.0, 0.0, 1.0)
  } else {
    (x / len, y / len, z / len)
  }
}

///|
/// frame_z_along returns a rotation mapping local +Z to `axis`.
fn frame_z_along(axis : @cad.Vec3) -> @common.Placement {
  let (x, y, z) = unit3(axis)
  let planar = (x * x + y * y).sqrt()
  if planar < 1.0e-12 {
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
/// tube_frame places a +Z tube so its `z = 0` face sits at `seat` and runs
/// along `axis_out`.
fn tube_frame(seat : @cad.Vec3, axis_out : @cad.Vec3) -> @common.Placement {
  let (x, y, z) = seat
  @common.Placement::compose(
    @common.Placement::translation(x, y, z),
    frame_z_along(axis_out),
  )
}

///|
/// socket_frame orientates a female bore mate at `seat` with outward mouth axis
/// `axis_out` and placement +Z pointing inward into the socket so
/// `snap_connectors` seats pipes outward through the mouth.
fn socket_frame(seat : @cad.Vec3, axis_out : @cad.Vec3) -> @common.Placement {
  let (ax, ay, az) = unit3(axis_out)
  tube_frame(seat, (-ax, -ay, -az))
}

///|
/// add_origin attaches the nominal `origin` datum at (0, 0, 0).
fn add_origin(component : @common.Component) -> @common.Component {
  component.with_connector_unchecked(
    @common.MateConnector::new(
      "origin",
      placement=@common.Placement::identity(),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      description="fitting or pipe datum origin",
    ),
  )
}

///|
/// add_pvc_socket attaches a female CylindricalBore mate at the pipe-stop
/// seat and a PlaneFace mouth mate at the opening face.
fn add_pvc_socket(
  component : @common.Component,
  size : PvcSize,
  socket_name : String,
  mouth_name : String,
  seat : @cad.Vec3,
  axis : @cad.Vec3,
  depth_mm : Double,
) -> @common.Component {
  let (ux, uy, uz) = unit3(axis)
  let (sx, sy, sz) = seat
  let mouth = (sx + depth_mm * ux, sy + depth_mm * uy, sz + depth_mm * uz)
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      socket_name,
      placement=socket_frame(seat, (ux, uy, uz)),
      axis=(ux, uy, uz),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=size.socket_bore_mm,
      depth_mm~,
      fit=@cad.Fit::Close,
      description="PVC socket bore; origin at internal pipe stop, axis out of mouth",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      mouth_name,
      placement=tube_frame(mouth, (ux, uy, uz)),
      axis=(ux, uy, uz),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=size.socket_outer_mm,
      description="PVC socket entrance rim plane facing outward",
    ),
  )
}

///|
/// add_pipe_connectors attaches `end-a` (-Z at z = 0) and `end-b` (+Z at
/// z = length_mm) CylindricalShaft connectors suitable for seating into any
/// PVC socket.
fn add_pipe_connectors(
  component : @common.Component,
  size : PvcSize,
  length_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-a",
      placement=@common.Placement::rotation_x(180.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=size.pipe_od_mm,
      depth_mm=size.socket_depth_mm,
      fit=@cad.Fit::Close,
      description="pipe spigot end at z = 0; outward axis -Z",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=size.pipe_od_mm,
      depth_mm=size.socket_depth_mm,
      fit=@cad.Fit::Close,
      description="pipe spigot end at z = length; outward axis +Z",
    ),
  )
}
