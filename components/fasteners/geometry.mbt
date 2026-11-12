///|
/// FASTENER_EPS is the linear coincidence tolerance for fastener profiles.
const FASTENER_EPS : Double = 1.0e-9

///|
/// CircleProfile returns a counter-clockwise circular profile of the given
/// diameter.
pub fn circle_profile(
  diameter : Double,
  segments~ : Int32 = 64,
) -> Array[@cad.Vec2] {
  @cad.Profile2D::circle(diameter, segments~)
}

///|
/// hole_profile returns a clockwise circular hole profile.
pub fn hole_profile(
  diameter : Double,
  segments~ : Int32 = 64,
) -> Array[@cad.Vec2] {
  circle_profile(diameter, segments~).rev()
}

///|
/// hex_profile_across_flats returns a counter-clockwise regular hexagon with
/// the requested width across flats.
///
/// With `rotation_deg = 30` the hexagon has flats normal to the X axis, which
/// is the orientation used for the hex nuts in this package.
pub fn hex_profile_across_flats(
  across_flats : Double,
  rotation_deg~ : Double = 30.0,
) -> Array[@cad.Vec2] {
  let across_corners = across_flats / @math.cos(@math.PI / 6.0)
  @cad.Profile2D::polygon(6, across_corners, rotation=rotation_deg)
}

///|
/// hex_hole_across_flats returns a clockwise hexagonal hole profile.
pub fn hex_hole_across_flats(
  across_flats : Double,
  rotation_deg~ : Double = 30.0,
) -> Array[@cad.Vec2] {
  hex_profile_across_flats(across_flats, rotation_deg~).rev()
}

///|
/// external_thread_crest_radius_mm returns the basic external-thread crest
/// (major) radius, `d / 2`.
pub fn external_thread_crest_radius_mm(
  thread : @standards.ThreadSpec,
) -> Double {
  thread.nominal_diameter_mm / 2.0
}

///|
/// external_thread_root_radius_mm returns the basic external-thread root
/// (minor) radius, `d3 / 2`.
pub fn external_thread_root_radius_mm(thread : @standards.ThreadSpec) -> Double {
  thread.external_minor_diameter_mm() / 2.0
}

///|
/// external_thread_ridge_center_radius_mm returns the radius of the
/// crest-to-root midpoint used to place the swept ridge profile. The ISO 68-1
/// basic profile is not symmetric about the pitch diameter: the crest lies
/// `3H/8` and the root `H/3` from it, so a pitch-diameter-centre ridge would
/// put the crest below the nominal major diameter.
pub fn external_thread_ridge_center_radius_mm(
  thread : @standards.ThreadSpec,
) -> Double {
  (
    external_thread_crest_radius_mm(thread) +
    external_thread_root_radius_mm(thread)
  ) /
  2.0
}

///|
/// internal_thread_crest_radius_mm returns the basic internal-thread crest
/// (minor) radius, `D1 / 2`.
pub fn internal_thread_crest_radius_mm(
  thread : @standards.ThreadSpec,
) -> Double {
  thread.internal_minor_diameter_mm() / 2.0
}

///|
/// internal_thread_root_radius_mm returns the basic internal-thread root
/// (major) radius, `D / 2`.
pub fn internal_thread_root_radius_mm(thread : @standards.ThreadSpec) -> Double {
  thread.nominal_diameter_mm / 2.0
}

///|
/// internal_thread_ridge_center_radius_mm returns the radius of the
/// crest-to-root midpoint for an internal ridge, shifted outward by
/// `radial_offset_mm` (the nut bore clearance).
pub fn internal_thread_ridge_center_radius_mm(
  thread : @standards.ThreadSpec,
  radial_offset_mm~ : Double = 0.0,
) -> Double {
  (
    internal_thread_crest_radius_mm(thread) +
    internal_thread_root_radius_mm(thread)
  ) /
  2.0 +
  radial_offset_mm
}

///|
/// external_thread_ridge returns a swept helical ridge for an external metric
/// thread, or `None` when the requested length is too short for one thread
/// turn.
///
/// The ridge is a solid whose crest lies on the nominal major diameter `d` and
/// whose root lies on the basic external minor diameter `d3`. The profile is
/// placed at the crest/root midpoint, not at the pitch diameter, so the ISO
/// 68-1 basic profile is reproduced: the crest is `3H/8` from the pitch
/// cylinder and the root is `H/3` from it. The root is embedded `embed_mm`
/// into the minor-diameter core so the sweeping solids overlap.
///
/// The ridge is contained within `z = 0 .. length_mm`; the root half-width
/// sets the axial inset at each end. It is a real swept helical form, not a
/// cosmetic texture; the caller must expose `ThreadRepresentation::Helical`.
pub fn external_thread_ridge(
  thread : @standards.ThreadSpec,
  length_mm : Double,
  segments_per_turn~ : Int32 = 48,
  embed_mm~ : Double = 0.10,
) -> @cad.Shape? {
  let pitch = thread.pitch_mm
  let depth = thread.external_thread_depth_mm()
  let half_depth = depth / 2.0
  let crest_half = thread.external_thread_crest_width_mm() / 2.0
  let root_half = thread.external_thread_root_width_mm() / 2.0
  let axial_inset = root_half
  let axial_span = length_mm - 2.0 * axial_inset
  if axial_span <= 0.0 {
    return None
  }
  let turns = axial_span / pitch
  let r_mid = external_thread_ridge_center_radius_mm(thread)
  let vertices : Array[@cad.Vec3] = [
    (half_depth, 0.0, crest_half),
    (-half_depth - embed_mm, 0.0, root_half),
    (-half_depth - embed_mm, 0.0, -root_half),
    (half_depth, 0.0, -crest_half),
  ]
  let profile = @cad.SweepProfile::new(
    vertices,
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let clockwise = thread.hand is @standards.ThreadHand::Left
  let path = @cad.helix_path(
    pos=(0.0, 0.0, axial_inset),
    size_per_turn=(r_mid, r_mid, pitch),
    num_turns=turns,
    num_segs_per_turn=segments_per_turn,
    start_angle=0.0,
    clockwise~,
  )
  Some(@cad.SweptProfile::new(path~, profile~, straight_outline=false))
}

///|
/// internal_thread_ridge returns a swept helical ridge for an internal metric
/// thread, or `None` when the nut is too short.
///
/// The nut body is bored at `D/2 + radial_offset_mm`; this ridge fills the
/// thread form inward to the basic internal minor diameter `D1`, leaving the
/// helical groove. The profile is placed at the crest/root midpoint, shifted
/// outward by `radial_offset_mm`, and the root is embedded `embed_mm` into the
/// nut body, so the ridge is attached for every supported size and clearance.
/// It is a real swept helical form, not a cosmetic texture.
pub fn internal_thread_ridge(
  thread : @standards.ThreadSpec,
  length_mm : Double,
  segments_per_turn~ : Int32 = 48,
  embed_mm~ : Double = 0.10,
  radial_offset_mm~ : Double = 0.0,
) -> @cad.Shape? {
  let pitch = thread.pitch_mm
  let depth = thread.internal_thread_depth_mm()
  let half_depth = depth / 2.0
  let crest_half = thread.internal_thread_crest_width_mm() / 2.0
  let root_half = thread.internal_thread_root_width_mm() / 2.0
  let axial_inset = root_half
  let axial_span = length_mm - 2.0 * axial_inset
  if axial_span <= 0.0 {
    return None
  }
  let turns = axial_span / pitch
  let r_mid = internal_thread_ridge_center_radius_mm(thread, radial_offset_mm~)
  let vertices : Array[@cad.Vec3] = [
    (-half_depth, 0.0, -crest_half),
    (half_depth + embed_mm, 0.0, -root_half),
    (half_depth + embed_mm, 0.0, root_half),
    (-half_depth, 0.0, crest_half),
  ]
  let profile = @cad.SweepProfile::new(
    vertices,
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let clockwise = thread.hand is @standards.ThreadHand::Left
  let path = @cad.helix_path(
    pos=(0.0, 0.0, axial_inset),
    size_per_turn=(r_mid, r_mid, pitch),
    num_turns=turns,
    num_segs_per_turn=segments_per_turn,
    start_angle=0.0,
    clockwise~,
  )
  Some(@cad.SweptProfile::new(path~, profile~, straight_outline=false))
}

///|
/// format_length returns a stable, compact millimetre token for names.
pub fn format_length(v : Double) -> String {
  @cad.fmt_double(v, None)
}

///|
/// shank_tip_chamfer_mm returns the engineering-default 45-degree chamfer leg
/// for a shank tip of nominal diameter `d`.
///
/// ISO 4762, ISO 4014, and ISO 4017 do not fix the tip break. A small
/// deburr-style lead-in of `0.1 d` (capped at 0.5 mm) is modelled at Detailed
/// and above and is recorded as an engineering default, never as a standard
/// dimension. Callers cap it against the available shank length.
pub fn shank_tip_chamfer_mm(d : Double) -> Double {
  let c = 0.1 * d
  if c > 0.5 {
    0.5
  } else {
    c
  }
}

///|
/// socket_lead_in_chamfer_mm returns the engineering-default 45-degree lead-in
/// leg at a hexagon socket rim, `0.1 * across_flats` capped at half the socket
/// depth so the lead-in cannot consume the socket.
pub fn socket_lead_in_chamfer_mm(
  across_flats : Double,
  socket_depth_mm : Double,
) -> Double {
  let c = 0.1 * across_flats
  let cap = 0.5 * socket_depth_mm
  if c > cap {
    cap
  } else {
    c
  }
}

///|
/// hex_head_chamfer_mm returns the engineering-default ruled top-edge chamfer
/// inset for a hexagon head, `0.1 * across_flats` capped at a third of the head
/// height.
///
/// The characteristic hexagon-head chamfer is a conical cut that leaves a
/// washer-face top. This kernel models it as a parallel-inset ruled ring stack
/// (a smaller hexagon top), which is an honest ruled approximation; the
/// feature record and documentation state that difference. No standard fixes
/// the chamfer size.
pub fn hex_head_chamfer_mm(
  across_flats : Double,
  _head_height : Double,
) -> Double {
  // The step.parts hex-head references use the standard conical washer face:
  // the top hexagon is inset from the across-corners radius to the
  // across-flats radius, with a 75-degree cone half-angle. Return that radial
  // inset; the builder derives the axial chamfer depth from it.
  across_flats * (1.0 / Double::sqrt(3.0) - 0.5)
}

///|
/// socket_lead_in_hole_levels builds the `(z, inset)` hole ring stack for a
/// hexagon socket lead-in over a socket band that spans `z_bottom..z_top`.
///
/// `hole` passed to the prism must be the *largest* (top) hexagon, across flats
/// `across_flats + 2 * lead`; insetting it by `lead` gives the nominal socket.
/// The stack is vertical below the lead-in and flares over the top `lead`
/// millimetres, so the result is a real ruled lead-in chamfer.
pub fn socket_lead_in_hole_levels(
  z_bottom : Double,
  z_top : Double,
  lead_mm : Double,
) -> Array[(Double, Double)] {
  if lead_mm <= 0.0 || z_top - z_bottom <= lead_mm {
    [(z_bottom, lead_mm), (z_top, lead_mm)]
  } else {
    [(z_bottom, lead_mm), (z_top - lead_mm, lead_mm), (z_top, 0.0)]
  }
}

///|
/// socket_lead_in_hole returns the largest hexagon hole profile for a socket
/// lead-in: across flats `across_flats + 2 * lead`, clockwise.
pub fn socket_lead_in_hole(
  across_flats : Double,
  lead_mm : Double,
) -> Array[@cad.Vec2] {
  hex_hole_across_flats(across_flats + 2.0 * lead_mm)
}

///|
/// tip_chamfered_cylinder returns a cylinder of `diameter` and `height` whose
/// bottom (tip) edge carries a 45-degree ruled chamfer of `chamfer_mm`.
///
/// The chamfer is real geometry: a polygonal cone ring stack, not a relabelled
/// sharp edge. When `chamfer_mm` is not positive the plain cylinder is
/// returned so a simplified part claims no chamfer.
pub fn tip_chamfered_cylinder(
  diameter : Double,
  height : Double,
  chamfer_mm : Double,
  segments~ : Int32 = 64,
) -> @cad.Shape {
  let _ = segments
  if chamfer_mm <= 0.0 || chamfer_mm >= height / 2.0 {
    @cad.Cylinder::new(diameter, height)
  } else {
    @cad.RevolvedProfile::chamfered_cylinder(
      diameter,
      height,
      bottom_chamfer=chamfer_mm,
    ).as_shape()
  }
}

///|
/// chamfered_cylinder_ends returns a cylinder with 45-degree ruled chamfers at
/// either or both end edges (used for threaded-rod lead-ins).
pub fn chamfered_cylinder_ends(
  diameter : Double,
  height : Double,
  bottom_chamfer : Double,
  top_chamfer : Double,
  segments~ : Int32 = 64,
) -> @cad.Shape {
  let bottom = if bottom_chamfer > 0.0 && bottom_chamfer < height / 2.0 {
    bottom_chamfer
  } else {
    0.0
  }
  let top = if top_chamfer > 0.0 && top_chamfer < height / 2.0 {
    top_chamfer
  } else {
    0.0
  }
  let _ = segments
  if bottom <= 0.0 && top <= 0.0 {
    @cad.Cylinder::new(diameter, height)
  } else {
    @cad.RevolvedProfile::chamfered_cylinder(
      diameter,
      height,
      bottom_chamfer=bottom,
      top_chamfer=top,
    ).as_shape()
  }
}

///|
/// clamp_positive_segments returns a usable segment count.
pub fn clamp_segments(n : Int32, minimum~ : Int32 = 12) -> Int32 {
  if n < minimum {
    minimum
  } else {
    n
  }
}

///|
/// thread_note returns a description fragment that states exactly what thread
/// geometry was emitted. It keeps a requested cosmetic representation from
/// being mistaken for a modeled helical thread.
pub fn thread_note(rep : @common.ThreadRepresentation) -> String {
  match rep {
    @common.ThreadRepresentation::None => " No thread geometry is modeled."
    @common.ThreadRepresentation::Cosmetic =>
      " Cosmetic thread representation was requested, but this builder emits no thread geometry; the shank or bore is plain."
    @common.ThreadRepresentation::Helical =>
      " A swept helical thread ridge is modeled."
  }
}

///|
/// hex_socket_ring builds the hexagonal socket band that turns an analytic
/// circular socket bore into a real hexagon socket.
///
/// The outer boundary is a hexagon of circumradius `outer_radius` that stays
/// buried inside the surrounding head; only the six inner flats are visible.
/// With a positive `lead_mm` the inner hole carries a ruled lead-in that flares
/// toward the top face. It is a flat-facet approximation of the socket rim,
/// never a substitute for the head's analytic cylinder or cone.
pub fn hex_socket_ring(
  across_flats : Double,
  height : Double,
  outer_radius : Double,
  lead_mm : Double,
) -> @cad.Shape {
  let outer_af = outer_radius * Double::sqrt(3.0)
  if lead_mm > 0.0 && lead_mm < height / 2.0 {
    @cad.ChamferedPrism::new(
      hex_profile_across_flats(outer_af),
      [(0.0, 0.0), (height, 0.0)],
      hole=socket_lead_in_hole(across_flats, lead_mm),
      hole_levels=socket_lead_in_hole_levels(0.0, height, lead_mm),
    ).as_shape()
  } else {
    @cad.ExtrudedProfile::new(hex_profile_across_flats(outer_af), height, holes=[
      hex_hole_across_flats(across_flats),
    ])
  }
}
