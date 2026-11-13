///|
/// VSlotProfile is the OpenBuilds V-Slot cross-section for the 20-series.
///
/// V-Slot is **not** the generic T-slot envelope in `tslot.mbt` and it is not
/// interchangeable with a vendor "B-slot6" section. Its defining feature is a
/// pair of 45 degree V lips: the slot mouth is wider than the neck, so a
/// V-wheel's 90 degree groove rides the lips while a T-nut passes the neck into
/// the cavity below.
///
/// Published cross-section values used here (all millimetres):
///
/// - 20 x 20 envelope, 1.8 mm lip, 11 mm cavity width, 4.3 mm cavity depth
/// - 6.25 mm neck, 9.16 mm V mouth, 90 degree included V angle
/// - 1.5 mm diagonal webs, 4.2 mm core bore, 0.5 mm outer corner radius
///
/// These numbers come from the OpenBuilds V-Slot 20 x 20 drawing as recorded
/// by the open `ink.parts` dimension sheet and cross-checked against the
/// published OpenBuilds cross-section DXF. The section is a manufacturer
/// geometry, not a universal standard, so the builder is labelled as an
/// OpenBuilds-compatible profile rather than a standard.
///
/// Dimensions are millimetres, the section is centred on the XY origin, and
/// `vslot_extrusion` sweeps it along +Z from `z = 0`.
pub(all) struct VSlotProfile {
  name : String
  width_mm : Double
  height_mm : Double
  /// Widest opening of the V at the outer surface (across the two lips).
  slot_mouth_mm : Double
  /// Narrowest opening between the two lip walls.
  slot_neck_mm : Double
  /// Axial thickness of the lip from the outer surface to its underside.
  lip_thickness_mm : Double
  /// Width of the cavity under the lips.
  cavity_width_mm : Double
  /// Cavity depth below the lip underside.
  cavity_depth_mm : Double
  /// Diagonal web thickness between adjacent slot cavities.
  corner_web_mm : Double
  core_bore_diameter_mm : Double
  corner_radius_mm : Double
  /// Small central relief at the inner end of each slot floor.
  floor_relief_mm : Double
  /// Nominal cell pitch of the 20-series.
  cell_pitch_mm : Double
  /// Number of 20 mm cells along the height.
  cells : Int32
}

///|
/// VSlotProfile::vslot_2020 returns the OpenBuilds V-Slot 20 x 20 section.
pub fn VSlotProfile::vslot_2020() -> VSlotProfile {
  {
    name: "V-Slot-2020",
    width_mm: 20.0,
    height_mm: 20.0,
    slot_mouth_mm: 9.16,
    slot_neck_mm: 6.25,
    lip_thickness_mm: 1.8,
    cavity_width_mm: 11.0,
    cavity_depth_mm: 4.3,
    corner_web_mm: 1.5,
    core_bore_diameter_mm: 4.2,
    corner_radius_mm: 0.5,
    floor_relief_mm: 0.21,
    cell_pitch_mm: 20.0,
    cells: 1,
  }
}

///|
/// VSlotProfile::vslot_2040 returns the OpenBuilds V-Slot 20 x 40 section.
///
/// The 20 x 40 section is two 20 mm cells tall. It has six slots (one on each
/// end face, two on each long face), two 4.2 mm core bores on the cell centres,
/// and a large central channel bounded by 1.5 mm webs.
pub fn VSlotProfile::vslot_2040() -> VSlotProfile {
  {
    ..VSlotProfile::vslot_2020(),
    name: "V-Slot-2040",
    height_mm: 40.0,
    cells: 2,
  }
}

///|
/// VSlotProfile::custom validates a caller-supplied OpenBuilds-style section.
///
/// The derived proportions used by the drawing (V angle, taper start, floor
/// width) are recomputed from these values, so a custom section must describe
/// a consistent V-Slot geometry. The builder rejects sections where the taper
/// or the core would run into the lip or the web.
pub fn VSlotProfile::custom(
  name~ : String,
  width_mm~ : Double,
  height_mm~ : Double,
  slot_mouth_mm~ : Double = 9.16,
  slot_neck_mm~ : Double = 6.25,
  lip_thickness_mm~ : Double = 1.8,
  cavity_width_mm~ : Double = 11.0,
  cavity_depth_mm~ : Double = 4.3,
  corner_web_mm~ : Double = 1.5,
  core_bore_diameter_mm~ : Double = 4.2,
  corner_radius_mm~ : Double = 0.5,
  floor_relief_mm~ : Double = 0.21,
  cell_pitch_mm~ : Double = 20.0,
) -> Result[VSlotProfile, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("profile width", width_mm),
    @common.require_positive("profile height", height_mm),
    @common.require_positive("slot mouth", slot_mouth_mm),
    @common.require_positive("slot neck", slot_neck_mm),
    @common.require_positive("lip thickness", lip_thickness_mm),
    @common.require_positive("cavity width", cavity_width_mm),
    @common.require_positive("cavity depth", cavity_depth_mm),
    @common.require_positive("corner web", corner_web_mm),
    @common.require_positive("core bore diameter", core_bore_diameter_mm),
    @common.require_positive("cell pitch", cell_pitch_mm),
    @common.require_non_negative("corner radius", corner_radius_mm),
    @common.require_non_negative("floor relief", floor_relief_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if height_mm < width_mm {
    return Err(
      @common.InvalidParameter(
        "V-Slot height must be at least the width for this section family",
      ),
    )
  }
  let cells = (height_mm / cell_pitch_mm).round().to_int()
  if cells < 1 ||
    (height_mm - Double::from_int(cells) * cell_pitch_mm).abs() > 1.0e-6 {
    return Err(
      @common.InvalidParameter(
        "V-Slot height must be a whole number of 20 mm cells",
      ),
    )
  }
  if cells > 2 {
    return Err(
      @common.InvalidParameter(
        "only one-cell (20x20) and two-cell (20x40) V-Slot sections are supported; the 20x60/20x80 channel is not modelled",
      ),
    )
  }
  if slot_mouth_mm <= slot_neck_mm {
    return Err(
      @common.InvalidParameter("slot mouth must be wider than the neck"),
    )
  }
  if cavity_width_mm <= slot_neck_mm {
    return Err(
      @common.InvalidParameter("cavity width must exceed the slot neck"),
    )
  }
  if cavity_width_mm >= width_mm {
    return Err(
      @common.InvalidParameter(
        "cavity width must be smaller than the section width",
      ),
    )
  }
  let half = width_mm / 2.0
  let c = corner_web_mm / Double::sqrt(2.0)
  let taper_side_top = half - c - cavity_width_mm / 2.0
  if taper_side_top <= lip_thickness_mm {
    return Err(
      @common.InvalidParameter(
        "slot cavity and diagonal web leave no straight lip wall",
      ),
    )
  }
  let floor_depth = lip_thickness_mm + cavity_depth_mm
  let floor_inner = half - c - floor_depth
  if floor_inner <= floor_relief_mm {
    return Err(
      @common.InvalidParameter(
        "slot cavity depth leaves no core floor (floor half-width \{floor_inner})",
      ),
    )
  }
  if core_bore_diameter_mm / 2.0 >= floor_inner {
    return Err(
      @common.InvalidParameter(
        "core bore does not leave a web between the bore and the slot floor",
      ),
    )
  }
  if corner_radius_mm >= half - slot_mouth_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "corner radius leaves no flat outer face above the V mouth",
      ),
    )
  }
  if cells == 2 {
    let x_wall = half - lip_thickness_mm
    let shoulder = x_wall - cavity_width_mm / 2.0
    let c_channel = half - c
    let top_half = c_channel - floor_depth
    if shoulder <= 0.0 || top_half <= floor_relief_mm {
      return Err(
        @common.InvalidParameter(
          "central channel does not fit inside the two-cell section",
        ),
      )
    }
  }
  Ok({
    name,
    width_mm,
    height_mm,
    slot_mouth_mm,
    slot_neck_mm,
    lip_thickness_mm,
    cavity_width_mm,
    cavity_depth_mm,
    corner_web_mm,
    core_bore_diameter_mm,
    corner_radius_mm,
    floor_relief_mm,
    cell_pitch_mm,
    cells,
  })
}

///|
/// VSlotProfile::designation returns the profile name used in part labels.
pub fn VSlotProfile::designation(self : VSlotProfile) -> String {
  self.name
}

///|
/// VSlotProfile::cell_centres returns the core-bore centres along Y.
///
/// A one-cell section has one bore at `y = 0`; a two-cell section has bores at
/// `y = +/- height/4`.
fn VSlotProfile::cell_centres(self : VSlotProfile) -> Array[Double] {
  let out : Array[Double] = []
  let pitch = self.cell_pitch_mm
  let start = -self.height_mm / 2.0 + pitch / 2.0
  for i in 0..<self.cells {
    out.push(start + Double::from_int(i) * pitch)
  }
  out
}

///|
/// VSlotProfile::side_slot_centres returns the slot centres on the long faces.
fn VSlotProfile::side_slot_centres(self : VSlotProfile) -> Array[Double] {
  self.cell_centres()
}

///|
/// VSlotProfile::taper_constant is the local coordinate offset of the 45 degree
/// cavity taper, measured from the face centre.
fn VSlotProfile::taper_constant(self : VSlotProfile) -> Double {
  self.corner_web_mm / Double::sqrt(2.0)
}

///|
/// VSlotProfile::floor_depth is the inward depth of the slot floor.
fn VSlotProfile::floor_depth(self : VSlotProfile) -> Double {
  self.lip_thickness_mm + self.cavity_depth_mm
}

///|
/// VSlotProfile::taper_side_top is the inward depth at which the straight
/// cavity wall meets the 45 degree taper.
fn VSlotProfile::taper_side_top(self : VSlotProfile) -> Double {
  let half = self.width_mm / 2.0
  half - self.taper_constant() - self.cavity_width_mm / 2.0
}

///|
/// VSlotProfile::floor_inner is the half-width of the flat slot floor.
fn VSlotProfile::floor_inner(self : VSlotProfile) -> Double {
  let half = self.width_mm / 2.0
  half - self.taper_constant() - self.floor_depth()
}

///|
/// vslot_slot_points returns the inward notch path for one slot, in
/// face-local coordinates `(u, d)` where `u` runs along the boundary and `d`
/// is the inward depth from the face.
///
/// The two ends lie on the face (`d = 0`), so the caller can splice the path
/// into a straight edge.
fn vslot_slot_points(
  profile : VSlotProfile,
  u_centre : Double,
) -> Array[@cad.Vec2] {
  let mouth_half = profile.slot_mouth_mm / 2.0
  let neck_half = profile.slot_neck_mm / 2.0
  let cavity_half = profile.cavity_width_mm / 2.0
  let lip = profile.lip_thickness_mm
  let shoulder = mouth_half - neck_half
  let side_top = profile.taper_side_top()
  let floor = profile.floor_depth()
  let inner = profile.floor_inner()
  let relief = profile.floor_relief_mm
  [
    (u_centre - mouth_half, 0.0),
    (u_centre - neck_half, shoulder),
    (u_centre - neck_half, lip),
    (u_centre - cavity_half, lip),
    (u_centre - cavity_half, side_top),
    (u_centre - inner, floor),
    (u_centre - relief, floor),
    (u_centre, floor - relief),
    (u_centre + relief, floor),
    (u_centre + inner, floor),
    (u_centre + cavity_half, side_top),
    (u_centre + cavity_half, lip),
    (u_centre + neck_half, lip),
    (u_centre + neck_half, shoulder),
    (u_centre + mouth_half, 0.0),
  ]
}

///|
/// vslot_edge_segments walks one straight outer face from `start` to `end`,
/// inserting each slot notch whose face-local centre is listed in `centres`.
///
/// `inward` is the unit inward normal. The returned segments cover the edge
/// exactly once, from `start` to `end`, with no corner arcs.
fn vslot_edge_segments(
  profile : VSlotProfile,
  start : @cad.Vec2,
  end : @cad.Vec2,
  inward : @cad.Vec2,
  centres : Array[Double],
) -> Array[@cad.ProfileSegment] {
  let (sx, sy) = start
  let (ex, ey) = end
  let (ix, iy) = inward
  let dx = ex - sx
  let dy = ey - sy
  let length = Double::sqrt(dx * dx + dy * dy)
  let ux = dx / length
  let uy = dy / length
  let ordered = centres.copy()
  ordered.sort_by(fn(a, b) { a.compare(b) })
  let out : Array[@cad.ProfileSegment] = []
  let mut cursor = (sx, sy)
  for centre in ordered {
    for (u, d) in vslot_slot_points(profile, centre) {
      let p = (sx + ux * u + ix * d, sy + uy * u + iy * d)
      out.push(@cad.SegmentLine(cursor, p))
      cursor = p
    }
  }
  out.push(@cad.SegmentLine(cursor, end))
  out
}

///|
/// VSlotProfile::outline returns the outer section loop as a counter-clockwise
/// line/arc chain.
///
/// The four outer corners are analytic arcs (minor, counter-clockwise) when
/// `corner_radius_mm > 0`; every V lip and cavity wall is a straight line. The
/// loop is suitable for `ExtrudedArcProfile`, so the corner radii compile to
/// real cylindrical surfaces rather than facets.
pub fn VSlotProfile::outline(self : VSlotProfile) -> Array[@cad.ProfileSegment] {
  let hw = self.width_mm / 2.0
  let hh = self.height_mm / 2.0
  let rc = self.corner_radius_mm
  let side = self.side_slot_centres()
  let out : Array[@cad.ProfileSegment] = []
  // Bottom edge, -X to +X.
  let bottom_start = (-hw + rc, -hh)
  let bottom_end = (hw - rc, -hh)
  out.push_iter(
    vslot_edge_segments(self, bottom_start, bottom_end, (0.0, 1.0), [hw - rc]).iter(),
  )
  out.push(@cad.SegmentArc(bottom_end, (hw, -hh + rc), (hw - rc, -hh + rc)))
  // Right edge, -Y to +Y, two slots for the two-cell section.
  let right_start = (hw, -hh + rc)
  let right_end = (hw, hh - rc)
  let right_centres = side.map(fn(y) { y + (hh - rc) })
  out.push_iter(
    vslot_edge_segments(
      self,
      right_start,
      right_end,
      (-1.0, 0.0),
      right_centres,
    ).iter(),
  )
  out.push(@cad.SegmentArc(right_end, (hw - rc, hh), (hw - rc, hh - rc)))
  // Top edge, +X to -X.
  let top_start = (hw - rc, hh)
  let top_end = (-hw + rc, hh)
  out.push_iter(
    vslot_edge_segments(self, top_start, top_end, (0.0, -1.0), [hw - rc]).iter(),
  )
  out.push(@cad.SegmentArc(top_end, (-hw, hh - rc), (-hw + rc, hh - rc)))
  // Left edge, +Y to -Y.
  let left_start = (-hw, hh - rc)
  let left_end = (-hw, -hh + rc)
  let left_centres = side.map(fn(y) { hh - rc - y })
  out.push_iter(
    vslot_edge_segments(self, left_start, left_end, (1.0, 0.0), left_centres).iter(),
  )
  out.push(@cad.SegmentArc(left_end, bottom_start, (-hw + rc, -hh + rc)))
  out
}

///|
/// vslot_circle_loop returns a counter-clockwise circle as four 90 degree arcs,
/// which the arc compiler turns into one analytic cylindrical hole.
fn vslot_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let right = (cx + radius, cy)
  let top = (cx, cy + radius)
  let left = (cx - radius, cy)
  let bottom = (cx, cy - radius)
  let centre = (cx, cy)
  [
    @cad.SegmentArc(right, top, centre),
    @cad.SegmentArc(top, left, centre),
    @cad.SegmentArc(left, bottom, centre),
    @cad.SegmentArc(bottom, right, centre),
  ]
}

///|
/// VSlotProfile::channel_loop returns the central channel of a two-cell
/// section as a counter-clockwise line loop, or an empty array for a one-cell
/// section.
///
/// The channel is a rectangle inset one lip thickness from the long faces,
/// with its flat ends at the slot floor depth and 45 degree corners offset from
/// the slot tapers by the diagonal web.
fn VSlotProfile::channel_loop(
  self : VSlotProfile,
) -> Array[@cad.ProfileSegment] {
  if self.cells < 2 {
    return []
  }
  let hw = self.width_mm / 2.0
  let x_wall = hw - self.lip_thickness_mm
  let y_wall = self.floor_depth()
  let shoulder = x_wall - self.cavity_width_mm / 2.0
  let c_channel = hw - self.taper_constant()
  let top_half = c_channel - y_wall
  let chamfer_x = c_channel - shoulder
  let points : Array[@cad.Vec2] = [
    (x_wall, -shoulder),
    (x_wall, shoulder),
    (chamfer_x, shoulder),
    (top_half, y_wall),
    (-top_half, y_wall),
    (-chamfer_x, shoulder),
    (-x_wall, shoulder),
    (-x_wall, -shoulder),
    (-chamfer_x, -shoulder),
    (-top_half, -y_wall),
    (top_half, -y_wall),
    (chamfer_x, -shoulder),
  ]
  let out : Array[@cad.ProfileSegment] = []
  for i in 0..<points.length() {
    out.push(@cad.SegmentLine(points[i], points[(i + 1) % points.length()]))
  }
  out
}

///|
/// VSlotProfile::holes returns the inner loops: one circular core bore per
/// cell and, for a two-cell section, the central channel.
pub fn VSlotProfile::holes(
  self : VSlotProfile,
) -> Array[Array[@cad.ProfileSegment]] {
  let radius = self.core_bore_diameter_mm / 2.0
  let out : Array[Array[@cad.ProfileSegment]] = []
  for y in self.cell_centres() {
    out.push(vslot_circle_loop(0.0, y, radius))
  }
  let channel = self.channel_loop()
  if !channel.is_empty() {
    out.push(channel)
  }
  out
}

///|
/// VSlotProfile::size returns `(width, height)` in millimetres.
pub fn VSlotProfile::size(self : VSlotProfile) -> @cad.Vec2 {
  (self.width_mm, self.height_mm)
}

///|
/// VSlotProfile::slot_count returns the number of open slots in the section.
pub fn VSlotProfile::slot_count(self : VSlotProfile) -> Int32 {
  if self.cells == 1 {
    4
  } else {
    2 * self.cells + 2
  }
}

///|
/// VSlotProfile::metadata builds provenance-aware metadata for a cut length.
pub fn VSlotProfile::metadata(
  self : VSlotProfile,
  length_mm : Double,
) -> @common.Metadata {
  @common.Metadata::new(
    designation="OpenBuilds \{self.name} x \{@cad.fmt_double(length_mm, None)}",
    standard="OpenBuilds V-Slot 20-series (manufacturer profile, not a universal standard)",
    family="aluminium V-Slot extrusion",
    size=self.name,
    length_mm~,
    source="OpenBuilds V-Slot cross-section dimensions as published by the open ink.parts dimension sheet and the OpenBuilds cross-section drawing; geometry recomputed parametrically in this library.",
  )
}

///|
/// vslot_extrusion builds a cut-to-length OpenBuilds V-Slot extrusion.
///
/// The section is centred on the XY origin and the length runs along +Z from
/// `z = 0`. The V lips, neck, cavity, core bores, and (for 20 x 40) the central
/// channel are modelled; no end machining or tapping is performed.
pub fn vslot_extrusion(
  profile : VSlotProfile,
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
        modeled=[
          "body", "v-lips", "slot-necks", "slot-cavities", "diagonal-webs", "outer-corner-radii",
          "core-bores",
        ],
        approximated=[],
        omitted=[
          @common.Omission::new(
            feature="end-caps-and-tapping",
            reason="end caps, cut burrs, and M5 tapping are not modelled",
          ),
          @common.Omission::new(
            feature="anodising",
            reason="surface finish is not a geometric feature",
          ),
        ],
      )
      let mut component = @common.Component::new(
        name="\{profile.name}-L\{@cad.fmt_double(length_mm, None)}",
        metadata=profile.metadata(length_mm),
        description="OpenBuilds-compatible V-Slot extrusion with 90 degree V lips, slot cavities, analytic core bores, and (for two-cell sections) a central channel. No end machining.",
        features~,
      ).add_layer(body, name="body", color~)
      component = with_vslot_connectors(component, profile, length_mm)
      Ok(component)
    }
  }
}
