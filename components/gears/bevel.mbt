///|
// Straight bevel gears.
//
// The tooth sector is the Tredgold back-cone equivalent spur gear: the virtual
// spur gear has the same module and z / cos(delta) teeth, pitch radius
// r / cos(delta), and the real gear's absolute addendum and dedendum. One tooth
// sector is generated in the back-cone plane, projected from the pitch apex
// onto the large face of a `ConicalExtrusion`, and replicated z times around
// the gear axis.
//
// The sector's root boundary angle is chosen so its projection lands exactly on
// the real pitch line. That makes adjacent sectors meet at a single point and
// avoids a chord across the root gap.
//
// The exact octoid/spherical involute is NOT modelled. The Tredgold tooth form
// is the standard engineering approximation and is declared in the component's
// feature record.

///|
/// BEVEL_MIN_TEETH is the smallest tooth count this builder accepts. Below it
/// the root circle and flank geometry degenerate for standard proportions.
const BEVEL_MIN_TEETH : Int32 = 6

///|
/// BEVEL_MIN_MATE_TEETH is the smallest mate tooth count accepted for a pair.
const BEVEL_MIN_MATE_TEETH : Int32 = 4

///|
/// BEVEL_FACE_WIDTH_FRACTION is the practical face-width limit. R/3 is the
/// common textbook guideline; real metric catalog bevel gears reach about
/// 0.35 R (for example a module 2, 20-tooth 90-degree miter with a 10 mm face
/// width has b/R = 0.354), so this builder accepts up to R/2.5.
const BEVEL_FACE_WIDTH_FRACTION : Double = 2.5

///|
/// BEVEL_OUTLINE_EPS2 is the squared coincidence tolerance used to drop the
/// duplicated junction points when the tooth sectors are replicated.
const BEVEL_OUTLINE_EPS2 : Double = 1.0e-8

///|
/// BevelEndFace selects the large-end construction.
pub(all) enum BevelEndFace {
  /// Flat face through the reference plane. Its outside diameter is larger
  /// than the standard back-cone value; declared as `flat-back-envelope`.
  Flat
  /// Standard back-cone tooth ends with a flat backing plane inside the root
  /// circle. The outside diameter matches `d + 2 * h_a * cos(delta)`.
  BackCone
}

///|
/// BevelGearParams is a validated straight bevel gear request.
pub(all) struct BevelGearParams {
  module_mm : Double
  teeth : Int32
  /// Mate tooth count; 0 when `pitch_angle_deg` supplies the pitch angle.
  mate_teeth : Int32
  /// Shaft angle of the pair in degrees; ignored for a standalone gear.
  shaft_angle_deg : Double
  /// Explicit pitch cone angle in degrees for a standalone gear.
  pitch_angle_deg : Double?
  pressure_angle_deg : Double
  /// Face width measured along the pitch cone.
  face_width_mm : Double
  bore_diameter_mm : Double
  backlash_mm : Double
  addendum_factor : Double
  dedendum_factor : Double
  involute_points : Int32
  arc_points : Int32
  /// Root fillet radius in the back-cone equivalent gear (0 = sharp root).
  root_fillet_radius_mm : Double
  fillet_segments : Int32
  /// Tip chamfer distance in the back-cone equivalent gear (0 = sharp tip).
  tip_chamfer_mm : Double
  /// Hub outside diameter behind the large face (0 = no hub).
  hub_diameter_mm : Double
  /// Hub length behind the large face (0 = no hub).
  hub_length_mm : Double
  /// Bore keyway width (0 = no keyway); requires a bore.
  keyway_width_mm : Double
  /// Radial depth of the bore keyway from the bore wall (0 = no keyway).
  keyway_depth_mm : Double
  /// Angular position of the keyway in the XY plane, degrees.
  keyway_angle_deg : Double
  /// Radial set-screw hole diameter (0 = no hole); requires a hub and bore.
  set_screw_diameter_mm : Double
  /// Angular position of the radial set-screw hole, degrees.
  set_screw_angle_deg : Double
  /// Axial position of the set-screw hole, measured from the hub back face;
  /// None places it at mid-hub.
  set_screw_offset_mm : Double?
  /// 45-degree edge break on the bore circles and the hub back-face rims
  /// (0 = sharp; requires the evaluated export).
  edge_chamfer_mm : Double
  /// Explicit 45-degree chamfer band around the front (small-end) tooth
  /// outline, built as geometry rather than trimmed by a kernel (0 = sharp).
  end_chamfer_mm : Double
  /// Physical outside radius of the tooth tip land in mm (0 = theoretical
  /// back-cone tip). The virtual addendum is solved so the projected tip
  /// reaches this radius, matching a landed CAD tooth.
  tip_land_radius_mm : Double
  /// Cylindrical outside radius trim at the large end in mm (0 = untrimmed).
  /// Unlike `tip_land_radius_mm`, this keeps the full standard addendum along
  /// the teeth and turns the outer large-end tips to a cylinder (requires the
  /// back-cone end face and evaluated export).
  od_radius_mm : Double
  /// Axial Z coordinate of the small-end recessed bore face (None = flush
  /// with the small-end tooth face). Requires `front_recess_radius_mm > 0`,
  /// the back-cone end face, and evaluated export.
  front_recess_z_mm : Double?
  /// Radius at the small-end tooth face where the inner 90-degree-to-pitch
  /// recess cone begins (0 = no front recess).
  front_recess_radius_mm : Double
  /// Angular phase offset applied to the teeth around +Z, in degrees (0 = tooth
  /// 0 centered on +X; e.g. 180 / teeth places a tooth gap on +X without
  /// rotating the keyway or set-screw hole).
  tooth_phase_deg : Double
  /// Extra diametral clearance applied to the drilled set-screw hole in mm
  /// (0 = nominal; e.g. 0.04 keeps an installed nominal set screw disjoint
  /// from the gear body during evaluated boolean union).
  set_screw_clearance_mm : Double
  /// Whether `edge_chamfer_mm` also breaks the outer hub back-face rim (true
  /// by default; false chamfers only the bore circles).
  chamfer_hub_outer : Bool
  /// ISO profile shift coefficient `x` in the back-cone equivalent plane
  /// (positive widens tooth thickness at the reference circle).
  profile_shift : Double
  /// Circular-arc flank radius in the virtual back-cone plane in mm
  /// (0 = standard involute flank).
  flank_arc_radius_mm : Double
  /// When true alongside a front recess, trims the outer tooth tips along
  /// a conical tip cone from the back OD radius to `front_recess_radius_mm`
  /// at the small-end tooth face instead of a cylinder.
  tip_cone_trim : Bool
  /// Large-end construction.
  end_face : BevelEndFace
}

///|
/// BevelGearParams::new validates a straight bevel gear request.
///
/// Supply exactly one of `mate_teeth` (for a pair at `shaft_angle_deg`) or
/// `pitch_angle_deg` (for a standalone gear).
pub fn BevelGearParams::new(
  module_mm~ : Double,
  teeth~ : Int32,
  mate_teeth~ : Int32 = 0,
  shaft_angle_deg~ : Double = 90.0,
  pitch_angle_deg? : Double,
  pressure_angle_deg~ : Double = 20.0,
  face_width_mm~ : Double = 10.0,
  bore_diameter_mm~ : Double = 0.0,
  backlash_mm~ : Double = 0.0,
  addendum_factor~ : Double = 1.0,
  dedendum_factor~ : Double = 1.25,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
  root_fillet_radius_mm~ : Double = 0.0,
  fillet_segments~ : Int32 = 4,
  tip_chamfer_mm~ : Double = 0.0,
  hub_diameter_mm~ : Double = 0.0,
  hub_length_mm~ : Double = 0.0,
  keyway_width_mm~ : Double = 0.0,
  keyway_depth_mm~ : Double = 0.0,
  keyway_angle_deg~ : Double = 90.0,
  set_screw_diameter_mm~ : Double = 0.0,
  set_screw_angle_deg~ : Double = 180.0,
  set_screw_offset_mm? : Double,
  edge_chamfer_mm~ : Double = 0.0,
  end_chamfer_mm~ : Double = 0.0,
  tip_land_radius_mm~ : Double = 0.0,
  od_radius_mm~ : Double = 0.0,
  front_recess_z_mm? : Double,
  front_recess_radius_mm~ : Double = 0.0,
  tooth_phase_deg~ : Double = 0.0,
  set_screw_clearance_mm~ : Double = 0.0,
  chamfer_hub_outer~ : Bool = true,
  profile_shift~ : Double = 0.0,
  flank_arc_radius_mm~ : Double = 0.0,
  tip_cone_trim~ : Bool = false,
  end_face~ : BevelEndFace = Flat,
) -> Result[BevelGearParams, @common.SpecError] {
  match @common.require_positive("bevel gear module", module_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if teeth < BEVEL_MIN_TEETH {
    return Err(
      @common.InvalidParameter("bevel gear teeth must be >= \{BEVEL_MIN_TEETH}"),
    )
  }
  match
    @common.require_in_range(
      "bevel pressure angle", pressure_angle_deg, 10.0, 35.0,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("bevel face width", face_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("bevel bore diameter", bore_diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("bevel backlash", backlash_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if backlash_mm >= @math.PI * module_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "bevel backlash must be below half the circular pitch (pi * module / 2)",
      ),
    )
  }
  match @common.require_positive("bevel addendum factor", addendum_factor) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("bevel dedendum factor", dedendum_factor) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_non_negative(
      "bevel root fillet radius", root_fillet_radius_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if root_fillet_radius_mm > 0.44 * module_mm {
    return Err(
      @common.InvalidParameter(
        "bevel root fillet radius must not exceed 0.44 * module",
      ),
    )
  }
  if fillet_segments < 2 {
    return Err(@common.InvalidParameter("bevel fillet segments must be >= 2"))
  }
  match @common.require_non_negative("bevel tip chamfer", tip_chamfer_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("bevel hub diameter", hub_diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("bevel hub length", hub_length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if (hub_diameter_mm > 0.0) != (hub_length_mm > 0.0) {
    return Err(
      @common.InvalidParameter(
        "bevel hub diameter and length must both be positive or both zero",
      ),
    )
  }
  if hub_diameter_mm > 0.0 && hub_diameter_mm <= bore_diameter_mm {
    return Err(
      @common.InvalidParameter(
        "bevel hub diameter must exceed the bore diameter",
      ),
    )
  }
  match @common.require_non_negative("bevel keyway width", keyway_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("bevel keyway depth", keyway_depth_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if (keyway_width_mm > 0.0) != (keyway_depth_mm > 0.0) {
    return Err(
      @common.InvalidParameter(
        "bevel keyway width and depth must both be positive or both zero",
      ),
    )
  }
  if keyway_width_mm > 0.0 && bore_diameter_mm <= 0.0 {
    return Err(
      @common.InvalidParameter("a bevel keyway requires a central bore"),
    )
  }
  match
    @common.require_non_negative(
      "bevel set screw diameter", set_screw_diameter_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if set_screw_diameter_mm > 0.0 {
    if hub_diameter_mm <= 0.0 || bore_diameter_mm <= 0.0 {
      return Err(
        @common.InvalidParameter(
          "a bevel set-screw hole requires a hub and a central bore",
        ),
      )
    }
    if set_screw_diameter_mm >= hub_diameter_mm {
      return Err(
        @common.InvalidParameter(
          "bevel set-screw hole must be narrower than the hub diameter",
        ),
      )
    }
    match set_screw_offset_mm {
      Some(offset) =>
        if offset <= 0.0 || offset >= hub_length_mm {
          return Err(
            @common.InvalidParameter(
              "bevel set-screw offset must lie inside the hub length",
            ),
          )
        }
      None => ()
    }
    if keyway_width_mm > 0.0 {
      let raw = (set_screw_angle_deg - keyway_angle_deg).abs()
      let wrapped = raw - 360.0 * Double::floor(raw / 360.0)
      let sep_deg = if wrapped > 180.0 { 360.0 - wrapped } else { wrapped }
      let sep = sep_deg * @math.PI / 180.0
      let bore_r = bore_diameter_mm / 2.0
      let need = keyway_width_mm / 2.0 + set_screw_diameter_mm / 2.0
      if need < bore_r && bore_r * @math.sin(sep) < need {
        return Err(
          @common.InvalidParameter(
            "bevel set-screw hole overlaps the keyway at the bore wall",
          ),
        )
      }
    }
  } else {
    match set_screw_offset_mm {
      Some(_) =>
        return Err(
          @common.InvalidParameter(
            "bevel set-screw offset needs a positive set-screw diameter",
          ),
        )
      None => ()
    }
  }
  match @common.require_non_negative("bevel edge chamfer", edge_chamfer_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if edge_chamfer_mm > 0.0 {
    let broken_r = if hub_diameter_mm > 0.0 {
      hub_diameter_mm / 2.0
    } else {
      bore_diameter_mm / 2.0
    }
    if broken_r > 0.0 && edge_chamfer_mm >= 0.5 * broken_r {
      return Err(
        @common.InvalidParameter(
          "bevel edge chamfer must be below half the radius it breaks",
        ),
      )
    }
  }
  if edge_chamfer_mm > 0.0 {
    match end_face {
      Flat =>
        return Err(
          @common.InvalidParameter(
            "bevel edge chamfers are supported only with the back-cone end face",
          ),
        )
      BackCone => ()
    }
  }
  match @common.require_non_negative("bevel end chamfer", end_chamfer_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if end_chamfer_mm >= 0.5 * module_mm {
    return Err(
      @common.InvalidParameter(
        "bevel end chamfer must be below half the module",
      ),
    )
  }
  if end_chamfer_mm > 0.0 {
    match end_face {
      Flat =>
        return Err(
          @common.InvalidParameter(
            "the explicit end chamfer is supported only with the back-cone end face",
          ),
        )
      BackCone => ()
    }
  }
  match
    @common.require_non_negative("bevel tip land radius", tip_land_radius_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if tip_land_radius_mm > 0.0 {
    match end_face {
      Flat =>
        return Err(
          @common.InvalidParameter(
            "the tip land is supported only with the back-cone end face",
          ),
        )
      BackCone => ()
    }
  }
  match @common.require_non_negative("bevel OD radius", od_radius_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if od_radius_mm > 0.0 {
    match end_face {
      Flat =>
        return Err(
          @common.InvalidParameter(
            "the cylindrical OD trim is supported only with the back-cone end face",
          ),
        )
      BackCone => ()
    }
    if tip_land_radius_mm > 0.0 {
      return Err(
        @common.InvalidParameter(
          "bevel gear takes either tip_land_radius_mm or od_radius_mm, not both",
        ),
      )
    }
  }
  match
    @common.require_non_negative(
      "bevel front recess radius", front_recess_radius_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let has_recess_z = match front_recess_z_mm {
    Some(_) => true
    None => false
  }
  if has_recess_z != (front_recess_radius_mm > 0.0) {
    return Err(
      @common.InvalidParameter(
        "bevel front_recess_z_mm and front_recess_radius_mm must both be set or both omitted/zero",
      ),
    )
  }
  if has_recess_z {
    match end_face {
      Flat =>
        return Err(
          @common.InvalidParameter(
            "the front recess is supported only with the back-cone end face",
          ),
        )
      BackCone => ()
    }
  }
  let pitch_angle = match pitch_angle_deg {
    Some(deg) => {
      if mate_teeth > 0 {
        return Err(
          @common.InvalidParameter(
            "bevel gear takes either mate_teeth or pitch_angle_deg, not both",
          ),
        )
      }
      match @common.require_in_range("bevel pitch angle", deg, 0.0, 90.0) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      if deg <= 0.0 || deg >= 90.0 {
        return Err(
          @common.InvalidParameter(
            "bevel pitch angle must be strictly between 0 and 90 degrees",
          ),
        )
      }
      Some(deg)
    }
    None => {
      if mate_teeth < BEVEL_MIN_MATE_TEETH {
        return Err(
          @common.InvalidParameter(
            "bevel gear needs a pitch_angle_deg or a mate_teeth count >= \{BEVEL_MIN_MATE_TEETH}",
          ),
        )
      }
      None
    }
  }
  // A standalone gear ignores the shaft angle; a pair needs a valid one.
  match pitch_angle {
    Some(_) => ()
    None => {
      match
        @common.require_in_range(
          "bevel shaft angle", shaft_angle_deg, 0.0, 180.0,
        ) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      if shaft_angle_deg <= 0.0 || shaft_angle_deg >= 180.0 {
        return Err(
          @common.InvalidParameter(
            "bevel shaft angle must be strictly between 0 and 180 degrees",
          ),
        )
      }
      // Reject a pair whose geometry would put the pitch angle outside (0, 90).
      let sigma = shaft_angle_deg * @math.PI / 180.0
      let ratio = mate_teeth.to_double() / teeth.to_double()
      let denom = ratio + @math.cos(sigma)
      if denom <= 0.0 {
        return Err(
          @common.InvalidParameter(
            "bevel pair tooth counts and shaft angle give no positive pitch angle",
          ),
        )
      }
    }
  }
  match
    @common.require_non_negative(
      "bevel set screw clearance", set_screw_clearance_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_in_range("bevel profile shift", profile_shift, -1.0, 1.0) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_non_negative("bevel flank arc radius", flank_arc_radius_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if tip_cone_trim {
    match end_face {
      Flat =>
        return Err(
          @common.InvalidParameter(
            "the tip cone trim is supported only with the back-cone end face",
          ),
        )
      BackCone => ()
    }
    if !has_recess_z {
      return Err(
        @common.InvalidParameter(
          "bevel tip cone trim requires front_recess_z_mm and front_recess_radius_mm",
        ),
      )
    }
  }
  let params : BevelGearParams = {
    module_mm,
    teeth,
    mate_teeth,
    shaft_angle_deg,
    pitch_angle_deg: pitch_angle,
    pressure_angle_deg,
    face_width_mm,
    bore_diameter_mm,
    backlash_mm,
    addendum_factor,
    dedendum_factor,
    involute_points,
    arc_points,
    root_fillet_radius_mm,
    fillet_segments,
    tip_chamfer_mm,
    hub_diameter_mm,
    hub_length_mm,
    keyway_width_mm,
    keyway_depth_mm,
    keyway_angle_deg,
    set_screw_diameter_mm,
    set_screw_angle_deg,
    set_screw_offset_mm,
    edge_chamfer_mm,
    end_chamfer_mm,
    tip_land_radius_mm,
    od_radius_mm,
    front_recess_z_mm,
    front_recess_radius_mm,
    tooth_phase_deg,
    set_screw_clearance_mm,
    chamfer_hub_outer,
    profile_shift,
    flank_arc_radius_mm,
    tip_cone_trim,
    end_face,
  }
  let geom = params.geometry()
  if face_width_mm > geom.cone_distance_mm / BEVEL_FACE_WIDTH_FRACTION {
    return Err(
      @common.InvalidParameter(
        "bevel face width \{face_width_mm} mm exceeds cone distance / 2.5 (\{geom.cone_distance_mm / BEVEL_FACE_WIDTH_FRACTION} mm)",
      ),
    )
  }
  if tip_land_radius_mm > 0.0 {
    if tip_land_radius_mm >= geom.standard_outer_radius_mm {
      return Err(
        @common.InvalidParameter(
          "bevel tip land radius must be below the standard outside radius",
        ),
      )
    }
    if tip_land_radius_mm <= geom.pitch_radius_mm {
      return Err(
        @common.InvalidParameter(
          "bevel tip land radius must exceed the pitch radius",
        ),
      )
    }
  }
  if od_radius_mm > 0.0 {
    if od_radius_mm >= geom.standard_outer_radius_mm {
      return Err(
        @common.InvalidParameter(
          "bevel OD radius must be below the standard outside radius",
        ),
      )
    }
    if od_radius_mm <= geom.pitch_radius_mm {
      return Err(
        @common.InvalidParameter("bevel OD radius must exceed the pitch radius"),
      )
    }
  }
  match front_recess_z_mm {
    Some(rz) => {
      let (root_z, _) = bevel_back_cone_root(geom)
      if rz <= root_z + edge_chamfer_mm || rz >= geom.axial_face_width_mm {
        return Err(
          @common.InvalidParameter(
            "bevel front recess Z must lie strictly between the backing root plane and the front tooth face",
          ),
        )
      }
      let delta = geom.pitch_angle_deg * @math.PI / 180.0
      let r_floor = front_recess_radius_mm -
        (geom.axial_face_width_mm - rz) / @math.tan(delta)
      let min_floor = bore_diameter_mm / 2.0 + edge_chamfer_mm
      if r_floor <= 0.0 || r_floor <= min_floor {
        return Err(
          @common.InvalidParameter(
            "bevel front recess floor radius \{r_floor} mm must exceed bore radius plus edge chamfer (\{min_floor} mm)",
          ),
        )
      }
    }
    None => ()
  }
  let root_radius = geom.virtual_pitch_radius_mm - geom.dedendum_mm
  if root_radius <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "bevel dedendum leaves no positive root radius at the back cone",
      ),
    )
  }
  if geom.root_cone_angle_deg <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "bevel dedendum leaves no positive root cone angle",
      ),
    )
  }
  if bore_diameter_mm > 0.0 {
    let inner_root = geom.small_end_scale *
      geom.apex_distance_mm *
      @math.tan(geom.root_cone_angle_deg * @math.PI / 180.0)
    if bore_diameter_mm / 2.0 >= inner_root {
      return Err(
        @common.InvalidParameter(
          "bevel bore \{bore_diameter_mm} mm does not fit inside the small-end root radius \{inner_root} mm",
        ),
      )
    }
  }
  Ok(params)
}

///|
/// BevelGearGeometry is the dimensional description of a straight bevel gear.
pub(all) struct BevelGearGeometry {
  module_mm : Double
  teeth : Int32
  pitch_angle_deg : Double
  cone_distance_mm : Double
  pitch_radius_mm : Double
  /// Apex height above the large face.
  apex_distance_mm : Double
  addendum_mm : Double
  /// Standard back-cone outside radius: pitch radius + addendum * cos(delta).
  /// The flat-back solid's actual outer radius is larger; the difference is
  /// declared in the component feature record.
  standard_outer_radius_mm : Double
  dedendum_mm : Double
  face_cone_angle_deg : Double
  root_cone_angle_deg : Double
  virtual_teeth : Double
  virtual_pitch_radius_mm : Double
  /// Axial height of the face width: b * cos(delta).
  axial_face_width_mm : Double
  /// Profile scale at the small end: (R - b) / R.
  small_end_scale : Double
}

///|
/// BevelGearParams::pitch_angle_rad resolves the pitch cone angle.
fn BevelGearParams::pitch_angle_rad(self : BevelGearParams) -> Double {
  match self.pitch_angle_deg {
    Some(deg) => deg * @math.PI / 180.0
    None => {
      let sigma = self.shaft_angle_deg * @math.PI / 180.0
      let ratio = self.mate_teeth.to_double() / self.teeth.to_double()
      @math.atan(@math.sin(sigma) / (ratio + @math.cos(sigma)))
    }
  }
}

///|
/// BevelGearParams::geometry computes the standard straight-bevel dimensions.
pub fn BevelGearParams::geometry(self : BevelGearParams) -> BevelGearGeometry {
  let m = self.module_mm
  let z = self.teeth.to_double()
  let r = m * z / 2.0
  let delta = self.pitch_angle_rad()
  let sin_d = @math.sin(delta)
  let cos_d = @math.cos(delta)
  let cone_distance = r / sin_d
  let apex = cone_distance * cos_d
  let h_a = m * self.addendum_factor
  let h_f = m * self.dedendum_factor
  let virtual_radius = r / cos_d
  let virtual_teeth = z / cos_d
  let face_angle = delta + @math.atan(h_a / cone_distance)
  let root_angle = delta - @math.atan(h_f / cone_distance)
  let axial = self.face_width_mm * cos_d
  {
    module_mm: m,
    teeth: self.teeth,
    pitch_angle_deg: delta * 180.0 / @math.PI,
    cone_distance_mm: cone_distance,
    pitch_radius_mm: r,
    apex_distance_mm: apex,
    addendum_mm: h_a,
    standard_outer_radius_mm: r + h_a * cos_d,
    dedendum_mm: h_f,
    face_cone_angle_deg: face_angle * 180.0 / @math.PI,
    root_cone_angle_deg: root_angle * 180.0 / @math.PI,
    virtual_teeth,
    virtual_pitch_radius_mm: virtual_radius,
    axial_face_width_mm: axial,
    small_end_scale: (cone_distance - self.face_width_mm) / cone_distance,
  }
}

///|
/// BevelGearParams::designation returns a compact gear designation.
pub fn BevelGearParams::designation(self : BevelGearParams) -> String {
  let g = self.geometry()
  "m\{@cad.fmt_double(self.module_mm, None)}-z\{self.teeth}-d\{@cad.fmt_double(g.pitch_angle_deg, Some(0.01))}"
}

///|
/// bevel_resample resamples an open polyline at `count` equally spaced arc
/// lengths, preserving both endpoints. Uniform roll-angle involute sampling
/// bunches points near the base circle (segments down to 0.02 mm), and those
/// tiny segments upset stricter B-rep checkers.
fn bevel_resample(points : Array[@cad.Vec2], count : Int32) -> Array[@cad.Vec2] {
  let m = points.length()
  if m < 2 || count < 2 {
    return points
  }
  let cumulative : Array[Double] = [0.0]
  for i in 1..<m {
    let dx = points[i].0 - points[i - 1].0
    let dy = points[i].1 - points[i - 1].1
    cumulative.push(cumulative[i - 1] + Double::sqrt(dx * dx + dy * dy))
  }
  let total = cumulative[m - 1]
  if total <= 0.0 {
    return points
  }
  let out : Array[@cad.Vec2] = []
  let mut seg = 0
  for k in 0..<count {
    let target = total * k.to_double() / (count - 1).to_double()
    while seg < m - 2 && cumulative[seg + 1] < target {
      seg = seg + 1
    }
    let s0 = cumulative[seg]
    let s1 = cumulative[seg + 1]
    let t = if s1 > s0 { (target - s0) / (s1 - s0) } else { 0.0 }
    out.push(
      (
        points[seg].0 + (points[seg + 1].0 - points[seg].0) * t,
        points[seg].1 + (points[seg + 1].1 - points[seg].1) * t,
      ),
    )
  }
  out
}

///|
/// bevel_tooth_sector builds one tooth sector in the back-cone plane, centred
/// on +X and spanning exactly one real pitch of root boundary.
///
/// The sector runs from the root gap centreline at -phi_b, up the lower flank,
/// across the tip, down the upper flank, to +phi_b. `phi_b` is chosen so the
/// projected sector spans `2 * pi / teeth` of azimuth around the gear axis.

///|
/// bevel_arc_flank_points generates `ip + 1` points from `rr` to `ra` along a
/// circular-arc tooth flank in the virtual back-cone plane passing through the
/// pitch circle at `theta_pitch` with pressure angle `pa`.
fn bevel_arc_flank_points(
  rr : Double,
  rp : Double,
  ra : Double,
  pa : Double,
  theta_pitch : Double,
  arc_radius : Double,
  ip : Int32,
) -> Result[Array[@cad.Vec2], @common.SpecError] {
  let px = rp * @math.cos(-theta_pitch)
  let py = rp * @math.sin(-theta_pitch)
  let erx = @math.cos(-theta_pitch)
  let ery = @math.sin(-theta_pitch)
  let etx = -ery
  let ety = erx
  let cx = px + arc_radius * (-@math.sin(pa) * erx + @math.cos(pa) * etx)
  let cy = py + arc_radius * (-@math.sin(pa) * ery + @math.cos(pa) * ety)
  let dc = Double::sqrt(cx * cx + cy * cy)
  if dc <= @step.TOL_1E12 {
    return Err(
      @common.InvalidParameter("bevel flank arc center collapses to the origin"),
    )
  }
  let pts : Array[@cad.Vec2] = []
  for i in 0..<=ip {
    let r = rr + (ra - rr) * i.to_double() / ip.to_double()
    let a = (r * r - arc_radius * arc_radius + dc * dc) / (2.0 * dc)
    let h2 = r * r - a * a
    if h2 < -@step.TOL_1E9 {
      return Err(
        @common.InvalidParameter(
          "bevel flank arc radius \{arc_radius} mm does not span root to tip",
        ),
      )
    }
    let h = Double::sqrt(if h2 > 0.0 { h2 } else { 0.0 })
    let p1 : @cad.Vec2 = ((a * cx - h * cy) / dc, (a * cy + h * cx) / dc)
    let p2 : @cad.Vec2 = ((a * cx + h * cy) / dc, (a * cy - h * cx) / dc)
    let d1 = (p1.0 - px) * (p1.0 - px) + (p1.1 - py) * (p1.1 - py)
    let d2 = (p2.0 - px) * (p2.0 - px) + (p2.1 - py) * (p2.1 - py)
    pts.push(if d1 <= d2 { p1 } else { p2 })
  }
  Ok(pts)
}

///|
fn bevel_tooth_sector(
  params : BevelGearParams,
  g : BevelGearGeometry,
  tip_radius_virtual? : Double,
) -> Result[(Array[@cad.Vec2], Int32, Double), @common.SpecError] {
  let zv = g.virtual_teeth
  let pa = params.pressure_angle_deg * @math.PI / 180.0
  let rp = g.virtual_pitch_radius_mm
  let rb = rp * @math.cos(pa)
  let rr = rp - g.dedendum_mm
  let ra = match tip_radius_virtual {
    Some(value) => value
    None => rp + g.addendum_mm
  }
  if rr <= 0.0 {
    return Err(
      @common.InvalidDimension("bevel virtual root radius must be positive"),
    )
  }
  let ip = if params.involute_points < 2 { 2 } else { params.involute_points }
  let arcs = if params.arc_points < 2 { 2 } else { params.arc_points }
  let backlash_angle = params.backlash_mm / (2.0 * rp)
  let shift_angle = 2.0 * params.profile_shift * @math.tan(pa) / zv
  let pitch_point = involute_xy(rb, involute_theta(rb, rp))
  let face_angle = @math.atan2(pitch_point.1, pitch_point.0)
  let center_angle = @math.PI / (2.0 * zv) +
    face_angle +
    shift_angle -
    backlash_angle
  let start_angle = involute_theta(rb, if rr > rb { rr } else { rb })
  let stop_angle = involute_theta(rb, ra)
  let d_theta = (stop_angle - start_angle) / ip.to_double()

  // One flank from the root to the tip, then the tip arc, then the mirrored
  // flank back to the root. This is the same construction as the spur gear.
  let use_arc = params.flank_arc_radius_mm > 0.0
  let inv : Array[@cad.Vec2] = []
  if !use_arc && rr < rb {
    inv.push(rotate_xy((rr, 0.0), -center_angle))
  }
  let flank_raw : Array[@cad.Vec2] = if use_arc {
    let theta_pitch = @math.PI / (2.0 * zv) + shift_angle - backlash_angle
    match
      bevel_arc_flank_points(
        rr,
        rp,
        ra,
        pa,
        theta_pitch,
        params.flank_arc_radius_mm,
        ip,
      ) {
      Ok(pts) => pts
      Err(e) => return Err(e)
    }
  } else {
    let mut angle = start_angle
    let pts : Array[@cad.Vec2] = []
    for _i in 0..<(ip + 1) {
      pts.push(rotate_xy(involute_xy(rb, angle), -center_angle))
      angle = angle + d_theta
    }
    pts
  }
  let flank = bevel_resample(flank_raw, ip + 1)
  if params.root_fillet_radius_mm > 0.0 {
    let root_corner = if !use_arc && rr < rb {
      rotate_xy((rr, 0.0), -center_angle)
    } else {
      flank[0]
    }
    let min_seg = (if use_arc { 1.15 } else { 1.5 }) *
      params.root_fillet_radius_mm
    let start_idx = if !use_arc && rr < rb { 0 } else { 1 }
    for i, pt in flank {
      if i < start_idx {
        inv.push(pt)
      } else if i == flank.length() - 1 {
        inv.push(pt)
      } else {
        let dx = pt.0 - root_corner.0
        let dy = pt.1 - root_corner.1
        if Double::sqrt(dx * dx + dy * dy) >= min_seg {
          inv.push(pt)
        }
      }
    }
  } else {
    inv.push_iter(flank.iter())
  }
  let num = inv.length()
  let arc_tip = inv[num - 1]
  let arc_tip_angle = Double::abs(@math.atan2(arc_tip.1, arc_tip.0))
  for i in 1..<arcs {
    let phi = -arc_tip_angle +
      2.0 * arc_tip_angle * i.to_double() / arcs.to_double()
    inv.push(rotate_xy((ra, 0.0), phi))
  }
  for i in 1..<=num {
    let pt = inv[num - i]
    inv.push((pt.0, -pt.1))
  }

  let a0 = Double::abs(@math.atan2(inv[0].1, inv[0].0))
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let phi_b = @math.atan(
    @math.cos(delta) * @math.tan(@math.PI / g.teeth.to_double()),
  )
  // The sector boundary must stay inside the root gap between this tooth and
  // the next virtual tooth.
  let next_root = 2.0 * @math.PI / zv - a0
  if phi_b <= a0 || phi_b >= next_root {
    return Err(
      @common.InvalidParameter(
        "bevel tooth sector does not fit between adjacent teeth; reduce the addendum or pressure angle",
      ),
    )
  }

  let sector : Array[@cad.Vec2] = []
  // A fillet consumes part of the root edge next to the corner. Sample the
  // root gap coarsely enough that the requested radius has room to land.
  let gap_pts = if params.root_fillet_radius_mm > 0.0 {
    let half_gap = phi_b - a0
    let target = half_gap * rr / (1.2 * params.root_fillet_radius_mm)
    let n = target.to_int()
    if n < 1 {
      1
    } else if n > arcs {
      arcs
    } else {
      n
    }
  } else {
    arcs
  }
  let gap_step = (phi_b - a0) / gap_pts.to_double()
  let gap_deviation = gap_step * gap_step * rr / 8.0
  for i in 0..<gap_pts {
    let ang = -phi_b + (phi_b - a0) * i.to_double() / gap_pts.to_double()
    sector.push(rotate_xy((rr, 0.0), ang))
  }
  sector.push_iter(inv.iter())
  for i in 1..<=gap_pts {
    let ang = a0 + (phi_b - a0) * i.to_double() / gap_pts.to_double()
    sector.push(rotate_xy((rr, 0.0), ang))
  }
  let mut result = sector
  if params.root_fillet_radius_mm > 0.0 {
    // The two flank/root junctions are the first and last tooth points.
    let lower = gap_pts
    let upper = gap_pts + inv.length() - 1
    match
      @cad.Profile2D::fillet_vertices(
        result,
        params.root_fillet_radius_mm,
        segments=params.fillet_segments,
        which=@cad.VertexSelection::Indices([lower, upper]),
      ) {
      Ok(filleted) => result = filleted
      Err(e) =>
        return Err(
          @common.InvalidParameter("bevel root fillet rejected: " + e.message()),
        )
    }
  }
  if params.tip_chamfer_mm > 0.0 {
    let tip_radius = ra
    let tol = @step.TOL_1E6 * (1.0 + tip_radius)
    let tip_pts = keep_tip_endpoints(result, tip_radius, tol)
    let indices = outline_indices_at_radius(tip_pts, tip_radius, tol)
    if indices.is_empty() {
      return Err(
        @common.InvalidParameter("bevel tip chamfer found no tip vertices"),
      )
    }
    let chamfered = match
      @cad.Profile2D::chamfer_vertices(
        tip_pts,
        params.tip_chamfer_mm,
        which=@cad.VertexSelection::Indices(indices),
      ) {
      Ok(p) => p
      Err(e) =>
        return Err(
          @common.InvalidParameter("bevel tip chamfer rejected: " + e.message()),
        )
    }
    if arcs > 2 && indices.length() == 2 {
      // Re-insert the circular tip-arc samples between the two chamfered tip
      // corners so the back-cone tooth keeps a curved cylindrical/conical tip
      // land instead of a single flat facet.
      let mut max_r = 0.0
      for pt in chamfered {
        let r = outline_radius(pt)
        if r > max_r {
          max_r = r
        }
      }
      let new_tol = @step.TOL_1E6 * (1.0 + max_r)
      let tip_idxs = outline_indices_at_radius(chamfered, max_r, new_tol)
      if tip_idxs.length() == 2 && tip_idxs[1] == tip_idxs[0] + 1 {
        let i0 = tip_idxs[0]
        let i1 = tip_idxs[1]
        let a_start = @math.atan2(chamfered[i0].1, chamfered[i0].0)
        let a_end = @math.atan2(chamfered[i1].1, chamfered[i1].0)
        let rebuilt : Array[@cad.Vec2] = []
        for idx in 0..<=i0 {
          rebuilt.push(chamfered[idx])
        }
        for k in 1..<arcs {
          let phi = a_start +
            (a_end - a_start) * k.to_double() / arcs.to_double()
          rebuilt.push(rotate_xy((max_r, 0.0), phi))
        }
        for idx in i1..<chamfered.length() {
          rebuilt.push(chamfered[idx])
        }
        result = rebuilt
      } else {
        result = chamfered
      }
    } else {
      result = chamfered
    }
  }
  Ok((result, gap_pts, gap_deviation))
}

///|
/// bevel_project_sector maps back-cone plane points onto the large face plane
/// by central projection from the pitch apex.
fn bevel_project_sector(
  g : BevelGearGeometry,
  sector : Array[@cad.Vec2],
) -> Array[@cad.Vec2] {
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let apex = g.apex_distance_mm
  let cone = g.cone_distance_mm
  let q = -cone * @math.sin(delta) * @math.sin(delta) / @math.cos(delta)
  sector.map(fn(p) {
    let wz = q + p.0 * @math.sin(delta)
    let t = apex / (apex - wz)
    (t * p.0 * @math.cos(delta), t * p.1)
  })
}

///|
/// bevel_outline builds the full outer face outline: one projected tooth
/// sector replicated `teeth` times around the gear axis.
fn bevel_outline(
  params : BevelGearParams,
  g : BevelGearGeometry,
) -> Result[(Array[@cad.Vec2], Int32, Double), @common.SpecError] {
  let (sector, gap_pts, gap_deviation) = match bevel_tooth_sector(params, g) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let projected = bevel_project_sector(g, sector)
  let z = g.teeth.to_double()
  let phase = params.tooth_phase_deg * @math.PI / 180.0
  let full : Array[@cad.Vec2] = []
  for k in 0..<g.teeth {
    let angle = phase + 2.0 * @math.PI * k.to_double() / z
    for p in projected {
      full.push(rotate_xy(p, angle))
    }
  }
  Ok((clean_polygon(full, BEVEL_OUTLINE_EPS2), gap_pts, gap_deviation))
}

///|
fn bevel_rotate_z(p : @cad.Vec3, angle : Double) -> @cad.Vec3 {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  (c * p.0 - s * p.1, s * p.0 + c * p.1, p.2)
}

///|
/// bevel_back_cone_root returns the root-circle z and radius where the coaxial
/// root cone meets the back cone.
fn bevel_back_cone_root(g : BevelGearGeometry) -> (Double, Double) {
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let delta_f = g.root_cone_angle_deg * @math.PI / 180.0
  let tan_d = @math.tan(delta)
  let tan_f = @math.tan(delta_f)
  let q = -g.pitch_radius_mm * tan_d
  let cot_d = 1.0 / tan_d
  let z_root = (g.apex_distance_mm * tan_f + q * cot_d) / (tan_f + cot_d)
  let root_radius = (g.apex_distance_mm - z_root) * tan_f
  (z_root, root_radius)
}

///|
/// bevel_ray_cone intersects the ray from the pitch apex through `w` with the
/// upper nappe of the back cone.
fn bevel_ray_cone(g : BevelGearGeometry, w : @cad.Vec3) -> @cad.Vec3? {
  let d = g.apex_distance_mm
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let tan_d = @math.tan(delta)
  let cot_d = 1.0 / tan_d
  let q = -g.pitch_radius_mm * tan_d
  let dx = w.0
  let dy = w.1
  let dz = w.2 - d
  let a = dx * dx + dy * dy
  let k = d - q
  let aa = a - cot_d * cot_d * dz * dz
  let bb = -2.0 * cot_d * cot_d * k * dz
  let cc = -cot_d * cot_d * k * k
  let roots : Array[Double] = []
  if Double::abs(aa) <= @step.TOL_1E15 {
    if Double::abs(bb) > @step.TOL_1E15 {
      roots.push(-cc / bb)
    }
  } else {
    let disc = bb * bb - 4.0 * aa * cc
    if disc >= 0.0 {
      let sq = Double::sqrt(disc)
      roots.push((-bb + sq) / (2.0 * aa))
      roots.push((-bb - sq) / (2.0 * aa))
    }
  }
  let mut best : @cad.Vec3? = None
  let mut best_z = -1.0e300
  for t in roots {
    if t > @step.TOL_1E12 {
      let z = d + t * dz
      if z >= q - @step.TOL_1E9 && z > best_z {
        best_z = z
        best = Some((t * dx, t * dy, z))
      }
    }
  }
  best
}

///|
/// bevel_sector_max_back_radius projects every sector point onto the back cone
/// and returns the largest physical radius. It is used to solve for the tip
/// land: a smaller virtual addendum gives a smaller projected tip.
fn bevel_sector_max_back_radius(
  g : BevelGearGeometry,
  sector : Array[@cad.Vec2],
) -> Double {
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let q = -g.pitch_radius_mm * @math.tan(delta)
  let mut rmax = 0.0
  for p in sector {
    let w = (p.0 * @math.cos(delta), p.1, q + p.0 * @math.sin(delta))
    match bevel_ray_cone(g, w) {
      Some(c) => {
        let r = Double::sqrt(c.0 * c.0 + c.1 * c.1)
        if r > rmax {
          rmax = r
        }
      }
      None => ()
    }
  }
  rmax
}

///|
/// bevel_back_cone_data projects one tooth sector onto the back cone and the
/// front plane, snaps the root points to the coaxial root circle, replicates
/// the profiles, and returns the per-tooth index ranges.
fn bevel_back_cone_data(
  g : BevelGearGeometry,
  sector : Array[@cad.Vec2],
  tooth_phase_deg~ : Double = 0.0,
) -> Result[
  (
    Array[@cad.Vec3],
    Array[@cad.Vec3],
    Array[(Int32, Int32)],
    Array[(Int32, Int32)],
    Double,
  ),
  @common.SpecError,
] {
  let delta = g.pitch_angle_deg * @math.PI / 180.0
  let d = g.apex_distance_mm
  let q = -g.pitch_radius_mm * @math.tan(delta)
  let root_z = bevel_back_cone_root(g).0
  let root_radius = bevel_back_cone_root(g).1
  if root_radius <= 0.0 {
    return Err(
      @common.InvalidDimension("bevel root circle must have a positive radius"),
    )
  }
  let rr_v = g.virtual_pitch_radius_mm - g.dedendum_mm
  let root_tol = @step.TOL_1E6 * (1.0 + rr_v)
  let s = sector.length()
  let radius_of = fn(p : @cad.Vec2) { Double::sqrt(p.0 * p.0 + p.1 * p.1) }
  let mut tooth_start = -1
  let mut tooth_end = -1
  // The tooth is the run above the root circle. With a root fillet the exact
  // root-circle vertex at the corner is replaced by a tangent arc, so find the
  // first/last points above the root and take their neighbouring root-side
  // points as the tooth limits.
  let mut first_above = -1
  let mut last_above = -1
  for i in 0..<s {
    if radius_of(sector[i]) > rr_v + root_tol {
      if first_above < 0 {
        first_above = i
      }
      last_above = i
    }
  }
  if first_above >= 0 && last_above >= first_above {
    tooth_start = if first_above > 0 { first_above - 1 } else { first_above }
    tooth_end = if last_above + 1 < s { last_above + 1 } else { last_above }
  }
  if tooth_start < 0 || tooth_end <= tooth_start {
    return Err(
      @common.InvalidParameter(
        "bevel tooth sector did not expose a usable tooth range",
      ),
    )
  }
  // The tip land is the run of sector points at the sector's largest radius.
  // Using the sector maximum instead of the theoretical addendum also covers a
  // truncated (landed) tooth.
  let mut ra_v = 0.0
  for i in tooth_start..<=tooth_end {
    let r = radius_of(sector[i])
    if r > ra_v {
      ra_v = r
    }
  }
  let tip_tol = @step.TOL_1E6 * (1.0 + ra_v)
  let mut tip_start_sector = -1
  let mut tip_end_sector = -1
  for i in tooth_start..<=tooth_end {
    if (radius_of(sector[i]) - ra_v).abs() <= tip_tol {
      if tip_start_sector < 0 {
        tip_start_sector = i
      }
      tip_end_sector = i
    }
  }
  // A tip chamfer trims the land off the virtual addendum circle; in that case
  // the smooth compiler falls back to a physical-radius scan.
  let has_tip_land = tip_start_sector >= 0 && tip_end_sector > tip_start_sector
  let front_z = g.axial_face_width_mm
  let back_sector : Array[@cad.Vec3] = []
  let front_sector : Array[@cad.Vec3] = []
  let mut snap_deviation = 0.0
  for p in sector {
    let w = (p.0 * @math.cos(delta), p.1, q + p.0 * @math.sin(delta))
    let c = match bevel_ray_cone(g, w) {
      Some(c) => c
      None =>
        return Err(
          @common.InvalidParameter(
            "bevel tooth ray does not meet the back cone",
          ),
        )
    }
    let snapped = if radius_of(p) <= rr_v + root_tol {
      let theta = @math.atan2(c.1, c.0)
      let sp = (
        root_radius * @math.cos(theta),
        root_radius * @math.sin(theta),
        root_z,
      )
      let dx = c.0 - sp.0
      let dy = c.1 - sp.1
      let dz = c.2 - sp.2
      let dev = Double::sqrt(dx * dx + dy * dy + dz * dz)
      if dev > snap_deviation {
        snap_deviation = dev
      }
      sp
    } else {
      c
    }
    let dz = snapped.2 - d
    if Double::abs(dz) <= @step.TOL_1E12 {
      return Err(
        @common.InvalidParameter(
          "bevel tooth ray is parallel to the front face",
        ),
      )
    }
    let t = (front_z - d) / dz
    back_sector.push(snapped)
    front_sector.push((t * snapped.0, t * snapped.1, front_z))
  }

  let back : Array[@cad.Vec3] = []
  let front : Array[@cad.Vec3] = []
  let teeth : Array[(Int32, Int32)] = []
  let tips : Array[(Int32, Int32)] = []
  let z = g.teeth.to_double()
  let phase = tooth_phase_deg * @math.PI / 180.0
  for k in 0..<g.teeth {
    let angle = phase + 2.0 * @math.PI * k.to_double() / z
    let mut start_clean = -1
    let mut end_clean = -1
    let mut tip_start_clean = -1
    let mut tip_end_clean = -1
    for i in 0..<s {
      if k > 0 && i == 0 {
        continue
      }
      if i == tooth_start {
        start_clean = back.length()
      }
      if i == tooth_end {
        end_clean = back.length()
      }
      if has_tip_land && i == tip_start_sector {
        tip_start_clean = back.length()
      }
      if has_tip_land && i == tip_end_sector {
        tip_end_clean = back.length()
      }
      back.push(bevel_rotate_z(back_sector[i], angle))
      front.push(bevel_rotate_z(front_sector[i], angle))
    }
    if start_clean < 0 ||
      end_clean < 0 ||
      (
        has_tip_land &&
        (tip_start_clean < 0 || tip_end_clean <= tip_start_clean)
      ) {
      return Err(@common.InvalidParameter("bevel tooth range tracking failed"))
    }
    teeth.push((start_clean, end_clean))
    if has_tip_land {
      tips.push((tip_start_clean, tip_end_clean))
    }
  }
  // The last sector's trailing gap boundary duplicates sector 0's first point.
  let last = back.length() - 1
  if last > 0 {
    let dx = back[0].0 - back[last].0
    let dy = back[0].1 - back[last].1
    let dz = back[0].2 - back[last].2
    if Double::sqrt(dx * dx + dy * dy + dz * dz) <= @step.TOL_1E9 {
      let _ = back.pop()
      let _ = front.pop()
    }
  }
  Ok((back, front, teeth, tips, snap_deviation))
}
