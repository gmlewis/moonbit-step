///|
/// DetailLevel selects how much mechanically relevant detail a component
/// carries.
///
/// The level is a request, not a promise: a family documents exactly which
/// features exist at each level. In particular, `Simplified` must never be
/// described as having real threads.
pub(all) enum DetailLevel {
  /// Lightweight assembly representation: major envelopes and bores, no
  /// cosmetic or helical thread geometry.
  Simplified
  /// Accurate head/body dimensions, recesses, bores, and other features the
  /// kernel can model without a trim kernel.
  Detailed
  /// Everything `Detailed` provides plus resolved helical threads or other
  /// swept detail geometry.
  FullyModeled
}

///|
/// ThreadRepresentation states exactly how a component's threads are modeled.
///
/// Keeping this explicit prevents a cosmetic cylinder from being mistaken for a
/// real helical thread in a downstream BOM or drawing.
pub(all) enum ThreadRepresentation {
  /// No thread geometry: a plain cylindrical shank or bore.
  None
  /// A visually suggestive feature (for example a relief groove). Never a real
  /// thread. Current builders do not emit cosmetic thread geometry; they treat
  /// this mode as `None` and state that in the component description.
  Cosmetic
  /// A swept helical ridge with the standard pitch and basic profile.
  Helical
}

///|
/// DetailPolicy is the resolved interpretation of a `DetailLevel` for one
/// component family.
pub(all) struct DetailPolicy {
  level : DetailLevel
  threads : ThreadRepresentation
  /// Segments per full turn for swept detail geometry.
  segments_per_turn : Int32
  /// Circular resolution for bores and envelopes.
  circle_segments : Int32
  /// Include small chamfers, recesses, and reliefs where the kernel supports
  /// them.
  include_small_features : Bool
}

///|
/// DetailPolicy::for_level returns the default policy for a detail level.
pub fn DetailPolicy::for_level(level : DetailLevel) -> DetailPolicy {
  match level {
    Simplified =>
      {
        level,
        threads: ThreadRepresentation::None,
        segments_per_turn: 24,
        circle_segments: 48,
        include_small_features: false,
      }
    Detailed =>
      {
        level,
        threads: ThreadRepresentation::None,
        segments_per_turn: 32,
        circle_segments: 64,
        include_small_features: true,
      }
    FullyModeled =>
      {
        level,
        threads: ThreadRepresentation::Helical,
        segments_per_turn: 24,
        circle_segments: 64,
        include_small_features: true,
      }
  }
}

///|
/// DetailPolicy::with_threads overrides the thread representation while
/// keeping the rest of the detail policy.
pub fn DetailPolicy::with_threads(
  self : DetailPolicy,
  threads : ThreadRepresentation,
) -> DetailPolicy {
  { ..self, threads, }
}
