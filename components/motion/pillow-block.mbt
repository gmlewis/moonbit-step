///|
/// PillowBlockInsertSize carries the measured geometry of the insert bearing
/// that sits in a UCP-series pillow-block housing.
///
/// The values are measured from the CC0 Innerscene UCP204 and UCP205 references
/// (the UC204/UC205 insert bearings). The insert is modelled as a
/// self-aligning outer race (spherical outside diameter), an extended inner
/// race with two set screws, two contact seals, and the two DIN 916 set screws
/// themselves; the rolling elements and cage between the races are omitted.
pub(all) struct PillowBlockInsertSize {
  outer_race_outer_radius_mm : Double
  outer_race_bore_radius_mm : Double
  outer_race_width_mm : Double
  inner_race_outer_radius_mm : Double
  inner_race_bore_radius_mm : Double
  inner_race_width_mm : Double
  inner_race_center_y_mm : Double
  race_chamfer_mm : Double
  seal_outer_radius_mm : Double
  seal_inner_radius_mm : Double
  seal_width_mm : Double
  seal_center_y_mm : Double
  set_screw_y_mm : Double
  set_screw_hole_radius_mm : Double
  set_screw_length_mm : Double
  set_screw_socket_radius_mm : Double
  set_screw_angles_deg : Array[Double]
  grease_hex_across_flats_mm : Double
  grease_hex_height_mm : Double
  grease_total_height_mm : Double
  grease_barrel_radius_mm : Double
  grease_tip_radius_mm : Double
  grease_neck_radius_mm : Double
  grease_shoulder_z_mm : Double
  grease_barrel_top_mm : Double
}

///|
/// PillowBlockSize carries the measured boundary dimensions of a UCP-series
/// pillow-block bearing: the housing casting, its insert bearing, and the two
/// base mounting slots.
///
/// The values are measured from the CC0 Innerscene UCP204 and UCP205 references
/// (Koyo published dimensions). The rolling elements and cage between the
/// insert races are not modelled.
pub(all) struct PillowBlockSize {
  designation : String
  shaft_bore_mm : Double
  shaft_height_mm : Double
  length_mm : Double
  base_width_mm : Double
  base_thickness_mm : Double
  bolt_pitch_mm : Double
  slot_width_mm : Double
  slot_length_mm : Double
  corner_radius_mm : Double
  relief_width_mm : Double
  relief_height_mm : Double
  arch_outer_radius_mm : Double
  arch_width_mm : Double
  seat_radius_mm : Double
  insert_outer_diameter_mm : Double
  insert_width_mm : Double
  arch_flank_half_width_mm : Double
  arch_flank_height_mm : Double
  arch_skirt_half_width_mm : Double
  insert : PillowBlockInsertSize
}

///|
/// pillow_block_designations returns every supported pillow-block designation.
pub fn pillow_block_designations() -> Array[String] {
  ["UCP204", "UCP205"]
}

///|
/// UCP204 insert geometry (UC204): measured from the Innerscene reference.
fn pb_insert_ucp204() -> PillowBlockInsertSize {
  {
    outer_race_outer_radius_mm: 23.5,
    outer_race_bore_radius_mm: 17.0,
    outer_race_width_mm: 16.0,
    inner_race_outer_radius_mm: 15.5,
    inner_race_bore_radius_mm: 10.0,
    inner_race_width_mm: 31.0,
    inner_race_center_y_mm: 2.8,
    race_chamfer_mm: 0.45,
    seal_outer_radius_mm: 16.975,
    seal_inner_radius_mm: 15.525,
    seal_width_mm: 1.1,
    seal_center_y_mm: 7.3,
    set_screw_y_mm: 13.3,
    set_screw_hole_radius_mm: 3.05,
    set_screw_length_mm: 4.0,
    set_screw_socket_radius_mm: 14.1,
    set_screw_angles_deg: [270.0, 150.0],
    grease_hex_across_flats_mm: 6.0,
    grease_hex_height_mm: 2.0,
    grease_total_height_mm: 5.8,
    grease_barrel_radius_mm: 1.9,
    grease_tip_radius_mm: 1.15,
    grease_neck_radius_mm: 1.5,
    grease_shoulder_z_mm: 3.8,
    grease_barrel_top_mm: 4.9,
  }
}

///|
/// UCP205 insert geometry (UC205): measured from the Innerscene reference.
fn pb_insert_ucp205() -> PillowBlockInsertSize {
  {
    outer_race_outer_radius_mm: 26.0,
    outer_race_bore_radius_mm: 19.5,
    outer_race_width_mm: 17.0,
    inner_race_outer_radius_mm: 18.0,
    inner_race_bore_radius_mm: 12.5,
    inner_race_width_mm: 34.1,
    inner_race_center_y_mm: 2.75,
    race_chamfer_mm: 0.45,
    seal_outer_radius_mm: 19.475,
    seal_inner_radius_mm: 18.025,
    seal_width_mm: 1.1,
    seal_center_y_mm: 7.8,
    set_screw_y_mm: 14.3,
    set_screw_hole_radius_mm: 3.05,
    set_screw_length_mm: 4.0,
    set_screw_socket_radius_mm: 16.6,
    set_screw_angles_deg: [270.0, 150.0],
    grease_hex_across_flats_mm: 6.0,
    grease_hex_height_mm: 2.0,
    grease_total_height_mm: 5.8,
    grease_barrel_radius_mm: 1.9,
    grease_tip_radius_mm: 1.15,
    grease_neck_radius_mm: 1.5,
    grease_shoulder_z_mm: 3.8,
    grease_barrel_top_mm: 4.9,
  }
}

///|
/// pillow_block_size looks up a UCP-series pillow-block boundary.
///
/// `arch_flank_half_width_mm`/`arch_flank_height_mm` and
/// `arch_skirt_half_width_mm` reproduce the measured cast-iron arch flank
/// (the straight flare between the round arch and the base top); they are not
/// derivable from the other dimensions and are recorded from the reference.
pub fn pillow_block_size(
  designation : String,
) -> Result[PillowBlockSize, @common.SpecError] {
  let token = designation.trim().to_owned().to_upper()
  match token {
    "UCP204" =>
      Ok({
        designation: token,
        shaft_bore_mm: 20.0,
        shaft_height_mm: 33.3,
        length_mm: 127.0,
        base_width_mm: 38.0,
        base_thickness_mm: 16.0,
        bolt_pitch_mm: 95.0,
        slot_width_mm: 13.0,
        slot_length_mm: 18.0,
        corner_radius_mm: 3.0,
        relief_width_mm: 55.0,
        relief_height_mm: 3.99,
        arch_outer_radius_mm: 31.7,
        arch_width_mm: 24.0,
        seat_radius_mm: 23.54,
        insert_outer_diameter_mm: 47.0,
        insert_width_mm: 16.0,
        arch_flank_half_width_mm: 30.7974,
        arch_flank_height_mm: 25.7894,
        arch_skirt_half_width_mm: 38.8882,
        insert: pb_insert_ucp204(),
      })
    "UCP205" =>
      Ok({
        designation: token,
        shaft_bore_mm: 25.0,
        shaft_height_mm: 36.5,
        length_mm: 140.0,
        base_width_mm: 38.0,
        base_thickness_mm: 16.0,
        bolt_pitch_mm: 105.0,
        slot_width_mm: 13.0,
        slot_length_mm: 18.0,
        corner_radius_mm: 3.0,
        relief_width_mm: 64.0,
        relief_height_mm: 3.99,
        arch_outer_radius_mm: 33.5,
        arch_width_mm: 26.0,
        seat_radius_mm: 26.04,
        insert_outer_diameter_mm: 52.0,
        insert_width_mm: 17.0,
        arch_flank_half_width_mm: 32.6298,
        arch_flank_height_mm: 28.914,
        arch_skirt_half_width_mm: 43.9731,
        insert: pb_insert_ucp205(),
      })
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported pillow block: \{other}; supported: UCP204, UCP205",
        ),
      )
  }
}

///|
/// Margin added to a cutter so it clearly spans the material it trims.
const PILLOW_BLOCK_CUTTER_MARGIN_MM : Double = 1.0

///|
/// Clearance kept between the grease fitting and the housing crown so the
/// evaluated compound keeps them as separate solids (as in the reference).
const PILLOW_BLOCK_GREASE_SEAT_GAP_MM : Double = 0.05

///|
/// Measured grease-fitting seat radius at its base, millimetres.
const PILLOW_BLOCK_GREASE_SEAT_RADIUS_MM : Double = 2.2

///|
/// Measured radius of the spot-faced counterbore the grease fitting sits in,
/// millimetres.
const PILLOW_BLOCK_GREASE_BOSS_RADIUS_MM : Double = 3.6

///|
/// Depth of the spot-faced counterbore below the crown apex, millimetres.
const PILLOW_BLOCK_GREASE_BOSS_DEPTH_MM : Double = 0.5

///|
/// pillow_block_bearing builds a UCP-series pillow-block bearing.
///
/// Frame: the mounting face is `z = 0` with its outward normal at -Z; the shaft
/// axis is +Y at `z = shaft_height`; the housing length runs along X. The base
/// is a rounded rectangular plate with two obround mounting slots on the bolt
/// pitch and a bottom centre relief. The arch is a horseshoe prism of
/// `arch_width` on the base top, so its bore opens down into the base and the
/// housing bore is a true through seat.
///
/// At `detail = Detailed` (the default) the insert bearing is the measured
/// self-aligning assembly: a spherical-OD outer race, an extended inner race
/// with 45-degree rim chamfers and two radial set-screw holes, two contact
/// seals, two DIN 916 set screws, and the grease fitting on the crown. The
/// parts sit at the reference's small clearances (0.025-0.05 mm) so the
/// OCCT-evaluated compound stays eight separate solids: the fused housing plus
/// the seven insert/fitting parts.
///
/// At `detail = Simplified` the insert is a plain sleeve envelope (two solids
/// total). Use `Component::write_step_evaluated` for the accepted artifact;
/// the flat writer cannot trim the relief or the seat bore. Rolling elements
/// and the cage are omitted at every detail level. No load, life, or safety
/// claim is made.
pub fn pillow_block_bearing(
  size : PillowBlockSize,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  fit_allowance_mm~ : Double = 0.04,
  color~ : @cad.Rgb = @cad.Rgb::new(0.035, 0.24, 0.09),
  insert_color~ : @cad.Rgb = @cad.Rgb::new(0.30, 0.36, 0.44),
) -> Result[@common.Component, @common.SpecError] {
  let insert = size.insert
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("pillow block shaft bore", size.shaft_bore_mm),
    @common.require_positive("pillow block shaft height", size.shaft_height_mm),
    @common.require_positive("pillow block length", size.length_mm),
    @common.require_positive("pillow block base width", size.base_width_mm),
    @common.require_positive(
      "pillow block base thickness",
      size.base_thickness_mm,
    ),
    @common.require_positive("pillow block bolt pitch", size.bolt_pitch_mm),
    @common.require_positive("pillow block slot width", size.slot_width_mm),
    @common.require_positive("pillow block slot length", size.slot_length_mm),
    @common.require_positive(
      "pillow block corner radius",
      size.corner_radius_mm,
    ),
    @common.require_positive("pillow block relief width", size.relief_width_mm),
    @common.require_non_negative(
      "pillow block relief height",
      size.relief_height_mm,
    ),
    @common.require_positive(
      "pillow block arch outside radius",
      size.arch_outer_radius_mm,
    ),
    @common.require_positive("pillow block arch width", size.arch_width_mm),
    @common.require_positive("pillow block seat radius", size.seat_radius_mm),
    @common.require_positive(
      "pillow block insert outside diameter",
      size.insert_outer_diameter_mm,
    ),
    @common.require_positive("pillow block insert width", size.insert_width_mm),
    @common.require_non_negative(
      "pillow block insert fit allowance", fit_allowance_mm,
    ),
    @common.require_positive(
      "pillow block outer race radius",
      insert.outer_race_outer_radius_mm,
    ),
    @common.require_positive(
      "pillow block outer race bore",
      insert.outer_race_bore_radius_mm,
    ),
    @common.require_positive(
      "pillow block outer race width",
      insert.outer_race_width_mm,
    ),
    @common.require_positive(
      "pillow block inner race radius",
      insert.inner_race_outer_radius_mm,
    ),
    @common.require_positive(
      "pillow block inner race bore",
      insert.inner_race_bore_radius_mm,
    ),
    @common.require_positive(
      "pillow block inner race width",
      insert.inner_race_width_mm,
    ),
    @common.require_non_negative(
      "pillow block inner race chamfer",
      insert.race_chamfer_mm,
    ),
    @common.require_positive(
      "pillow block seal outer radius",
      insert.seal_outer_radius_mm,
    ),
    @common.require_positive(
      "pillow block seal inner radius",
      insert.seal_inner_radius_mm,
    ),
    @common.require_positive("pillow block seal width", insert.seal_width_mm),
    @common.require_non_negative(
      "pillow block seal centre offset",
      insert.seal_center_y_mm,
    ),
    @common.require_positive(
      "pillow block set-screw hole radius",
      insert.set_screw_hole_radius_mm,
    ),
    @common.require_positive(
      "pillow block set-screw length",
      insert.set_screw_length_mm,
    ),
    @common.require_positive(
      "pillow block set-screw socket radius",
      insert.set_screw_socket_radius_mm,
    ),
    @common.require_positive(
      "pillow block grease across flats",
      insert.grease_hex_across_flats_mm,
    ),
    @common.require_positive(
      "pillow block grease hex height",
      insert.grease_hex_height_mm,
    ),
    @common.require_positive(
      "pillow block grease height",
      insert.grease_total_height_mm,
    ),
    @common.require_positive(
      "pillow block grease barrel radius",
      insert.grease_barrel_radius_mm,
    ),
    @common.require_positive(
      "pillow block grease tip radius",
      insert.grease_tip_radius_mm,
    ),
    @common.require_positive(
      "pillow block grease neck radius",
      insert.grease_neck_radius_mm,
    ),
    @common.require_positive(
      "pillow block grease shoulder height",
      insert.grease_shoulder_z_mm,
    ),
    @common.require_positive(
      "pillow block grease barrel top",
      insert.grease_barrel_top_mm,
    ),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let half_length = size.length_mm / 2.0
  let half_base_width = size.base_width_mm / 2.0
  let base_top = size.base_thickness_mm
  let seat_clearance = size.seat_radius_mm - size.insert_outer_diameter_mm / 2.0
  if seat_clearance < 0.0 {
    return Err(
      @common.InvalidDimension(
        "pillow block insert outside diameter exceeds the seat bore; increase the seat radius",
      ),
    )
  }
  if size.shaft_bore_mm >= size.insert_outer_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block shaft bore must be smaller than the insert outside diameter",
      ),
    )
  }
  if size.seat_radius_mm >= size.arch_outer_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block seat radius must be smaller than the arch outside radius",
      ),
    )
  }
  if size.shaft_height_mm <= base_top ||
    size.shaft_height_mm - base_top >= size.seat_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block shaft height must place the seat bore partly below the base top",
      ),
    )
  }
  if size.shaft_height_mm - size.insert_outer_diameter_mm / 2.0 <=
    size.relief_height_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block insert bearing would reach the bottom relief; raise the shaft height or lower the relief",
      ),
    )
  }
  if size.insert_width_mm > size.arch_width_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block insert bearing is wider than the arch",
      ),
    )
  }
  if size.arch_width_mm >= size.base_width_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block arch width must be smaller than the base width",
      ),
    )
  }
  if size.arch_flank_half_width_mm <= 0.0 ||
    size.arch_flank_half_width_mm >= size.arch_outer_radius_mm ||
    size.arch_flank_half_width_mm >= size.arch_skirt_half_width_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block arch flank must lie between the arch centre and the skirt, inside the outer radius",
      ),
    )
  }
  if size.arch_skirt_half_width_mm >= half_length {
    return Err(
      @common.InvalidDimension(
        "pillow block arch skirt runs past the base length",
      ),
    )
  }
  if size.relief_width_mm >= size.length_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block bottom relief is wider than the base",
      ),
    )
  }
  if size.relief_height_mm >= base_top {
    return Err(
      @common.InvalidDimension(
        "pillow block bottom relief is thicker than the base",
      ),
    )
  }
  if size.corner_radius_mm >= half_base_width ||
    size.corner_radius_mm >= half_length {
    return Err(
      @common.InvalidDimension(
        "pillow block corner radius does not fit the base",
      ),
    )
  }
  if size.slot_width_mm >= size.base_width_mm {
    return Err(
      @common.InvalidDimension("pillow block slot is wider than the base"),
    )
  }
  if size.slot_length_mm < size.slot_width_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block slot length must be at least its width",
      ),
    )
  }
  let slot_half_travel = (size.slot_length_mm - size.slot_width_mm) / 2.0
  let slot_outer = size.bolt_pitch_mm / 2.0 +
    slot_half_travel +
    size.slot_width_mm / 2.0
  if slot_outer >= half_length - size.corner_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block mounting slot runs past the base corner radius; reduce the pitch or the slot",
      ),
    )
  }
  if size.relief_width_mm / 2.0 >= half_length - size.corner_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block bottom relief reaches the base corner radius",
      ),
    )
  }
  // Insert consistency: the races must nest with a rolling gap, and the seals
  // must clear both races. All clearances are positive, which also keeps the
  // evaluated assembly as separate solids.
  if insert.outer_race_bore_radius_mm <= insert.inner_race_outer_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block outer race bore must clear the inner race outside diameter",
      ),
    )
  }
  if insert.inner_race_bore_radius_mm * 2.0 != size.shaft_bore_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block inner race bore must equal the declared shaft bore",
      ),
    )
  }
  if insert.inner_race_outer_radius_mm <= insert.inner_race_bore_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block inner race outside diameter must exceed its bore",
      ),
    )
  }
  if insert.seal_outer_radius_mm >= insert.outer_race_bore_radius_mm ||
    insert.seal_inner_radius_mm <= insert.inner_race_outer_radius_mm ||
    insert.seal_inner_radius_mm >= insert.seal_outer_radius_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block seal must clear both races and have a positive radial width",
      ),
    )
  }
  if insert.race_chamfer_mm >=
    (insert.inner_race_outer_radius_mm - insert.inner_race_bore_radius_mm) / 2.0 {
    return Err(
      @common.InvalidDimension(
        "pillow block race chamfer does not fit the inner race wall",
      ),
    )
  }
  if insert.set_screw_hole_radius_mm * 2.0 >= insert.inner_race_width_mm ||
    insert.set_screw_length_mm >= insert.inner_race_width_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block set screw does not fit the inner race width",
      ),
    )
  }
  if insert.grease_hex_across_flats_mm <= insert.grease_barrel_radius_mm * 2.0 {
    return Err(
      @common.InvalidDimension(
        "pillow block grease barrel does not fit the hex body",
      ),
    )
  }
  if insert.grease_neck_radius_mm >= insert.grease_barrel_radius_mm ||
    insert.grease_tip_radius_mm >= insert.grease_barrel_radius_mm ||
    insert.grease_hex_height_mm >= insert.grease_shoulder_z_mm ||
    insert.grease_shoulder_z_mm >= insert.grease_barrel_top_mm ||
    insert.grease_barrel_top_mm >= insert.grease_total_height_mm {
    return Err(
      @common.InvalidDimension(
        "pillow block grease-fitting profile is not monotonic",
      ),
    )
  }
  let inner_half = Double::sqrt(
    size.seat_radius_mm * size.seat_radius_mm -
    (size.shaft_height_mm - base_top) * (size.shaft_height_mm - base_top),
  )
  let slot_radius = size.slot_width_mm / 2.0
  let base_loop = pb_rounded_rect_loop(
    half_length,
    half_base_width,
    size.corner_radius_mm,
  )
  let slots : Array[Array[@cad.ProfileSegment]] = [
    pb_slot_loop(-size.bolt_pitch_mm / 2.0, slot_radius, slot_half_travel),
    pb_slot_loop(size.bolt_pitch_mm / 2.0, slot_radius, slot_half_travel),
  ]
  let base_prism = @cad.ExtrudedArcProfile::new(
    base_loop,
    size.base_thickness_mm,
    holes=slots,
  ).as_shape()
  let relief = @cad.Cuboid::new(
      size.relief_width_mm,
      size.base_width_mm + 2.0 * PILLOW_BLOCK_CUTTER_MARGIN_MM,
      size.relief_height_mm + PILLOW_BLOCK_CUTTER_MARGIN_MM,
    )
    .with_name("bottom-relief")
    .translate(
      x=-size.relief_width_mm / 2.0,
      y=-(half_base_width + PILLOW_BLOCK_CUTTER_MARGIN_MM),
      z=-PILLOW_BLOCK_CUTTER_MARGIN_MM,
    )
  let seat_cutter = @cad.Cylinder::new(
      2.0 * size.seat_radius_mm,
      size.base_width_mm + 2.0 * PILLOW_BLOCK_CUTTER_MARGIN_MM,
    )
    .with_name("insert-seat-bore")
    .rotate_x(90.0)
    .translate(
      y=half_base_width + PILLOW_BLOCK_CUTTER_MARGIN_MM,
      z=size.shaft_height_mm,
    )
  // The base plate keeps its obround mounting slots as profile holes; only the
  // bottom relief and the seat bore need a real boolean trim.
  let base = @cad.difference(
    base_prism.with_name("pillow-block-base-body"),
    [relief, seat_cutter],
    name="pillow-block-base",
  )
  let arch = @cad.ExtrudedArcProfile::new(
    pb_arch_loop(size, inner_half),
    size.arch_width_mm,
  ).as_shape()
  let crown = size.shaft_height_mm + size.arch_outer_radius_mm
  let grease_floor = crown - PILLOW_BLOCK_GREASE_BOSS_DEPTH_MM
  // The crown carries a measured spot-faced counterbore for the grease fitting.
  // This cutter is a child of the arch difference, so it lives in the arch's
  // local frame: local (x, y) = (world X, world Z), local z = axial width.
  let boss_cutter = @cad.Cylinder::new(
      2.0 * PILLOW_BLOCK_GREASE_BOSS_RADIUS_MM,
      PILLOW_BLOCK_GREASE_BOSS_DEPTH_MM + PILLOW_BLOCK_CUTTER_MARGIN_MM,
    )
    .with_name("grease-boss-bore")
    .rotate_x(-90.0)
    .translate(x=0.0, y=grease_floor, z=size.arch_width_mm / 2.0)
  let arch_scene = @cad.difference(
      arch.with_name("arch-body"),
      [boss_cutter],
      name="arch",
    )
    .rotate_x(90.0)
    .translate(y=size.arch_width_mm / 2.0)
  // One housing layer: the base and the arch fuse into the single cast body, so
  // its layer bounding box matches the evaluated housing solid (and it keeps a
  // presentation colour).
  let housing = @cad.union_all([base, arch_scene], name="housing")
  let features = @common.FeatureRecord::new(
    modeled=[
      "housing", "mounting-base", "obround-mounting-slots", "bottom-relief", "arch",
      "insert-seat-bore", "grease-boss-bore", "outer-race-spherical-od", "inner-race-extended",
      "inner-race-chamfers", "set-screw-holes", "seals", "set-screws", "grease-fitting",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="rolling-elements-and-cage",
        reason="the balls and cage between the insert races are not modelled",
      ),
      @common.Omission::new(
        feature="seat-bore-shoulder-relief",
        reason="the seat bore is trimmed through the base centre as a full saddle; the measured shoulder relief at the bore sides is not separately modelled",
      ),
      @common.Omission::new(
        feature="insert-inner-race-set-screw-threads",
        reason="the inner race set-screw holes are modelled as 6.1 mm tap-drill bores; the M6 threads are declared by the set-screw connectors",
      ),
      @common.Omission::new(
        feature="grease-fitting-thread",
        reason="the grease fitting is a measured envelope in the crown spot-face; its M6 thread is declared by the grease-port connector",
      ),
      @common.Omission::new(
        feature="tolerance-and-rating",
        reason="the 0.04 mm seat clearance and the insert/shaft bore clearances are declared fits; no tolerance class, load, life, or safety claim is made",
      ),
    ],
  )
  let mut component = @common.Component::new(
    name="pillow-block-bearing-\{size.designation.to_lower()}",
    metadata=@common.Metadata::new(
      designation="\{size.designation} pillow block bearing, \{@cad.fmt_double(size.shaft_bore_mm, None)} mm shaft",
      standard="Koyo UCP-series published dimensions (boundary)",
      family="pillow block bearing",
      size=size.designation,
      length_mm=size.length_mm,
      source="UCP-series pillow-block assembly measured from the CC0 Innerscene references: cast housing with two obround base slots and an insert seat, plus a self-aligning insert bearing (spherical-OD outer race, extended inner race with two set screws, contact seals) and a grease fitting. Rolling elements and cage are omitted.",
    ),
    description="UCP-series pillow-block bearing: a trimmed housing (base plate with obround mounting slots and bottom relief, plus a horseshoe arch with a spot-faced grease-fitting bore around the insert seat) and a self-aligning insert bearing (spherical-OD outer race, extended inner race with set screws, two contact seals, two DIN 916 set screws) with a measured grease fitting. The declared seat fit is metadata; no load, life, or safety claim is made.",
    features~,
  ).add_layer(housing.shape_intent(), name="housing", color~)
  let detailed = detail is @common.DetailLevel::Detailed ||
    detail is @common.DetailLevel::FullyModeled
  let outer_race_color = @cad.Rgb::new(0.36, 0.40, 0.45)
  let inner_race_color = @cad.Rgb::new(0.36, 0.40, 0.45)
  let seal_color = @cad.Rgb::new(0.025, 0.03, 0.035)
  let screw_color = @cad.Rgb::new(0.07, 0.085, 0.105)
  let grease_color = @cad.Rgb::new(0.64, 0.40, 0.12)
  if detailed {
    let outer_race = pb_outer_race_profile(insert).as_shape()
    let inner_base = @cad.RevolvedProfile::chamfered_tube(
      2.0 * insert.inner_race_outer_radius_mm,
      2.0 * insert.inner_race_bore_radius_mm,
      insert.inner_race_width_mm,
      outer_bottom_chamfer=insert.race_chamfer_mm,
      outer_top_chamfer=insert.race_chamfer_mm,
      inner_bottom_chamfer=insert.race_chamfer_mm,
      inner_top_chamfer=insert.race_chamfer_mm,
    ).as_shape()
    let inner_trans_y = insert.inner_race_center_y_mm +
      insert.inner_race_width_mm / 2.0
    let local_z_screw = inner_trans_y - insert.set_screw_y_mm
    let holes : Array[@cad.SceneNode] = insert.set_screw_angles_deg.map(fn(
      angle,
    ) {
      pb_radial_hole_local(
        insert.set_screw_hole_radius_mm * 2.0,
        insert.inner_race_outer_radius_mm -
        insert.inner_race_bore_radius_mm +
        1.5,
        insert.inner_race_outer_radius_mm,
        local_z_screw,
        angle,
      )
    })
    let inner_race = @cad.difference(
      inner_base.with_name("inner-race-body"),
      holes,
      name="inner-race",
    )
    let seal_minus = @cad.RevolvedProfile::tube(
      2.0 * insert.seal_outer_radius_mm,
      2.0 * insert.seal_inner_radius_mm,
      insert.seal_width_mm,
    ).as_shape()
    let seal_plus = @cad.RevolvedProfile::tube(
      2.0 * insert.seal_outer_radius_mm,
      2.0 * insert.seal_inner_radius_mm,
      insert.seal_width_mm,
    ).as_shape()
    let grease_hex = @cad.ExtrudedArcProfile::new(
      pb_hex_loop(insert.grease_hex_across_flats_mm),
      insert.grease_hex_height_mm,
    ).as_shape()
    let grease_nipple = pb_grease_nipple_profile(insert).as_shape()
    let grease_z = grease_floor + PILLOW_BLOCK_GREASE_SEAT_GAP_MM
    let grease_part = @cad.union_all(
      [
        grease_hex.with_name("grease-hex-body").translate(z=grease_z),
        grease_nipple.with_name("grease-nipple-body").translate(z=grease_z),
      ],
      name="grease-fitting",
    )
    component = component
      .add_layer(
        outer_race,
        name="outer-race",
        color=outer_race_color,
        placement=@common.Placement::at(
          0.0,
          insert.outer_race_width_mm / 2.0,
          size.shaft_height_mm,
          rx=90.0,
        ),
      )
      .add_layer(
        inner_race.shape_intent(),
        name="inner-race",
        color=inner_race_color,
        placement=@common.Placement::at(
          0.0,
          inner_trans_y,
          size.shaft_height_mm,
          rx=90.0,
        ),
      )
      .add_layer(
        seal_minus,
        name="seal-minus",
        color=seal_color,
        placement=@common.Placement::at(
          0.0,
          -(insert.seal_center_y_mm - insert.seal_width_mm / 2.0),
          size.shaft_height_mm,
          rx=90.0,
        ),
      )
      .add_layer(
        seal_plus,
        name="seal-plus",
        color=seal_color,
        placement=@common.Placement::at(
          0.0,
          insert.seal_center_y_mm + insert.seal_width_mm / 2.0,
          size.shaft_height_mm,
          rx=90.0,
        ),
      )
      .add_layer(
        grease_part.shape_intent(),
        name="grease-fitting",
        color=grease_color,
      )
    for i in 0..<insert.set_screw_angles_deg.length() {
      let angle = insert.set_screw_angles_deg[i]
      let radians = angle * @math.PI / 180.0
      let ca = @math.cos(radians)
      let sa = @math.sin(radians)
      let socket_x = ca * insert.set_screw_socket_radius_mm
      let socket_z = size.shaft_height_mm +
        sa * insert.set_screw_socket_radius_mm
      let theta = @math.atan2(-ca, -sa) * 180.0 / @math.PI
      let screw = match
        @fasteners.din916_cup_point_set_screw(
          @standards.MetricSize::M6,
          insert.set_screw_length_mm,
          orient_to_reference=true,
        ) {
        Ok(c) => c
        Err(e) => return Err(e)
      }
      let placed = screw
        .rotate_y(theta)
        .translate(x=socket_x, y=insert.set_screw_y_mm, z=socket_z)
      component = pb_add_component_layers(
        component,
        placed,
        "set-screw-\{i + 1}",
        screw_color,
      )
    }
  } else {
    let sleeve = @cad.RevolvedProfile::tube(
      size.insert_outer_diameter_mm,
      size.shaft_bore_mm,
      size.insert_width_mm,
    ).as_shape()
    component = component.add_layer(
      sleeve,
      name="insert-bearing",
      color=insert_color,
      placement=@common.Placement::at(
        0.0,
        size.insert_width_mm / 2.0,
        size.shaft_height_mm,
        rx=90.0,
      ),
    )
  }
  Ok(
    with_pillow_block_connectors(
      component,
      size,
      detail,
      seat_clearance + fit_allowance_mm,
    ),
  )
}

///|
/// pb_add_component_layers appends every layer of `placed` to `target` under a
/// common name prefix, keeping the layer's own placement.
fn pb_add_component_layers(
  target : @common.Component,
  placed : @common.Component,
  prefix : String,
  color : @cad.Rgb,
) -> @common.Component {
  let mut out = target
  let mut index = 0
  for layer in placed.layers() {
    out = out.add_layer(
      layer.shape,
      name="\{prefix}-\{index}",
      color~,
      placement=layer.placement,
    )
    index = index + 1
  }
  out
}

///|
/// pb_outer_race_profile builds the self-aligning outer race as a solid of
/// revolution: a spherical outside band (arc centred on the axis) between two
/// annular end faces, with a cylindrical bore.
fn pb_outer_race_profile(
  insert : PillowBlockInsertSize,
) -> @cad.RevolvedProfile {
  let ro = insert.outer_race_outer_radius_mm
  let ri = insert.outer_race_bore_radius_mm
  let width = insert.outer_race_width_mm
  let half = width / 2.0
  let r_end = Double::sqrt(ro * ro - half * half)
  @cad.RevolvedProfile::new([
    @cad.RevLine((ri, 0.0), (r_end, 0.0)),
    @cad.RevArc((r_end, 0.0), (r_end, width), (0.0, half)),
    @cad.RevLine((r_end, width), (ri, width)),
    @cad.RevLine((ri, width), (ri, 0.0)),
  ])
}

///|
/// pb_radial_hole_local builds one radial set-screw hole cutter in the inner
/// race's local frame (tube axis = local Z, radial plane = local XY).
///
/// `outward_angle_deg` is the outward radial direction; the cutter runs inward
/// from just outside the race outside diameter to just past the bore.
fn pb_radial_hole_local(
  diameter : Double,
  length : Double,
  outer_radius : Double,
  local_z : Double,
  outward_angle_deg : Double,
) -> @cad.SceneNode {
  let radians = outward_angle_deg * @math.PI / 180.0
  let ca = @math.cos(radians)
  let sa = @math.sin(radians)
  let phi = @math.atan2(ca, -sa) * 180.0 / @math.PI
  @cad.Cylinder::new(diameter, length)
  .with_name("set-screw-hole")
  .rotate_x(-90.0)
  .rotate_z(phi)
  .translate(
    x=ca * (outer_radius + PILLOW_BLOCK_CUTTER_MARGIN_MM),
    y=sa * (outer_radius + PILLOW_BLOCK_CUTTER_MARGIN_MM),
    z=local_z,
  )
}

///|
/// pb_grease_nipple_profile builds the grease fitting's measured barrel/tip
/// profile as a solid of revolution about the crown axis: a seat cone, a
/// shoulder step, a short barrel, and a tapered tip with a flat top. Its base
/// sits at the fitting's base plane; the hex body overlaps it.
fn pb_grease_nipple_profile(
  insert : PillowBlockInsertSize,
) -> @cad.RevolvedProfile {
  let seat = PILLOW_BLOCK_GREASE_SEAT_RADIUS_MM
  let neck = insert.grease_neck_radius_mm
  let shoulder = insert.grease_barrel_radius_mm
  let shoulder_z = insert.grease_shoulder_z_mm
  let barrel_top = insert.grease_barrel_top_mm
  let tip = insert.grease_tip_radius_mm
  let total = insert.grease_total_height_mm
  let hex_top = insert.grease_hex_height_mm
  @cad.RevolvedProfile::new([
    @cad.RevLine((0.0, 0.0), (seat, 0.0)),
    @cad.RevLine((seat, 0.0), (seat, hex_top)),
    @cad.RevLine((seat, hex_top), (neck, shoulder_z)),
    @cad.RevLine((neck, shoulder_z), (shoulder, shoulder_z)),
    @cad.RevLine((shoulder, shoulder_z), (shoulder, barrel_top)),
    @cad.RevLine((shoulder, barrel_top), (tip, total)),
    @cad.RevLine((tip, total), (0.0, total)),
  ])
}

///|
/// pb_hex_loop builds a closed counter-clockwise regular hexagon profile with
/// the given across-flats size, flats parallel to X/Y as in the reference.
fn pb_hex_loop(across_flats : Double) -> Array[@cad.ProfileSegment] {
  let across_corners = across_flats / @math.cos(@math.PI / 6.0)
  let points = @cad.Profile2D::polygon(6, across_corners, rotation=0.0)
  let n = points.length()
  let out : Array[@cad.ProfileSegment] = []
  for i in 0..<n {
    out.push(@cad.SegmentLine(points[i], points[(i + 1) % n]))
  }
  out
}

///|
/// pb_rounded_rect_loop builds a closed counter-clockwise rounded rectangle of
/// half extents `hx`, `hy` and corner radius `r`, with 90 degree corner arcs.
fn pb_rounded_rect_loop(
  hx : Double,
  hy : Double,
  r : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((hx, -hy + r), (hx, hy - r)),
    @cad.SegmentArc((hx, hy - r), (hx - r, hy), (hx - r, hy - r)),
    @cad.SegmentLine((hx - r, hy), (-hx + r, hy)),
    @cad.SegmentArc((-hx + r, hy), (-hx, hy - r), (-hx + r, hy - r)),
    @cad.SegmentLine((-hx, hy - r), (-hx, -hy + r)),
    @cad.SegmentArc((-hx, -hy + r), (-hx + r, -hy), (-hx + r, -hy + r)),
    @cad.SegmentLine((-hx + r, -hy), (hx - r, -hy)),
    @cad.SegmentArc((hx - r, -hy), (hx, -hy + r), (hx - r, -hy + r)),
  ]
}

///|
/// pb_slot_loop builds one closed counter-clockwise obround mounting slot:
/// a straight-sided slot of half width `r` with semicircular ends whose
/// centres are `2 * half_travel` apart, centred on `(cx, 0)`.
fn pb_slot_loop(
  cx : Double,
  r : Double,
  half_travel : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentArc(
      (cx + half_travel, -r),
      (cx + half_travel, r),
      (cx + half_travel, 0.0),
    ),
    @cad.SegmentLine((cx + half_travel, r), (cx - half_travel, r)),
    @cad.SegmentArc(
      (cx - half_travel, r),
      (cx - half_travel, -r),
      (cx - half_travel, 0.0),
    ),
    @cad.SegmentLine((cx - half_travel, -r), (cx + half_travel, -r)),
  ]
}

///|
/// pb_arch_loop builds the housing arch as a closed counter-clockwise
/// horseshoe in the XZ plane, expressed as local `(x, z)` pairs.
///
/// The outer boundary is the round crown of radius `arch_outer_radius` with a
/// straight flank down to the measured skirt half width; the inner boundary is
/// the seat bore, split where it meets the base top at `z = base_thickness`.
/// The bore opens downward, so the cross-section is one simply-connected loop.
fn pb_arch_loop(
  size : PillowBlockSize,
  inner_half : Double,
) -> Array[@cad.ProfileSegment] {
  let h = size.shaft_height_mm
  let base_top = size.base_thickness_mm
  let radius = size.arch_outer_radius_mm
  let crown = h + radius
  let bore_crown = h + size.seat_radius_mm
  let centre = (0.0, h)
  // The measured flank half width is rounded, so recompute its height on the
  // outer circle exactly; the arc validator rejects a rounded point.
  let flank_x = size.arch_flank_half_width_mm
  let flank_z = h - Double::sqrt(radius * radius - flank_x * flank_x)
  let skirt_x = size.arch_skirt_half_width_mm
  [
    @cad.SegmentLine((-skirt_x, base_top), (-inner_half, base_top)),
    @cad.SegmentArc((-inner_half, base_top), (0.0, bore_crown), centre),
    @cad.SegmentArc((0.0, bore_crown), (inner_half, base_top), centre),
    @cad.SegmentLine((inner_half, base_top), (skirt_x, base_top)),
    @cad.SegmentLine((skirt_x, base_top), (flank_x, flank_z)),
    @cad.SegmentArc((flank_x, flank_z), (0.0, crown), centre),
    @cad.SegmentArc((0.0, crown), (-flank_x, flank_z), centre),
    @cad.SegmentLine((-flank_x, flank_z), (-skirt_x, base_top)),
  ]
}

///|
/// with_pillow_block_connectors attaches the mating interfaces: the shaft bore
/// in the insert, the insert seat in the housing, the base mounting face, and
/// the two obround base slots. At detailed level it also exposes the two
/// set-screw threads and the grease port.
fn with_pillow_block_connectors(
  component : @common.Component,
  size : PillowBlockSize,
  detail : @common.DetailLevel,
  seat_allowance_mm : Double,
) -> @common.Component {
  let insert = size.insert
  let detailed = detail is @common.DetailLevel::Detailed ||
    detail is @common.DetailLevel::FullyModeled
  let axis_y = (0.0, 1.0, 0.0)
  let shaft_depth = if detailed {
    insert.inner_race_width_mm
  } else {
    size.insert_width_mm
  }
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "shaft-bore",
        placement=@common.Placement::translation(0.0, 0.0, size.shaft_height_mm),
        axis=axis_y,
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.shaft_bore_mm,
        depth_mm=shaft_depth,
        description="through shaft bore of the insert bearing inner race",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "insert-seat",
        placement=@common.Placement::translation(0.0, 0.0, size.shaft_height_mm),
        axis=axis_y,
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * size.seat_radius_mm,
        depth_mm=size.arch_width_mm,
        fit=if seat_allowance_mm > 0.0 {
          @cad.Fit::Free
        } else {
          @cad.Fit::Nominal
        },
        description="insert-bearing seat bore in the housing; declared clearance \{@cad.fmt_double(seat_allowance_mm, None)} mm",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        gender=@common.MateGender::Neutral,
        diameter_mm=size.base_width_mm,
        description="base mounting face; outward normal is -Z",
      ),
    )
  for i in 0..<2 {
    let sign = if i == 0 { -1.0 } else { 1.0 }
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "mounting-slot-\{i + 1}",
        placement=@common.Placement::translation(
          sign * size.bolt_pitch_mm / 2.0,
          0.0,
          0.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.slot_width_mm,
        depth_mm=size.base_thickness_mm,
        fit=@cad.Fit::Free,
        description="obround mounting slot \{@cad.fmt_double(size.slot_length_mm, None)} x \{@cad.fmt_double(size.slot_width_mm, None)} mm along X; the frame is at the slot centre",
      ),
    )
  }
  if detailed {
    for i in 0..<insert.set_screw_angles_deg.length() {
      let angle = insert.set_screw_angles_deg[i]
      let radians = angle * @math.PI / 180.0
      let ca = @math.cos(radians)
      let sa = @math.sin(radians)
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "set-screw-\{i + 1}",
          placement=@common.Placement::translation(
            ca * insert.set_screw_socket_radius_mm,
            insert.set_screw_y_mm,
            size.shaft_height_mm + sa * insert.set_screw_socket_radius_mm,
          ),
          axis=(-ca, 0.0, -sa),
          kind=@common.MateKind::Threaded,
          gender=@common.MateGender::Female,
          diameter_mm=6.0,
          depth_mm=insert.set_screw_length_mm,
          description="M6 set-screw thread in the inner race; the modelled hole is a \{@cad.fmt_double(insert.set_screw_hole_radius_mm * 2.0, None)} mm tap drill and the set screw is a DIN 916 envelope",
        ),
      )
    }
    let crown = size.shaft_height_mm + size.arch_outer_radius_mm
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "grease-port",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          crown - PILLOW_BLOCK_GREASE_BOSS_DEPTH_MM,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=6.0,
        depth_mm=insert.grease_hex_height_mm,
        description="M6 grease-fitting port in the crown spot-face; the fitting is a measured envelope and the thread is declared, not modelled",
      ),
    )
  }
  out
}
