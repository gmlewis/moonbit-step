///|
/// hex_nut builds an ISO 4032 hexagon regular nut.
///
/// The nut axis is +Z, its bearing face is `z = 0`, and one pair of flats is
/// normal to the X axis. The bore is a simple cylindrical hole in simplified
/// mode. At `Detailed` and above the body carries the customary chamfer on both
/// bearing faces (a parallel inset of the hexagon, built as a real ruled ring
/// stack). This chamfer is an engineering default derived from the nut size;
/// ISO 4032 does not fix its dimensions. With
/// `ThreadRepresentation::Helical` the body is bored at the major diameter and
/// a swept helical ridge fills the ISO 68-1 internal thread form inward to the
/// minor diameter; the helical body is not chamfered.
pub fn hex_nut(
  spec : @standards.ISO4032Spec,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  color? : @cad.Rgb,
) -> @common.Component {
  let policy = @common.DetailPolicy::for_level(detail)
  let thread_rep = match threads {
    Some(t) => t
    None => policy.threads
  }
  let dims = spec.size_dims
  let thread = dims.thread
  let d = thread.nominal_diameter_mm
  let s = dims.width_across_flats_mm
  let m = dims.height_mm
  let segments = clamp_segments(policy.circle_segments)
  let name = "ISO4032-\{dims.size.designation()}"
  let metal = match color {
    Some(c) => c
    None => @cad.Rgb::purple()
  }
  let accent = @cad.Rgb::cyan()
  let outer = hex_profile_across_flats(s)
  let bore_d = d + 2.0 * spec.clearance_mm
  // The bore is an analytic circular hole, not a sampled polygon.
  let round_bore = ((0.0, 0.0), bore_d)
  let features = nut_feature_record(
    policy, thread_rep, thread, bore_d, s, segments,
  )
  let base = @common.Component::new(
    name~,
    metadata=spec.metadata(),
    description="Hexagon regular nut with a through bore." +
      nut_chamfer_note(policy) +
      thread_note(thread_rep),
    features~,
  )
  if thread_rep is @common.ThreadRepresentation::Helical {
    let body = if policy.include_small_features {
      let c = nut_chamfer_mm(s, m)
      @cad.ChamferedPrism::new(
        outer,
        [(0.0, c), (c, 0.0), (m - c, 0.0), (m, c)],
        round_bore~,
      ).as_shape()
    } else {
      @cad.ChamferedPrism::new(outer, [(0.0, 0.0), (m, 0.0)], round_bore~).as_shape()
    }
    let mut component = base.add_layer(body, name="body", color=metal)
    match
      internal_thread_ridge(
        thread,
        m,
        segments_per_turn=policy.segments_per_turn,
        radial_offset_mm=spec.clearance_mm,
      ) {
      Some(shape) =>
        component = component.add_layer(
          shape,
          name="helical-thread",
          color=accent,
        )
      None => ()
    }
    component
  } else if policy.include_small_features {
    // A real conical washer face on each bearing face: 75 degrees for the small
    // sizes and 60 degrees for M3 and above, with the reference bore lead-in
    // (0.2 mm through M5, 0.5 mm from M6; none for M2/M2.5). These angles and
    // lead-ins come from the detailed reference family and are recorded as
    // engineering defaults, not ISO dimensions.
    let face_angle = match dims.size {
      @standards.MetricSize::M2 | @standards.MetricSize::M2_5 => 75.0
      _ => 60.0
    }
    let lead = match dims.size {
      @standards.MetricSize::M2 | @standards.MetricSize::M2_5 => 0.0
      @standards.MetricSize::M6 | @standards.MetricSize::M8 => 0.5
      _ => 0.2
    }
    let body = @cad.ConicalNut::new(
      across_flats_mm=s,
      height_mm=m,
      bore_diameter_mm=bore_d,
      face_angle_deg=face_angle,
      lead_in_mm=lead,
      // Reference clocking (not a standard dimension): M2/M2.5 and M4 put a
      // hexagon corner on +X (flat at +Y, matching the M4 reference's top
      // view), the other M3+ references put a flat on +X (corner at +Y).
      rotation_deg=if dims.size is @standards.MetricSize::M2 ||
        dims.size is @standards.MetricSize::M2_5 ||
        dims.size is @standards.MetricSize::M4 {
        0.0
      } else {
        30.0
      },
    ).as_shape()
    base.add_layer(body, name="body", color=metal)
  } else {
    let body = @cad.ChamferedPrism::new(
      outer,
      [(0.0, 0.0), (m, 0.0)],
      round_bore~,
    ).as_shape()
    base.add_layer(body, name="body", color=metal)
  }
}

///|
/// nut_chamfer_mm returns the engineering-default face-chamfer inset for an
/// ISO 4032 nut. The standard does not fix the chamfer; this keeps it visible
/// and below a third of the nut height.
fn nut_chamfer_mm(s : Double, m : Double) -> Double {
  let by_width = 0.1 * s
  let by_height = m / 3.0
  if by_width < by_height {
    by_width
  } else {
    by_height
  }
}

///|
fn nut_chamfer_note(policy : @common.DetailPolicy) -> String {
  if policy.include_small_features {
    " Both bearing faces carry a true conical washer face (75 degrees for M2/M2.5, 60 degrees for M3 and above) trimmed by the six flats, plus the reference bore lead-in; these are engineering defaults, not ISO dimensions."
  } else {
    " Face chamfers are omitted in this detail level."
  }
}

///|
/// nut_feature_record builds the machine-readable feature record for an ISO
/// 4032 hexagon regular nut.
fn nut_chamfer_deviation_mm(across_flats : Double) -> Double {
  across_flats * (1.0 / @math.cos(@math.PI / 6.0) - 1.0)
}

///|
fn nut_feature_record(
  policy : @common.DetailPolicy,
  thread_rep : @common.ThreadRepresentation,
  thread : @standards.ThreadSpec,
  bore_d : Double,
  across_flats : Double,
  segments : Int32,
) -> @common.FeatureRecord {
  let _ = bore_d
  let _ = segments
  let base = @common.FeatureRecord::new(
    modeled=["hex-body", "through-bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="bore-edge-chamfer",
        reason="not modelled by this builder",
      ),
      @common.Omission::new(
        feature="thread-runout",
        reason="not modelled by this builder",
      ),
    ],
  )
  let with_chamfer = if policy.include_small_features {
    if thread_rep is @common.ThreadRepresentation::Helical {
      // The helical body is still the ruled parallel-inset prism so the swept
      // ridge stays on a simple envelope.
      base
      .add_modeled("nut-face-chamfer")
      .add_approximated(
        @common.Approximation::new(
          feature="nut-face-chamfer-band",
          kind=@common.ApproximationKind::PolygonRevolve,
          deviation_mm=nut_chamfer_deviation_mm(across_flats),
          control="parallel-inset hexagon ruled chamfer on the helical body; the detailed body carries a true conical washer face",
        ),
      )
    } else {
      base.add_modeled("nut-face-chamfer")
    }
  } else {
    base.add_omitted(
      @common.Omission::new(
        feature="nut-face-chamfer",
        reason="omitted at Simplified detail level",
      ),
    )
  }
  fastener_thread_features(
    with_chamfer,
    thread_rep,
    policy,
    thread.pitch_diameter_mm() / 2.0,
  )
}

///|
/// iso4032_nut validates a request and builds the component.
pub fn iso4032_nut(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Simplified,
  threads? : @common.ThreadRepresentation,
  clearance_mm~ : Double = 0.0,
) -> Result[@common.Component, @common.SpecError] {
  match @standards.iso4032_spec(size, clearance_mm~) {
    Err(e) => Err(e)
    Ok(spec) => {
      let component = match threads {
        Some(t) => hex_nut(spec, detail~, threads=t)
        None => hex_nut(spec, detail~)
      }
      Ok(component)
    }
  }
}

///|
/// iso4035_nut builds an ISO 4035 thin hexagon nut.
///
/// The nut axis is +Z with the bearing face at z = 0 and a corner on +X. The
/// body is a `ConicalNut` with a 75-degree washer face on both ends and a
/// straight through bore; the 75-degree angle is the value used by the thin-nut
/// reference family (ISO 4035 does not fix the washer face).
pub fn iso4035_nut(
  size : @standards.MetricSize,
  detail~ : @common.DetailLevel = Detailed,
  clearance_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @standards.iso4035_spec(size, clearance_mm~) {
    Err(e) => Err(e)
    Ok(spec) => {
      let dims = spec.size_dims
      let d = dims.thread.nominal_diameter_mm
      let bore_d = d + 2.0 * spec.clearance_mm
      let body = @cad.ConicalNut::new(
        across_flats_mm=dims.width_across_flats_mm,
        height_mm=dims.height_mm,
        bore_diameter_mm=bore_d,
        face_angle_deg=75.0,
        lead_in_mm=0.0,
        rotation_deg=0.0,
      ).as_shape()
      let features = @common.FeatureRecord::new(
        modeled=["hex-body", "conical-washer-faces", "through-bore"],
        approximated=[
          @common.Approximation::new(
            feature="washer-face-angle",
            kind=@common.ApproximationKind::EngineeringDefault,
            deviation_mm=0.0,
            control="75-degree conical washer face on both ends, taken from the thin-nut reference family; ISO 4035 does not fix it",
          ),
        ],
        omitted=[
          @common.Omission::new(
            feature="thread",
            reason="the bore is the nominal thread envelope; the internal thread form is not modeled",
          ),
          @common.Omission::new(
            feature="corner-break",
            reason="the reference family rounds each vertical corner by about 0.001 mm; the model keeps sharp corners",
          ),
        ],
      )
      Ok(
        @common.Component::new(
          name="ISO4035-\{size.designation()}",
          metadata=spec.metadata(),
          description="Thin hexagon nut: one closed solid with a hexagon body, a 75-degree conical washer face on each end, and a circular through bore.",
          features~,
        ).add_layer(body, name="body", color~),
      )
    }
  }
}
