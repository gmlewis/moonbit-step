///|
/// A12MotorSpec describes the XAIRCRAFT A12 8318 100KV agricultural
/// outrunner motor envelope.
///
/// The frame is +X along the motor axis with `x = 0` at the bell face plane
/// and +X toward the fixed stator. The rotating prop adapter and hub boss
/// extend to negative X, and the fixed mount plate is at positive X.
///
/// The defaults are the measured motor dimensions: a 91 mm bell outside
/// diameter, a 33 mm overall height, a 23 mm M4 propeller circle, and 30 mm
/// M3 / 32 mm M4 mount circles. The
/// "8318" model code denotes a 83 mm stator lamination diameter with an 18 mm
/// stack length. `100KV` is a catalog designation only; no KV, torque,
/// current, efficiency, or thermal rating is implied by the geometry.
///
/// The large endbell is the **rotor**; the circular mount plate with the M3
/// and M4 hole patterns is the fixed **stator** and is the only part that may
/// be bolted to an enclosure. See `a12_motor` for the full connector roles.
///
/// Every dimension is a parameter so the same builder can represent other
/// large outrunners.
pub(all) struct A12MotorSpec {
  // Rotating bell
  bell_outer_diameter_mm : Double
  bell_wall_thickness_mm : Double
  bell_skirt_length_mm : Double
  bell_face_thickness_mm : Double
  bell_shoulder_radius_mm : Double
  bell_hub_boss_diameter_mm : Double
  bell_hub_boss_height_mm : Double
  bell_hub_bore_diameter_mm : Double
  bell_window_count : Int32
  bell_window_inner_diameter_mm : Double
  bell_window_outer_diameter_mm : Double
  bell_window_inner_half_angle_deg : Double
  bell_window_outer_half_angle_deg : Double
  bell_window_corner_radius_mm : Double
  bell_window_phase_deg : Double
  // Rotor magnets inside the skirt
  magnet_count : Int32
  magnet_outer_diameter_mm : Double
  magnet_thickness_mm : Double
  magnet_gap_mm : Double
  magnet_start_mm : Double
  magnet_length_mm : Double
  magnet_phase_deg : Double
  // Rotating prop adapter on the bell face
  prop_adapter_diameter_mm : Double
  prop_adapter_thickness_mm : Double
  prop_adapter_bore_diameter_mm : Double
  prop_hole_count : Int32
  prop_hole_diameter_mm : Double
  prop_hole_circle_diameter_mm : Double
  prop_hole_phase_deg : Double
  prop_screw_count : Int32
  prop_screw_diameter_mm : Double
  prop_screw_circle_diameter_mm : Double
  // Fixed stator lamination and windings
  stator_outer_diameter_mm : Double
  stator_inner_diameter_mm : Double
  stator_stack_length_mm : Double
  stator_stack_start_mm : Double
  stator_tooth_count : Int32
  stator_tooth_width_mm : Double
  stator_slot_floor_diameter_mm : Double
  stator_tooth_phase_deg : Double
  coil_radial_inner_diameter_mm : Double
  coil_radial_outer_diameter_mm : Double
  coil_width_mm : Double
  coil_axial_overhang_mm : Double
  coil_corner_radius_mm : Double
  coil_inner_corner_radius_mm : Double
  // Fixed stator mount plate
  stator_plate_diameter_mm : Double
  stator_plate_thickness_mm : Double
  stator_plate_start_mm : Double
  stator_plate_window_count : Int32
  stator_plate_window_inner_diameter_mm : Double
  stator_plate_window_outer_diameter_mm : Double
  stator_plate_window_inner_half_angle_deg : Double
  stator_plate_window_outer_half_angle_deg : Double
  stator_plate_window_corner_radius_mm : Double
  stator_plate_window_phase_deg : Double
  mount_m3_count : Int32
  mount_m3_hole_diameter_mm : Double
  mount_m3_circle_diameter_mm : Double
  mount_m4_count : Int32
  mount_m4_hole_diameter_mm : Double
  mount_m4_circle_diameter_mm : Double
  mount_hole_phase_deg : Double
  // Bearings, insulator, and shaft
  bearing_tube_outer_diameter_mm : Double
  bearing_bore_diameter_mm : Double
  pcb_ring_inner_diameter_mm : Double
  pcb_ring_outer_diameter_mm : Double
  pcb_thickness_mm : Double
  shaft_diameter_mm : Double
  shaft_front_extension_mm : Double
  shaft_rear_extension_mm : Double
}

///|
/// a12_motor_100kv_spec returns the measured defaults for the A12 8318
/// 100KV motor.
pub fn a12_motor_100kv_spec() -> A12MotorSpec {
  {
    bell_outer_diameter_mm: 91.0,
    bell_wall_thickness_mm: 1.5,
    bell_skirt_length_mm: 22.0,
    bell_face_thickness_mm: 3.0,
    bell_shoulder_radius_mm: 3.0,
    bell_hub_boss_diameter_mm: 40.0,
    bell_hub_boss_height_mm: 1.0,
    bell_hub_bore_diameter_mm: 28.0,
    bell_window_count: 8,
    bell_window_inner_diameter_mm: 41.0,
    bell_window_outer_diameter_mm: 83.0,
    bell_window_inner_half_angle_deg: 12.5,
    bell_window_outer_half_angle_deg: 17.5,
    bell_window_corner_radius_mm: 4.2,
    bell_window_phase_deg: 22.5,
    magnet_count: 42,
    magnet_outer_diameter_mm: 88.0,
    magnet_thickness_mm: 2.0,
    magnet_gap_mm: 1.0,
    magnet_start_mm: 3.5,
    magnet_length_mm: 18.0,
    magnet_phase_deg: 0.0,
    prop_adapter_diameter_mm: 29.0,
    prop_adapter_thickness_mm: 3.5,
    prop_adapter_bore_diameter_mm: 12.6,
    prop_hole_count: 4,
    prop_hole_diameter_mm: 4.0,
    prop_hole_circle_diameter_mm: 23.0,
    prop_hole_phase_deg: 0.0,
    prop_screw_count: 4,
    prop_screw_diameter_mm: 3.4,
    prop_screw_circle_diameter_mm: 23.0,
    stator_outer_diameter_mm: 83.0,
    stator_inner_diameter_mm: 66.0,
    stator_stack_length_mm: 18.0,
    stator_stack_start_mm: 4.8,
    stator_tooth_count: 36,
    stator_tooth_width_mm: 3.6,
    stator_slot_floor_diameter_mm: 72.0,
    stator_tooth_phase_deg: 0.0,
    coil_radial_inner_diameter_mm: 71.0,
    coil_radial_outer_diameter_mm: 83.6,
    coil_width_mm: 6.15,
    coil_axial_overhang_mm: 1.6,
    coil_corner_radius_mm: 1.6,
    coil_inner_corner_radius_mm: 0.8,
    stator_plate_diameter_mm: 63.0,
    stator_plate_thickness_mm: 5.7,
    stator_plate_start_mm: 22.8,
    stator_plate_window_count: 8,
    stator_plate_window_inner_diameter_mm: 39.0,
    stator_plate_window_outer_diameter_mm: 61.0,
    stator_plate_window_inner_half_angle_deg: 10.0,
    stator_plate_window_outer_half_angle_deg: 12.0,
    stator_plate_window_corner_radius_mm: 3.2,
    stator_plate_window_phase_deg: 0.0,
    mount_m3_count: 4,
    mount_m3_hole_diameter_mm: 3.4,
    mount_m3_circle_diameter_mm: 30.0,
    mount_m4_count: 4,
    mount_m4_hole_diameter_mm: 4.5,
    mount_m4_circle_diameter_mm: 32.0,
    mount_hole_phase_deg: 22.5,
    bearing_tube_outer_diameter_mm: 23.0,
    bearing_bore_diameter_mm: 12.6,
    pcb_ring_inner_diameter_mm: 61.0,
    pcb_ring_outer_diameter_mm: 68.0,
    pcb_thickness_mm: 0.8,
    shaft_diameter_mm: 12.0,
    shaft_front_extension_mm: 0.0,
    shaft_rear_extension_mm: 0.0,
  }
}

///|
/// a12_motor_spec validates an A12 outrunner envelope specification.
pub fn a12_motor_spec(spec : A12MotorSpec) -> Result[Unit, @common.SpecError] {
  let positive : Array[(String, Double)] = [
    ("a12 bell outer diameter", spec.bell_outer_diameter_mm),
    ("a12 bell wall", spec.bell_wall_thickness_mm),
    ("a12 bell skirt length", spec.bell_skirt_length_mm),
    ("a12 bell face thickness", spec.bell_face_thickness_mm),
    ("a12 bell hub boss diameter", spec.bell_hub_boss_diameter_mm),
    ("a12 bell window inner diameter", spec.bell_window_inner_diameter_mm),
    ("a12 bell window outer diameter", spec.bell_window_outer_diameter_mm),
    ("a12 magnet outer diameter", spec.magnet_outer_diameter_mm),
    ("a12 magnet thickness", spec.magnet_thickness_mm),
    ("a12 magnet length", spec.magnet_length_mm),
    ("a12 prop adapter diameter", spec.prop_adapter_diameter_mm),
    ("a12 prop adapter thickness", spec.prop_adapter_thickness_mm),
    ("a12 stator outer diameter", spec.stator_outer_diameter_mm),
    ("a12 stator inner diameter", spec.stator_inner_diameter_mm),
    ("a12 stator stack length", spec.stator_stack_length_mm),
    ("a12 stator tooth width", spec.stator_tooth_width_mm),
    ("a12 stator plate diameter", spec.stator_plate_diameter_mm),
    ("a12 stator plate thickness", spec.stator_plate_thickness_mm),
    ("a12 shaft diameter", spec.shaft_diameter_mm),
  ]
  for entry in positive {
    let (name, value) = entry
    match @common.require_positive(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let non_negative : Array[(String, Double)] = [
    ("a12 bell shoulder radius", spec.bell_shoulder_radius_mm),
    ("a12 bell hub boss height", spec.bell_hub_boss_height_mm),
    ("a12 bell window corner radius", spec.bell_window_corner_radius_mm),
    ("a12 magnet gap", spec.magnet_gap_mm),
    ("a12 magnet start", spec.magnet_start_mm),
    ("a12 stator stack start", spec.stator_stack_start_mm),
    ("a12 coil axial overhang", spec.coil_axial_overhang_mm),
    ("a12 coil corner radius", spec.coil_corner_radius_mm),
    ("a12 stator plate start", spec.stator_plate_start_mm),
    (
      "a12 stator plate window corner radius",
      spec.stator_plate_window_corner_radius_mm,
    ),
    ("a12 pcb thickness", spec.pcb_thickness_mm),
    ("a12 shaft front extension", spec.shaft_front_extension_mm),
    ("a12 shaft rear extension", spec.shaft_rear_extension_mm),
  ]
  for entry in non_negative {
    let (name, value) = entry
    match @common.require_non_negative(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if spec.bell_window_count < 3 {
    return Err(@common.InvalidParameter("a12 bell needs at least 3 windows"))
  }
  if spec.stator_plate_window_count < 3 {
    return Err(
      @common.InvalidParameter("a12 stator plate needs at least 3 windows"),
    )
  }
  if spec.magnet_count < 2 || spec.stator_tooth_count < 3 {
    return Err(
      @common.InvalidParameter(
        "a12 motor needs at least 2 magnets and 3 stator teeth",
      ),
    )
  }
  if spec.prop_hole_count < 1 ||
    spec.prop_screw_count < 1 ||
    spec.mount_m3_count < 1 ||
    spec.mount_m4_count < 1 {
    return Err(
      @common.InvalidParameter(
        "a12 motor needs at least one hole in every mounting pattern",
      ),
    )
  }
  let bell_radius = spec.bell_outer_diameter_mm / 2.0
  let wall = spec.bell_wall_thickness_mm
  let rim_inner_radius = bell_radius - wall
  let shoulder = spec.bell_shoulder_radius_mm
  let face_outer_radius = bell_radius - shoulder
  let boss_radius = spec.bell_hub_boss_diameter_mm / 2.0
  let bell_bore_radius = spec.bell_hub_bore_diameter_mm / 2.0
  if wall >= bell_radius / 2.0 {
    return Err(
      @common.InvalidDimension("a12 bell wall is too thick for its diameter"),
    )
  }
  if shoulder <= 0.0 || shoulder >= bell_radius / 2.0 {
    return Err(
      @common.InvalidDimension("a12 bell shoulder radius is out of range"),
    )
  }
  if face_outer_radius <= boss_radius {
    return Err(
      @common.InvalidDimension(
        "a12 bell face must be wider than the central hub boss",
      ),
    )
  }
  if bell_bore_radius >= boss_radius {
    return Err(
      @common.InvalidDimension("a12 bell bore does not fit the hub boss"),
    )
  }
  let win_inner_radius = spec.bell_window_inner_diameter_mm / 2.0
  let win_outer_radius = spec.bell_window_outer_diameter_mm / 2.0
  if win_inner_radius <= boss_radius || win_outer_radius >= face_outer_radius {
    return Err(
      @common.InvalidDimension("a12 bell windows do not fit the bell face"),
    )
  }
  if spec.bell_window_outer_half_angle_deg <=
    spec.bell_window_inner_half_angle_deg ||
    spec.bell_window_outer_half_angle_deg >=
    180.0 / spec.bell_window_count.to_double() {
    return Err(
      @common.InvalidParameter(
        "a12 bell window angles must increase outward and stay within a spoke pitch",
      ),
    )
  }
  let magnet_outer_radius = spec.magnet_outer_diameter_mm / 2.0
  let magnet_inner_radius = magnet_outer_radius - spec.magnet_thickness_mm
  if magnet_outer_radius > rim_inner_radius {
    return Err(
      @common.InvalidDimension("a12 magnets do not fit inside the bell skirt"),
    )
  }
  let stator_outer_radius = spec.stator_outer_diameter_mm / 2.0
  let stator_inner_radius = spec.stator_inner_diameter_mm / 2.0
  let slot_floor_radius = spec.stator_slot_floor_diameter_mm / 2.0
  if stator_outer_radius >= magnet_inner_radius {
    return Err(
      @common.InvalidDimension(
        "a12 stator outer diameter leaves no air gap inside the magnets",
      ),
    )
  }
  if slot_floor_radius <= stator_inner_radius ||
    slot_floor_radius >= stator_outer_radius {
    return Err(
      @common.InvalidDimension(
        "a12 stator slot floor must lie between the bore and the tooth tips",
      ),
    )
  }
  let half_tooth = spec.stator_tooth_width_mm / 2.0
  let tooth_pitch_half = 180.0 / spec.stator_tooth_count.to_double()
  let floor_half_deg = @math.asin(half_tooth / slot_floor_radius) *
    180.0 /
    @math.PI
  if floor_half_deg >= tooth_pitch_half {
    return Err(
      @common.InvalidDimension(
        "a12 stator teeth overlap their neighbours at the slot floor",
      ),
    )
  }
  let coil_inner_radius = spec.coil_radial_inner_diameter_mm / 2.0
  let coil_outer_radius = spec.coil_radial_outer_diameter_mm / 2.0
  if coil_inner_radius < slot_floor_radius - 1.0 ||
    coil_outer_radius <= coil_inner_radius ||
    coil_outer_radius > stator_outer_radius + 0.5 {
    return Err(
      @common.InvalidDimension(
        "a12 winding band must sit in the stator slots and clear the magnets",
      ),
    )
  }
  let coil_pitch = 2.0 *
    @math.PI *
    coil_inner_radius /
    spec.stator_tooth_count.to_double()
  if spec.coil_width_mm >= coil_pitch {
    return Err(
      @common.InvalidDimension(
        "a12 winding frames overlap their neighbours at the slot floor",
      ),
    )
  }
  let coil_hole_half = (spec.stator_tooth_width_mm + 0.4) / 2.0
  if spec.coil_width_mm <= 2.0 * coil_hole_half ||
    spec.coil_axial_overhang_mm <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "a12 winding frame must enclose the tooth with a positive wall",
      ),
    )
  }
  let plate_radius = spec.stator_plate_diameter_mm / 2.0
  if plate_radius > stator_inner_radius + 1.0 {
    return Err(
      @common.InvalidDimension(
        "a12 stator mount plate is wider than the lamination bore",
      ),
    )
  }
  let bearing_outer_radius = spec.bearing_tube_outer_diameter_mm / 2.0
  let bearing_bore_radius = spec.bearing_bore_diameter_mm / 2.0
  if bearing_outer_radius >= plate_radius ||
    bearing_bore_radius >= bearing_outer_radius {
    return Err(
      @common.InvalidDimension("a12 bearing tube does not fit the mount plate"),
    )
  }
  if spec.shaft_diameter_mm / 2.0 >= bearing_bore_radius {
    return Err(
      @common.InvalidDimension("a12 shaft does not clear the bearing bore"),
    )
  }
  let plate_win_inner = spec.stator_plate_window_inner_diameter_mm / 2.0
  let plate_win_outer = spec.stator_plate_window_outer_diameter_mm / 2.0
  if plate_win_inner <= bearing_outer_radius || plate_win_outer >= plate_radius {
    return Err(
      @common.InvalidDimension("a12 plate windows do not fit the mount plate"),
    )
  }
  if spec.stator_plate_window_outer_half_angle_deg <=
    spec.stator_plate_window_inner_half_angle_deg ||
    spec.stator_plate_window_outer_half_angle_deg >=
    180.0 / spec.stator_plate_window_count.to_double() {
    return Err(
      @common.InvalidParameter(
        "a12 plate window angles must increase outward and stay within a spoke pitch",
      ),
    )
  }
  let m3_reach = spec.mount_m3_circle_diameter_mm / 2.0 +
    spec.mount_m3_hole_diameter_mm / 2.0
  let m4_reach = spec.mount_m4_circle_diameter_mm / 2.0 +
    spec.mount_m4_hole_diameter_mm / 2.0
  if m3_reach >= plate_win_inner || m4_reach >= plate_win_inner {
    return Err(
      @common.InvalidDimension(
        "a12 mount holes overlap the stator plate windows",
      ),
    )
  }
  if spec.mount_m3_circle_diameter_mm / 2.0 -
    spec.mount_m3_hole_diameter_mm / 2.0 <=
    bearing_outer_radius ||
    spec.mount_m4_circle_diameter_mm / 2.0 -
    spec.mount_m4_hole_diameter_mm / 2.0 <=
    bearing_outer_radius {
    return Err(
      @common.InvalidDimension(
        "a12 mount holes overlap the central bearing tube",
      ),
    )
  }
  let prop_radius = spec.prop_adapter_diameter_mm / 2.0
  let prop_reach = spec.prop_hole_circle_diameter_mm / 2.0 +
    spec.prop_hole_diameter_mm / 2.0
  let screw_reach = spec.prop_screw_circle_diameter_mm / 2.0 +
    spec.prop_screw_diameter_mm / 2.0
  if prop_reach >= prop_radius || screw_reach >= prop_radius {
    return Err(
      @common.InvalidDimension(
        "a12 propeller holes and adapter screws do not fit the prop adapter",
      ),
    )
  }
  if spec.prop_adapter_bore_diameter_mm / 2.0 >=
    spec.prop_screw_circle_diameter_mm / 2.0 - spec.prop_screw_diameter_mm / 2.0 {
    return Err(
      @common.InvalidDimension("a12 adapter bore reaches the adapter screws"),
    )
  }
  if spec.magnet_gap_mm <= 0.0 {
    return Err(@common.InvalidDimension("a12 magnet gap must be positive"))
  }
  if spec.bell_skirt_length_mm <= spec.bell_face_thickness_mm + shoulder {
    return Err(
      @common.InvalidDimension(
        "a12 bell skirt must be long enough to clear the face and shoulder",
      ),
    )
  }
  if spec.magnet_start_mm + spec.magnet_length_mm > spec.bell_skirt_length_mm {
    return Err(
      @common.InvalidDimension("a12 magnets extend past the bell skirt"),
    )
  }
  if spec.stator_plate_start_mm <
    spec.stator_stack_start_mm + spec.stator_stack_length_mm - 1.0e-6 {
    return Err(
      @common.InvalidDimension(
        "a12 stator mount plate must sit behind the lamination stack",
      ),
    )
  }
  let bell_fillet = spec.bell_window_corner_radius_mm
  if bell_fillet >= (win_outer_radius - win_inner_radius) / 2.0 ||
    bell_fillet >=
    win_inner_radius *
    @math.sin(spec.bell_window_inner_half_angle_deg * @math.PI / 180.0) {
    return Err(
      @common.InvalidDimension("a12 bell window corner radius is too large"),
    )
  }
  let plate_fillet = spec.stator_plate_window_corner_radius_mm
  if plate_fillet >= (plate_win_outer - plate_win_inner) / 2.0 ||
    plate_fillet >=
    plate_win_inner *
    @math.sin(spec.stator_plate_window_inner_half_angle_deg * @math.PI / 180.0) {
    return Err(
      @common.InvalidDimension("a12 plate window corner radius is too large"),
    )
  }
  let coil_hole_axial_half = (spec.stator_stack_length_mm + 0.4) / 2.0
  let coil_outer_half = spec.coil_width_mm / 2.0
  if spec.coil_corner_radius_mm >= coil_outer_half ||
    spec.coil_corner_radius_mm >=
    coil_hole_axial_half + spec.coil_axial_overhang_mm {
    return Err(
      @common.InvalidDimension("a12 winding frame corner radius is too large"),
    )
  }
  if spec.coil_inner_corner_radius_mm >=
    (spec.stator_tooth_width_mm + 0.4) / 2.0 ||
    spec.coil_inner_corner_radius_mm >= coil_hole_axial_half {
    return Err(
      @common.InvalidDimension(
        "a12 winding frame hole corner radius is too large",
      ),
    )
  }
  Ok(())
}

///|
/// a12_polar returns a point at a radius and angle in degrees.
fn a12_polar(radius : Double, angle_deg : Double) -> (Double, Double) {
  let angle = angle_deg * @math.PI / 180.0
  (radius * @math.cos(angle), radius * @math.sin(angle))
}

///|
/// a12_circle_loop returns a counter-clockwise circle as four minor arcs.
fn a12_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let c = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), c),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), c),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), c),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), c),
  ]
}

///|
/// a12_bolt_hole_loops returns circular hole loops on a bolt circle.
fn a12_bolt_hole_loops(
  count : Int32,
  circle_diameter_mm : Double,
  hole_diameter_mm : Double,
  phase_deg : Double,
) -> Array[Array[@cad.ProfileSegment]] {
  let loops : Array[Array[@cad.ProfileSegment]] = []
  let radius = circle_diameter_mm / 2.0
  let hole_radius = hole_diameter_mm / 2.0
  for i in 0..<count {
    let angle = phase_deg + 360.0 * i.to_double() / count.to_double()
    let p = a12_polar(radius, angle)
    loops.push(a12_circle_loop(p.0, p.1, hole_radius))
  }
  loops
}

///|
/// a12_side_tangent returns the two tangent points of a straight side between
/// equal-radius corner fillets. `sign` mirrors the normal to the correct side
/// of the window.
fn a12_side_tangent(
  c1 : (Double, Double),
  c2 : (Double, Double),
  radius : Double,
  sign : Double,
) -> ((Double, Double), (Double, Double)) {
  let dx = c2.0 - c1.0
  let dy = c2.1 - c1.1
  let length = Double::sqrt(dx * dx + dy * dy)
  let nx = sign * (-dy / length)
  let ny = sign * (dx / length)
  (
    (c1.0 + radius * nx, c1.1 + radius * ny),
    (c2.0 + radius * nx, c2.1 + radius * ny),
  )
}

///|
/// a12_sector_loop returns a rounded annular-sector loop: a circular inner
/// edge, a circular outer edge, two straight sides, and a round at each
/// corner. The fillets are tangent to both the arc and the side, so every
/// segment of the emitted loop is an exact line or circular arc.
fn a12_sector_loop(
  center_deg : Double,
  inner_radius : Double,
  outer_radius : Double,
  inner_half_deg : Double,
  outer_half_deg : Double,
  fillet_radius : Double,
) -> Array[@cad.ProfileSegment] {
  let inner_left_angle = center_deg - inner_half_deg
  let inner_right_angle = center_deg + inner_half_deg
  let outer_left_angle = center_deg - outer_half_deg
  let outer_right_angle = center_deg + outer_half_deg
  let inner_left = a12_polar(inner_radius, inner_left_angle)
  let inner_right = a12_polar(inner_radius, inner_right_angle)
  let outer_left = a12_polar(outer_radius, outer_left_angle)
  let outer_right = a12_polar(outer_radius, outer_right_angle)
  let inner_center_left = a12_polar(
    inner_radius + fillet_radius,
    inner_left_angle,
  )
  let inner_center_right = a12_polar(
    inner_radius + fillet_radius,
    inner_right_angle,
  )
  let outer_center_left = a12_polar(
    outer_radius - fillet_radius,
    outer_left_angle,
  )
  let outer_center_right = a12_polar(
    outer_radius - fillet_radius,
    outer_right_angle,
  )
  let (inner_side_left, outer_side_left) = a12_side_tangent(
    inner_center_left, outer_center_left, fillet_radius, -1.0,
  )
  let (inner_side_right, outer_side_right) = a12_side_tangent(
    inner_center_right, outer_center_right, fillet_radius, 1.0,
  )
  let origin = (0.0, 0.0)
  // These points run clockwise around the window; reverse them so the emitted
  // loop is counter-clockwise like the other profiles in this package.
  let clockwise : Array[@cad.ProfileSegment] = [
    @cad.SegmentArc(inner_left, inner_right, origin),
    @cad.SegmentArc(inner_right, inner_side_right, inner_center_right),
    @cad.SegmentLine(inner_side_right, outer_side_right),
    @cad.SegmentArc(outer_side_right, outer_right, outer_center_right),
    @cad.SegmentArc(outer_right, outer_left, origin),
    @cad.SegmentArc(outer_left, outer_side_left, outer_center_left),
    @cad.SegmentLine(outer_side_left, inner_side_left),
    @cad.SegmentArc(inner_side_left, inner_left, inner_center_left),
  ]
  let reversed : Array[@cad.ProfileSegment] = []
  for i in 0..<clockwise.length() {
    match clockwise[clockwise.length() - 1 - i] {
      @cad.SegmentArc(a, b, c) => reversed.push(@cad.SegmentArc(b, a, c))
      @cad.SegmentLine(a, b) => reversed.push(@cad.SegmentLine(b, a))
    }
  }
  reversed
}

///|
/// a12_curved_plate_loop returns one rotor magnet: a curved plate of constant
/// width between two concentric arcs. The flanks are straight and parallel, so
/// the gap to the neighbouring plate stays even across the thickness.
fn a12_curved_plate_loop(
  center_deg : Double,
  inner_radius : Double,
  outer_radius : Double,
  width : Double,
) -> Array[@cad.ProfileSegment] {
  let origin = (0.0, 0.0)
  let half_width = width / 2.0
  let inner_half = @math.asin(half_width / inner_radius) * 180.0 / @math.PI
  let outer_half = @math.asin(half_width / outer_radius) * 180.0 / @math.PI
  let outer_left = a12_polar(outer_radius, center_deg - outer_half)
  let outer_right = a12_polar(outer_radius, center_deg + outer_half)
  let inner_left = a12_polar(inner_radius, center_deg - inner_half)
  let inner_right = a12_polar(inner_radius, center_deg + inner_half)
  [
    @cad.SegmentArc(outer_left, outer_right, origin),
    @cad.SegmentLine(outer_right, inner_right),
    @cad.SegmentArc(inner_right, inner_left, origin),
    @cad.SegmentLine(inner_left, outer_left),
  ]
}

///|
/// a12_rounded_rect_loop returns a counter-clockwise rectangle with circular
/// corner fillets, centred on the profile origin.
fn a12_rounded_rect_loop(
  half_x : Double,
  half_y : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let r = radius
  let hx = half_x
  let hy = half_y
  [
    @cad.SegmentLine((-hx + r, -hy), (hx - r, -hy)),
    @cad.SegmentArc((hx - r, -hy), (hx, -hy + r), (hx - r, -hy + r)),
    @cad.SegmentLine((hx, -hy + r), (hx, hy - r)),
    @cad.SegmentArc((hx, hy - r), (hx - r, hy), (hx - r, hy - r)),
    @cad.SegmentLine((hx - r, hy), (-hx + r, hy)),
    @cad.SegmentArc((-hx + r, hy), (-hx, hy - r), (-hx + r, hy - r)),
    @cad.SegmentLine((-hx, hy - r), (-hx, -hy + r)),
    @cad.SegmentArc((-hx, -hy + r), (-hx + r, -hy), (-hx + r, -hy + r)),
  ]
}

///|
/// a12_stator_tooth_loop returns the outer boundary of a 36-slot stator
/// lamination: a ring yoke with radial teeth and slots that open outward.
/// Every segment is an exact line or circular arc.
fn a12_stator_tooth_loop(
  tooth_count : Int32,
  tip_radius : Double,
  tooth_width : Double,
  floor_radius : Double,
  phase_deg : Double,
) -> Array[@cad.ProfileSegment] {
  let segments : Array[@cad.ProfileSegment] = []
  let origin = (0.0, 0.0)
  let pitch = 360.0 / tooth_count.to_double()
  let half_width = tooth_width / 2.0
  let tip_half = @math.asin(half_width / tip_radius) * 180.0 / @math.PI
  let floor_half = @math.asin(half_width / floor_radius) * 180.0 / @math.PI
  for i in 0..<tooth_count {
    let center = phase_deg + pitch * i.to_double()
    let tip_left = a12_polar(tip_radius, center - tip_half)
    let tip_right = a12_polar(tip_radius, center + tip_half)
    let floor_right = a12_polar(floor_radius, center + floor_half)
    let next_floor_left = a12_polar(floor_radius, center + pitch - floor_half)
    let next_tip_left = a12_polar(tip_radius, center + pitch - tip_half)
    segments.push(@cad.SegmentArc(tip_left, tip_right, origin))
    segments.push(@cad.SegmentLine(tip_right, floor_right))
    segments.push(@cad.SegmentArc(floor_right, next_floor_left, origin))
    segments.push(@cad.SegmentLine(next_floor_left, next_tip_left))
  }
  segments
}

///|
/// a12_motor builds a parameterized A12 8318 outrunner motor envelope.
///
/// The rotating assembly is a stacked, boolean-free set of bodies: an 8-spoke
/// endbell face plate with eight large rounded cooling windows in its profile,
/// an axisymmetric skirt with a rounded shoulder, a raised hub boss, one exact
/// curved magnet per pole, and a machined prop adapter. The fixed assembly is a
/// 36-slot stator lamination with one exact copper winding frame per tooth, an
/// 8-window mount plate whose teardrop openings sit between eight spokes, with
/// the interleaved M3 and M4 mount holes drilled through those spokes, a
/// bearing tube, and an insulator ring. A through shaft joins the two ends.
///
/// Every face is an analytic plane, cylinder, cone, sphere, or torus produced
/// by exact line and circular-arc profiles; no surface is triangulated.
///
/// **Rotor / stator role convention (important when building an assembly):**
///
/// - The large windowed **endbell is the rotor**. It spins. Attach gears,
///   pulleys, propellers, or other moving parts only through
///   `rotor-output-face`, `rotor-output-hole-*`, or the rotating
///   `rotor-shaft-*` ends.
/// - The circular **mount plate with the 30 mm M3 / 32 mm M4 holes is the
///   stator**. It must be bolted to the motor enclosure, frame, or gearbox
///   housing through `stator-mount-face` and `stator-mount-hole-*`. Nothing
///   that must rotate may be attached to the stator face.
pub fn a12_motor(
  spec : A12MotorSpec,
) -> Result[@common.Component, @common.SpecError] {
  match a12_motor_spec(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let bell_radius = spec.bell_outer_diameter_mm / 2.0
  let rim_inner_radius = bell_radius - spec.bell_wall_thickness_mm
  let face_outer_radius = bell_radius - spec.bell_shoulder_radius_mm
  let bell_bore_radius = spec.bell_hub_bore_diameter_mm / 2.0
  let face_thickness = spec.bell_face_thickness_mm
  let boss_height = spec.bell_hub_boss_height_mm
  let skirt_length = spec.bell_skirt_length_mm
  let shoulder = spec.bell_shoulder_radius_mm
  // Extruded profiles are built in a local frame with their axis on +Z, so
  // each layer carries the rotation onto +X and its axial origin in its
  // placement. A revolved profile is already axisymmetric.
  let on_axis = fn(x : Double) -> @common.Placement {
    @common.Placement::compose(
      @common.Placement::translation(x, 0.0, 0.0),
      @common.Placement::rotation_y(90.0),
    )
  }
  // Bell face: one spoked plate with the 8 cooling windows and the central
  // bore as profile holes. No boolean is needed to open the windows.
  let win_inner_radius = spec.bell_window_inner_diameter_mm / 2.0
  let win_outer_radius = spec.bell_window_outer_diameter_mm / 2.0
  let face_holes : Array[Array[@cad.ProfileSegment]] = []
  for i in 0..<spec.bell_window_count {
    // Profiles are built in XY and rotated +90 degrees about Y onto the +X
    // axis, which maps profile angle theta to world YZ angle theta - 90.
    let center = spec.bell_window_phase_deg +
      90.0 +
      360.0 * i.to_double() / spec.bell_window_count.to_double()
    face_holes.push(
      a12_sector_loop(
        center,
        win_inner_radius,
        win_outer_radius,
        spec.bell_window_inner_half_angle_deg,
        spec.bell_window_outer_half_angle_deg,
        spec.bell_window_corner_radius_mm,
      ),
    )
  }
  face_holes.push(a12_circle_loop(0.0, 0.0, bell_bore_radius))
  let bell_face_profile = @cad.ExtrudedArcProfile::new(
    a12_circle_loop(0.0, 0.0, face_outer_radius),
    face_thickness,
    holes=face_holes,
  )
  if !bell_face_profile.validate() {
    return Err(
      @common.InvalidParameter("a12 bell face did not form a valid profile"),
    )
  }
  // Bell skirt: an axisymmetric ring with a rounded outer shoulder and the
  // inner wall that clears the stator.
  let skirt_profile = @cad.RevolvedProfile::new([
    @cad.RevArc(
      (face_outer_radius, 0.0),
      (bell_radius, shoulder),
      (face_outer_radius, shoulder),
    ),
    @cad.RevLine((bell_radius, shoulder), (bell_radius, skirt_length)),
    @cad.RevLine((bell_radius, skirt_length), (rim_inner_radius, skirt_length)),
    @cad.RevLine(
      (rim_inner_radius, skirt_length),
      (rim_inner_radius, face_thickness),
    ),
    @cad.RevLine(
      (rim_inner_radius, face_thickness),
      (face_outer_radius, face_thickness),
    ),
    @cad.RevLine((face_outer_radius, face_thickness), (face_outer_radius, 0.0)),
  ])
  match skirt_profile.validate() {
    Err(e) =>
      return Err(
        @common.InvalidParameter("a12 bell skirt profile: \{e.message()}"),
      )
    Ok(_) => ()
  }
  // Raised hub boss on the face, clear of the windows.
  let boss_profile = @cad.RevolvedProfile::tube(
    spec.bell_hub_boss_diameter_mm,
    spec.bell_hub_bore_diameter_mm,
    boss_height,
  )
  match boss_profile.validate() {
    Err(e) =>
      return Err(
        @common.InvalidParameter("a12 bell boss profile: \{e.message()}"),
      )
    Ok(_) => ()
  }
  // Rotor magnets: one curved plate per pole, each an exact extrusion.
  let magnet_outer_radius = spec.magnet_outer_diameter_mm / 2.0
  let magnet_inner_radius = magnet_outer_radius - spec.magnet_thickness_mm
  let magnet_mid_radius = (magnet_outer_radius + magnet_inner_radius) / 2.0
  let magnet_pitch = 360.0 / spec.magnet_count.to_double()
  let pitch_chord = 2.0 *
    magnet_mid_radius *
    @math.sin(magnet_pitch * @math.PI / 360.0)
  let magnet_width = pitch_chord - spec.magnet_gap_mm
  if magnet_width <= 1.0e-6 {
    return Err(
      @common.InvalidDimension(
        "a12 magnet gap leaves no magnet width at the magnet ring",
      ),
    )
  }
  let magnet_layers : Array[@common.ComponentLayer] = []
  for i in 0..<spec.magnet_count {
    let center = spec.magnet_phase_deg + 90.0 + magnet_pitch * i.to_double()
    let magnet_profile = @cad.ExtrudedArcProfile::new(
      a12_curved_plate_loop(
        center, magnet_inner_radius, magnet_outer_radius, magnet_width,
      ),
      spec.magnet_length_mm,
    )
    if !magnet_profile.validate() {
      return Err(
        @common.InvalidParameter(
          "a12 rotor magnet did not form a valid profile",
        ),
      )
    }
    magnet_layers.push({
      shape: magnet_profile.as_shape(),
      name: "rotor-magnet-\{i + 1}",
      color: @cad.Rgb::grey(),
      placement: on_axis(spec.magnet_start_mm),
    })
  }
  // Machined prop adapter on the bell face.
  let prop_adapter_radius = spec.prop_adapter_diameter_mm / 2.0
  let adapter_front = -(boss_height + spec.prop_adapter_thickness_mm)
  let adapter_holes : Array[Array[@cad.ProfileSegment]] = []
  for
    hole in a12_bolt_hole_loops(
      spec.prop_hole_count,
      spec.prop_hole_circle_diameter_mm,
      spec.prop_hole_diameter_mm,
      spec.prop_hole_phase_deg + 90.0,
    ) {
    adapter_holes.push(hole)
  }
  for
    hole in a12_bolt_hole_loops(
      spec.prop_screw_count,
      spec.prop_screw_circle_diameter_mm,
      spec.prop_screw_diameter_mm,
      spec.prop_hole_phase_deg + 135.0,
    ) {
    adapter_holes.push(hole)
  }
  adapter_holes.push(
    a12_circle_loop(0.0, 0.0, spec.prop_adapter_bore_diameter_mm / 2.0),
  )
  let adapter_profile = @cad.ExtrudedArcProfile::new(
    a12_circle_loop(0.0, 0.0, prop_adapter_radius),
    spec.prop_adapter_thickness_mm,
    holes=adapter_holes,
  )
  if !adapter_profile.validate() {
    return Err(
      @common.InvalidParameter("a12 prop adapter did not form a valid profile"),
    )
  }
  // Stator lamination: ring yoke plus radial teeth, one exact extrusion.
  let stator_outer_radius = spec.stator_outer_diameter_mm / 2.0
  let slot_floor_radius = spec.stator_slot_floor_diameter_mm / 2.0
  let lamination_outer = a12_stator_tooth_loop(
    spec.stator_tooth_count,
    stator_outer_radius,
    spec.stator_tooth_width_mm,
    slot_floor_radius,
    spec.stator_tooth_phase_deg + 90.0,
  )
  let lamination = @cad.ExtrudedArcProfile::new(
    lamination_outer,
    spec.stator_stack_length_mm,
    holes=[a12_circle_loop(0.0, 0.0, spec.stator_inner_diameter_mm / 2.0)],
  )
  if !lamination.validate() {
    return Err(
      @common.InvalidParameter(
        "a12 stator lamination did not form a valid profile",
      ),
    )
  }
  // Stator mount plate: an 8-window disc with the two mount circles and the
  // central bearing bore, all exact profile loops.
  let plate_radius = spec.stator_plate_diameter_mm / 2.0
  let plate_holes : Array[Array[@cad.ProfileSegment]] = []
  for i in 0..<spec.stator_plate_window_count {
    let center = spec.stator_plate_window_phase_deg +
      90.0 +
      360.0 * i.to_double() / spec.stator_plate_window_count.to_double()
    plate_holes.push(
      a12_sector_loop(
        center,
        spec.stator_plate_window_inner_diameter_mm / 2.0,
        spec.stator_plate_window_outer_diameter_mm / 2.0,
        spec.stator_plate_window_inner_half_angle_deg,
        spec.stator_plate_window_outer_half_angle_deg,
        spec.stator_plate_window_corner_radius_mm,
      ),
    )
  }
  for
    hole in a12_bolt_hole_loops(
      spec.mount_m3_count,
      spec.mount_m3_circle_diameter_mm,
      spec.mount_m3_hole_diameter_mm,
      spec.mount_hole_phase_deg + 90.0,
    ) {
    plate_holes.push(hole)
  }
  for
    hole in a12_bolt_hole_loops(
      spec.mount_m4_count,
      spec.mount_m4_circle_diameter_mm,
      spec.mount_m4_hole_diameter_mm,
      spec.mount_hole_phase_deg + 135.0,
    ) {
    plate_holes.push(hole)
  }
  plate_holes.push(
    a12_circle_loop(0.0, 0.0, spec.bearing_tube_outer_diameter_mm / 2.0),
  )
  let plate_profile = @cad.ExtrudedArcProfile::new(
    a12_circle_loop(0.0, 0.0, plate_radius),
    spec.stator_plate_thickness_mm,
    holes=plate_holes,
  )
  if !plate_profile.validate() {
    return Err(
      @common.InvalidParameter(
        "a12 stator mount plate did not form a valid profile",
      ),
    )
  }
  let bearing_tube = @cad.RevolvedProfile::tube(
    spec.bearing_tube_outer_diameter_mm,
    spec.bearing_bore_diameter_mm,
    spec.stator_plate_thickness_mm,
  ).as_shape()
  let pcb_ring = @cad.RevolvedProfile::tube(
    spec.pcb_ring_outer_diameter_mm,
    spec.pcb_ring_inner_diameter_mm,
    spec.pcb_thickness_mm,
  ).as_shape()
  // One exact copper frame per stator tooth. The frame is a rounded rectangle
  // with a rounded-rectangle hole, extruded radially over the slot depth.
  let coil_inner_radius = spec.coil_radial_inner_diameter_mm / 2.0
  let coil_outer_radius = spec.coil_radial_outer_diameter_mm / 2.0
  let coil_hole_half = (spec.stator_tooth_width_mm + 0.4) / 2.0
  let coil_outer_half = spec.coil_width_mm / 2.0
  let coil_hole_axial_half = (spec.stator_stack_length_mm + 0.4) / 2.0
  let coil_outer_axial_half = coil_hole_axial_half + spec.coil_axial_overhang_mm
  let coil_profile = @cad.ExtrudedArcProfile::new(
    a12_rounded_rect_loop(
      coil_outer_axial_half,
      coil_outer_half,
      spec.coil_corner_radius_mm,
    ),
    coil_outer_radius - coil_inner_radius,
    holes=[
      a12_rounded_rect_loop(
        coil_hole_axial_half,
        coil_hole_half,
        spec.coil_inner_corner_radius_mm,
      ),
    ],
  )
  if !coil_profile.validate() {
    return Err(
      @common.InvalidParameter("a12 winding frame did not form a valid profile"),
    )
  }
  let coil_shape = coil_profile.as_shape()
  let coil_axial_mid = spec.stator_stack_start_mm +
    spec.stator_stack_length_mm / 2.0
  let rear_face = spec.stator_plate_start_mm + spec.stator_plate_thickness_mm
  let shaft_front = adapter_front - spec.shaft_front_extension_mm
  let shaft_rear = rear_face + spec.shaft_rear_extension_mm
  let shaft_length = shaft_rear - shaft_front
  let total_length = shaft_rear - shaft_front
  let layers : Array[@common.ComponentLayer] = [
    {
      shape: bell_face_profile.as_shape(),
      name: "bell-face",
      color: @cad.Rgb::black(),
      placement: on_axis(0.0),
    },
    {
      shape: skirt_profile.as_shape(),
      name: "bell-skirt",
      color: @cad.Rgb::black(),
      placement: on_axis(0.0),
    },
    {
      shape: boss_profile.as_shape(),
      name: "bell-hub-boss",
      color: @cad.Rgb::black(),
      placement: on_axis(-boss_height),
    },
    {
      shape: adapter_profile.as_shape(),
      name: "prop-adapter",
      color: @cad.Rgb::white(),
      placement: on_axis(adapter_front),
    },
    {
      shape: lamination.as_shape(),
      name: "stator-lamination",
      color: @cad.Rgb::grey(),
      placement: on_axis(spec.stator_stack_start_mm),
    },
    {
      shape: plate_profile.as_shape(),
      name: "stator-plate",
      color: @cad.Rgb::black(),
      placement: on_axis(spec.stator_plate_start_mm),
    },
    {
      shape: bearing_tube,
      name: "bearing-tube",
      color: @cad.Rgb::grey(),
      placement: on_axis(spec.stator_plate_start_mm),
    },
    {
      shape: pcb_ring,
      name: "pcb-insulator",
      color: @cad.Rgb::green(),
      placement: on_axis(spec.stator_plate_start_mm - spec.pcb_thickness_mm),
    },
    {
      shape: @cad.RevolvedProfile::cylinder(
        spec.shaft_diameter_mm,
        shaft_length,
      ).as_shape(),
      name: "shaft",
      color: @cad.Rgb::grey(),
      placement: on_axis(shaft_front),
    },
  ]
  for magnet_layer in magnet_layers {
    layers.push(magnet_layer)
  }
  for i in 0..<spec.stator_tooth_count {
    let angle_deg = spec.stator_tooth_phase_deg +
      360.0 * i.to_double() / spec.stator_tooth_count.to_double()
    let angle = angle_deg * @math.PI / 180.0
    let radial_cos = @math.cos(angle)
    let radial_sin = @math.sin(angle)
    let placement : @common.Placement = {
      rot: @cad.Matrix3x3::{
        m00: 1.0,
        m01: 0.0,
        m02: 0.0,
        m10: 0.0,
        m11: radial_sin,
        m12: radial_cos,
        m20: 0.0,
        m21: -radial_cos,
        m22: radial_sin,
      },
      trans: (
        coil_axial_mid,
        coil_inner_radius * radial_cos,
        coil_inner_radius * radial_sin,
      ),
    }
    layers.push({
      shape: coil_shape,
      name: "stator-coil-\{i + 1}",
      color: @cad.Rgb::orange(),
      placement,
    })
  }
  let features = @common.FeatureRecord::new(
    modeled=[
      "bell-skirt", "bell-face", "bell-windows", "rounded-window-corners", "rounded-bell-shoulder",
      "bell-hub-boss", "rotor-magnets", "prop-adapter", "prop-mount-holes", "prop-adapter-screws",
      "stator-lamination", "stator-teeth", "stator-windings", "stator-mount-plate",
      "stator-plate-windows", "m3-mount-holes", "m4-mount-holes", "bearing-tube",
      "pcb-insulator-ring", "through-shaft",
    ],
    omitted=[
      @common.Omission::new(
        feature="individual-wire-turns",
        reason="each tooth carries one exact copper bundle frame; individual wire turns and crossover lacing are not modelled",
      ),
      @common.Omission::new(
        feature="bearings-and-magnets-flux",
        reason="bearing rolling elements and magnetic circuit behavior are not modelled",
      ),
      @common.Omission::new(
        feature="wires-and-connectors",
        reason="no phase wires, bullet connectors, sensor harness, or strain relief is modelled",
      ),
      @common.Omission::new(
        feature="kv-and-performance",
        reason="no KV, torque, current, efficiency, or thermal rating is implied",
      ),
    ],
  )
  let name = "a12-8318-motor-\{@cad.fmt_double(spec.bell_outer_diameter_mm, None)}x\{@cad.fmt_double(total_length, None)}"
  let mut motor = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="XAIRCRAFT A12 8318 100KV outrunner motor envelope",
      standard="measured motor dimensions",
      family="large agricultural outrunner brushless motor envelope",
      size="\{@cad.fmt_double(spec.bell_outer_diameter_mm, None)}x\{@cad.fmt_double(total_length, None)}",
      length_mm=total_length,
      source="Defaults are the measured A12 8318 100KV motor dimensions (91 mm OD, 33 mm height, 23 mm M4 prop circle, 30 mm M3 / 32 mm M4 mount circles, 83 mm x 18 mm stator). All dimensions are parameters.",
    ),
    description="Parameterized large outrunner brushless-motor envelope: windowed spoked bell with rounded shoulder and hub boss, discrete rotor magnets, machined prop adapter, 36-slot stator lamination with one exact copper winding frame per tooth, 8-window mount plate with M3 and M4 mounting circles, bearing tube, insulator ring, and through shaft. No electrical or performance rating is implied.",
    features~,
  ).add_layers(layers)
  let connectors : Array[@common.MateConnector] = [
    @common.MateConnector::new(
      "rotor-shaft-bell-side",
      placement=@common.Placement::translation(shaft_front, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=spec.shaft_diameter_mm,
      depth_mm=shaft_length,
      description="ROTATING rotor shaft end on the endbell side; drives gears, pulleys, or couplings; never clamp it to the enclosure",
    ),
    @common.MateConnector::new(
      "rotor-shaft-mount-side",
      placement=@common.Placement::translation(shaft_rear, 0.0, 0.0),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=spec.shaft_diameter_mm,
      depth_mm=shaft_length,
      description="ROTATING rotor shaft end on the stator mount side; drives gears, pulleys, or couplings; never clamp it to the enclosure",
    ),
    @common.MateConnector::new(
      "rotor-output-face",
      placement=@common.Placement::translation(adapter_front, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.prop_adapter_diameter_mm,
      description="ROTATING rotor endbell output face; attach a propeller, gear, or pulley here, never the enclosure",
    ),
    @common.MateConnector::new(
      "stator-mount-face",
      placement=@common.Placement::translation(rear_face, 0.0, 0.0),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.stator_plate_diameter_mm,
      description="FIXED stator mount face; bolt this face to the motor enclosure or frame; it never rotates",
    ),
  ]
  for connector in connectors {
    motor = motor.with_connector_unchecked(connector)
  }
  let prop_radius = spec.prop_hole_circle_diameter_mm / 2.0
  for i in 0..<spec.prop_hole_count {
    let angle = (
        spec.prop_hole_phase_deg +
        360.0 * i.to_double() / spec.prop_hole_count.to_double()
      ) *
      @math.PI /
      180.0
    motor = motor.with_connector_unchecked(
      @common.MateConnector::new(
        "rotor-output-hole-\{i + 1}",
        placement=@common.Placement::translation(
          adapter_front,
          prop_radius * @math.cos(angle),
          prop_radius * @math.sin(angle),
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.prop_hole_diameter_mm,
        depth_mm=spec.prop_adapter_thickness_mm,
        description="screw hole on the ROTATING rotor output face; attach a gear, pulley, or propeller here",
      ),
    )
  }
  let m3_radius = spec.mount_m3_circle_diameter_mm / 2.0
  for i in 0..<spec.mount_m3_count {
    let angle = (
        spec.mount_hole_phase_deg +
        360.0 * i.to_double() / spec.mount_m3_count.to_double()
      ) *
      @math.PI /
      180.0
    motor = motor.with_connector_unchecked(
      @common.MateConnector::new(
        "stator-mount-hole-m3-\{i + 1}",
        placement=@common.Placement::translation(
          rear_face,
          m3_radius * @math.cos(angle),
          m3_radius * @math.sin(angle),
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.mount_m3_hole_diameter_mm,
        depth_mm=spec.stator_plate_thickness_mm,
        description="M3 clearance hole in the FIXED stator mount face; bolt it to the enclosure",
      ),
    )
  }
  let m4_radius = spec.mount_m4_circle_diameter_mm / 2.0
  for i in 0..<spec.mount_m4_count {
    let angle = (
        spec.mount_hole_phase_deg +
        45.0 +
        360.0 * i.to_double() / spec.mount_m4_count.to_double()
      ) *
      @math.PI /
      180.0
    motor = motor.with_connector_unchecked(
      @common.MateConnector::new(
        "stator-mount-hole-m4-\{i + 1}",
        placement=@common.Placement::translation(
          rear_face,
          m4_radius * @math.cos(angle),
          m4_radius * @math.sin(angle),
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.mount_m4_hole_diameter_mm,
        depth_mm=spec.stator_plate_thickness_mm,
        description="M4 clearance hole in the FIXED stator mount face; bolt it to the enclosure",
      ),
    )
  }
  Ok(motor)
}

///|
/// a12_motor_100kv builds the measured A12 8318 100KV envelope.
pub fn a12_motor_100kv() -> Result[@common.Component, @common.SpecError] {
  a12_motor(a12_motor_100kv_spec())
}
