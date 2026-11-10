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
/// external_thread_ridge returns a swept helical ridge for an external metric
/// thread, or `None` when the requested length is too short for at least one
/// complete thread turn.
///
/// The ridge is a solid whose crest lies on the nominal major diameter and
/// whose root is embedded `embed_mm` into the minor-diameter core. It is a
/// real swept helical form, not a cosmetic texture; the caller must expose
/// `ThreadRepresentation::Helical` for it.
pub fn external_thread_ridge(
  thread : @standards.ThreadSpec,
  length_mm : Double,
  segments_per_turn~ : Int32 = 48,
  embed_mm~ : Double = 0.10,
) -> @cad.Shape? {
  let pitch = thread.pitch_mm
  if length_mm <= pitch {
    return None
  }
  let turns = (length_mm - pitch) / pitch
  let depth = thread.external_thread_depth_mm()
  let half_depth = depth / 2.0
  let crest_half = thread.crest_flat_mm() / 2.0
  let root_half = thread.root_flat_mm() / 2.0
  let r_mid = thread.pitch_diameter_mm() / 2.0
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
    pos=(0.0, 0.0, pitch / 2.0),
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
/// The nut body is bored at the major diameter; this ridge fills the thread
/// form inward to the minor diameter, leaving the helical groove. The ridge is
/// a real swept helical form.
pub fn internal_thread_ridge(
  thread : @standards.ThreadSpec,
  length_mm : Double,
  segments_per_turn~ : Int32 = 48,
  embed_mm~ : Double = 0.10,
) -> @cad.Shape? {
  let pitch = thread.pitch_mm
  if length_mm <= pitch {
    return None
  }
  let turns = (length_mm - pitch) / pitch
  let depth = thread.internal_thread_depth_mm()
  let half_depth = depth / 2.0
  let crest_half = 0.125 * pitch
  let root_half = 0.4375 * pitch
  let r_mid = thread.pitch_diameter_mm() / 2.0
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
    pos=(0.0, 0.0, pitch / 2.0),
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
