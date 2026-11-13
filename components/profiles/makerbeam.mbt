///|
/// MakerBeamProfile is the MakerBeam 10 x 10 mm extrusion cross-section.
///
/// The section is not a generic T-slot. MakerBeam's drawing (article 100168,
/// "beam clear anodised, M3, Ø2.5") defines a 3 mm slot on each face over a
/// straight dovetail undercut that runs at 41.1 degrees down to a 4 x 4 mm
/// core; a Ø2.5 mm centre bore is the tap drill of the M3 x 8 mm end threads.
///
/// Published values used here (millimetres), from the drawing's DXF geometry
/// and printed dimensions:
///
/// - 10 x 10 envelope
/// - 3.0 mm slot opening, 1.0 mm lip
/// - 4.0 x 4.0 core (slot floor 2.0 mm from the centre)
/// - dovetail wall through (2.8908, 3.6493) and (1.0565, 2.0493), 41.1 degrees
/// - the wall meets the lip underside 3.293 mm from the face centre and the
///   slot floor 1.000 mm from it
/// - Ø2.5 mm centre bore, M3 x 8 mm end threads (threads are not modelled)
///
/// MakerBeam's R0.2 corner and edge radii are not modelled by this builder;
/// the sharp dimensioned outline is used, whose section area is 48.75 mm².
/// This is a manufacturer profile, not a universal standard. Do not assume a
/// generic T-slot nut or a V-Slot accessory fits it.
///
/// Dimensions are millimetres and the section is centred on the XY origin.
/// `makerbeam_extrusion` sweeps it along +Z from `z = 0`.
pub(all) struct MakerBeamProfile {
  name : String
  /// Square envelope size (10.0 for MakerBeam).
  size_mm : Double
  /// Slot opening width at the outer face.
  slot_width_mm : Double
  /// Lip thickness from the outer face to its underside.
  lip_thickness_mm : Double
  /// Square core width (the slot floor sits at `core_width_mm / 2`).
  core_width_mm : Double
  /// Centre bore diameter (the M3 tap drill).
  bore_diameter_mm : Double
  /// Half-width where the dovetail wall meets the lip underside.
  lip_undercut_half_mm : Double
  /// Half-width where the dovetail wall meets the slot floor.
  floor_undercut_half_mm : Double
  /// Optional outer corner radius; 0 keeps the sharp dimensioned outline.
  corner_radius_mm : Double
}

///|
/// MakerBeamProfile::mb_1010 returns the MakerBeam 10 x 10 mm section.
pub fn MakerBeamProfile::mb_1010() -> MakerBeamProfile {
  {
    name: "MakerBeam-1010",
    size_mm: 10.0,
    slot_width_mm: 3.0,
    lip_thickness_mm: 1.0,
    core_width_mm: 4.0,
    bore_diameter_mm: 2.5,
    lip_undercut_half_mm: 3.293,
    floor_undercut_half_mm: 1.0,
    corner_radius_mm: 0.0,
  }
}

///|
/// MakerBeamProfile::custom validates a caller-supplied MakerBeam-style
/// section. The dovetail wall is described by the two half-widths at the lip
/// underside and at the slot floor.
pub fn MakerBeamProfile::custom(
  name~ : String,
  size_mm~ : Double,
  slot_width_mm~ : Double,
  lip_thickness_mm~ : Double,
  core_width_mm~ : Double,
  bore_diameter_mm~ : Double,
  lip_undercut_half_mm~ : Double,
  floor_undercut_half_mm~ : Double,
  corner_radius_mm~ : Double = 0.0,
) -> Result[MakerBeamProfile, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("profile size", size_mm),
    @common.require_positive("slot width", slot_width_mm),
    @common.require_positive("lip thickness", lip_thickness_mm),
    @common.require_positive("core width", core_width_mm),
    @common.require_positive("bore diameter", bore_diameter_mm),
    @common.require_positive("lip undercut half-width", lip_undercut_half_mm),
    @common.require_positive(
      "floor undercut half-width", floor_undercut_half_mm,
    ),
    @common.require_non_negative("corner radius", corner_radius_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let half = size_mm / 2.0
  let slot_half = slot_width_mm / 2.0
  let floor_y = core_width_mm / 2.0
  if slot_width_mm >= size_mm {
    return Err(
      @common.InvalidParameter(
        "slot width must be smaller than the profile size",
      ),
    )
  }
  if lip_thickness_mm >= half {
    return Err(
      @common.InvalidParameter(
        "lip thickness must be smaller than half the size",
      ),
    )
  }
  if core_width_mm >= size_mm {
    return Err(
      @common.InvalidParameter(
        "core width must be smaller than the profile size",
      ),
    )
  }
  if bore_diameter_mm >= core_width_mm {
    return Err(
      @common.InvalidParameter(
        "bore diameter must be smaller than the core width",
      ),
    )
  }
  if lip_undercut_half_mm <= slot_half {
    return Err(
      @common.InvalidParameter(
        "lip undercut must be wider than the slot opening",
      ),
    )
  }
  if lip_undercut_half_mm >= half {
    return Err(
      @common.InvalidParameter("lip undercut must stay inside the outer face"),
    )
  }
  if floor_undercut_half_mm <= 0.0 {
    return Err(@common.InvalidParameter("floor undercut must be positive"))
  }
  if floor_undercut_half_mm >= lip_undercut_half_mm {
    return Err(
      @common.InvalidParameter(
        "floor undercut must be narrower than the lip undercut",
      ),
    )
  }
  if floor_y <= lip_thickness_mm {
    return Err(
      @common.InvalidParameter(
        "core floor must be deeper than the lip underside",
      ),
    )
  }
  if corner_radius_mm > 0.25 * size_mm {
    return Err(
      @common.InvalidParameter(
        "corner radius must not exceed a quarter of the profile size",
      ),
    )
  }
  Ok({
    name,
    size_mm,
    slot_width_mm,
    lip_thickness_mm,
    core_width_mm,
    bore_diameter_mm,
    lip_undercut_half_mm,
    floor_undercut_half_mm,
    corner_radius_mm,
  })
}

///|
/// MakerBeamProfile::designation returns the label used in part names.
pub fn MakerBeamProfile::designation(self : MakerBeamProfile) -> String {
  self.name
}

///|
/// MakerBeamProfile::section_area_mm2 returns the exact sharp-section area.
///
/// The outer loop area is computed from the polygon; the centre bore is
/// subtracted. For the standard profile this is 48.75 mm², matching the
/// MakerBeam drawing.
pub fn MakerBeamProfile::section_area_mm2(self : MakerBeamProfile) -> Double {
  let mut area = 0.0
  let pts = self.section_points()
  let n = pts.length()
  for i in 0..<n {
    let (x1, y1) = pts[i]
    let (x2, y2) = pts[(i + 1) % n]
    area += x1 * y2 - x2 * y1
  }
  area = area / 2.0
  if area < 0.0 {
    area = -area
  }
  let r = self.corner_radius_mm
  if r > 0.0 {
    // Each rounded outer corner removes r^2 - pi r^2 / 4 from the sharp area.
    area = area - 4.0 * (r * r - 3.141592653589793 * r * r / 4.0)
  }
  let radius = self.bore_diameter_mm / 2.0
  area - 3.141592653589793 * radius * radius
}

///|
/// makerbeam_one_side returns the nine points of one side of the section, from
/// the anti-clockwise corner `(-half, +half)` to the slot mouth `(+s2, +half)`.
/// The points are in face-local top coordinates; the caller rotates them.
fn makerbeam_one_side(
  half : Double,
  s2 : Double,
  lip_y : Double,
  floor_y : Double,
  under : Double,
  foot : Double,
) -> Array[@cad.Vec2] {
  [
    (-half, half),
    (-s2, half),
    (-s2, lip_y),
    (-under, lip_y),
    (-foot, floor_y),
    (foot, floor_y),
    (under, lip_y),
    (s2, lip_y),
    (s2, half),
  ]
}

///|
/// MakerBeamProfile::section_points returns the closed outer loop as a
/// counter-clockwise array of 36 sharp vertices (four sides of nine points).
///
/// The construction repeats one side rotated by -90 degrees; reversing the
/// clockwise concatenation yields the counter-clockwise loop the extrusion
/// compiler expects. Adjacent sides meet with a straight segment from the
/// slot mouth to the next corner.
pub fn MakerBeamProfile::section_points(
  self : MakerBeamProfile,
) -> Array[@cad.Vec2] {
  let half = self.size_mm / 2.0
  let s2 = self.slot_width_mm / 2.0
  let lip_y = half - self.lip_thickness_mm
  let floor_y = self.core_width_mm / 2.0
  let side = makerbeam_one_side(
    half,
    s2,
    lip_y,
    floor_y,
    self.lip_undercut_half_mm,
    self.floor_undercut_half_mm,
  )
  let clockwise : Array[@cad.Vec2] = []
  let mut current = side.copy()
  for _ in 0..<4 {
    for point in current {
      clockwise.push(point)
    }
    // Rotate the side by -90 degrees: (x, y) -> (y, -x).
    current = current.map(fn(point) { (point.1, -point.0) })
  }
  let out : Array[@cad.Vec2] = []
  let n = clockwise.length()
  for i in 0..<n {
    out.push(clockwise[n - 1 - i])
  }
  out
}

///|
/// MakerBeamProfile::outline returns the outer section loop as a
/// counter-clockwise line/arc chain.
///
/// The optional corner radius rounds only the four outer corners; the
/// dimensioned slot and core geometry stays sharp. Internal R0.2 rounds from
/// the drawing are not modelled.
pub fn MakerBeamProfile::outline(
  self : MakerBeamProfile,
) -> Array[@cad.ProfileSegment] {
  let pts = self.section_points()
  let radius = self.corner_radius_mm
  let out : Array[@cad.ProfileSegment] = []
  if radius <= 0.0 {
    for i in 0..<pts.length() {
      out.push(@cad.SegmentLine(pts[i], pts[(i + 1) % pts.length()]))
    }
    return out
  }
  let half = self.size_mm / 2.0
  let n = pts.length()
  for i in 0..<n {
    let current = pts[i]
    let prev = pts[(i + n - 1) % n]
    let next = pts[(i + 1) % n]
    let is_outer = (current.0.abs() - half).abs() < 1.0e-9 &&
      (current.1.abs() - half).abs() < 1.0e-9
    let entry = if is_outer {
      makerbeam_toward(current, prev, radius)
    } else {
      current
    }
    let leave = if is_outer {
      makerbeam_toward(current, next, radius)
    } else {
      current
    }
    if is_outer {
      let centre = (
        entry.0 + (leave.0 - current.0),
        entry.1 + (leave.1 - current.1),
      )
      out.push(@cad.SegmentArc(entry, leave, centre))
    }
    // Next vertex's entry point (or the vertex itself when it is sharp).
    let next_point = pts[(i + 1) % n]
    let next_is_outer = (next_point.0.abs() - half).abs() < 1.0e-9 &&
      (next_point.1.abs() - half).abs() < 1.0e-9
    let next_entry = if next_is_outer {
      makerbeam_toward(next_point, current, radius)
    } else {
      next_point
    }
    out.push(@cad.SegmentLine(leave, next_entry))
  }
  out
}

///|
/// makerbeam_toward returns the point `distance` from `from` toward `to`.
fn makerbeam_toward(
  from : @cad.Vec2,
  to : @cad.Vec2,
  distance : Double,
) -> @cad.Vec2 {
  let dx = to.0 - from.0
  let dy = to.1 - from.1
  let length = Double::sqrt(dx * dx + dy * dy)
  (from.0 + dx / length * distance, from.1 + dy / length * distance)
}

///|
/// MakerBeamProfile::holes returns the centre bore as a counter-clockwise
/// four-arc loop, which the arc compiler turns into one analytic cylinder.
pub fn MakerBeamProfile::holes(
  self : MakerBeamProfile,
) -> Array[Array[@cad.ProfileSegment]] {
  [vslot_circle_loop(0.0, 0.0, self.bore_diameter_mm / 2.0)]
}

///|
/// MakerBeamProfile::slot_count returns the number of open slots (four).
pub fn MakerBeamProfile::slot_count(self : MakerBeamProfile) -> Int32 {
  let _ = self
  4
}

///|
/// MakerBeamProfile::metadata builds provenance-aware metadata for a cut
/// length.
pub fn MakerBeamProfile::metadata(
  self : MakerBeamProfile,
  length_mm : Double,
) -> @common.Metadata {
  @common.Metadata::new(
    designation="MakerBeam \{@cad.fmt_double(self.size_mm, None)} x \{@cad.fmt_double(self.size_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
    standard="MakerBeam article 100168 (manufacturer drawing, not a universal standard)",
    family="aluminium MakerBeam extrusion",
    size=self.name,
    length_mm~,
    source="MakerBeam technical drawing article 100168 (DXF geometry and printed dimensions); section recomputed parametrically in this library.",
  )
}

///|
/// with_makerbeam_connectors attaches the four face-slot connectors and the
/// two end datums, then adds the M3 end-thread interfaces.
///
/// The end threads are declared from MakerBeam's specification (M3, 8 mm deep)
/// but are not modelled geometrically.
fn with_makerbeam_connectors(
  component : @common.Component,
  profile : MakerBeamProfile,
  length_mm : Double,
) -> @common.Component {
  let base = with_extrusion_connectors(
    component,
    profile.size_mm,
    profile.size_mm,
    length_mm,
    profile.slot_width_mm,
    profile.bore_diameter_mm,
  )
  base
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-thread-a",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(0.0, 0.0, -1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=3.0,
      depth_mm=8.0,
      description="M3 x 8 mm tapped end at z = 0 (thread not modelled)",
    ),
  )
  .with_connector_unchecked(
    @common.MateConnector::new(
      "end-thread-b",
      placement=@common.Placement::translation(0.0, 0.0, length_mm),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::Threaded,
      gender=@common.MateGender::Female,
      diameter_mm=3.0,
      depth_mm=8.0,
      description="M3 x 8 mm tapped end at z = length (thread not modelled)",
    ),
  )
}

///|
/// makerbeam_extrusion builds a cut-to-length MakerBeam 10 x 10 extrusion.
///
/// The section is centred on the XY origin and the length runs along +Z from
/// `z = 0`. The four slots, dovetail undercuts, 4 x 4 core, and Ø2.5 mm centre
/// bore are modelled analytically. The R0.2 drawing radii and the M3 end
/// threads are not modelled; no anodising, cut burrs, or strength claim.
pub fn makerbeam_extrusion(
  profile : MakerBeamProfile,
  length_mm : Double,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("extrusion length", length_mm) {
    Err(e) => Err(e)
    Ok(_) => {
      let _ = detail
      let body = @cad.ExtrudedArcProfile::new(
        profile.outline(),
        length_mm,
        holes=profile.holes(),
      ).as_shape()
      let features = @common.FeatureRecord::new(
        modeled=["body", "slots", "dovetail-undercuts", "core", "central-bore"],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="r0.2-corner-and-edge-radii",
            reason="MakerBeam's R0.2 corner and edge radii are omitted; the sharp dimensioned outline is modelled",
          ),
          @common.Omission::new(
            feature="m3-end-threads",
            reason="the M3 x 8 mm end threads are declared by connectors but not modelled geometrically",
          ),
          @common.Omission::new(
            feature="anodising-and-cut-burrs",
            reason="surface finish and cut burrs are not geometric features",
          ),
        ],
      )
      let mut component = @common.Component::new(
        name="\{profile.name}-L\{@cad.fmt_double(length_mm, None)}",
        metadata=profile.metadata(length_mm),
        description="MakerBeam-compatible 10 x 10 extrusion with a 3 mm slot on each face, 41.1 degree dovetail undercuts, a 4 x 4 core, and an analytic Ø2.5 mm centre bore. No end tapping.",
        features~,
      ).add_layer(body, name="body", color~)
      component = with_makerbeam_connectors(component, profile, length_mm)
      Ok(component)
    }
  }
}
