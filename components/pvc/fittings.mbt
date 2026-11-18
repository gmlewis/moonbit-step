///|
/// Default PVC fitting center-stop wall length (mm), end-cap end-wall thickness
/// (mm), and outer/mouth chamfer leg at `Detailed`.
const PVC_STOP_LEN_MM : Double = 4.0

///|
const PVC_CAP_END_WALL_FACTOR : Double = 1.35

///|
const PVC_FITTING_CHAMFER_MM : Double = 0.5

///|
fn resolve_pvc_color(size : PvcSize, color : @cad.Rgb?) -> @cad.Rgb {
  match color {
    Some(c) => c
    None => pvc_default_color(size.schedule)
  }
}

///|
fn pvc_fitting_metadata(
  size : PvcSize,
  designation : String,
  family : String,
  detail : String,
) -> @common.Metadata {
  @common.Metadata::new(
    designation~,
    standard="ASTM D2466 Schedule 40 IPS socket fitting envelope",
    family~,
    size="\{size.trade_size} \{size.schedule.tag()}",
    material="molded rigid PVC",
    source="ASTM D1785 / D2466: socket bore \{@cad.fmt_double(size.socket_bore_mm, None)} mm, depth \{@cad.fmt_double(size.socket_depth_mm, None)} mm; \{detail}",
  )
}

///|
fn pvc_fitting_features(
  modeled : Array[String],
  approximated : Array[@common.Approximation],
) -> @common.FeatureRecord {
  @common.FeatureRecord::new(modeled~, approximated~, omitted=[
    @common.Omission::new(
      feature="draft-and-fillets",
      reason="injection-mold draft taper (about 0.5 deg) and external gusset fillets are represented by nominal cylindrical collars",
    ),
    @common.Omission::new(
      feature="pressure-rating",
      reason="geometry alone does not establish hydraulic pressure rating",
    ),
  ])
}

///|
fn detailed_chamfer(size : PvcSize, detail : @common.DetailLevel) -> Double {
  let policy = @common.DetailPolicy::for_level(detail)
  if !policy.include_small_features {
    return 0.0
  }
  let wall = (size.socket_outer_mm - size.socket_bore_mm) / 2.0
  let max_c = wall * 0.25
  if PVC_FITTING_CHAMFER_MM < max_c {
    PVC_FITTING_CHAMFER_MM
  } else {
    max_c
  }
}

///|
/// pvc_socket_sleeve_shape builds one revolved socket sleeve along +Z starting
/// at `z = 0` (body origin or seat transition) through `total_len` (`reach +
/// socket_depth`), with internal bore `through_bore_mm` up to `reach` and
/// `socket_bore_mm` from `reach` to `total_len` (forming a pipe-stop shoulder).
fn pvc_socket_sleeve_shape(
  size : PvcSize,
  reach_mm : Double,
  chamfer_mm : Double,
) -> @cad.Shape {
  let r_in_flow = size.through_bore_mm / 2.0
  let r_in_sock = size.socket_bore_mm / 2.0
  let r_out = size.socket_outer_mm / 2.0
  let z_seat = reach_mm
  let z_mouth = reach_mm + size.socket_depth_mm
  let pts : Array[@cad.Vec2] = [(r_in_flow, 0.0)]
  if z_seat > 1.0e-6 {
    pts.push((r_in_flow, z_seat))
  }
  pts.push((r_in_sock, z_seat))
  if chamfer_mm > 0.0 {
    pts.push((r_in_sock, z_mouth - chamfer_mm))
    pts.push((r_in_sock + chamfer_mm, z_mouth))
    pts.push((r_out - chamfer_mm, z_mouth))
    pts.push((r_out, z_mouth - chamfer_mm))
  } else {
    pts.push((r_in_sock, z_mouth))
    pts.push((r_out, z_mouth))
  }
  pts.push((r_out, 0.0))
  @cad.RevolvedProfile::polyline(pts, closed=true).as_shape()
}

///|
/// elbow_bend_barrel_od returns the curved sweep barrel outside diameter between
/// the thicker socket collars so the elbow shows realistic molded socket hubs.
fn elbow_bend_barrel_od(size : PvcSize) -> Double {
  let barrel_wall = (size.pipe_od_mm - size.through_bore_mm) / 2.0 * 1.15
  let od = size.through_bore_mm + 2.0 * barrel_wall
  if od < size.socket_outer_mm - 0.5 {
    od
  } else {
    size.socket_outer_mm - 0.5
  }
}

///|
/// coupling builds a straight slip-to-slip PVC coupling centered on z = 0 with
/// an internal pipe-stop ridge (`though_bore` over `PVC_STOP_LEN_MM`).
pub fn coupling(
  size : PvcSize,
  stop_length_mm~ : Double = PVC_STOP_LEN_MM,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  if !@common.is_finite(stop_length_mm) || stop_length_mm <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "PVC coupling internal stop length must be positive",
      ),
    )
  }
  let c = detailed_chamfer(size, detail)
  let half_stop = stop_length_mm / 2.0
  let half_len = half_stop + size.socket_depth_mm
  let r_flow = size.through_bore_mm / 2.0
  let r_sock = size.socket_bore_mm / 2.0
  let r_out = size.socket_outer_mm / 2.0
  let pts : Array[@cad.Vec2] = [
    (r_flow, -half_stop),
    (r_flow, half_stop),
    (r_sock, half_stop),
  ]
  if c > 0.0 {
    pts.push((r_sock, half_len - c))
    pts.push((r_sock + c, half_len))
    pts.push((r_out - c, half_len))
    pts.push((r_out, half_len - c))
    pts.push((r_out, -half_len + c))
    pts.push((r_out - c, -half_len))
    pts.push((r_sock + c, -half_len))
    pts.push((r_sock, -half_len + c))
  } else {
    pts.push((r_sock, half_len))
    pts.push((r_out, half_len))
    pts.push((r_out, -half_len))
    pts.push((r_sock, -half_len))
  }
  pts.push((r_sock, -half_stop))
  let body = @cad.RevolvedProfile::polyline(pts, closed=true).as_shape()
  let modeled = ["socket-a", "socket-b", "pipe-stop-ridge"]
  if c > 0.0 {
    modeled.push("mouth-chamfers")
  }
  let part_color = resolve_pvc_color(size, color)
  let base = @common.Component::new(
    name="pvc-coupling-\{size.trade_size}-\{size.schedule.tag().to_lower()}",
    metadata=pvc_fitting_metadata(
      size,
      "PVC coupling \{size.trade_size} in (\{size.schedule.label()})",
      "PVC coupling",
      "internal stop width \{@cad.fmt_double(stop_length_mm, None)} mm",
    ),
    description="Straight PVC slip-to-slip socket coupling centered at z = 0 with internal pipe-stop ridge.",
    features=pvc_fitting_features(modeled, []),
  ).add_layer(body, name="body", color=part_color)
  let with_a = add_pvc_socket(
    base,
    size,
    "socket-a",
    "mouth-a",
    (0.0, 0.0, -half_stop),
    (0.0, 0.0, -1.0),
    size.socket_depth_mm,
  )
  let with_b = add_pvc_socket(
    with_a,
    size,
    "socket-b",
    "mouth-b",
    (0.0, 0.0, half_stop),
    (0.0, 0.0, 1.0),
    size.socket_depth_mm,
  )
  Ok(
    add_origin(
      with_b.with_connector_unchecked(
        @common.MateConnector::new(
          "seam",
          placement=@common.Placement::identity(),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::Datum,
          description="center datum plane of the internal pipe stop",
        ),
      ),
    ),
  )
}

///|
/// cap builds a closed PVC socket end cap whose closed face lies at z = 0 and
/// whose socket mouth opens toward +Z.
pub fn cap(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let end_wall = size.pipe_wall_mm * PVC_CAP_END_WALL_FACTOR
  let total_len = end_wall + size.socket_depth_mm
  let r_sock = size.socket_bore_mm / 2.0
  let r_out = size.socket_outer_mm / 2.0
  let c = detailed_chamfer(size, detail)
  let pts : Array[@cad.Vec2] = [(0.0, 0.0)]
  if c > 0.0 {
    pts.push((r_out - c, 0.0))
    pts.push((r_out, c))
    pts.push((r_out, total_len - c))
    pts.push((r_out - c, total_len))
    pts.push((r_sock + c, total_len))
    pts.push((r_sock, total_len - c))
  } else {
    pts.push((r_out, 0.0))
    pts.push((r_out, total_len))
    pts.push((r_sock, total_len))
  }
  pts.push((r_sock, end_wall))
  pts.push((0.0, end_wall))
  let body = @cad.RevolvedProfile::polyline(pts).as_shape()
  let modeled = ["cap-end-wall", "socket"]
  if c > 0.0 {
    modeled.push("outer-chamfer")
  }
  let part_color = resolve_pvc_color(size, color)
  let comp = @common.Component::new(
      name="pvc-cap-\{size.trade_size}-\{size.schedule.tag().to_lower()}",
      metadata=pvc_fitting_metadata(
        size,
        "PVC cap \{size.trade_size} in (\{size.schedule.label()})",
        "PVC end cap",
        "closed end wall \{@cad.fmt_double(end_wall, None)} mm",
      ),
      description="Closed PVC slip end cap: solid end wall at z = 0 with a single female pipe socket opening along +Z.",
      features=pvc_fitting_features(modeled, []),
    )
    .add_layer(body, name="body", color=part_color)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "cap-face",
        placement=@common.Placement::rotation_x(180.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=size.socket_outer_mm,
        description="closed outer end face at z = 0",
      ),
    )
  Ok(
    add_origin(
      add_pvc_socket(
        comp,
        size,
        "socket",
        "mouth",
        (0.0, 0.0, end_wall),
        (0.0, 0.0, 1.0),
        size.socket_depth_mm,
      ),
    ),
  )
}

///|
/// reducer_coupling builds a concentric reducing coupling joining `large` (-Z)
/// to `small` (+Z) with a tapered transition zone between internal pipe stops.
pub fn reducer_coupling(
  large : PvcSize,
  small : PvcSize,
  transition_mm~ : Double = 0.0,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  if large.pipe_od_mm <= small.pipe_od_mm {
    return Err(
      @common.InvalidParameter(
        "PVC reducer requires large size OD (\{large.trade_size}) > small size OD (\{small.trade_size})",
      ),
    )
  }
  let trans = if transition_mm > 0.0 {
    transition_mm
  } else {
    let raw = (large.socket_outer_mm - small.socket_outer_mm) * 0.9
    if raw > 6.0 {
      raw
    } else {
      6.0
    }
  }
  let half_t = trans / 2.0
  let z_a_mouth = -half_t - large.socket_depth_mm
  let z_b_mouth = half_t + small.socket_depth_mm
  let r_a_flow = large.through_bore_mm / 2.0
  let r_b_flow = small.through_bore_mm / 2.0
  let r_a_sock = large.socket_bore_mm / 2.0
  let r_b_sock = small.socket_bore_mm / 2.0
  let r_a_out = large.socket_outer_mm / 2.0
  let r_b_out = small.socket_outer_mm / 2.0
  let c = detailed_chamfer(small, detail)
  let pts : Array[@cad.Vec2] = [
    (r_a_flow, -half_t),
    (r_b_flow, half_t),
    (r_b_sock, half_t),
  ]
  if c > 0.0 {
    pts.push((r_b_sock, z_b_mouth - c))
    pts.push((r_b_sock + c, z_b_mouth))
    pts.push((r_b_out - c, z_b_mouth))
    pts.push((r_b_out, z_b_mouth - c))
  } else {
    pts.push((r_b_sock, z_b_mouth))
    pts.push((r_b_out, z_b_mouth))
  }
  pts.push((r_b_out, half_t))
  pts.push((r_a_out, -half_t))
  if c > 0.0 {
    pts.push((r_a_out, z_a_mouth + c))
    pts.push((r_a_out - c, z_a_mouth))
    pts.push((r_a_sock + c, z_a_mouth))
    pts.push((r_a_sock, z_a_mouth + c))
  } else {
    pts.push((r_a_out, z_a_mouth))
    pts.push((r_a_sock, z_a_mouth))
  }
  pts.push((r_a_sock, -half_t))
  let body = @cad.RevolvedProfile::polyline(pts, closed=true).as_shape()
  let modeled = ["large-socket", "small-socket", "conical-reducer-transition"]
  if c > 0.0 {
    modeled.push("mouth-chamfers")
  }
  let part_color = resolve_pvc_color(large, color)
  let comp = @common.Component::new(
    name="pvc-reducer-\{large.trade_size}-to-\{small.trade_size}",
    metadata=pvc_fitting_metadata(
      large,
      "PVC reducer coupling \{large.trade_size} x \{small.trade_size} in",
      "PVC reducer coupling",
      "reduces to \{small.trade_size} in",
    ),
    description="Concentric PVC reducer coupling from \{large.trade_size} in (-Z) to \{small.trade_size} in (+Z) with internal pipe stops at both ends.",
    features=pvc_fitting_features(modeled, []),
  ).add_layer(body, name="body", color=part_color)
  let with_a = add_pvc_socket(
    comp,
    large,
    "socket-a",
    "mouth-a",
    (0.0, 0.0, -half_t),
    (0.0, 0.0, -1.0),
    large.socket_depth_mm,
  )
  let with_b = add_pvc_socket(
    with_a,
    small,
    "socket-b",
    "mouth-b",
    (0.0, 0.0, half_t),
    (0.0, 0.0, 1.0),
    small.socket_depth_mm,
  )
  Ok(add_origin(with_b))
}

///|
/// elbow_bend_shape builds the analytic toroidal hollow bend for a 45- or
/// 90-degree PVC elbow in the XY plane around +Z (sweeping from `(R, 0, 0)` along
/// `+Y`), to be placed into the XZ plane at `(0, 0, -lay_mm)`.
fn elbow_bend_shape(
  size : PvcSize,
  angle_deg : Double,
  lay_mm : Double,
) -> (@cad.Shape, @common.Placement) {
  let alpha = angle_deg * @math.PI / 180.0
  let r_bend = lay_mm / @math.tan(alpha / 2.0)
  let bend = @cad.ToroidalBend::new(
    r_bend,
    elbow_bend_barrel_od(size),
    angle_deg,
    inner_diameter_mm=size.through_bore_mm,
  )
  let placement = @common.Placement::at(
    r_bend,
    0.0,
    -lay_mm,
    rx=90.0,
    ry=0.0,
    rz=180.0,
  )
  (bend, placement)
}

///|
/// pvc_elbow_collar_shape builds a socket collar with a small overlap skirt
/// buried strictly inside the swept bend wall (`r_mid`) so OCCT `bfuse` joins
/// the collar and bend without coincident cylindrical inner bore faces.
fn pvc_elbow_collar_shape(
  size : PvcSize,
  overlap_mm : Double,
  chamfer_mm : Double,
) -> @cad.Shape {
  let r_in_flow = size.through_bore_mm / 2.0
  let r_in_sock = size.socket_bore_mm / 2.0
  let r_mid = (r_in_flow + r_in_sock) / 2.0
  let r_out = size.socket_outer_mm / 2.0
  let z_seat = overlap_mm
  let z_mouth = overlap_mm + size.socket_depth_mm
  let pts : Array[@cad.Vec2] = [
    (r_mid, 0.0),
    (r_mid, z_seat),
    (r_in_sock, z_seat),
  ]
  if chamfer_mm > 0.0 {
    pts.push((r_in_sock, z_mouth - chamfer_mm))
    pts.push((r_in_sock + chamfer_mm, z_mouth))
    pts.push((r_out - chamfer_mm, z_mouth))
    pts.push((r_out, z_mouth - chamfer_mm))
  } else {
    pts.push((r_in_sock, z_mouth))
    pts.push((r_out, z_mouth))
  }
  pts.push((r_out, 0.0))
  @cad.RevolvedProfile::polyline(pts, closed=true).as_shape()
}

///|
/// elbow_fitting builds a 45- or 90-degree socket-to-socket PVC elbow whose
/// bend corner datum is at (0, 0, 0).
fn elbow_fitting(
  size : PvcSize,
  angle_deg : Double,
  lay_mm : Double,
  kind_tag : String,
  detail : @common.DetailLevel,
  color : @cad.Rgb?,
) -> Result[@common.Component, @common.SpecError] {
  let alpha = angle_deg * @math.PI / 180.0
  let seat_a : @cad.Vec3 = (0.0, 0.0, -lay_mm)
  let axis_a : @cad.Vec3 = (0.0, 0.0, -1.0)
  let axis_b : @cad.Vec3 = (@math.sin(alpha), 0.0, @math.cos(alpha))
  let seat_b : @cad.Vec3 = (
    lay_mm * axis_b.0,
    lay_mm * axis_b.1,
    lay_mm * axis_b.2,
  )
  let c = detailed_chamfer(size, detail)
  let overlap = 0.4
  let socket_shape = pvc_elbow_collar_shape(size, overlap, c)
  let (bend, bend_placement) = elbow_bend_shape(size, angle_deg, lay_mm)
  let collar_a_pos : @cad.Vec3 = (
    seat_a.0 - overlap * axis_a.0,
    seat_a.1 - overlap * axis_a.1,
    seat_a.2 - overlap * axis_a.2,
  )
  let collar_b_pos : @cad.Vec3 = (
    seat_b.0 - overlap * axis_b.0,
    seat_b.1 - overlap * axis_b.1,
    seat_b.2 - overlap * axis_b.2,
  )
  let part_color = resolve_pvc_color(size, color)
  let modeled = ["swept-hollow-bend", "socket-a", "socket-b", "pipe-stops"]
  if c > 0.0 {
    modeled.push("mouth-chamfers")
  }
  let comp = @common.Component::new(
      name="pvc-\{kind_tag}-\{size.trade_size}-\{size.schedule.tag().to_lower()}",
      metadata=pvc_fitting_metadata(
        size,
        "PVC \{@cad.fmt_double(angle_deg, None)} deg elbow \{size.trade_size} in (\{size.schedule.label()})",
        "PVC \{@cad.fmt_double(angle_deg, None)}-degree elbow",
        "center-to-seat \{@cad.fmt_double(lay_mm, None)} mm",
      ),
      description="Analytic toroidal hollow \{@cad.fmt_double(angle_deg, None)}-degree PVC socket elbow in the XZ plane with socket collars at both ends.",
      features=pvc_fitting_features(modeled, []),
    )
    .add_layer(bend, name="bend", color=part_color, placement=bend_placement)
    .add_layer(
      socket_shape,
      name="socket-a-collar",
      color=part_color,
      placement=tube_frame(collar_a_pos, axis_a),
    )
    .add_layer(
      socket_shape,
      name="socket-b-collar",
      color=part_color,
      placement=tube_frame(collar_b_pos, axis_b),
    )
  let with_a = add_pvc_socket(
    comp,
    size,
    "socket-a",
    "mouth-a",
    seat_a,
    axis_a,
    size.socket_depth_mm,
  )
  let with_b = add_pvc_socket(
    with_a,
    size,
    "socket-b",
    "mouth-b",
    seat_b,
    axis_b,
    size.socket_depth_mm,
  )
  Ok(add_origin(with_b))
}

///|
/// elbow_90 builds a standard 90-degree PVC socket elbow in the XZ plane.
pub fn elbow_90(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  elbow_fitting(
    size,
    90.0,
    size.center_to_seat_90_mm,
    "elbow-90",
    detail,
    color,
  )
}

///|
/// elbow_45 builds a standard 45-degree PVC socket elbow in the XZ plane.
pub fn elbow_45(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  elbow_fitting(
    size,
    45.0,
    size.center_to_seat_45_mm,
    "elbow-45",
    detail,
    color,
  )
}

///|
/// multi_port_fitting builds a symmetric multi-branch PVC fitting (`tee`,
/// `cross`, `corner_3way`, `four_way_tee`, `five_way`) as one trimmed analytic
/// `PipeJunction` solid with open intersecting bores, pipe-stop shoulders, and
/// socket connectors along each port's outward unit axis.
fn multi_port_fitting(
  size : PvcSize,
  kind_tag : String,
  designation : String,
  family : String,
  description : String,
  ports : Array[(String, String, @cad.Vec3)],
  detail : @common.DetailLevel,
  color : @cad.Rgb?,
) -> Result[@common.Component, @common.SpecError] {
  let lay = size.center_to_seat_90_mm
  let c = detailed_chamfer(size, detail)
  let axes = ports.map(fn(p) { unit3(p.2) })
  let body = @cad.PipeJunction::new(
    axes,
    size.socket_outer_mm,
    size.through_bore_mm,
    size.socket_bore_mm,
    lay,
    size.socket_depth_mm,
    mouth_chamfer_mm=c,
  )
  let part_color = resolve_pvc_color(size, color)
  let modeled : Array[String] = ["junction-hub", "pipe-stops"]
  for port in ports {
    modeled.push(port.0)
  }
  if c > 0.0 {
    modeled.push("mouth-chamfers")
  }
  let mut comp = @common.Component::new(
    name="pvc-\{kind_tag}-\{size.trade_size}-\{size.schedule.tag().to_lower()}",
    metadata=pvc_fitting_metadata(
      size,
      designation,
      family,
      "center-to-seat \{@cad.fmt_double(lay, None)} mm",
    ),
    description~,
    features=pvc_fitting_features(modeled, []),
  ).add_layer(body, name="body", color=part_color)
  for port in ports {
    let (sock_name, mouth_name, raw_axis) = port
    let u = unit3(raw_axis)
    let seat = (lay * u.0, lay * u.1, lay * u.2)
    comp = add_pvc_socket(
      comp,
      size,
      sock_name,
      mouth_name,
      seat,
      u,
      size.socket_depth_mm,
    )
  }
  Ok(add_origin(comp))
}

///|
/// tee builds a 3-way PVC tee (through run along Z, 90-degree branch along +X).
pub fn tee(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  multi_port_fitting(
    size,
    "tee",
    "PVC tee \{size.trade_size} in (\{size.schedule.label()})",
    "PVC tee",
    "Three-way PVC tee fitting: run ports along -Z and +Z with a 90-degree branch along +X.",
    [
      ("socket-a", "mouth-a", (0.0, 0.0, -1.0)),
      ("socket-b", "mouth-b", (0.0, 0.0, 1.0)),
      ("branch", "mouth-branch", (1.0, 0.0, 0.0)),
    ],
    detail,
    color,
  )
}

///|
/// cross builds a 4-way planar PVC cross fitting along -Z, +Z, +X, and -X.
pub fn cross(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  multi_port_fitting(
    size,
    "cross",
    "PVC 4-way cross \{size.trade_size} in (\{size.schedule.label()})",
    "PVC cross",
    "Four-way planar PVC cross fitting along -Z, +Z, +X, and -X.",
    [
      ("socket-a", "mouth-a", (0.0, 0.0, -1.0)),
      ("socket-b", "mouth-b", (0.0, 0.0, 1.0)),
      ("branch-a", "mouth-branch-a", (1.0, 0.0, 0.0)),
      ("branch-b", "mouth-branch-b", (-1.0, 0.0, 0.0)),
    ],
    detail,
    color,
  )
}

///|
/// corner_3way builds a furniture-grade 3-way PVC corner elbow along +X, +Y, +Z.
pub fn corner_3way(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  multi_port_fitting(
    size,
    "corner-3way",
    "PVC 3-way corner elbow \{size.trade_size} in (\{size.schedule.label()})",
    "PVC 3-way corner",
    "Furniture-grade 3-way structural PVC corner elbow with sockets along +X, +Y, and +Z.",
    [
      ("socket-x", "mouth-x", (1.0, 0.0, 0.0)),
      ("socket-y", "mouth-y", (0.0, 1.0, 0.0)),
      ("socket-z", "mouth-z", (0.0, 0.0, 1.0)),
    ],
    detail,
    color,
  )
}

///|
/// four_way_tee builds a furniture-grade 4-way structural PVC tee along +X, -X,
/// +Y, and +Z.
pub fn four_way_tee(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  multi_port_fitting(
    size,
    "four-way-tee",
    "PVC 4-way structural tee \{size.trade_size} in (\{size.schedule.label()})",
    "PVC 4-way tee",
    "Furniture-grade 4-way structural PVC tee with sockets along +X, -X, +Y, and +Z.",
    [
      ("socket-x", "mouth-x", (1.0, 0.0, 0.0)),
      ("socket-nx", "mouth-nx", (-1.0, 0.0, 0.0)),
      ("socket-y", "mouth-y", (0.0, 1.0, 0.0)),
      ("socket-z", "mouth-z", (0.0, 0.0, 1.0)),
    ],
    detail,
    color,
  )
}

///|
/// five_way builds a furniture-grade 5-way structural PVC cross along +X, -X,
/// +Y, -Y, and +Z.
pub fn five_way(
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  multi_port_fitting(
    size,
    "five-way",
    "PVC 5-way structural cross \{size.trade_size} in (\{size.schedule.label()})",
    "PVC 5-way cross",
    "Furniture-grade 5-way structural PVC cross with sockets along +X, -X, +Y, -Y, and +Z.",
    [
      ("socket-x", "mouth-x", (1.0, 0.0, 0.0)),
      ("socket-nx", "mouth-nx", (-1.0, 0.0, 0.0)),
      ("socket-y", "mouth-y", (0.0, 1.0, 0.0)),
      ("socket-ny", "mouth-ny", (0.0, -1.0, 0.0)),
      ("socket-z", "mouth-z", (0.0, 0.0, 1.0)),
    ],
    detail,
    color,
  )
}

///|
fn circle_loop_at(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), centre),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), centre),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), centre),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), centre),
  ]
}

///|
/// flange builds a surface-mounting PVC floor/table flange with 4 mounting bolt
/// holes at `z = 0` and a female pipe socket opening toward +Z.
pub fn flange(
  size : PvcSize,
  base_diameter_mm~ : Double = 0.0,
  base_thickness_mm~ : Double = 6.0,
  bolt_circle_mm~ : Double = 0.0,
  bolt_hole_mm~ : Double = 5.5,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let base_d = if base_diameter_mm > 0.0 {
    base_diameter_mm
  } else {
    size.socket_outer_mm + 36.0
  }
  let bc = if bolt_circle_mm > 0.0 {
    bolt_circle_mm
  } else {
    (size.socket_outer_mm + base_d) / 2.0
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("PVC flange base thickness", base_thickness_mm),
    @common.require_positive("PVC flange base diameter", base_d),
    @common.require_positive("PVC flange bolt circle", bc),
    @common.require_positive("PVC flange bolt hole diameter", bolt_hole_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if bc - bolt_hole_mm <= size.socket_outer_mm || bc + bolt_hole_mm >= base_d {
    return Err(
      @common.InvalidParameter(
        "PVC flange bolt holes must sit cleanly between the socket hub and base outer rim",
      ),
    )
  }
  let outer = circle_loop_at(0.0, 0.0, base_d / 2.0)
  let holes : Array[Array[@cad.ProfileSegment]] = [
    circle_loop_at(0.0, 0.0, size.through_bore_mm / 2.0),
  ]
  let hole_r = bc / 2.0
  for i in 0..<4 {
    let ang = (45.0 + 90.0 * i.to_double()) * @math.PI / 180.0
    holes.push(
      circle_loop_at(
        hole_r * @math.cos(ang),
        hole_r * @math.sin(ang),
        bolt_hole_mm / 2.0,
      ),
    )
  }
  let base_shape = @cad.ExtrudedArcProfile::new(
    outer,
    base_thickness_mm,
    holes~,
  ).as_shape()
  let c = detailed_chamfer(size, detail)
  let collar_shape = pvc_socket_sleeve_shape(size, 0.0, c)
  let part_color = resolve_pvc_color(size, color)
  let modeled = ["mounting-base", "bolt-holes", "through-bore", "socket-collar"]
  if c > 0.0 {
    modeled.push("mouth-chamfer")
  }
  let mut comp = @common.Component::new(
      name="pvc-flange-\{size.trade_size}-\{size.schedule.tag().to_lower()}",
      metadata=pvc_fitting_metadata(
        size,
        "PVC floor flange \{size.trade_size} in (\{size.schedule.label()})",
        "PVC floor flange",
        "base OD \{@cad.fmt_double(base_d, None)} mm, 4x M5/#10 bolt circle \{@cad.fmt_double(bc, None)} mm",
      ),
      description="Surface-mounting PVC floor/table flange with 4 mounting bolt holes at z = 0 and a socket collar along +Z.",
      features=pvc_fitting_features(modeled, []),
    )
    .add_layer(base_shape, name="base", color=part_color)
    .add_layer(
      collar_shape,
      name="socket-collar",
      color=part_color,
      placement=@common.Placement::translation(0.0, 0.0, base_thickness_mm),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mount-face",
        placement=@common.Placement::rotation_x(180.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=base_d,
        description="flat mounting face at z = 0; outward normal is -Z",
      ),
    )
  for i in 0..<4 {
    let ang = (45.0 + 90.0 * i.to_double()) * @math.PI / 180.0
    let pos = (hole_r * @math.cos(ang), hole_r * @math.sin(ang), 0.0)
    comp = comp.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{i + 1}",
        placement=socket_frame(pos, (0.0, 0.0, -1.0)),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_mm,
        depth_mm=base_thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting bolt clearance bore through the flange base",
      ),
    )
  }
  Ok(
    add_origin(
      add_pvc_socket(
        comp,
        size,
        "socket",
        "mouth",
        (0.0, 0.0, base_thickness_mm),
        (0.0, 0.0, 1.0),
        size.socket_depth_mm,
      ),
    ),
  )
}
