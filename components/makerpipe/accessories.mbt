///|
/// emt_boundary looks up the EMT boundary dimensions for an accessory.
fn emt_boundary(trade : String) -> Result[@motion.EmtSize, @common.SpecError] {
  @motion.emt_size(trade)
}

///|
/// emt_inside_diameter returns the tube inside diameter.
fn emt_inside_diameter(size : @motion.EmtSize) -> Double {
  size.outside_diameter_mm - 2.0 * size.wall_mm
}

///|
/// rect_loop_2d returns a counter-clockwise rectangle.
fn rect_loop_2d(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, y0), (x1, y0)),
    @cad.SegmentLine((x1, y0), (x1, y1)),
    @cad.SegmentLine((x1, y1), (x0, y1)),
    @cad.SegmentLine((x0, y1), (x0, y0)),
  ]
}

///|
/// accessory_metadata builds metadata for a Maker Pipe-compatible accessory.
fn accessory_metadata(
  designation : String,
  family : String,
  size : String,
  source : String,
  material : String,
) -> @common.Metadata {
  @common.Metadata::new(
    designation~,
    standard="Maker Pipe-compatible accessory (vendor-proprietary; not a standard)",
    family~,
    size~,
    material~,
    source~,
  )
}

///|
/// adapter_shim builds a C-shaped adapter shim from one EMT size to a larger
/// Maker Pipe connector socket.
///
/// Frame: pipe axis +Z, from `z = 0` to `z = length`. The outer surface enters
/// the connector socket; the inner bore slides over the smaller pipe.
pub fn adapter_shim(
  from_trade : String,
  to_trade : String,
  length_mm~ : Double = 30.0,
  slot_width_mm~ : Double = 6.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let from = match emt_boundary(from_trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let to = match makerpipe_size(to_trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let inner = from.outside_diameter_mm + 0.2
  let outer = to.socket_bore_mm - 0.2
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("adapter shim length", length_mm),
    @common.require_positive("adapter shim slot width", slot_width_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if outer <= inner + 1.0 {
    return Err(
      @common.InvalidParameter(
        "adapter shim has no wall between the smaller pipe and the connector bore",
      ),
    )
  }
  if slot_width_mm >= inner {
    return Err(
      @common.InvalidParameter("adapter shim slot width leaves no inner ring"),
    )
  }
  let body = @cad.SlitTube::new(
    outer_diameter_mm=outer,
    inner_diameter_mm=inner,
    length_mm~,
    slot_width_mm~,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["c-sleeve", "outer-surface", "inner-bore", "slot"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="stacked-shims",
        reason="one nominal C-sleeve is modelled; multiple stacked shims are caller-selected hardware",
      ),
      @common.Omission::new(
        feature="spring-and-retention",
        reason="no spring, adhesive, or retention feature is modelled",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-shim-\{from_trade}-to-\{to_trade}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible adapter shim \{from_trade} in EMT to \{to_trade} in socket",
      "adapter shim",
      "\{from_trade}->\{to_trade}",
      "Shim sized from the EMT outside diameter and the published connector socket bore; one nominal C-sleeve",
      "nylon",
    ),
    description="Nominal Maker Pipe-compatible adapter shim: a C-shaped sleeve that slides over a smaller EMT pipe and enters a larger connector socket. No spring, adhesive, or stacked-shim kit is modelled.",
    features~,
  ).add_layer(body, name="shim", color~)
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "outer",
          placement=tube_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalShaft,
          gender=@common.MateGender::Male,
          diameter_mm=outer,
          depth_mm=length_mm,
          fit=@cad.Fit::Close,
          description="outer surface that enters the connector socket",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "inner",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=length_mm,
          fit=@cad.Fit::Free,
          description="inner bore that slides over the smaller pipe",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "end-a",
          placement=@common.Placement::translation(0.0, 0.0, 0.0),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=outer,
          description="shim end at z = 0",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "end-b",
          placement=@common.Placement::translation(0.0, 0.0, length_mm),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=outer,
          description="shim end at z = length",
        ),
      ),
    ),
  )
}

///|
/// pipe_tube_shim builds a thin C-sleeve with explicit bore and outer
/// diameters, for non-EMT pipes and tubes.
pub fn pipe_tube_shim(
  inner_diameter_mm : Double,
  outer_diameter_mm : Double,
  length_mm~ : Double = 30.0,
  slot_width_mm~ : Double = 6.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("pipe shim inner diameter", inner_diameter_mm),
    @common.require_positive("pipe shim outer diameter", outer_diameter_mm),
    @common.require_positive("pipe shim length", length_mm),
    @common.require_positive("pipe shim slot width", slot_width_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if outer_diameter_mm <= inner_diameter_mm + 0.5 {
    return Err(
      @common.InvalidParameter("pipe shim outer diameter must exceed the bore"),
    )
  }
  if slot_width_mm >= inner_diameter_mm {
    return Err(
      @common.InvalidParameter("pipe shim slot width leaves no inner ring"),
    )
  }
  let body = @cad.SlitTube::new(
    outer_diameter_mm~,
    inner_diameter_mm~,
    length_mm~,
    slot_width_mm~,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["c-sleeve", "outer-surface", "inner-bore", "slot"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="spring-and-retention",
        reason="no spring, adhesive, or retention feature is modelled",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-pipe-shim-\{@cad.fmt_double(outer_diameter_mm, None)}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible pipe and tube adapter shim",
      "adapter shim",
      "\{@cad.fmt_double(inner_diameter_mm, None)}-\{@cad.fmt_double(outer_diameter_mm, None)}",
      "Caller-supplied bore and outer diameter; one nominal C-sleeve",
      "nylon",
    ),
    description="Nominal thin C-shaped pipe and tube adapter shim. No spring, adhesive, or retention feature is modelled.",
    features~,
  ).add_layer(body, name="shim", color~)
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "outer",
          placement=tube_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalShaft,
          gender=@common.MateGender::Male,
          diameter_mm=outer_diameter_mm,
          depth_mm=length_mm,
          fit=@cad.Fit::Close,
          description="outer surface that enters the connector socket",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "inner",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner_diameter_mm,
          depth_mm=length_mm,
          fit=@cad.Fit::Free,
          description="inner bore that slides over the smaller pipe",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "end-a",
          placement=@common.Placement::translation(0.0, 0.0, 0.0),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=outer_diameter_mm,
          description="shim end at z = 0",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "end-b",
          placement=@common.Placement::translation(0.0, 0.0, length_mm),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=outer_diameter_mm,
          description="shim end at z = length",
        ),
      ),
    ),
  )
}

///|
/// end_cap builds the Maker Pipe push-in end cap for an EMT trade size.
///
/// Reuses the repository's EMT spigot end cap; the cap disc is flush with the
/// tube OD and the plug enters the tube bore.
pub fn end_cap(
  trade : String,
  cap_thickness_mm~ : Double = 3.0,
  plug_length_mm~ : Double = 15.0,
  plug_clearance_mm~ : Double = 0.25,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  match
    @motion.emt_end_cap(
      size,
      cap_thickness_mm,
      plug_length_mm,
      plug_clearance_mm~,
      color~,
    ) {
    Err(e) => Err(e)
    Ok(cap) => Ok(add_origin(cap))
  }
}

///|
/// rubber_foot builds a push-on rubber pipe foot.
///
/// Frame: foot bottom at `z = 0`, pipe axis +Z. The pipe seat is at the floor
/// top; the pipe extends up through the mouth.
pub fn rubber_foot(
  trade : String,
  height_mm~ : Double = 20.0,
  wall_mm~ : Double = 3.0,
  floor_mm~ : Double = 3.0,
  clearance_mm~ : Double = 0.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("rubber foot height", height_mm),
    @common.require_positive("rubber foot wall", wall_mm),
    @common.require_positive("rubber foot floor", floor_mm),
    @common.require_non_negative("rubber foot clearance", clearance_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if floor_mm >= height_mm {
    return Err(
      @common.InvalidParameter(
        "rubber foot floor must be thinner than the height",
      ),
    )
  }
  let ri = size.outside_diameter_mm / 2.0 + clearance_mm
  let ro = ri + wall_mm
  let embed = 0.5
  let floor = @cad.Cylinder::new(2.0 * ro, floor_mm)
  let wall = @cad.RevolvedProfile::tube(
    2.0 * ro,
    2.0 * ri,
    height_mm - floor_mm + embed,
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["floor-disc", "cup-wall", "pipe-bore", "mouth"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="rubber-detail",
        reason="no ribs, texture, or material compliance is modelled",
      ),
    ],
  )
  let component = @common.Component::new(
      name="makerpipe-foot-\{trade}",
      metadata=accessory_metadata(
        "Maker Pipe-compatible rubber pipe foot \{trade} in EMT",
        "rubber pipe foot",
        trade,
        "Sized from the EMT outside diameter; height, wall, and floor are engineering defaults",
        "rubber (EPDM)",
      ),
      description="Nominal push-on rubber pipe foot: a revolved cup with a closed floor and an open pipe bore. No ribs, texture, or material compliance is modelled.",
      features~,
    )
    .add_layer(floor, name="floor", color~)
    .add_layer(
      wall,
      name="cup-wall",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, floor_mm - embed),
    )
  let depth = height_mm - floor_mm
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "pipe-seat",
          placement=socket_frame((0.0, 0.0, floor_mm), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=2.0 * ri,
          depth_mm=depth,
          fit=@cad.Fit::Free,
          description="pipe bore; the pipe end seats on the floor top",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "floor",
          placement=@common.Placement::identity(),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=2.0 * ro,
          description="floor contact face; outward normal is -Z",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "mouth",
          placement=@common.Placement::translation(0.0, 0.0, height_mm),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=2.0 * ro,
          description="open mouth at z = height",
        ),
      ),
    ),
  )
}

///|
/// thread_nominal returns the nominal diameter of a supported inch thread.
fn thread_nominal(thread : String) -> Result[Double, @common.SpecError] {
  match thread {
    "1/4-20" => Ok(6.35)
    "3/8-16" => Ok(9.525)
    other =>
      Err(
        @common.InvalidSize(
          "unsupported pipe-insert thread: \{other}; supported: 1/4-20, 3/8-16",
        ),
      )
  }
}

///|
/// star_loop returns a counter-clockwise star polygon for an expansion insert.
fn star_loop(
  outer_radius : Double,
  inner_radius : Double,
  lobes : Int32,
) -> Array[@cad.ProfileSegment] {
  let count = 2 * lobes
  let points : Array[@cad.Vec2] = []
  for k in 0..<count {
    let angle = 2.0 * @math.PI * k.to_double() / count.to_double()
    let radius = if k % 2 == 0 { outer_radius } else { inner_radius }
    points.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
  let segments : Array[@cad.ProfileSegment] = []
  for k in 0..<count {
    segments.push(@cad.SegmentLine(points[k], points[(k + 1) % count]))
  }
  segments
}

///|
/// threaded_insert builds a star expansion insert with a declared inch thread.
///
/// Frame: leading end at `z = 0`, thread opening at `z = length` (the lip, if
/// present, is at the top). The thread is declared by a mate, never modelled.
pub fn threaded_insert(
  trade : String,
  thread : String,
  lip~ : Bool = true,
  length_mm~ : Double = 12.0,
  lip_thickness_mm~ : Double = 1.2,
  interference_mm~ : Double = 0.3,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let nominal = match thread_nominal(thread) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("threaded insert length", length_mm),
    @common.require_positive("threaded insert lip thickness", lip_thickness_mm),
    @common.require_non_negative(
      "threaded insert interference", interference_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if lip && lip_thickness_mm >= length_mm {
    return Err(
      @common.InvalidParameter(
        "threaded insert lip must be thinner than the insert",
      ),
    )
  }
  let tube_id = emt_inside_diameter(size)
  let outer_r = (tube_id + interference_mm) / 2.0
  let star_inner_r = outer_r - 0.8
  if star_inner_r <= nominal / 2.0 + 0.8 {
    return Err(
      @common.InvalidParameter(
        "threaded insert has no material between the star valleys and the thread bore",
      ),
    )
  }
  let thread_r = nominal / 2.0
  let body = @cad.ExtrudedArcProfile::new(
    star_loop(outer_r, star_inner_r, 8),
    length_mm,
    holes=[circle_loop_at(0.0, 0.0, thread_r)],
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["expansion-star", "thread-bore", "seat"],
    approximated=[
      @common.Approximation::new(
        feature="star-petals",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.5,
        control="eight straight lobes; no spring temper or expansion petals are modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="thread-profile",
        reason="the inch thread is declared by the thread mate, never modelled",
      ),
      @common.Omission::new(
        feature="installation-tool",
        reason="no setting tool or swaging operation is modelled",
      ),
    ],
  )
  let component = @common.Component::new(
    name="makerpipe-insert-\{trade}-\{thread}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible threaded pipe insert \{thread} for \{trade} in EMT",
      "threaded pipe insert",
      "\{trade}/\{thread}",
      "Star envelope sized from the EMT inside diameter; thread and lip dimensions are engineering defaults",
      "zinc-plated steel",
    ),
    description="Nominal Maker Pipe-compatible threaded pipe insert: an eight-lobe expansion star with a declared inch thread and an optional lip. No spring temper, swaging, or thread profile is modelled.",
    features~,
  ).add_layer(body, name="star", color~)
  let mut with_lip = component
  if lip {
    with_lip = with_lip.add_layer(
      @cad.RevolvedProfile::tube(
        size.outside_diameter_mm,
        nominal,
        lip_thickness_mm,
      ).as_shape(),
      name="lip",
      color~,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        length_mm - lip_thickness_mm,
      ),
    )
  }
  let with_connectors = with_lip
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=socket_frame((0.0, 0.0, length_mm), (0.0, 0.0, 1.0)),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=nominal,
        depth_mm=length_mm,
        fit=@cad.Fit::Nominal,
        description="declared inch thread opening at the lip",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "outer",
        placement=tube_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=2.0 * outer_r,
        depth_mm=length_mm,
        fit=@cad.Fit::Press,
        description="expansion-star envelope; a press fit in the pipe inside diameter",
      ),
    )
  let with_connectors = if lip {
    with_connectors.with_connector_unchecked(
      @common.MateConnector::new(
        "seat",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          length_mm - lip_thickness_mm,
        ),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=size.outside_diameter_mm,
        description="lip underside that abuts the pipe end",
      ),
    )
  } else {
    with_connectors
  }
  Ok(add_origin(with_connectors))
}

///|
/// strap_tab adds one mounting tab to a strap.
fn strap_tab(
  component : @common.Component,
  suffix : String,
  ring_outer_r : Double,
  width_mm : Double,
  tab_length_mm : Double,
  tab_width_mm : Double,
  tab_thickness_mm : Double,
  hole_diameter_mm : Double,
  side : Double,
  color : @cad.Rgb,
) -> @common.Component {
  let embed = 0.5
  let tab_start = ring_outer_r - embed
  let tab_end = tab_start + tab_length_mm
  let x0 = if side > 0.0 { tab_start } else { -tab_end }
  let x1 = if side > 0.0 { tab_end } else { -tab_start }
  let hole_x = side * (tab_start + tab_length_mm * 0.7)
  let tab = @cad.ExtrudedArcProfile::new(
    rect_loop_2d(x0, -width_mm / 2.0, x1, width_mm / 2.0),
    tab_thickness_mm,
    holes=[circle_loop_at(hole_x, 0.0, hole_diameter_mm / 2.0)],
  ).as_shape()
  let tab_placement = @common.Placement::compose(
    @common.Placement::translation(0.0, -tab_thickness_mm / 2.0, width_mm / 2.0),
    @common.Placement::rotation_x(-90.0),
  )
  let face_placement = @common.Placement::translation(
    hole_x,
    tab_thickness_mm / 2.0,
    width_mm / 2.0,
  )
  let axis = (0.0, 1.0, 0.0)
  component
  .add_layer(
    tab,
    name=hinge_name("tab", suffix),
    color~,
    placement=tab_placement,
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      hinge_name("mount", suffix),
      placement=face_placement,
      axis~,
      kind=@common.MateKind::PlaneFace,
      diameter_mm=tab_width_mm,
      description="tab mounting face",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      hinge_name("mount-hole", suffix),
      placement=socket_frame(
        (hole_x, tab_thickness_mm / 2.0, width_mm / 2.0),
        axis,
      ),
      axis~,
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=hole_diameter_mm,
      depth_mm=tab_thickness_mm,
      fit=@cad.Fit::Free,
      description="tab mounting-hole clearance",
    ),
  )
}

///|
/// strap_collar builds the pipe collar for a strap.
fn strap_collar(
  size : @motion.EmtSize,
  width_mm : Double,
  wall_mm : Double,
  clearance_mm : Double,
) -> (@cad.Shape, Double, Double) {
  let inner = size.outside_diameter_mm + clearance_mm
  let outer = inner + 2.0 * wall_mm
  let shape = @cad.RevolvedProfile::tube(outer, inner, width_mm).as_shape()
  (shape, inner, outer)
}

///|
/// one_hole_strap builds a one-hole EMT mounting strap.
pub fn one_hole_strap(
  trade : String,
  width_mm~ : Double = 16.0,
  wall_mm~ : Double = 1.5,
  clearance_mm~ : Double = 0.5,
  tab_length_mm~ : Double = 18.0,
  tab_width_mm~ : Double = 16.0,
  tab_thickness_mm~ : Double = 1.5,
  hole_diameter_mm~ : Double = 5.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("one-hole strap width", width_mm),
    @common.require_positive("one-hole strap wall", wall_mm),
    @common.require_non_negative("one-hole strap clearance", clearance_mm),
    @common.require_positive("one-hole strap tab length", tab_length_mm),
    @common.require_positive("one-hole strap tab width", tab_width_mm),
    @common.require_positive("one-hole strap tab thickness", tab_thickness_mm),
    @common.require_positive("one-hole strap hole", hole_diameter_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let (collar, inner, outer) = strap_collar(
    size, width_mm, wall_mm, clearance_mm,
  )
  let component = @common.Component::new(
    name="makerpipe-one-hole-strap-\{trade}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible one-hole EMT strap \{trade} in EMT",
      "mounting strap",
      trade,
      "Sized from the EMT outside diameter; tab and hole dimensions are engineering defaults",
      "zinc-plated steel",
    ),
    description="Nominal one-hole EMT mounting strap: a pipe collar with one flat tab and a mounting-hole clearance. No thread, screw, or load rating is modelled.",
    features=@common.FeatureRecord::new(
      modeled=["collar", "pipe-bore", "tab", "mounting-hole"],
      approximated=[],
      omitted=[
        @common.Omission::new(
          feature="screw-and-thread",
          reason="the mounting screw is separate hardware and is not modelled",
        ),
      ],
    ),
  ).add_layer(collar, name="collar", color~)
  let with_tab = strap_tab(
    component,
    "",
    outer / 2.0,
    width_mm,
    tab_length_mm,
    tab_width_mm,
    tab_thickness_mm,
    hole_diameter_mm,
    1.0,
    color,
  )
  Ok(
    add_origin(
      with_tab.with_connector_unchecked(
        @common.MateConnector::new(
          "pipe",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=width_mm,
          fit=@cad.Fit::Free,
          description="pipe bore through the strap collar",
        ),
      ),
    ),
  )
}

///|
/// two_hole_strap builds a two-hole EMT mounting strap with tabs on opposite
/// sides.
pub fn two_hole_strap(
  trade : String,
  width_mm~ : Double = 16.0,
  wall_mm~ : Double = 1.5,
  clearance_mm~ : Double = 0.5,
  tab_length_mm~ : Double = 18.0,
  tab_width_mm~ : Double = 16.0,
  tab_thickness_mm~ : Double = 1.5,
  hole_diameter_mm~ : Double = 5.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let (collar, inner, outer) = strap_collar(
    size, width_mm, wall_mm, clearance_mm,
  )
  let component = @common.Component::new(
    name="makerpipe-two-hole-strap-\{trade}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible two-hole EMT strap \{trade} in EMT",
      "mounting strap",
      trade,
      "Sized from the EMT outside diameter; tab and hole dimensions are engineering defaults",
      "zinc-plated steel",
    ),
    description="Nominal two-hole EMT mounting strap: a pipe collar with two flat tabs and mounting-hole clearances. No thread, screw, or load rating is modelled.",
    features=@common.FeatureRecord::new(
      modeled=["collar", "pipe-bore", "two-tabs", "two-mounting-holes"],
      approximated=[],
      omitted=[
        @common.Omission::new(
          feature="screws-and-threads",
          reason="the mounting screws are separate hardware and are not modelled",
        ),
      ],
    ),
  ).add_layer(collar, name="collar", color~)
  let with_tabs = strap_tab(
    component,
    "1",
    outer / 2.0,
    width_mm,
    tab_length_mm,
    tab_width_mm,
    tab_thickness_mm,
    hole_diameter_mm,
    1.0,
    color,
  )
  let with_tabs = strap_tab(
    with_tabs,
    "2",
    outer / 2.0,
    width_mm,
    tab_length_mm,
    tab_width_mm,
    tab_thickness_mm,
    hole_diameter_mm,
    -1.0,
    color,
  )
  Ok(
    add_origin(
      with_tabs.with_connector_unchecked(
        @common.MateConnector::new(
          "pipe",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=width_mm,
          fit=@cad.Fit::Free,
          description="pipe bore through the strap collar",
        ),
      ),
    ),
  )
}

///|
/// mounting_strap builds the EMT mounting strap with a clamp bolt and one
/// mounting tab.
pub fn mounting_strap(
  trade : String,
  width_mm~ : Double = 16.0,
  wall_mm~ : Double = 1.5,
  clearance_mm~ : Double = 0.5,
  tab_length_mm~ : Double = 18.0,
  tab_width_mm~ : Double = 16.0,
  tab_thickness_mm~ : Double = 1.5,
  hole_diameter_mm~ : Double = 5.5,
  bolt_diameter_mm~ : Double = 6.6,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let (collar, inner, outer) = strap_collar(
    size, width_mm, wall_mm, clearance_mm,
  )
  let ear = @cad.RevolvedProfile::tube(14.0, bolt_diameter_mm, 6.0).as_shape()
  let ear_placement = tube_frame(
    (0.0, outer / 2.0 - 3.0, width_mm / 2.0),
    (0.0, 1.0, 0.0),
  )
  let component = @common.Component::new(
      name="makerpipe-mounting-strap-\{trade}",
      metadata=accessory_metadata(
        "Maker Pipe-compatible mounting strap \{trade} in EMT",
        "mounting strap",
        trade,
        "Sized from the EMT outside diameter; tab, ear, and hole dimensions are engineering defaults",
        "zinc-plated steel",
      ),
      description="Nominal EMT mounting strap: a pipe collar with one flat mounting tab and a clamp-bolt ear. The bolt and its thread are separate hardware and are not modelled.",
      features=@common.FeatureRecord::new(
        modeled=[
          "collar", "pipe-bore", "tab", "mounting-hole", "bolt-ear", "bolt-bore",
        ],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="bolt-and-thread",
            reason="the clamp bolt and its thread are separate hardware and are not modelled",
          ),
        ],
      ),
    )
    .add_layer(collar, name="collar", color~)
    .add_layer(ear, name="bolt-ear", color~, placement=ear_placement)
  let with_tab = strap_tab(
    component,
    "",
    outer / 2.0,
    width_mm,
    tab_length_mm,
    tab_width_mm,
    tab_thickness_mm,
    hole_diameter_mm,
    1.0,
    color,
  )
  Ok(
    add_origin(
      with_tab
      .with_connector_unchecked(
        @common.MateConnector::new(
          "pipe",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=width_mm,
          fit=@cad.Fit::Free,
          description="pipe bore through the strap collar",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "bolt",
          placement=socket_frame(
            (0.0, outer / 2.0, width_mm / 2.0),
            (0.0, 1.0, 0.0),
          ),
          axis=(0.0, 1.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=bolt_diameter_mm,
          depth_mm=6.0,
          fit=@cad.Fit::Free,
          description="clamp-bolt clearance through the ear",
        ),
      ),
    ),
  )
}

///|
/// cross_over_clamp builds a clamp for two perpendicular continuous pipes.
///
/// Frame: pipe A along +Z, pipe B along +X, both through the origin.
pub fn cross_over_clamp(
  trade : String,
  width_mm~ : Double = 20.0,
  wall_mm~ : Double = 3.0,
  clearance_mm~ : Double = 0.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let inner = size.outside_diameter_mm + clearance_mm
  let outer = inner + 2.0 * wall_mm
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("cross-over width", width_mm),
    @common.require_positive("cross-over wall", wall_mm),
    @common.require_non_negative("cross-over clearance", clearance_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let slot_width = inner - 0.05
  if slot_width <= size.outside_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "cross-over clearance is too small for the opposite pipe to pass the slot",
      ),
    )
  }
  let body = @cad.SlitTube::new(
    outer_diameter_mm=outer,
    inner_diameter_mm=inner,
    length_mm=width_mm,
    slot_width_mm=slot_width,
  ).as_shape()
  let component = @common.Component::new(
      name="makerpipe-cross-over-\{trade}",
      metadata=accessory_metadata(
        "Maker Pipe-compatible cross-over conduit clamp \{trade} in EMT",
        "cross-over clamp",
        trade,
        "Sized from the EMT outside diameter; width and wall are engineering defaults",
        "zinc-plated steel",
      ),
      description="Nominal cross-over clamp for two perpendicular continuous pipes: two C-shaped collars whose slots face the opposite pipe, so both bores stay open, plus a nominal clamp bolt. No stamped saddle or thread is modelled.",
      features=@common.FeatureRecord::new(
        modeled=[
          "collar-a", "collar-b", "slot-a", "slot-b", "pipe-a-bore", "pipe-b-bore",
          "bolt-bore",
        ],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="stamped-saddle-and-bolt",
            reason="the stamped saddle and clamp bolt are represented by two slotted collars and a bolt mate",
          ),
        ],
      ),
    )
    .add_layer(
      body,
      name="collar-a",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, -width_mm / 2.0),
    )
    .add_layer(
      body,
      name="collar-b",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(width_mm / 2.0, 0.0, 0.0),
        @common.Placement::rotation_y(-90.0),
      ),
    )
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "pipe-a",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=width_mm,
          fit=@cad.Fit::Free,
          description="continuous pipe A bore along +Z",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "pipe-b",
          placement=socket_frame((0.0, 0.0, 0.0), (-1.0, 0.0, 0.0)),
          axis=(-1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=width_mm,
          fit=@cad.Fit::Free,
          description="continuous pipe B bore along +X",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "bolt",
          placement=socket_frame((0.0, outer / 2.0, 0.0), (0.0, 1.0, 0.0)),
          axis=(0.0, 1.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=6.6,
          depth_mm=2.0 * wall_mm,
          fit=@cad.Fit::Free,
          description="nominal clamp-bolt clearance",
        ),
      ),
    ),
  )
}

///|
/// telescoping_clamp builds the 1/2 in into 3/4 in adjustable telescoping
/// clamp with a hand knob.
///
/// Frame: 3/4 in pipe enters from `z = 0`; the 1/2 in pipe slides through the
/// upper sleeve. The knob axis is +X.
pub fn telescoping_clamp(
  outer_trade~ : String = "3/4",
  inner_trade~ : String = "1/2",
  clearance_mm~ : Double = 0.5,
  wall_mm~ : Double = 3.0,
  lower_length_mm~ : Double = 30.0,
  upper_length_mm~ : Double = 40.0,
  knob_diameter_mm~ : Double = 18.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let outer_size = match emt_boundary(outer_trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let inner_size = match emt_boundary(inner_trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let ri1 = outer_size.outside_diameter_mm / 2.0 + clearance_mm
  let ro1 = ri1 + wall_mm
  let ri2 = inner_size.outside_diameter_mm / 2.0 + clearance_mm
  let ro2 = ri2 + wall_mm
  if outer_size.outside_diameter_mm <= inner_size.outside_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "telescoping clamp outer pipe must be larger than the inner pipe",
      ),
    )
  }
  if ro2 >= ro1 {
    return Err(
      @common.InvalidParameter(
        "telescoping clamp upper sleeve does not fit inside the lower outer wall",
      ),
    )
  }
  let total = lower_length_mm + upper_length_mm
  let body = @cad.RevolvedProfile::polyline(
    [
      (ri1, 0.0),
      (ro1, 0.0),
      (ro1, lower_length_mm),
      (ro2, lower_length_mm),
      (ro2, total),
      (ri2, total),
      (ri2, lower_length_mm),
      (ri1, lower_length_mm),
    ],
    closed=true,
  )
  let knob_z = lower_length_mm + upper_length_mm / 2.0
  let stem = @cad.Cylinder::new(10.0, 12.0)
  let knob = @cad.Cylinder::new(knob_diameter_mm, 5.0)
  let component = @common.Component::new(
      name="makerpipe-telescoping-clamp",
      metadata=accessory_metadata(
        "Maker Pipe-compatible telescoping clamp for 1/2 in into 3/4 in EMT",
        "telescoping clamp",
        "\{outer_trade}/\{inner_trade}",
        "Stepped sleeve sized from the two EMT outside diameters; lengths and knob are engineering defaults",
        "glass-filled nylon",
      ),
      description="Nominal telescoping clamp: a stepped plastic sleeve with a 3/4 in lower collar, a 1/2 in sliding upper sleeve, and a hand knob. No thread, clamp force, or retention rating is modelled.",
      features=@common.FeatureRecord::new(
        modeled=[
          "stepped-sleeve", "outer-pipe-bore", "inner-pipe-bore", "knob-stem", "knob",
        ],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="knob-thread-and-clamp",
            reason="the knob screw, thread, and clamp force are not modelled",
          ),
        ],
      ),
    )
    .add_layer(body.as_shape(), name="sleeve", color~)
    .add_layer(
      stem,
      name="knob-stem",
      color~,
      placement=tube_frame((ro2, 0.0, knob_z), (1.0, 0.0, 0.0)),
    )
    .add_layer(
      knob,
      name="knob",
      color~,
      placement=tube_frame((ro2 + 12.0, 0.0, knob_z), (1.0, 0.0, 0.0)),
    )
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "outer-pipe",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=2.0 * ri1,
          depth_mm=lower_length_mm,
          fit=@cad.Fit::Free,
          description="3/4 in lower pipe bore, entered from z = 0",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "inner-pipe",
          placement=socket_frame((0.0, 0.0, lower_length_mm), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=2.0 * ri2,
          depth_mm=upper_length_mm,
          fit=@cad.Fit::Free,
          description="1/2 in sliding upper pipe bore",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "knob",
          placement=tube_frame((ro2 + 12.0, 0.0, knob_z), (1.0, 0.0, 0.0)),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::Datum,
          diameter_mm=knob_diameter_mm,
          description="hand-knob axis along +X",
        ),
      ),
    ),
  )
}

///|
/// barrel_hinge builds the 0.94 in OD, 4 in barrel hinge that 3/4 in connectors
/// clamp as if it were EMT.
///
/// Frame: hinge axis +Z, from `z = 0` to `z = length`. The lower and upper
/// barrels are separated by a bearing washer.
pub fn barrel_hinge(
  length_mm~ : Double = 101.6,
  diameter_mm~ : Double = 23.876,
  pin_diameter_mm~ : Double = 7.8,
  barrel_gap_mm~ : Double = 1.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("barrel hinge length", length_mm),
    @common.require_positive("barrel hinge diameter", diameter_mm),
    @common.require_positive("barrel hinge pin diameter", pin_diameter_mm),
    @common.require_positive("barrel hinge gap", barrel_gap_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if pin_diameter_mm >= diameter_mm - 2.0 {
    return Err(
      @common.InvalidParameter("barrel hinge pin is too large for the barrel"),
    )
  }
  if length_mm <= barrel_gap_mm + 2.0 {
    return Err(
      @common.InvalidParameter("barrel hinge is too short for two barrels"),
    )
  }
  let barrel_length = (length_mm - barrel_gap_mm) / 2.0
  let bore = pin_diameter_mm + 0.2
  let barrel = @cad.RevolvedProfile::tube(diameter_mm, bore, barrel_length).as_shape()
  let bearing = @cad.RevolvedProfile::tube(
    diameter_mm, pin_diameter_mm, barrel_gap_mm,
  ).as_shape()
  let pin = @cad.Cylinder::new(pin_diameter_mm, length_mm)
  let component = @common.Component::new(
      name="makerpipe-barrel-hinge",
      metadata=accessory_metadata(
        "Maker Pipe-compatible barrel hinge, 0.94 in OD x 4 in", "barrel hinge",
        "0.94 in", "Barrel OD 23.876 mm and length 101.6 mm from the published product dimensions; pin and bearing are engineering defaults",
        "zinc-plated steel",
      ),
      description="Nominal Maker Pipe-compatible barrel hinge: two hollow barrels on the +Z hinge axis with a bearing washer and a through pin. The 0.94 in barrel OD matches the 3/4 in connector socket bore. No thread, retention, or load rating is modelled.",
      features=@common.FeatureRecord::new(
        modeled=["barrel-a", "barrel-b", "bearing-washer", "pin", "pin-bores"],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="pin-retention",
            reason="no set screw, peening, or retaining feature is modelled",
          ),
        ],
      ),
    )
    .add_layer(barrel, name="barrel-a", color~)
    .add_layer(
      barrel,
      name="barrel-b",
      color~,
      placement=@common.Placement::translation(
        0.0,
        0.0,
        barrel_length + barrel_gap_mm,
      ),
    )
    .add_layer(
      bearing,
      name="bearing",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, barrel_length),
    )
    .add_layer(pin, name="pin", color~)
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "barrel-a",
          placement=tube_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalShaft,
          gender=@common.MateGender::Male,
          diameter_mm~,
          depth_mm=barrel_length,
          fit=@cad.Fit::Close,
          description="lower barrel outside diameter, entered from z = 0",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "barrel-b",
          placement=@common.Placement::translation(0.0, 0.0, length_mm),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalShaft,
          gender=@common.MateGender::Male,
          diameter_mm~,
          depth_mm=barrel_length,
          fit=@cad.Fit::Close,
          description="upper barrel outside diameter, entered from z = length",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "hinge-axis",
          placement=@common.Placement::identity(),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          diameter_mm~,
          description="barrel hinge rotation axis along +Z",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "joint",
          placement=@common.Placement::translation(
            0.0,
            0.0,
            barrel_length + barrel_gap_mm / 2.0,
          ),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          diameter_mm~,
          description="barrel joint mid-plane",
        ),
      ),
    ),
  )
}
