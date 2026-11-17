///|
/// printed_hinge builds a 3D-printed EMT conduit hinge.
///
/// Frame: two parallel pipe axes along +Z at `x = +/-c`; the hinge barrel and
/// pin lie on +Z at `x = 0`. Each leaf is a half-shell saddle around its pipe,
/// open away from the hinge. The two leaves own one barrel each. The 1/4 in
/// through-bolts are declared by mates but not cut into the nominal saddles.
pub fn printed_hinge(
  trade : String,
  leaf_height_mm~ : Double = 40.0,
  wall_mm~ : Double = 3.0,
  clearance_mm~ : Double = 0.5,
  pin_diameter_mm~ : Double = 6.0,
  barrel_gap_mm~ : Double = 1.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("printed hinge leaf height", leaf_height_mm),
    @common.require_positive("printed hinge wall", wall_mm),
    @common.require_non_negative("printed hinge clearance", clearance_mm),
    @common.require_positive("printed hinge pin diameter", pin_diameter_mm),
    @common.require_positive("printed hinge barrel gap", barrel_gap_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let ri = size.outside_diameter_mm / 2.0 + clearance_mm
  let ro = ri + wall_mm
  let barrel_od = size.outside_diameter_mm * 0.7
  let barrel_r = barrel_od / 2.0
  if pin_diameter_mm >= barrel_od - 2.0 {
    return Err(
      @common.InvalidParameter(
        "printed hinge pin is too large for the hinge barrel",
      ),
    )
  }
  let c = ri + barrel_r + 2.0
  let half = (leaf_height_mm - barrel_gap_mm) / 2.0
  if half <= 0.0 {
    return Err(
      @common.InvalidParameter("printed hinge is too short for two barrels"),
    )
  }
  let plus_saddle = @cad.ExtrudedArcProfile::new(
    annular_sector_loop(ri, ro, @math.PI / 2.0, 3.0 * @math.PI / 2.0),
    leaf_height_mm,
  ).as_shape()
  let barrel = @cad.RevolvedProfile::tube(
    barrel_od,
    pin_diameter_mm + 0.2,
    half,
  ).as_shape()
  let pin = @cad.Cylinder::new(pin_diameter_mm, leaf_height_mm + 2.0)
  let features = @common.FeatureRecord::new(
    modeled=[
      "plus-saddle", "minus-saddle", "half-shells", "barrels", "pin", "hinge-axis",
    ],
    approximated=[
      @common.Approximation::new(
        feature="printed-hinge-saddles",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.5,
        control="half-shell saddles; the printed clamp details and bolt bosses are not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="bolt-holes",
        reason="the 1/4 in through-bolt holes are declared by mates but are not cut in the nominal saddles",
      ),
      @common.Omission::new(
        feature="print-detail",
        reason="no layer lines, fillets, or print orientation are modelled",
      ),
    ],
  )
  let component = @common.Component::new(
      name="makerpipe-printed-hinge-\{trade}",
      metadata=accessory_metadata(
        "Maker Pipe-compatible printed EMT conduit hinge \{trade} in EMT",
        "printed EMT hinge",
        trade,
        "Sized from the EMT outside diameter; leaf, barrel, and pin dimensions are engineering defaults; 1/4 in hardware is declared only",
        "PETG",
      ),
      description="Nominal 3D-printed EMT conduit hinge: two half-shell saddle leaves around parallel +Z pipes, one barrel per leaf, and a through pin on the +Z hinge axis. The 1/4 in through-bolt holes and print detail are not modelled.",
      features~,
    )
    .add_layer(
      plus_saddle,
      name="plus-saddle",
      color~,
      placement=@common.Placement::translation(c, 0.0, 0.0),
    )
    .add_layer(
      plus_saddle,
      name="minus-saddle",
      color~,
      placement=@common.Placement::compose(
        @common.Placement::translation(-c, 0.0, 0.0),
        @common.Placement::rotation_z(180.0),
      ),
    )
    .add_layer(
      barrel,
      name="barrel-plus",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
    )
    .add_layer(
      barrel,
      name="barrel-minus",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, half + barrel_gap_mm),
    )
    .add_layer(
      pin,
      name="pin",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, -1.0),
    )
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "pipe-a",
          placement=socket_frame((c, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=size.outside_diameter_mm + clearance_mm,
          depth_mm=leaf_height_mm,
          fit=@cad.Fit::Free,
          description="pipe A half-shell bore on the +X leaf",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "pipe-b",
          placement=socket_frame((-c, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=size.outside_diameter_mm + clearance_mm,
          depth_mm=leaf_height_mm,
          fit=@cad.Fit::Free,
          description="pipe B half-shell bore on the -X leaf",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "hinge-axis",
          placement=@common.Placement::identity(),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          diameter_mm=barrel_od,
          description="hinge barrel rotation axis along +Z",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "joint",
          placement=@common.Placement::translation(
            0.0,
            0.0,
            leaf_height_mm / 2.0,
          ),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Datum,
          diameter_mm=barrel_od,
          description="barrel joint mid-plane",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "bolt-a",
          placement=socket_frame(
            (c - ro, 0.0, leaf_height_mm / 2.0),
            (1.0, 0.0, 0.0),
          ),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=6.6,
          depth_mm=2.0 * ro,
          fit=@cad.Fit::Free,
          description="1/4 in through-bolt clearance for pipe A; declared, not cut",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "bolt-b",
          placement=socket_frame(
            (-c + ro, 0.0, leaf_height_mm / 2.0),
            (-1.0, 0.0, 0.0),
          ),
          axis=(-1.0, 0.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=6.6,
          depth_mm=2.0 * ro,
          fit=@cad.Fit::Free,
          description="1/4 in through-bolt clearance for pipe B; declared, not cut",
        ),
      ),
    ),
  )
}

///|
/// pipe_clip builds a generic printed C-shaped snap clip for EMT.
///
/// It represents the spring clip, cover clip, and GadgetKlips family: a
/// flexible C-sleeve that snaps over the pipe. The slot opens toward +X.
pub fn pipe_clip(
  trade : String,
  width_mm~ : Double = 12.0,
  wall_mm~ : Double = 2.0,
  clearance_mm~ : Double = 0.4,
  gap_mm~ : Double = 7.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let inner = size.outside_diameter_mm + clearance_mm
  let outer = inner + 2.0 * wall_mm
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("pipe clip width", width_mm),
    @common.require_positive("pipe clip wall", wall_mm),
    @common.require_positive("pipe clip gap", gap_mm),
    @common.require_non_negative("pipe clip clearance", clearance_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if gap_mm >= inner {
    return Err(@common.InvalidParameter("pipe clip gap leaves no clip ring"))
  }
  let body = @cad.SlitTube::new(
    outer_diameter_mm=outer,
    inner_diameter_mm=inner,
    length_mm=width_mm,
    slot_width_mm=gap_mm,
  ).as_shape()
  let component = @common.Component::new(
    name="makerpipe-pipe-clip-\{trade}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible printed EMT snap clip \{trade} in EMT",
      "printed pipe clip",
      trade,
      "Sized from the EMT outside diameter; width, wall, and gap are engineering defaults",
      "PETG",
    ),
    description="Nominal printed C-shaped EMT snap clip for the spring-clip, cover-clip, and GadgetKlips family. The slot opens toward +X. No spring finger, tab, or print detail is modelled.",
    features=@common.FeatureRecord::new(
      modeled=["c-clip", "pipe-bore", "slot"],
      approximated=[],
      omitted=[
        @common.Omission::new(
          feature="spring-finger-and-tab",
          reason="the flexible finger, cover tab, or cable saddle is not modelled",
        ),
      ],
    ),
  ).add_layer(body, name="clip", color~)
  Ok(
    add_origin(
      component
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
          description="pipe bore inside the snap clip",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "opening",
          placement=@common.Placement::translation(
            outer / 2.0,
            0.0,
            width_mm / 2.0,
          ),
          axis=(1.0, 0.0, 0.0),
          kind=@common.MateKind::Datum,
          diameter_mm=gap_mm,
          description="slot opening toward +X",
        ),
      ),
    ),
  )
}

///|
/// friction_band builds an elastomer friction band or shim ring.
pub fn friction_band(
  trade : String,
  width_mm~ : Double = 6.0,
  thickness_mm~ : Double = 1.5,
  interference_mm~ : Double = 0.2,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let size = match emt_boundary(trade) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("friction band width", width_mm),
    @common.require_positive("friction band thickness", thickness_mm),
    @common.require_non_negative("friction band interference", interference_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let inner = size.outside_diameter_mm - interference_mm
  let outer = inner + 2.0 * thickness_mm
  let body = @cad.RevolvedProfile::tube(outer, inner, width_mm).as_shape()
  let component = @common.Component::new(
    name="makerpipe-friction-band-\{trade}",
    metadata=accessory_metadata(
      "Maker Pipe-compatible friction band \{trade}",
      "friction band",
      trade,
      "Sized from the EMT outside diameter; width and thickness are engineering defaults",
      "elastomer",
    ),
    description="Nominal elastomer friction band or shim ring. Geometry only; no stretch, friction, or retention rating is modelled.",
    features=@common.FeatureRecord::new(
      modeled=["ring", "inner-bore", "outer-surface"],
      approximated=[],
      omitted=[
        @common.Omission::new(
          feature="elastomer-behavior",
          reason="no stretch, friction coefficient, or retention rating is modelled",
        ),
      ],
    ),
  ).add_layer(body, name="band", color~)
  Ok(
    add_origin(
      component
      .with_connector_unchecked(
        @common.MateConnector::new(
          "inner",
          placement=socket_frame((0.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=inner,
          depth_mm=width_mm,
          fit=@cad.Fit::Press,
          description="stretched inner bore",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "outer",
          placement=tube_frame((0.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::CylindricalShaft,
          gender=@common.MateGender::Male,
          diameter_mm=outer,
          depth_mm=width_mm,
          fit=@cad.Fit::Close,
          description="outer band surface",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "end-a",
          placement=@common.Placement::translation(0.0, 0.0, 0.0),
          axis=(0.0, 0.0, -1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=outer,
          description="band end at z = 0",
        ),
      )
      .with_connector_unchecked(
        @common.MateConnector::new(
          "end-b",
          placement=@common.Placement::translation(0.0, 0.0, width_mm),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::PlaneFace,
          diameter_mm=outer,
          description="band end at z = width",
        ),
      ),
    ),
  )
}
