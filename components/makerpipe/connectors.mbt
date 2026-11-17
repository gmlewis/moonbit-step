///|
/// normalize_branch_angles validates, sorts, and de-duplicates branch angles.
///
/// Angles are degrees in the plane perpendicular to the through pipe,
/// counter-clockwise from +X.
fn normalize_branch_angles(
  angles_deg : Array[Double],
) -> Result[Array[Double], @common.SpecError] {
  if angles_deg.length() == 0 {
    return Err(
      @common.InvalidParameter("a saddle connector needs at least one branch"),
    )
  }
  if angles_deg.length() > 8 {
    return Err(
      @common.InvalidParameter("a saddle connector supports at most 8 branches"),
    )
  }
  let radians : Array[Double] = []
  for angle in angles_deg {
    if !@common.is_finite(angle) {
      return Err(@common.InvalidParameter("branch angles must be finite"))
    }
    radians.push(normalize_angle(angle * @math.PI / 180.0))
  }
  radians.sort_by(fn(a, b) { a.compare(b) })
  let out : Array[Double] = []
  for angle in radians {
    match out.last() {
      Some(previous) => if (angle - previous).abs() > 1.0e-6 { out.push(angle) }
      None => out.push(angle)
    }
  }
  Ok(out)
}

///|
/// makerpipe_connector_features returns the feature record for a connector.
fn makerpipe_connector_features(
  kind : String,
  through_pipe : Bool,
) -> @common.FeatureRecord {
  let modeled : Array[String] = [
    kind, "branch-socket", "socket-bore", "branch-opening",
  ]
  if through_pipe {
    modeled.push("through-bore")
  } else {
    modeled.push("run-bore")
  }
  @common.FeatureRecord::new(
    modeled~,
    approximated=[
      @common.Approximation::new(
        feature="stamped-shell",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.5,
        control="constant nominal wall; the stamped hem, swage, and nut pocket are not modelled",
      ),
      @common.Approximation::new(
        feature="clamp-ring",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.5,
        control="the T run is a C-sleeve and the saddle is two full rims above and below the branch-bore band; the stamped saddle blend is not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="interlock-and-nut-pocket",
        reason="the puzzle-piece interlock, nut pocket, and fastener head recess are not modelled",
      ),
      @common.Omission::new(
        feature="set-screw-thread",
        reason="the set screw and its thread are separate hardware and are not modelled",
      ),
      @common.Omission::new(
        feature="zinc-coating",
        reason="the zinc coating is a finish, not geometry",
      ),
      @common.Omission::new(
        feature="strength-rating",
        reason="geometry alone does not establish a structural rating",
      ),
    ],
  )
}

///|
/// makerpipe_metadata builds the shared connector metadata.
fn makerpipe_metadata(
  size : MakerPipeSize,
  designation : String,
  source : String,
) -> @common.Metadata {
  @common.Metadata::new(
    designation~,
    standard="Maker Pipe published 3/4 in connector dimensions (vendor-proprietary; not a standard)",
    family="structural EMT pipe fitting (Maker Pipe-compatible)",
    size=size.trade_size,
    material="zinc-plated steel",
    source~,
  )
}

///|
/// makerpipe_source states the provenance, including the derived 1 in status.
fn makerpipe_source(size : MakerPipeSize, detail : String) -> String {
  if size.derived {
    "\{detail}; 1 in dimensions derived from the 3/4 in drawing by the EMT OD ratio, approximate"
  } else {
    "\{detail}; Maker Pipe published 3/4 in dimension drawing"
  }
}

///|
/// branch_axis returns the unit branch direction in the XY plane.
fn branch_axis(angle_rad : Double) -> @cad.Vec3 {
  (@math.cos(angle_rad), @math.sin(angle_rad), 0.0)
}

///|
/// add_socket_connectors attaches the socket and mouth mates for one branch.
fn add_socket_connectors(
  component : @common.Component,
  size : MakerPipeSize,
  index : Int32,
  seat : @cad.Vec3,
  axis : @cad.Vec3,
  depth_mm : Double,
  prefix~ : String = "socket",
) -> @common.Component {
  let (sx, sy, sz) = seat
  let (ax, ay, az) = axis
  let mouth = (sx + depth_mm * ax, sy + depth_mm * ay, sz + depth_mm * az)
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "\{prefix}-\{index}",
      placement=socket_frame(seat, axis),
      axis~,
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=size.socket_bore_mm,
      depth_mm~,
      fit=@cad.Fit::Free,
      description="branch socket bore; origin at the pipe seat, axis out of the mouth",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "mouth-\{index}",
      placement=@common.Placement::translation(mouth.0, mouth.1, mouth.2),
      axis~,
      kind=@common.MateKind::PlaneFace,
      diameter_mm=size.socket_bore_mm,
      description="branch socket mouth plane; outward normal along the branch",
    ),
  )
}

///|
/// add_bolt_connector attaches a nominal cross-bolt clearance frame.
fn add_bolt_connector(
  component : @common.Component,
  origin : @cad.Vec3,
  axis : @cad.Vec3,
  depth_mm : Double,
) -> @common.Component {
  component.with_connector_unchecked(
    @common.MateConnector::new(
      "bolt",
      placement=socket_frame(origin, axis),
      axis~,
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=6.6,
      depth_mm~,
      fit=@cad.Fit::Free,
      description="nominal cross-bolt clearance (1/4-20 class); position is approximate",
    ),
  )
}

///|
/// tee builds a Maker Pipe-compatible T connector.
///
/// The T is a straight run sleeve along +X plus one branch socket along +Y.
/// The run sleeve is C-shaped, open toward +Y, so a branch pipe can butt
/// against a continuous run pipe without a boolean cut. The branch socket is a
/// full annular tube from the run-pipe outside diameter to its mouth.
///
/// Frame: origin at the run/branch intersection, run axis +X, branch axis +Y.
/// Layers are closed solids; the opening is a nominal angular gap, not a
/// trimmed stamped saddle.
pub fn tee(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("T run length", size.run_length_mm),
    @common.require_positive("T branch depth", size.tee_branch_depth_mm),
    @common.require_positive("T socket bore", size.socket_bore_mm),
    @common.require_positive("T socket outer diameter", size.socket_outer_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let run_outer_r = size.socket_outer_mm / 2.0
  let run_inner_r = size.socket_bore_mm / 2.0
  let pipe_r = size.through_pipe_od_mm / 2.0
  let opening = opening_half_angle(run_inner_r, run_outer_r)
  if opening <= 1.0e-6 || opening >= @math.PI / 2.0 - 1.0e-6 {
    return Err(
      @common.InvalidParameter(
        "T run sleeve opening is degenerate for this socket bore and shell",
      ),
    )
  }
  let run_loop = annular_sector_loop(
    run_inner_r,
    run_outer_r,
    opening,
    2.0 * @math.PI - opening,
  )
  let run_shape = @cad.ExtrudedArcProfile::new(run_loop, size.run_length_mm).as_shape()
  let run_placement = @common.Placement::compose(
    @common.Placement::translation(-size.run_length_mm / 2.0, 0.0, 0.0),
    frame_x_to_y_z_to_x(),
  )
  let branch_shape = @cad.RevolvedProfile::tube(
    size.socket_outer_mm,
    size.socket_bore_mm,
    size.tee_branch_depth_mm,
  ).as_shape()
  let branch_seat = (0.0, pipe_r, 0.0)
  let branch_direction = (0.0, 1.0, 0.0)
  let features = makerpipe_connector_features("run-sleeve", false)
  let component = @common.Component::new(
      name="makerpipe-tee-\{size.trade_size}",
      metadata=makerpipe_metadata(
        size,
        "Maker Pipe-compatible T connector \{size.trade_size} in EMT",
        makerpipe_source(
          size, "T drawing: 3.07 in overall, 1.22 in socket depth, 0.94/1.14 in socket, 0.93/1.13 in run",
        ),
      ),
      description="Nominal Maker Pipe-compatible T connector: a C-shaped run sleeve along +X and a full socket cup along +Y. The run sleeve opening is a nominal angular gap; branch bores and pipe seats are analytic. No boolean trim, set-screw thread, hem, swage, or strength rating is modelled.",
      features~,
    )
    .add_layer(run_shape, name="run-sleeve", color~, placement=run_placement)
    .add_layer(
      branch_shape,
      name="branch-1",
      color~,
      placement=tube_frame(branch_seat, branch_direction),
    )
  let with_sockets = add_socket_connectors(
    component,
    size,
    1,
    branch_seat,
    branch_direction,
    size.tee_branch_depth_mm,
    prefix="branch",
  )
  let bolt_origin = (0.0, pipe_r + size.tee_branch_depth_mm / 2.0, 0.0)
  Ok(
    add_bolt_connector(
      with_sockets
      .with_connector_unchecked(
        @common.MateConnector::new(
          "origin",
          placement=@common.Placement::identity(),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          description="fitting origin at the run/branch intersection",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "run-axis",
          placement=@common.Placement::identity(),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::Datum,
          diameter_mm=size.socket_bore_mm,
          description="continuous run-pipe axis along +X",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "run-a",
          placement=socket_frame(
            (-size.run_length_mm / 2.0, 0.0, 0.0),
            (-1.0, 0.0, 0.0),
          ),
          axis=(-1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=size.socket_bore_mm,
          depth_mm=size.run_length_mm,
          fit=@cad.Fit::Free,
          description="run sleeve mouth at -X; a continuous run pipe slides through",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "run-b",
          placement=socket_frame(
            (size.run_length_mm / 2.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
          ),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=size.socket_bore_mm,
          depth_mm=size.run_length_mm,
          fit=@cad.Fit::Free,
          description="run sleeve mouth at +X; a continuous run pipe slides through",
        ),
      ),
      bolt_origin,
      (0.0, 0.0, 1.0),
      size.socket_outer_mm / 2.0,
    ),
  )
}

///|
/// saddle_connector builds a through-saddle connector with one or more branch
/// sockets.
///
/// The through pipe runs along +Z and is clamped in a partial annular ring.
/// Branch sockets lie in the XY plane at the supplied angles, measured
/// counter-clockwise from +X. Each socket is a full tube from the through-pipe
/// outside diameter to its mouth. The saddle ring is built only in the angular
/// spans between the branch openings, so the branch bores are open without a
/// boolean cut.
///
/// This single builder covers the 45, 90, 135, 180, 4-way, and 5-way families:
/// pass the branch angles. The 4-way has three branches and the 5-way four.
pub fn saddle_connector(
  size : MakerPipeSize,
  branch_angles_deg : Array[Double],
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match normalize_branch_angles(branch_angles_deg) {
    Err(e) => Err(e)
    Ok(angles) => {
      let checks : Array[Result[Unit, @common.SpecError]] = [
        @common.require_positive(
          "saddle branch mouth radius",
          size.branch_centre_to_mouth_mm,
        ),
        @common.require_positive("saddle width", size.saddle_width_mm),
        @common.require_positive("saddle bore", size.saddle_bore_mm),
        @common.require_positive("saddle outer diameter", size.saddle_outer_mm),
      ]
      for check in checks {
        match check {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
      let pipe_r = size.through_pipe_od_mm / 2.0
      let socket_depth = size.branch_centre_to_mouth_mm - pipe_r
      if socket_depth <= 0.0 {
        return Err(
          @common.InvalidParameter(
            "saddle branch mouth radius must exceed the through-pipe radius",
          ),
        )
      }
      let saddle_outer_r = size.saddle_outer_mm / 2.0
      let rim_height = size.saddle_width_mm / 2.0 - size.socket_bore_mm / 2.0
      if rim_height <= 0.5 {
        return Err(
          @common.InvalidParameter(
            "saddle width is too small for the branch socket bore; the clamp rims would vanish",
          ),
        )
      }
      let opening = opening_half_angle(
        size.socket_bore_mm / 2.0,
        saddle_outer_r,
      )
      let intervals = branch_material_intervals(angles, opening)
      let features = makerpipe_connector_features("saddle-rims", true)
      let designation = if angles.length() == 1 {
        "Maker Pipe-compatible saddle connector \{size.trade_size} in EMT"
      } else {
        "Maker Pipe-compatible \{angles.length()}-branch saddle connector \{size.trade_size} in EMT"
      }
      let component = @common.Component::new(
        name="makerpipe-saddle-\{size.trade_size}-\{angles.length()}",
        metadata=makerpipe_metadata(
          size,
          designation,
          makerpipe_source(
            size, "90/180/45 drawings: 2.5 in centre-to-mouth, 1.22 in socket depth, 0.93/1.13 in socket, 0.94/1.14 in saddle",
          ),
        ),
        description="Nominal Maker Pipe-compatible through-saddle connector: two full clamp rims around a +Z through pipe and full socket cups in the XY plane at the requested branch angles. The rims sit above and below the branch-bore band, so the sockets stay open without a boolean cut. Bores and pipe seats are analytic. No boolean trim, set-screw thread, hem, swage, or strength rating is modelled.",
        features~,
      )
      let mut with_branches = component
      for i in 0..<angles.length() {
        let angle = angles[i]
        let axis = branch_axis(angle)
        let seat = (pipe_r * @math.cos(angle), pipe_r * @math.sin(angle), 0.0)
        let branch_shape = @cad.RevolvedProfile::tube(
          size.socket_outer_mm,
          size.socket_bore_mm,
          socket_depth,
        ).as_shape()
        with_branches = with_branches.add_layer(
          branch_shape,
          name="branch-\{i + 1}",
          color~,
          placement=tube_frame(seat, axis),
        )
        with_branches = add_socket_connectors(
          with_branches,
          size,
          i + 1,
          seat,
          axis,
          socket_depth,
        )
      }
      let rim_shape = @cad.RevolvedProfile::tube(
        size.saddle_outer_mm,
        size.saddle_bore_mm,
        rim_height,
      ).as_shape()
      let with_rims = with_branches
        .add_layer(
          rim_shape,
          name="saddle-top",
          color~,
          placement=@common.Placement::translation(
            0.0,
            0.0,
            size.socket_bore_mm / 2.0,
          ),
        )
        .add_layer(
          rim_shape,
          name="saddle-bottom",
          color~,
          placement=@common.Placement::translation(
            0.0,
            0.0,
            -size.saddle_width_mm / 2.0,
          ),
        )
      let bolt_angle = largest_interval_midpoint(intervals)
      let bolt_origin = (
        saddle_outer_r * @math.cos(bolt_angle),
        saddle_outer_r * @math.sin(bolt_angle),
        0.0,
      )
      let bolt_axis = branch_axis(bolt_angle)
      Ok(
        add_bolt_connector(
          with_rims
          .with_connector_unchecked(
            @common.MateConnector::new(
              "origin",
              placement=@common.Placement::identity(),
              axis=(0.0, 0.0, 1.0),
              kind=@common.MateKind::Datum,
              description="fitting origin on the through-pipe axis at the branch plane",
            ),
          )
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
              description="through-saddle bore; a continuous pipe is clamped here",
            ),
          ),
          bolt_origin,
          bolt_axis,
          size.saddle_outer_mm / 2.0,
        ),
      )
    }
  }
}

///|
/// elbow builds a two-branch saddle connector at the requested included angle.
pub fn elbow(
  size : MakerPipeSize,
  angle_deg : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  if !@common.is_finite(angle_deg) {
    return Err(@common.InvalidParameter("elbow angle must be finite"))
  }
  if angle_deg <= 0.0 || angle_deg >= 360.0 {
    return Err(
      @common.InvalidParameter("elbow angle must be between 0 and 360 degrees"),
    )
  }
  saddle_connector(size, [0.0, angle_deg], color~)
}

///|
/// elbow_45 builds a 45 degree two-branch saddle connector.
pub fn elbow_45(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  elbow(size, 45.0, color~)
}

///|
/// elbow_90 builds a 90 degree two-branch saddle connector.
pub fn elbow_90(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  elbow(size, 90.0, color~)
}

///|
/// elbow_135 builds a 135 degree two-branch saddle connector.
pub fn elbow_135(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  elbow(size, 135.0, color~)
}

///|
/// straight_180 builds a 180 degree two-branch saddle connector.
pub fn straight_180(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  saddle_connector(size, [0.0, 180.0], color~)
}

///|
/// four_way builds the Maker Pipe 4-way connector (three branches at 90 degrees).
pub fn four_way(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  saddle_connector(size, [0.0, 90.0, 180.0], color~)
}

///|
/// five_way builds the Maker Pipe 5-way connector (four branches at 90 degrees).
pub fn five_way(
  size : MakerPipeSize,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  saddle_connector(size, [0.0, 90.0, 180.0, 270.0], color~)
}
