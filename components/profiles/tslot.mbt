///|
/// TSlotProfile is a generic metric T-slot extrusion cross-section.
///
/// **These are engineering envelopes, not a universal interchange standard.**
/// Slot width, slot depth, core geometry, and corner radii differ between
/// manufacturers and series. A part modelled from this profile is
/// cross-section compatible with itself; do not assume it mates with a
/// particular vendor's extrusion without checking that vendor's drawing.
///
/// Dimensions are millimetres and the section is centred on the origin in the
/// XY plane. `extrusion()` sweeps the section along +Z.
///
/// When a rectangular slot cavity would intersect the cavity on the adjacent
/// face, the cavity back is tapered to leave a solid corner web. The resulting
/// section has the four characteristic corner "arrows" connected to the
/// central core, rather than a self-intersecting outline.
pub(all) struct TSlotProfile {
  name : String
  width_mm : Double
  height_mm : Double
  slot_width_mm : Double
  slot_neck_depth_mm : Double
  slot_depth_mm : Double
  cavity_width_mm : Double
  core_bore_diameter_mm : Double
  wall_mm : Double
}

///|
/// TSlotProfile::custom validates a generic profile.
pub fn TSlotProfile::custom(
  name~ : String,
  width_mm~ : Double,
  height_mm~ : Double,
  slot_width_mm~ : Double,
  slot_neck_depth_mm~ : Double,
  slot_depth_mm~ : Double,
  cavity_width_mm~ : Double,
  core_bore_diameter_mm~ : Double,
  wall_mm~ : Double,
) -> Result[TSlotProfile, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("profile width", width_mm),
    @common.require_positive("profile height", height_mm),
    @common.require_positive("slot width", slot_width_mm),
    @common.require_positive("slot neck depth", slot_neck_depth_mm),
    @common.require_positive("slot depth", slot_depth_mm),
    @common.require_positive("cavity width", cavity_width_mm),
    @common.require_positive("core bore diameter", core_bore_diameter_mm),
    @common.require_positive("wall thickness", wall_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if cavity_width_mm <= slot_width_mm {
    return Err(
      @common.InvalidParameter(
        "cavity width (\{cavity_width_mm}) must exceed slot width (\{slot_width_mm})",
      ),
    )
  }
  if slot_depth_mm <= slot_neck_depth_mm {
    return Err(
      @common.InvalidParameter("slot depth must exceed the neck depth"),
    )
  }
  let min_size = if width_mm < height_mm { width_mm } else { height_mm }
  if slot_depth_mm >= min_size / 2.0 {
    return Err(
      @common.InvalidParameter(
        "slot depth (\{slot_depth_mm}) must be less than half the smaller section size",
      ),
    )
  }
  let limit = min_size - 2.0 * slot_depth_mm - 2.0 * wall_mm
  if core_bore_diameter_mm >= limit {
    return Err(
      @common.InvalidParameter(
        "core bore diameter (\{core_bore_diameter_mm}) leaves no wall; must be below \{limit}",
      ),
    )
  }
  if cavity_width_mm + 2.0 * wall_mm > width_mm ||
    cavity_width_mm + 2.0 * wall_mm > height_mm {
    return Err(
      @common.InvalidParameter(
        "cavity width and wall thickness do not fit the section",
      ),
    )
  }
  let core_min = min_size / 2.0 - slot_depth_mm
  if core_min <= wall_mm / 2.0 {
    return Err(
      @common.InvalidParameter(
        "slot depth and wall thickness leave no corner web between adjacent slots",
      ),
    )
  }
  Ok({
    name,
    width_mm,
    height_mm,
    slot_width_mm,
    slot_neck_depth_mm,
    slot_depth_mm,
    cavity_width_mm,
    core_bore_diameter_mm,
    wall_mm,
  })
}

///|
/// TSlotProfile::generic_2020 returns a generic 20 x 20 T-slot envelope.
pub fn TSlotProfile::generic_2020() -> TSlotProfile {
  {
    name: "generic-2020",
    width_mm: 20.0,
    height_mm: 20.0,
    slot_width_mm: 6.0,
    slot_neck_depth_mm: 2.5,
    slot_depth_mm: 6.0,
    cavity_width_mm: 11.0,
    core_bore_diameter_mm: 4.2,
    wall_mm: 1.8,
  }
}

///|
/// TSlotProfile::generic_2040 returns a generic 20 x 40 T-slot envelope.
pub fn TSlotProfile::generic_2040() -> TSlotProfile {
  { ..TSlotProfile::generic_2020(), name: "generic-2040", height_mm: 40.0, }
}

///|
/// TSlotProfile::generic_3030 returns a generic 30 x 30 T-slot envelope.
pub fn TSlotProfile::generic_3030() -> TSlotProfile {
  {
    name: "generic-3030",
    width_mm: 30.0,
    height_mm: 30.0,
    slot_width_mm: 8.0,
    slot_neck_depth_mm: 3.0,
    slot_depth_mm: 8.0,
    cavity_width_mm: 14.0,
    core_bore_diameter_mm: 6.0,
    wall_mm: 2.0,
  }
}

///|
/// TSlotProfile::generic_4040 returns a generic 40 x 40 T-slot envelope.
pub fn TSlotProfile::generic_4040() -> TSlotProfile {
  {
    name: "generic-4040",
    width_mm: 40.0,
    height_mm: 40.0,
    slot_width_mm: 8.0,
    slot_neck_depth_mm: 3.0,
    slot_depth_mm: 8.0,
    cavity_width_mm: 14.0,
    core_bore_diameter_mm: 6.5,
    wall_mm: 2.5,
  }
}

///|
/// TSlotProfile::designation returns a short label for part names.
pub fn TSlotProfile::designation(self : TSlotProfile) -> String {
  self.name
}

///|
/// slot_taper decides whether the slot cavity must be tapered at the back and,
/// if so, returns the tapered back half-width.
///
/// When a rectangular cavity would reach the core corner and intersect the
/// cavity on the adjacent face, the cavity back is narrowed to leave a solid
/// corner web of half thickness `wall / 2`. Without the taper the outline
/// would be self-intersecting and the exported extrusion would not be a simple
/// solid section.
fn slot_taper(profile : TSlotProfile) -> (Bool, Double) {
  let rect_half = profile.cavity_width_mm / 2.0
  let core_x = profile.width_mm / 2.0 - profile.slot_depth_mm
  let core_y = profile.height_mm / 2.0 - profile.slot_depth_mm
  let web = profile.wall_mm / 2.0
  if rect_half > core_x - web && rect_half > core_y - web {
    let core = if core_x < core_y { core_x } else { core_y }
    (true, core - web)
  } else {
    (false, rect_half)
  }
}

///|
/// side_with_slot returns the boundary points along one side, starting at `a`
/// and including the T-slot, but excluding the far corner `b`.
fn side_with_slot(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  profile : TSlotProfile,
) -> Array[@cad.Vec2] {
  let dx = bx - ax
  let dy = by - ay
  let length = Double::sqrt(dx * dx + dy * dy)
  let ux = dx / length
  let uy = dy / length
  // Left normal: interior for a counter-clockwise boundary.
  let nx = -uy
  let ny = ux
  let w = profile.slot_width_mm
  let cavity = profile.cavity_width_mm
  let neck = profile.slot_neck_depth_mm
  let depth = profile.slot_depth_mm
  let (taper, back_half) = slot_taper(profile)
  let rect_half = cavity / 2.0
  let half = length / 2.0
  let t0 = (length - w) / 2.0
  let t1 = t0 + w
  let slot_points : Array[@cad.Vec2] = []
  slot_points.push((t0, 0.0))
  slot_points.push((t0, neck))
  if taper {
    // Widen to the cavity, then taper the back so the cavity on this face does
    // not run into the cavity on the adjacent face. The remaining corner
    // material is the four characteristic "arrow" quadrants, connected to the
    // central core by a web.
    let shoulder = neck + 0.4 * (depth - neck)
    slot_points.push((half - rect_half, neck))
    slot_points.push((half - rect_half, shoulder))
    slot_points.push((half - back_half, depth))
    slot_points.push((half + back_half, depth))
    slot_points.push((half + rect_half, shoulder))
    slot_points.push((half + rect_half, neck))
  } else {
    slot_points.push((half - rect_half, neck))
    slot_points.push((half - rect_half, depth))
    slot_points.push((half + rect_half, depth))
    slot_points.push((half + rect_half, neck))
  }
  slot_points.push((t1, neck))
  slot_points.push((t1, 0.0))
  let out : Array[@cad.Vec2] = [(ax, ay)]
  for (t, d) in slot_points {
    out.push((ax + ux * t + nx * d, ay + uy * t + ny * d))
  }
  out
}

///|
/// TSlotProfile::outline returns the counter-clockwise outer boundary of the
/// section with one T-slot centred on each of the four faces.
pub fn TSlotProfile::outline(self : TSlotProfile) -> Array[@cad.Vec2] {
  let hw = self.width_mm / 2.0
  let hh = self.height_mm / 2.0
  let points : Array[@cad.Vec2] = []
  points.push_iter(side_with_slot(-hw, -hh, hw, -hh, self).iter())
  points.push_iter(side_with_slot(hw, -hh, hw, hh, self).iter())
  points.push_iter(side_with_slot(hw, hh, -hw, hh, self).iter())
  points.push_iter(side_with_slot(-hw, hh, -hw, -hh, self).iter())
  points
}

///|
/// TSlotProfile::holes returns the central core bore as a clockwise loop.
pub fn TSlotProfile::holes(
  self : TSlotProfile,
  segments~ : Int32 = 48,
) -> Array[Array[@cad.Vec2]] {
  [@cad.Profile2D::circle(self.core_bore_diameter_mm, segments~).rev()]
}

///|
/// TSlotProfile::metadata builds provenance-aware metadata for a cut length.
pub fn TSlotProfile::metadata(
  self : TSlotProfile,
  length_mm : Double,
) -> @common.Metadata {
  @common.Metadata::new(
    designation="Generic T-slot \{self.name} x \{length_mm}",
    standard="Generic T-slot envelope (not a universal standard)",
    family="aluminum extrusion",
    size=self.name,
    length_mm~,
    source="Generic engineering envelope generated by this library; verify slot and core geometry against the intended manufacturer's drawing. See components/DATA_SOURCES.md.",
  )
}

///|
/// extrusion builds a cut-to-length generic T-slot extrusion.
///
/// The section is centred on the XY origin and the length runs along +Z from
/// z = 0. Slot, neck, cavity, and wall dimensions are explicit in the profile.
///
/// This is a generic envelope, not a claim of compatibility with any particular
/// 2020/2040/3030/4040 system.
pub fn extrusion(
  profile : TSlotProfile,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("extrusion length", length_mm) {
    Err(e) => Err(e)
    Ok(_) => {
      let policy = @common.DetailPolicy::for_level(detail)
      let segments = if policy.circle_segments < 24 {
        24
      } else {
        policy.circle_segments
      }
      let outer = profile.outline()
      let holes = profile.holes(segments~)
      let body = @cad.ExtrudedProfile::new(outer, length_mm, holes~)
      let name = "extrusion-\{profile.name}-\{@cad.fmt_double(length_mm, None)}"
      Ok(
        @common.Component::new(
          name~,
          metadata=profile.metadata(length_mm),
          description="Generic T-slot extrusion with four centred slots and a central core bore. Sharp section corners; no end machining.",
        ).add_layer(body, name="body", color=@cad.Rgb::cyan()),
      )
    }
  }
}

///|
/// TSlotProfile::size returns `(width, height)` in millimetres.
pub fn TSlotProfile::size(self : TSlotProfile) -> @cad.Vec2 {
  (self.width_mm, self.height_mm)
}
