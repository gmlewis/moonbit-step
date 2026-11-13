///|
/// thread_token_diameter_mm returns the nominal diameter for the metric thread
/// tokens used by insert and T-nut specifications.
fn thread_token_diameter_mm(token : String) -> Double {
  match token {
    "M2" => 2.0
    "M2.5" => 2.5
    "M3" => 3.0
    "M4" => 4.0
    "M5" => 5.0
    "M6" => 6.0
    "M8" => 8.0
    "M10" => 10.0
    _ => 0.0
  }
}

///|
/// with_insert_connectors attaches the thread and end-face frames to a heat-set
/// insert whose axis is +Z and whose insertion end is `z = 0`.
fn with_insert_connectors(
  component : @common.Component,
  thread_token : String,
  length_mm : Double,
  body_diameter_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "thread",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=thread_token_diameter_mm(thread_token),
      depth_mm=length_mm,
      description="internal thread envelope, entered from the bottom face",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "insertion-end",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=body_diameter_mm,
      description="end that is pressed into the printed boss",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "top-face",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=body_diameter_mm,
      description="flush top face",
    ),
  )
}

///|
/// with_tnut_connectors attaches the thread, slot-engagement, and bearing-face
/// frames to an extrusion T-nut.
fn with_tnut_connectors(
  component : @common.Component,
  thread_token : String,
  thickness_mm : Double,
  across_flats_mm : Double,
  slot_width_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "thread",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=thread_token_diameter_mm(thread_token),
      depth_mm=thickness_mm,
      description="thread envelope",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "slot-engagement",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::ProfileSlot,
      diameter_mm=slot_width_mm,
      depth_mm=thickness_mm,
      description="slot series the nut body is intended to engage",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bearing-face",
      placement=@common.Placement::translation(0.0, 0.0, thickness_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=across_flats_mm,
      description="face that clamps the profile slot",
    ),
  )
}

///|
/// with_screw_connectors attaches the documented fasteners-side mate frames to
/// a headed screw or bolt.
///
/// Frame: the screw axis is +Z, `tip_z_mm` is the free end of the shank,
/// `bearing_face_z_mm` is the under-head contact face, and `head_top_z_mm` is
/// the top of the head. The shank connector points outward along -Z; the
/// under-head bearing face points outward along -Z; the head top points +Z.
fn with_screw_connectors(
  component : @common.Component,
  diameter_mm : Double,
  shank_length_mm : Double,
  thread_length_mm : Double,
  head_diameter_mm : Double,
  bearing_face_z_mm~ : Double,
  head_top_z_mm~ : Double,
  tip_z_mm~ : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft",
      placement=@common.Placement::translation(0.0, 0.0, tip_z_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=shank_length_mm,
      description="free end of the shank; axis points out of the screw",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "thread-start",
      placement=@common.Placement::translation(0.0, 0.0, tip_z_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=thread_length_mm,
      description="start of the external thread, measured from the tip",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "head-bearing-face",
      placement=@common.Placement::translation(0.0, 0.0, bearing_face_z_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=head_diameter_mm,
      description="under-head clamp face; outward normal points toward the shank",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "head-top",
      placement=@common.Placement::translation(0.0, 0.0, head_top_z_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=head_diameter_mm,
      description="outer top face of the head",
    ),
  )
}

///|
/// with_nut_connectors attaches the documented nut-side mate frames.
///
/// Frame: the nut axis is +Z, the bearing face is `z = 0`, and the height is
/// `height_mm`. The bore points +Z into the nut; the two bearing faces point
/// outward.
fn with_nut_connectors(
  component : @common.Component,
  thread_diameter_mm : Double,
  height_mm : Double,
  width_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=thread_diameter_mm,
      depth_mm=height_mm,
      description="through bore, entered from the z = 0 bearing face",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bearing-face-bottom",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=width_mm,
      description="bearing face at z = 0; outward normal is -Z",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bearing-face-top",
      placement=@common.Placement::translation(0.0, 0.0, height_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=width_mm,
      description="bearing face at z = height; outward normal is +Z",
    ),
  )
}

///|
/// with_washer_connectors attaches the documented washer mate frames.
///
/// Frame: the washer faces are `z = 0` and `z = thickness_mm`.
fn with_washer_connectors(
  component : @common.Component,
  inner_diameter_mm : Double,
  outer_diameter_mm : Double,
  thickness_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "bore",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=inner_diameter_mm,
      depth_mm=thickness_mm,
      description="central clearance bore",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-bottom",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="bearing face at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "face-top",
      placement=@common.Placement::translation(0.0, 0.0, thickness_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=outer_diameter_mm,
      description="bearing face at z = thickness",
    ),
  )
}

///|
/// with_pin_connectors attaches end-shaft frames to a centred or base-origin
/// pin.
fn with_pin_connectors(
  component : @common.Component,
  diameter_mm : Double,
  length_mm : Double,
  centered~ : Bool = true,
) -> @common.Component {
  let z0 = if centered { -length_mm / 2.0 } else { 0.0 }
  let z1 = if centered { length_mm / 2.0 } else { length_mm }
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft-a",
      placement=@common.Placement::translation(0.0, 0.0, z0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="negative-Z end of the pin",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "shaft-b",
      placement=@common.Placement::translation(0.0, 0.0, z1),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="positive-Z end of the pin",
    ),
  )
}

///|
/// with_set_screw_connectors attaches the point and top-face frames to a set
/// screw. `point_z_mm` is the point end and `top_z_mm` the socket end; the point
/// axis points outward along -Z.
fn with_set_screw_connectors(
  component : @common.Component,
  diameter_mm : Double,
  length_mm : Double,
  point_z_mm~ : Double,
  top_z_mm~ : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "point",
      placement=@common.Placement::translation(0.0, 0.0, point_z_mm),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="point end; outward normal is -Z",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "top-face",
      placement=@common.Placement::translation(0.0, 0.0, top_z_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm~,
      description="socket end face; outward normal is +Z",
    ),
  )
}

///|
/// with_rod_connectors attaches a threaded end frame at each end of a rod whose
/// axis runs from `z = 0` to `z = length_mm`.
fn with_rod_connectors(
  component : @common.Component,
  diameter_mm : Double,
  length_mm : Double,
) -> @common.Component {
  component
  .with_connector_unchecked(
    @common.MateConnector::new(
      "thread-end-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="threaded end at z = 0",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "thread-end-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Male,
      diameter_mm~,
      depth_mm=length_mm,
      description="threaded end at z = length",
    ),
  )
}
