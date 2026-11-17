///|
/// circle_loop_at returns a counter-clockwise circle as four arcs.
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
/// flange_base_shape builds the circular mounting base with a central pipe
/// bore and four real bolt holes.
fn flange_base_shape(
  base_diameter_mm : Double,
  base_thickness_mm : Double,
  bore_diameter_mm : Double,
  bolt_circle_mm : Double,
  bolt_hole_mm : Double,
) -> @cad.Shape {
  let outer = circle_loop_at(0.0, 0.0, base_diameter_mm / 2.0)
  let holes : Array[Array[@cad.ProfileSegment]] = []
  if bore_diameter_mm > 0.0 {
    holes.push(circle_loop_at(0.0, 0.0, bore_diameter_mm / 2.0))
  }
  let hole_radius = bolt_circle_mm / 2.0
  for i in 0..<4 {
    let angle = (45.0 + 90.0 * i.to_double()) * @math.PI / 180.0
    holes.push(
      circle_loop_at(
        hole_radius * @math.cos(angle),
        hole_radius * @math.sin(angle),
        bolt_hole_mm / 2.0,
      ),
    )
  }
  @cad.ExtrudedArcProfile::new(outer, base_thickness_mm, holes~).as_shape()
}

///|
/// fittings_feature_record builds the shared feature record for the
/// non-branch fittings.
fn fittings_feature_record(
  modeled : Array[String],
  omitted : Array[@common.Omission],
) -> @common.FeatureRecord {
  @common.FeatureRecord::new(
    modeled~,
    approximated=[
      @common.Approximation::new(
        feature="stamped-shell",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.5,
        control="constant nominal wall; the stamped hem, swage, and nut pocket are not modelled",
      ),
    ],
    omitted~,
  )
}

///|
/// add_named_socket attaches one socket bore and one mouth plane under explicit
/// names, for fittings whose ports are lettered or numbered differently from
/// the saddle family.
fn add_named_socket(
  component : @common.Component,
  size : MakerPipeSize,
  name : String,
  mouth_name : String,
  seat : @cad.Vec3,
  axis : @cad.Vec3,
  depth_mm : Double,
) -> @common.Component {
  let (sx, sy, sz) = seat
  let (ax, ay, az) = axis
  let mouth = (sx + depth_mm * ax, sy + depth_mm * ay, sz + depth_mm * az)
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      name,
      placement=socket_frame(seat, axis),
      axis~,
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=size.socket_bore_mm,
      depth_mm~,
      fit=@cad.Fit::Free,
      description="socket bore; origin at the pipe seat, axis out of the mouth",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      mouth_name,
      placement=@common.Placement::translation(mouth.0, mouth.1, mouth.2),
      axis~,
      kind=@common.MateKind::PlaneFace,
      diameter_mm=size.socket_bore_mm,
      description="socket mouth plane; outward normal along the socket",
    ),
  )
}

///|
/// add_origin attaches the common origin datum.
fn add_origin(component : @common.Component) -> @common.Component {
  component.with_connector_unchecked(
    @common.MateConnector::new(
      "origin",
      placement=@common.Placement::identity(),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Datum,
      description="fitting origin",
    ),
  )
}

///|
/// coupling joins two pipe ends in line.
///
/// Frame: pipe axis +Z, symmetric about `z = 0`. Each pipe end seats at the
/// centre plane and extends outward through `z = +/- length/2`. The nominal
/// body is one annular sleeve; the two stamped clamp halves and their seam are
/// not modelled. The default length is twice the published T socket depth; pass
/// `length_mm` to override.
pub fn coupling(
  size : MakerPipeSize,
  length_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let length = if length_mm > 0.0 {
    length_mm
  } else {
    2.0 * size.tee_branch_depth_mm
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("coupling length", length),
    @common.require_positive("coupling bore", size.socket_bore_mm),
    @common.require_positive("coupling outside diameter", size.socket_outer_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if size.socket_outer_mm <= size.socket_bore_mm {
    return Err(
      @common.InvalidParameter("coupling outside diameter must exceed the bore"),
    )
  }
  let half = length / 2.0
  let body = @cad.RevolvedProfile::tube(
    size.socket_outer_mm,
    size.socket_bore_mm,
    length,
  ).as_shape()
  let features = fittings_feature_record(
    ["socket-sleeve", "socket-a-bore", "socket-b-bore", "bolt-bore"],
    [
      @common.Omission::new(
        feature="clamp-halves-and-seam",
        reason="the two stamped clamp halves and their seam are represented by one nominal sleeve",
      ),
      @common.Omission::new(
        feature="set-screw-thread",
        reason="the cross bolt and its thread are separate hardware and are not modelled",
      ),
      @common.Omission::new(
        feature="strength-rating",
        reason="geometry alone does not establish a structural rating",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-coupling-\{size.trade_size}",
    metadata=makerpipe_metadata(
      size,
      "Maker Pipe-compatible structural coupling \{size.trade_size} in EMT",
      makerpipe_source(
        size, "Coupling length defaults to twice the 1.22 in T socket depth; bore and shell use the published socket dimensions",
      ),
    ),
    description="Nominal Maker Pipe-compatible structural coupling: one annular sleeve along +Z with a socket at each end. Pipe ends seat at the centre plane. The two stamped clamp halves, seam, bolt, and thread are not modelled.",
    features~,
  ).add_layer(
    body,
    name="socket-sleeve",
    color~,
    placement=@common.Placement::translation(0.0, 0.0, -half),
  )
  let with_sockets = add_named_socket(
    component,
    size,
    "socket-a",
    "mouth-a",
    (0.0, 0.0, 0.0),
    (0.0, 0.0, -1.0),
    half,
  )
  let with_sockets = add_named_socket(
    with_sockets,
    size,
    "socket-b",
    "mouth-b",
    (0.0, 0.0, 0.0),
    (0.0, 0.0, 1.0),
    half,
  )
  Ok(
    add_bolt_connector(
      add_origin(
        with_sockets.with_connector_unchecked(
          @common.MateConnector::new(
            "seam",
            placement=@common.Placement::identity(),
            axis=(1.0, 0.0, 0.0),
            kind=@common.MateKind::Datum,
            description="nominal centre seam and pipe butt plane",
          ),
        ),
      ),
      (size.socket_outer_mm / 2.0, 0.0, 0.0),
      (1.0, 0.0, 0.0),
      size.socket_outer_mm / 2.0,
    ),
  )
}

///|
/// flange mounts a pipe socket on a flat surface.
///
/// Frame: mounting face at `z = 0` with outward normal -Z, pipe axis +Z. The
/// base is a nominal annular plate with a central pipe bore; the four mounting
/// holes are declared by `mount-hole-1..4` but are not cut into the nominal
/// geometry. The socket tube rises from the base top; its seat is at
/// `z = base_thickness`.
pub fn flange(
  size : MakerPipeSize,
  base_diameter_mm~ : Double = 70.0,
  base_thickness_mm~ : Double = 5.0,
  bolt_circle_mm~ : Double = 54.0,
  bolt_hole_mm~ : Double = 6.6,
  socket_depth_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let depth = if socket_depth_mm > 0.0 {
    socket_depth_mm
  } else {
    size.tee_branch_depth_mm
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("flange base diameter", base_diameter_mm),
    @common.require_positive("flange base thickness", base_thickness_mm),
    @common.require_positive("flange bolt circle", bolt_circle_mm),
    @common.require_positive("flange bolt hole", bolt_hole_mm),
    @common.require_positive("flange socket depth", depth),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if base_diameter_mm <= size.socket_outer_mm + bolt_hole_mm {
    return Err(
      @common.InvalidParameter(
        "flange base diameter must exceed the socket shell plus a bolt hole",
      ),
    )
  }
  if bolt_circle_mm + bolt_hole_mm >= base_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "flange bolt circle plus hole diameter must fit inside the base",
      ),
    )
  }
  let embed = 0.5
  let base = flange_base_shape(
    base_diameter_mm,
    base_thickness_mm,
    size.socket_bore_mm,
    bolt_circle_mm,
    bolt_hole_mm,
  )
  let socket = @cad.RevolvedProfile::tube(
    size.socket_outer_mm,
    size.socket_bore_mm,
    depth + embed,
  ).as_shape()
  let features = fittings_feature_record(
    [
      "mounting-base", "central-bore", "mounting-holes", "socket-bore", "mounting-face",
    ],
    [
      @common.Omission::new(
        feature="stamped-clamp-halves",
        reason="the two mirrored stamped pieces are represented by one nominal base and socket",
      ),
      @common.Omission::new(
        feature="strength-rating",
        reason="geometry alone does not establish a structural or pull-out rating",
      ),
    ],
  )
  let component = @common.Component::new(
      name="makerpipe-flange-\{size.trade_size}",
      metadata=makerpipe_metadata(
        size,
        "Maker Pipe-compatible flange connector \{size.trade_size} in EMT",
        makerpipe_source(
          size, "Flange base diameter, thickness, bolt circle, and hole diameter are engineering defaults; the four mounting holes are modelled. Socket dimensions come from the published 3/4 in drawings",
        ),
      ),
      description="Nominal Maker Pipe-compatible flange: a circular mounting base with a central pipe bore and four real mounting holes, plus a socket tube along +Z. No pull-out or strength rating is modelled.",
      features~,
    )
    .add_layer(base, name="base", color~)
    .add_layer(
      socket,
      name="socket",
      color~,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        base_thickness_mm - embed,
      ),
    )
  let mut with_connectors = add_named_socket(
    component,
    size,
    "socket",
    "mouth",
    (0.0, 0.0, base_thickness_mm),
    (0.0, 0.0, 1.0),
    depth,
  )
  with_connectors = with_connectors.with_connector_unchecked(
    @common.MateConnector::new(
      "mount",
      placement=@common.Placement::identity(),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=base_diameter_mm,
      description="flat mounting face at z = 0; outward normal is -Z",
    ),
  )
  let hole_radius = bolt_circle_mm / 2.0
  for i in 0..<4 {
    let angle = (45.0 + 90.0 * i.to_double()) * @math.PI / 180.0
    let origin = (
      hole_radius * @math.cos(angle),
      hole_radius * @math.sin(angle),
      0.0,
    )
    with_connectors = with_connectors.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{i + 1}",
        placement=socket_frame(origin, (0.0, 0.0, -1.0)),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_mm,
        depth_mm=base_thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting-hole clearance, declared but not cut in the nominal base",
      ),
    )
  }
  Ok(add_origin(with_connectors))
}

///|
/// hinge_angle_valid reports whether an adjustable angle is in [-90, 90].
fn hinge_angle_valid(angle_deg : Double) -> Bool {
  @common.is_finite(angle_deg) && angle_deg >= -90.0 && angle_deg <= 90.0
}

///|
/// hinge_arm_axis returns the end-clamp axis for a hinge angle.
///
/// Zero is horizontal (+X for a +X-side arm); positive tilts toward +Z.
fn hinge_arm_axis(angle_deg : Double, sign : Double) -> @cad.Vec3 {
  let radians = angle_deg * @math.PI / 180.0
  (sign * @math.cos(radians), 0.0, @math.sin(radians))
}

///|
/// Hinge geometry constants. The ear is a pin lug; the straps are flat plates
/// that sit in the socket wall so they do not block the pipe bore.
let hinge_ear_radius_mm : Double = 8.0

///|
let hinge_ear_width_mm : Double = 6.0

///|
let hinge_strap_width_mm : Double = 2.0

///|
let hinge_strap_height_mm : Double = 10.0

///|
let hinge_socket_start_mm : Double = 12.0

///|
let hinge_lug_length_mm : Double = 18.0

///|
let hinge_pin_hole_mm : Double = 6.6

///|
let hinge_embed_mm : Double = 1.0

///|
/// hinge_strap_y returns the mid-wall offset of an arm strap.
///
/// The strap sits between the socket bore and the socket shell so it can join
/// the outer wall without entering the pipe passage.
fn hinge_strap_y(size : MakerPipeSize) -> Double {
  (size.socket_bore_mm / 2.0 + size.socket_outer_mm / 2.0) / 2.0
}

///|
/// hinge_name appends a suffix when one is given.
fn hinge_name(base : String, suffix : String) -> String {
  if suffix == "" {
    base
  } else {
    "\{base}-\{suffix}"
  }
}

///|
/// add_hinge_arm adds the pivoting side of a hinge: two pin ears, two flat
/// straps, and the end-clamp socket.
///
/// The ears are at `+/- strap_y` on the pin axis; the straps run from the ear
/// to the socket wall. The pipe seat is `socket_start_mm` out from the pivot, so
/// the socket cup clears the through clamp.
fn add_hinge_arm(
  component : @common.Component,
  size : MakerPipeSize,
  suffix : String,
  pivot : @cad.Vec3,
  arm_axis : @cad.Vec3,
  arm_length_mm : Double,
  color : @cad.Rgb,
) -> @common.Component {
  let (px, py, pz) = pivot
  let strap_y = hinge_strap_y(size)
  let cup_start = (
    px + hinge_socket_start_mm * arm_axis.0,
    py + hinge_socket_start_mm * arm_axis.1,
    pz + hinge_socket_start_mm * arm_axis.2,
  )
  let ear = @cad.RevolvedProfile::tube(
    2.0 * hinge_ear_radius_mm,
    hinge_pin_hole_mm,
    hinge_strap_width_mm,
  ).as_shape()
  let strap_start = hinge_ear_radius_mm - hinge_embed_mm
  let strap_end = hinge_socket_start_mm + hinge_embed_mm
  let strap_length = strap_end - strap_start
  let strap_mid = strap_start + strap_length / 2.0
  let strap = @cad.Cuboid::new(
    strap_length, hinge_strap_width_mm, hinge_strap_height_mm,
  )
  let cup = @cad.RevolvedProfile::tube(
    size.socket_outer_mm,
    size.socket_bore_mm,
    arm_length_mm,
  ).as_shape()
  let arm_rotation = frame_x_along_xz(arm_axis)
  let mut with_layers = component
  let strap_offsets = [strap_y, -strap_y]
  let strap_names = [
    hinge_name("strap-a", suffix),
    hinge_name("strap-b", suffix),
  ]
  let ear_names = [
    hinge_name("strap-ear-a", suffix),
    hinge_name("strap-ear-b", suffix),
  ]
  for i in 0..<2 {
    let y = strap_offsets[i]
    let center = (
      px + strap_mid * arm_axis.0,
      py + y + strap_mid * arm_axis.1,
      pz + strap_mid * arm_axis.2,
    )
    let corner = arm_rotation.apply_dir(
      (
        -strap_length / 2.0,
        -hinge_strap_width_mm / 2.0,
        -hinge_strap_height_mm / 2.0,
      ),
    )
    let strap_placement = @common.Placement::compose(
      @common.Placement::translation(
        center.0 + corner.0,
        center.1 + corner.1,
        center.2 + corner.2,
      ),
      arm_rotation,
    )
    with_layers = with_layers
      .add_layer(
        ear,
        name=ear_names[i],
        color~,
        placement=tube_frame(
          (px, py + y - hinge_strap_width_mm / 2.0, pz),
          (0.0, 1.0, 0.0),
        ),
      )
      .add_layer(strap, name=strap_names[i], color~, placement=strap_placement)
  }
  let with_layers = with_layers.add_layer(
    cup,
    name=hinge_name("end-socket", suffix),
    color~,
    placement=tube_frame(cup_start, arm_axis),
  )
  let pin_length = 2.0 * (strap_y + hinge_strap_width_mm) + 2.0
  let with_layers = with_layers.add_layer(
    @cad.Cylinder::new(6.0, pin_length),
    name=hinge_name("pivot-pin", suffix),
    color~,
    placement=tube_frame((px, py - pin_length / 2.0, pz), (0.0, 1.0, 0.0)),
  )
  let with_layers = add_named_socket(
    with_layers,
    size,
    hinge_name("socket-end", suffix),
    hinge_name("mouth-end", suffix),
    cup_start,
    arm_axis,
    arm_length_mm,
  )
  with_layers.with_connector_unchecked(
    @common.MateConnector::new(
      hinge_name("pivot", suffix),
      placement=socket_frame(pivot, (0.0, 1.0, 0.0)),
      axis=(0.0, 1.0, 0.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=hinge_pin_hole_mm,
      depth_mm=2.0 * (strap_y + hinge_strap_width_mm),
      fit=@cad.Fit::Free,
      description="hinge-pin clearance through the lug and both straps; axis +Y",
    ),
  )
}

///|
/// add_hinge_lug adds the fixed side of a hinge: a web from the through ring
/// to a central pin ear.
fn add_hinge_lug(
  component : @common.Component,
  size : MakerPipeSize,
  suffix : String,
  pivot : @cad.Vec3,
  sign : Double,
  color : @cad.Rgb,
) -> @common.Component {
  let (px, _, pz) = pivot
  let web_start = sign * (size.saddle_bore_mm / 2.0 + 1.0)
  let web_end = px - sign * (hinge_ear_radius_mm - hinge_embed_mm)
  let web_length = (web_end - web_start).abs()
  let web_min_x = if web_start < web_end { web_start } else { web_end }
  let web_height = hinge_strap_height_mm + 2.0
  let web = @cad.Cuboid::new(web_length, hinge_ear_width_mm, web_height)
  let ear = @cad.RevolvedProfile::tube(
    2.0 * hinge_ear_radius_mm,
    hinge_pin_hole_mm,
    hinge_ear_width_mm,
  ).as_shape()
  component
  .add_layer(
    web,
    name="lug-web-\{suffix}",
    color~,
    placement=@common.Placement::translation(
      web_min_x,
      -hinge_ear_width_mm / 2.0,
      pz - web_height / 2.0,
    ),
  )
  .add_layer(
    ear,
    name="lug-ear-\{suffix}",
    color~,
    placement=tube_frame((px, -hinge_ear_width_mm / 2.0, pz), (0.0, 1.0, 0.0)),
  )
}

///|
/// adjustable_hinge combines a through-pipe clamp with one pivoting end clamp.
///
/// Frame: through pipe along +Z. The end-clamp seat is at the pivot on +X; its
/// axis is `(cos(angle), 0, sin(angle))`, so 0 is horizontal and +/-90 is
/// vertical. The pivot pin runs along +Y. This is a nominal engineering
/// envelope for the four-piece Maker Pipe adjustable angle connector.
pub fn adjustable_hinge(
  size : MakerPipeSize,
  angle_deg : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if !hinge_angle_valid(angle_deg) {
    return Err(
      @common.InvalidParameter(
        "adjustable hinge angle must be finite and between -90 and 90 degrees",
      ),
    )
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive(
      "adjustable hinge through width",
      size.saddle_width_mm,
    ),
    @common.require_positive(
      "adjustable hinge arm length",
      size.branch_centre_to_mouth_mm - size.socket_outer_mm / 2.0,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let ring = @cad.RevolvedProfile::tube(
    size.saddle_outer_mm,
    size.saddle_bore_mm,
    size.saddle_width_mm,
  ).as_shape()
  let pivot = (size.saddle_outer_mm / 2.0 + hinge_lug_length_mm, 0.0, 0.0)
  let arm_length = size.branch_centre_to_mouth_mm - size.socket_outer_mm / 2.0
  let features = fittings_feature_record(
    [
      "through-ring", "central-pin-lug", "outer-straps", "end-socket", "pivot-pin",
      "socket-bore", "pivot-bore",
    ],
    [
      @common.Omission::new(
        feature="four-piece-stamping",
        reason="the two long end-clamp pieces and two puzzle-piece clamp pieces are represented by a ring, a central lug, two outer straps, and a socket",
      ),
      @common.Omission::new(
        feature="fastener-thread",
        reason="the assembly bolts and their threads are separate hardware and are not modelled",
      ),
      @common.Omission::new(
        feature="strength-rating",
        reason="geometry alone does not establish a hinge or structural rating",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-adjustable-hinge-\{size.trade_size}",
    metadata=makerpipe_metadata(
      size,
      "Maker Pipe-compatible adjustable angle hinge \{size.trade_size} in EMT",
      makerpipe_source(
        size, "Adjustable hinge socket, through ring, lug, and straps use the published socket and saddle dimensions; pivot offset is an engineering default",
      ),
    ),
    description="Nominal Maker Pipe-compatible adjustable angle hinge: a through-pipe ring with a central pin lug, two outer straps, and one end-clamp socket pivoting in the XZ plane. The pin runs along +Y; zero angle is horizontal and positive tilts toward +Z. No stamped four-piece detail, bolt thread, or hinge rating is modelled.",
    features~,
  ).add_layer(
    ring,
    name="through-ring",
    color~,
    placement=@common.Placement::translation(
      0.0,
      0.0,
      -size.saddle_width_mm / 2.0,
    ),
  )
  let with_lug = add_hinge_lug(component, size, "1", pivot, 1.0, color)
  let with_arm = add_hinge_arm(
    with_lug,
    size,
    "1",
    pivot,
    hinge_arm_axis(angle_deg, 1.0),
    arm_length,
    color,
  )
  Ok(
    add_origin(
      with_arm
      .with_connector_unchecked(
        @common.MateConnector::new(
          "through",
          placement=@common.Placement::identity(),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          diameter_mm=size.through_pipe_od_mm,
          description="continuous through-pipe axis along +Z",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "through-bore",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=size.saddle_bore_mm,
          depth_mm=size.saddle_width_mm,
          fit=@cad.Fit::Free,
          description="through-ring bore; a continuous pipe is clamped here",
        ),
      ),
    ),
  )
}

///|
/// adjustable_180 combines a through-pipe clamp with two pivoting end clamps.
///
/// The two end clamps sit on +X and -X. Each angle is independent in
/// [-90, 90]; zero is horizontal and positive tilts toward +Z. The pins run
/// along +Y.
pub fn adjustable_180(
  size : MakerPipeSize,
  angle_1_deg : Double,
  angle_2_deg : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if !hinge_angle_valid(angle_1_deg) || !hinge_angle_valid(angle_2_deg) {
    return Err(
      @common.InvalidParameter(
        "adjustable 180 angles must be finite and between -90 and 90 degrees",
      ),
    )
  }
  let arm_length = size.branch_centre_to_mouth_mm - size.socket_outer_mm / 2.0
  if arm_length <= 0.0 {
    return Err(
      @common.InvalidParameter("adjustable 180 arm length must be positive"),
    )
  }
  let ring = @cad.RevolvedProfile::tube(
    size.saddle_outer_mm,
    size.saddle_bore_mm,
    size.saddle_width_mm,
  ).as_shape()
  let features = fittings_feature_record(
    [
      "through-ring", "two-pin-lugs", "four-outer-straps", "two-end-sockets", "pivot-pins",
      "socket-bores", "pivot-bores",
    ],
    [
      @common.Omission::new(
        feature="six-piece-stamping",
        reason="the six stamped pieces are represented by a ring, two central lugs, four outer straps, and two sockets",
      ),
      @common.Omission::new(
        feature="fastener-thread",
        reason="the assembly bolts and their threads are separate hardware and are not modelled",
      ),
      @common.Omission::new(
        feature="strength-rating",
        reason="geometry alone does not establish a hinge or structural rating",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-adjustable-180-\{size.trade_size}",
    metadata=makerpipe_metadata(
      size,
      "Maker Pipe-compatible adjustable 180 connector \{size.trade_size} in EMT",
      makerpipe_source(
        size, "Adjustable 180 sockets, through ring, lugs, and straps use the published socket and saddle dimensions; pivot offsets are engineering defaults",
      ),
    ),
    description="Nominal Maker Pipe-compatible adjustable 180 connector: a through-pipe ring with two central pin lugs and two independent pivoting end clamps on +X and -X. Outer straps straddle each lug; the pins run along +Y. Zero angle is horizontal and positive tilts toward +Z. No stamped six-piece detail, bolt thread, or hinge rating is modelled.",
    features~,
  ).add_layer(
    ring,
    name="through-ring",
    color~,
    placement=@common.Placement::translation(
      0.0,
      0.0,
      -size.saddle_width_mm / 2.0,
    ),
  )
  let pivot_x = size.saddle_outer_mm / 2.0 + hinge_lug_length_mm
  let with_lugs = add_hinge_lug(
    component,
    size,
    "1",
    (pivot_x, 0.0, 0.0),
    1.0,
    color,
  )
  let with_lugs = add_hinge_lug(
    with_lugs,
    size,
    "2",
    (-pivot_x, 0.0, 0.0),
    -1.0,
    color,
  )
  let with_arms = add_hinge_arm(
    with_lugs,
    size,
    "1",
    (pivot_x, 0.0, 0.0),
    hinge_arm_axis(angle_1_deg, 1.0),
    arm_length,
    color,
  )
  let with_arms = add_hinge_arm(
    with_arms,
    size,
    "2",
    (-pivot_x, 0.0, 0.0),
    hinge_arm_axis(angle_2_deg, -1.0),
    arm_length,
    color,
  )
  Ok(
    add_origin(
      with_arms
      .with_connector_unchecked(
        @common.MateConnector::new(
          "through",
          placement=@common.Placement::identity(),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          diameter_mm=size.through_pipe_od_mm,
          description="continuous through-pipe axis along +Z",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "through-bore",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=size.saddle_bore_mm,
          depth_mm=size.saddle_width_mm,
          fit=@cad.Fit::Free,
          description="through-ring bore; a continuous pipe is clamped here",
        ),
      ),
    ),
  )
}

///|
/// adjustable_flange mounts one pivoting pipe socket on a flat surface.
///
/// Frame: mounting face at `z = 0`, normal -Z. The pivot is above the base and
/// its pin runs along +Y. The arm axis is `(sin(angle), 0, cos(angle))`, so zero
/// is vertical and positive tilts toward +X.
pub fn adjustable_flange(
  size : MakerPipeSize,
  angle_deg : Double,
  base_diameter_mm~ : Double = 70.0,
  base_thickness_mm~ : Double = 5.0,
  bolt_circle_mm~ : Double = 54.0,
  bolt_hole_mm~ : Double = 6.6,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if !hinge_angle_valid(angle_deg) {
    return Err(
      @common.InvalidParameter(
        "adjustable flange angle must be finite and between -90 and 90 degrees",
      ),
    )
  }
  if base_diameter_mm <= size.socket_outer_mm + bolt_hole_mm {
    return Err(
      @common.InvalidParameter(
        "adjustable flange base diameter must exceed the socket shell plus a bolt hole",
      ),
    )
  }
  if bolt_circle_mm + bolt_hole_mm >= base_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "adjustable flange bolt circle plus hole diameter must fit inside the base",
      ),
    )
  }
  let arm_length = size.branch_centre_to_mouth_mm - size.socket_outer_mm / 2.0
  if arm_length <= 0.0 {
    return Err(
      @common.InvalidParameter("adjustable flange arm length must be positive"),
    )
  }
  let base = flange_base_shape(
    base_diameter_mm, base_thickness_mm, 0.0, bolt_circle_mm, bolt_hole_mm,
  )
  let upstand_length = 6.0
  let pivot_z = base_thickness_mm + upstand_length + hinge_ear_radius_mm
  let pivot = (0.0, 0.0, pivot_z)
  let arm_axis = (
    @math.sin(angle_deg * @math.PI / 180.0),
    0.0,
    @math.cos(angle_deg * @math.PI / 180.0),
  )
  let features = fittings_feature_record(
    [
      "mounting-base", "mounting-holes", "upstand", "pin-lug", "outer-straps", "end-socket",
      "pivot-pin", "socket-bore", "pivot-bore",
    ],
    [
      @common.Omission::new(
        feature="four-piece-stamping",
        reason="the stamped end-clamp and adjustable base pieces are represented by a base, an upstand, a pin lug, outer straps, and a socket",
      ),
      @common.Omission::new(
        feature="strength-rating",
        reason="geometry alone does not establish a hinge, pull-out, or structural rating",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-adjustable-flange-\{size.trade_size}",
    metadata=makerpipe_metadata(
      size,
      "Maker Pipe-compatible adjustable angle flange \{size.trade_size} in EMT",
      makerpipe_source(
        size, "Adjustable flange socket, base, lug, and straps use the published dimensions; the four mounting holes are modelled; upstand and pivot locations are engineering defaults",
      ),
    ),
    description="Nominal Maker Pipe-compatible adjustable flange: a circular solid mounting base with four real mounting holes, an upstand and central pin lug, two outer straps, and one end-clamp socket pivoting in the XZ plane. The pin runs along +Y; zero is vertical and positive tilts toward +X. No stamped detail, bolt thread, or rating is modelled.",
    features~,
  ).add_layer(base, name="base", color~)
  let upstand_start = base_thickness_mm - hinge_embed_mm
  let upstand_end = pivot_z - hinge_ear_radius_mm + hinge_embed_mm
  let upstand_height = upstand_end - upstand_start
  let with_upstand = component.add_layer(
    @cad.Cuboid::new(12.0, hinge_ear_width_mm, upstand_height),
    name="upstand",
    color~,
    placement=@common.Placement::translation(
      -6.0,
      -hinge_ear_width_mm / 2.0,
      upstand_start,
    ),
  )
  let with_ear = with_upstand.add_layer(
    @cad.RevolvedProfile::tube(
      2.0 * hinge_ear_radius_mm,
      hinge_pin_hole_mm,
      hinge_ear_width_mm,
    ).as_shape(),
    name="lug-ear",
    color~,
    placement=tube_frame(
      (0.0, -hinge_ear_width_mm / 2.0, pivot_z),
      (0.0, 1.0, 0.0),
    ),
  )
  let with_arm = add_hinge_arm(
    with_ear, size, "", pivot, arm_axis, arm_length, color,
  )
  let with_arm = with_arm.with_connector_unchecked(
    @common.MateConnector::new(
      "mount",
      placement=@common.Placement::identity(),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=base_diameter_mm,
      description="flat mounting face at z = 0; outward normal is -Z",
    ),
  )
  let hole_radius = bolt_circle_mm / 2.0
  let mut with_holes = with_arm
  for i in 0..<4 {
    let hole_angle = (45.0 + 90.0 * i.to_double()) * @math.PI / 180.0
    let origin = (
      hole_radius * @math.cos(hole_angle),
      hole_radius * @math.sin(hole_angle),
      0.0,
    )
    with_holes = with_holes.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{i + 1}",
        placement=socket_frame(origin, (0.0, 0.0, -1.0)),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=bolt_hole_mm,
        depth_mm=base_thickness_mm,
        fit=@cad.Fit::Free,
        description="mounting-hole clearance, declared but not cut in the nominal base",
      ),
    )
  }
  Ok(add_origin(with_holes))
}

///|
/// top_rail_size returns the 1-3/8 in (1.315 in OD) top-rail envelope.
///
/// Maker Pipe publishes the rail OD but no dimension drawing for the Top Rail
/// T. The socket, saddle, and length values are derived from the 3/4 in
/// drawings by the OD ratio and are marked approximate.
pub fn top_rail_size() -> MakerPipeSize {
  let od = 33.401
  let ratio = od / emt_3_4_od_mm
  let socket_bore = od + 0.46
  let saddle_bore = od + 0.20
  {
    trade_size: "1-3/8",
    through_pipe_od_mm: od,
    socket_bore_mm: socket_bore,
    socket_outer_mm: socket_bore + 2.0 * makerpipe_wall_mm,
    saddle_bore_mm: saddle_bore,
    saddle_outer_mm: saddle_bore + 2.0 * makerpipe_wall_mm,
    tee_branch_depth_mm: 30.988 * ratio,
    branch_centre_to_mouth_mm: 63.5 * ratio,
    saddle_width_mm: 33.02 * ratio,
    run_length_mm: 0.0,
    wall_mm: makerpipe_wall_mm,
    derived: true,
  }
}

///|
/// top_rail_tee builds the Top Rail T: a clamp around a 1.315 in through rail
/// and one 1.315 in terminating socket at 90 degrees.
///
/// Frame: through rail along +Z, branch socket toward +X. `rail` and
/// `rail-bore` are aliases for the through-pipe datum and bore.
pub fn top_rail_tee(
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = top_rail_size()
  let rim_height = size.saddle_width_mm / 2.0 - size.socket_bore_mm / 2.0
  let socket_depth = size.branch_centre_to_mouth_mm -
    size.through_pipe_od_mm / 2.0
  if rim_height <= 0.5 || socket_depth <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "top-rail T envelope is degenerate: no clamp rim or socket depth",
      ),
    )
  }
  let rim = @cad.RevolvedProfile::tube(
    size.saddle_outer_mm,
    size.saddle_bore_mm,
    rim_height,
  ).as_shape()
  let branch = @cad.RevolvedProfile::tube(
    size.socket_outer_mm,
    size.socket_bore_mm,
    socket_depth,
  ).as_shape()
  let seat = (size.through_pipe_od_mm / 2.0, 0.0, 0.0)
  let features = makerpipe_connector_features("rail-rims", true)
  let component = @common.Component::new(
      name="makerpipe-top-rail-tee",
      metadata=makerpipe_metadata(
        size, "Maker Pipe-compatible Top Rail T 1-3/8 in", "Top Rail T: 1.315 in OD through rail; socket, saddle, and length derived from the 3/4 in drawings by OD ratio; approximate",
      ),
      description="Nominal Maker Pipe-compatible Top Rail T: two clamp rims around a 1.315 in through rail and one full socket tube at 90 degrees. The rims sit above and below the branch-bore band so the socket stays open without a boolean cut. No stamped detail, bolt thread, or strength rating is modelled.",
      features~,
    )
    .add_layer(
      rim,
      name="rail-rim-top",
      color~,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        size.socket_bore_mm / 2.0,
      ),
    )
    .add_layer(
      rim,
      name="rail-rim-bottom",
      color~,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        -size.saddle_width_mm / 2.0,
      ),
    )
    .add_layer(
      branch,
      name="branch-1",
      color~,
      placement=tube_frame(seat, (1.0, 0.0, 0.0)),
    )
  let with_socket = add_named_socket(
    component,
    size,
    "socket-1",
    "mouth-1",
    seat,
    (1.0, 0.0, 0.0),
    socket_depth,
  )
  let with_aliases = with_socket
    .with_connector_unchecked(
      @common.MateConnector::new(
        "through",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=size.through_pipe_od_mm,
        description="continuous top-rail axis along +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "through-bore",
        placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.saddle_bore_mm,
        depth_mm=size.saddle_width_mm,
        fit=@cad.Fit::Free,
        description="top-rail saddle bore; a continuous rail is clamped here",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=size.through_pipe_od_mm,
        description="alias for the continuous top-rail axis along +Z; 1.315 in OD",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-bore",
        placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.saddle_bore_mm,
        depth_mm=size.saddle_width_mm,
        fit=@cad.Fit::Free,
        description="alias for the top-rail saddle bore",
      ),
    )
  Ok(
    add_bolt_connector(
      add_origin(with_aliases),
      (0.0, size.saddle_outer_mm / 2.0, 0.0),
      (0.0, 1.0, 0.0),
      size.socket_outer_mm / 2.0,
    ),
  )
}
