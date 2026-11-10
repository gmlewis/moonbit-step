///|
/// fastener_thread_features appends the thread-related feature entries for a
/// component.
///
/// A helical representation is a real swept ridge (modelled) sampled as a
/// polyline (approximated, `SweptSpline`); every other representation omits
/// the thread with a reason instead of pretending a plain cylinder is threaded.
pub fn fastener_thread_features(
  record : @common.FeatureRecord,
  thread_rep : @common.ThreadRepresentation,
  policy : @common.DetailPolicy,
  pitch_radius_mm : Double,
) -> @common.FeatureRecord {
  match thread_rep {
    @common.ThreadRepresentation::Helical =>
      record
      .add_modeled("helical-thread")
      .add_approximated(
        @common.Approximation::new(
          feature="helical-ridge",
          kind=@common.ApproximationKind::SweptSpline,
          deviation_mm=@common.chord_deviation(
            pitch_radius_mm,
            policy.segments_per_turn,
          ),
          control="segments_per_turn=\{policy.segments_per_turn}",
        ),
      )
      .add_omitted(
        @common.Omission::new(
          feature="thread-runout",
          reason="the swept ridge ends at the shank ends; thread runout and lead-in are not modelled",
        ),
      )
    _ =>
      record.add_omitted(
        @common.Omission::new(
          feature="thread",
          reason="no thread geometry at this detail level",
        ),
      )
  }
}

///|
/// polyline_circle_approximation builds an approximation entry for a circular
/// boundary sampled into `segments` chords.
pub fn polyline_circle_approximation(
  feature : String,
  radius_mm : Double,
  segments : Int32,
) -> @common.Approximation {
  @common.Approximation::new(
    feature~,
    kind=@common.ApproximationKind::PolylineArc,
    deviation_mm=@common.chord_deviation(radius_mm, segments),
    control="circle_segments=\{segments}",
  )
}
