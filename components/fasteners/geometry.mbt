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
