///|
/// tapped_boss builds a flanged boss with a real blind bore and a declared
/// internal thread.
///
/// Frame: the boss axis is +Z, the flange sits on `z = 0`, and the body runs to
/// `z = body_height`. The blind bore is the ISO metric internal minor diameter
/// of the declared thread, with an optional counterbore at the top face. The
/// thread itself is connector metadata and is never modelled.
///
/// The blind bore opens at +Z. No pull-out, torque, or boss-strength rating is
/// claimed.
pub fn tapped_boss(
  body_diameter_mm : Double,
  body_height_mm : Double,
  flange_diameter_mm : Double,
  flange_thickness_mm : Double,
  thread_diameter_mm : Double,
  thread_pitch_mm : Double,
  thread_depth_mm : Double,
  counterbore_diameter_mm~ : Double = 0.0,
  counterbore_depth_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("tapped boss body diameter", body_diameter_mm),
      ("tapped boss body height", body_height_mm),
      ("tapped boss flange diameter", flange_diameter_mm),
      ("tapped boss flange thickness", flange_thickness_mm),
      ("tapped boss thread diameter", thread_diameter_mm),
      ("tapped boss thread pitch", thread_pitch_mm),
      ("tapped boss thread depth", thread_depth_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    mechanism_non_negative_checks([
      ("tapped boss counterbore diameter", counterbore_diameter_mm),
      ("tapped boss counterbore depth", counterbore_depth_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if flange_diameter_mm <= body_diameter_mm {
    return Err(
      @common.InvalidDimension(
        "boss flange diameter must exceed the boss body diameter",
      ),
    )
  }
  if flange_thickness_mm >= body_height_mm {
    return Err(
      @common.InvalidDimension(
        "boss flange thickness must be smaller than its height",
      ),
    )
  }
  let bore_radius = (thread_diameter_mm - 1.082532 * thread_pitch_mm) / 2.0
  if bore_radius <= 0.0 {
    return Err(
      @common.InvalidDimension(
        "declared thread leaves a non-positive boss bore",
      ),
    )
  }
  let body_radius = body_diameter_mm / 2.0
  let flange_radius = flange_diameter_mm / 2.0
  let has_counterbore = counterbore_diameter_mm > 0.0
  if has_counterbore {
    if counterbore_depth_mm <= 0.0 {
      return Err(
        @common.InvalidParameter("boss counterbore needs a positive depth"),
      )
    }
    if counterbore_diameter_mm <= thread_diameter_mm {
      return Err(
        @common.InvalidDimension(
          "boss counterbore diameter must exceed the thread diameter",
        ),
      )
    }
    if counterbore_diameter_mm / 2.0 >= body_radius {
      return Err(
        @common.InvalidDimension("boss counterbore does not fit the boss body"),
      )
    }
    if counterbore_depth_mm + thread_depth_mm >=
      body_height_mm - flange_thickness_mm {
      return Err(
        @common.InvalidDimension(
          "boss counterbore and thread depth exceed the available body height",
        ),
      )
    }
  } else {
    if counterbore_depth_mm != 0.0 {
      return Err(
        @common.InvalidParameter(
          "boss counterbore depth must be zero when the counterbore diameter is zero",
        ),
      )
    }
    if thread_depth_mm >= body_height_mm - flange_thickness_mm {
      return Err(
        @common.InvalidDimension(
          "boss thread depth exceeds the available body height",
        ),
      )
    }
  }
  let top = body_height_mm
  let cb_radius = if has_counterbore {
    counterbore_diameter_mm / 2.0
  } else {
    bore_radius
  }
  let cb_floor = top -
    (if has_counterbore { counterbore_depth_mm } else { 0.0 })
  let bore_floor = cb_floor - thread_depth_mm
  if bore_floor <= flange_thickness_mm {
    return Err(
      @common.InvalidDimension(
        "boss blind bore does not leave material above the flange",
      ),
    )
  }
  let profile : Array[@cad.RevSegment] = [
    @cad.RevLine((0.0, 0.0), (flange_radius, 0.0)),
    @cad.RevLine((flange_radius, 0.0), (flange_radius, flange_thickness_mm)),
    @cad.RevLine(
      (flange_radius, flange_thickness_mm),
      (body_radius, flange_thickness_mm),
    ),
    @cad.RevLine((body_radius, flange_thickness_mm), (body_radius, top)),
    @cad.RevLine((body_radius, top), (cb_radius, top)),
  ]
  if has_counterbore {
    profile.push(@cad.RevLine((cb_radius, top), (cb_radius, cb_floor)))
    profile.push(@cad.RevLine((cb_radius, cb_floor), (bore_radius, cb_floor)))
  }
  profile.push(@cad.RevLine((bore_radius, cb_floor), (bore_radius, bore_floor)))
  profile.push(@cad.RevLine((bore_radius, bore_floor), (0.0, bore_floor)))
  let body = @cad.RevolvedProfile::new(profile)
  let modeled : Array[String] = ["boss-body", "flange", "blind-bore"]
  if has_counterbore {
    modeled.push("counterbore")
  }
  let name = "tapped-boss-\{@cad.fmt_double(body_diameter_mm, None)}x\{@cad.fmt_double(body_height_mm, None)}"
  let mut out = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Tapped boss \{@cad.fmt_double(thread_diameter_mm, None)} x \{@cad.fmt_double(thread_pitch_mm, None)}",
      family="tapped boss (engineering envelope)",
      size="\{@cad.fmt_double(thread_diameter_mm, None)}x\{@cad.fmt_double(thread_pitch_mm, None)}",
      length_mm=body_height_mm,
      source="Parametric flanged boss with a real blind minor-diameter bore and a declared thread. No standard or strength rating is implied.",
    ),
    description="Flanged boss with a real blind bore at the thread minor diameter and an optional counterbore. The thread is connector metadata.",
    features=@common.FeatureRecord::new(modeled~, approximated=[], omitted=[
      @common.Omission::new(
        feature="thread",
        reason="declared by the `thread` connector and never modelled",
      ),
      @common.Omission::new(
        feature="knurl-or-anti-rotation-feature",
        reason="no anti-rotation or insert-retention feature is modelled",
      ),
      @common.Omission::new(
        feature="pull-out-and-torque-strength",
        reason="no insert retention, torque, or strength rating is implied",
      ),
    ]),
  ).add_layer(body.as_shape(), name="body", color~)
  out = out
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=@common.Placement::translation(0.0, 0.0, top),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=thread_diameter_mm,
        depth_mm=thread_depth_mm,
        description="declared internal thread; entered from the top face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          if has_counterbore {
            cb_floor
          } else {
            top
          },
        ),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * bore_radius,
        depth_mm=thread_depth_mm,
        description="modelled blind minor-diameter bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "top-face",
        placement=@common.Placement::translation(0.0, 0.0, top),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=body_diameter_mm,
        description="boss top face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bottom-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=flange_diameter_mm,
        description="flange mounting face",
      ),
    )
  if has_counterbore {
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "counterbore",
        placement=@common.Placement::translation(0.0, 0.0, top),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=counterbore_diameter_mm,
        depth_mm=counterbore_depth_mm,
        description="counterbore at the top face",
      ),
    )
  }
  Ok(out)
}
