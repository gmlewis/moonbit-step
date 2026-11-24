///|
/// HiwinRailSpec is the measured cross-section and mounting pattern of one
/// Hiwin HGR linear-guideway rail size.
pub(all) struct HiwinRailSpec {
  size : String
  width_mm : Double
  height_mm : Double
  pitch_mm : Double
  end_margin_mm : Double
  counterbore_diameter_mm : Double
  counterbore_depth_mm : Double
  hole_diameter_mm : Double
  thread : String
}

///|
/// hiwin_rail_spec returns the catalogue data for an HGR rail size.
///
/// Sources: Hiwin HGR15/HGR20 catalogue dimension tables (W x H, hole pitch P,
/// end distance E, counterbore and through-hole diameters).
pub fn hiwin_rail_spec(
  size : String,
) -> Result[HiwinRailSpec, @common.SpecError] {
  match size {
    "HGR15" =>
      Ok({
        size: "HGR15",
        width_mm: 15.0,
        height_mm: 15.0,
        pitch_mm: 60.0,
        end_margin_mm: 20.0,
        counterbore_diameter_mm: 7.5,
        counterbore_depth_mm: 5.3,
        hole_diameter_mm: 4.5,
        thread: "M4",
      })
    "HGR20" =>
      Ok({
        size: "HGR20",
        width_mm: 20.0,
        height_mm: 17.5,
        pitch_mm: 60.0,
        end_margin_mm: 20.0,
        counterbore_diameter_mm: 9.5,
        counterbore_depth_mm: 8.5,
        hole_diameter_mm: 6.0,
        thread: "M5",
      })
    _ =>
      Err(
        @common.InvalidParameter(
          "unknown Hiwin rail size (expected HGR15 or HGR20)",
        ),
      )
  }
}

///|
/// hiwin_hgr_rail builds a Hiwin HGR rail as a closed B-rep: a rectangular
/// section with real counterbored mounting holes along the centre line.
///
/// Frame: the rail runs from `x = 0` to `x = length_mm`, its width is centred on
/// `y = 0`, and its base and top faces are at `z = 0` and `z = height_mm`. Each
/// hole is a counterbore of `counterbore_diameter_mm` through the top
/// `counterbore_depth_mm` layer and a through hole of `hole_diameter_mm` in the
/// remaining base layer. Both layers are analytic extrusions with real profile
/// holes; the component's evaluated export fuses them into one solid.
///
/// The rail cross-section is the catalogue rectangle; the raceway grooves are
/// not modelled (a mating block's raceway is carried by the block envelope).
pub fn hiwin_hgr_rail(
  size~ : String = "HGR15",
  length_mm~ : Double = 400.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let spec = match hiwin_rail_spec(size) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  match @common.require_positive("Hiwin rail length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let span = length_mm - 2.0 * spec.end_margin_mm
  if span < 0.0 {
    return Err(
      @common.InvalidDimension("Hiwin rail is shorter than its two end margins"),
    )
  }
  let count = (span / spec.pitch_mm).floor().to_int() + 1
  let positions : Array[Double] = []
  for i in 0..<count {
    positions.push(spec.end_margin_mm + i.to_double() * spec.pitch_mm)
  }
  let half_width = spec.width_mm / 2.0
  let base_height = spec.height_mm - spec.counterbore_depth_mm
  let hole_radius = spec.hole_diameter_mm / 2.0
  let cbore_radius = spec.counterbore_diameter_mm / 2.0
  let base_holes : Array[Array[@cad.ProfileSegment]] = []
  let cbore_holes : Array[Array[@cad.ProfileSegment]] = []
  for x in positions {
    base_holes.push(@common.circle_loop(x, 0.0, hole_radius))
    cbore_holes.push(@common.circle_loop(x, 0.0, cbore_radius))
  }
  let base = @cad.ExtrudedArcProfile::new(
      hiwin_rect_loop(0.0, -half_width, length_mm, half_width),
      base_height,
      holes=base_holes,
    )
    .as_shape()
    .with_name("rail-base")
  let top = @cad.ExtrudedArcProfile::new(
      hiwin_rect_loop(0.0, -half_width, length_mm, half_width),
      spec.counterbore_depth_mm,
      holes=cbore_holes,
    )
    .as_shape()
    .with_name("rail-top")
    .translate(z=base_height)
  let top_node = @cad.union_all([base, top], name="rail-body")
  let features = @common.FeatureRecord::new(
    modeled=["rail-section", "counterbored-mounting-holes"],
    approximated=[
      @common.Approximation::new(
        feature="raceway-grooves",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the rail cross-section is the catalogue rectangle; the longitudinal raceway grooves are not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="rail-length-grading",
        reason="Hiwin's rail accuracy grades and end-cap machining are not modelled",
      ),
    ],
  )
  let name = "hiwin-\{spec.size}-rail-\{@cad.fmt_double(length_mm, None)}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Hiwin \{spec.size} linear guideway rail (\{@cad.fmt_double(length_mm, None)} mm)",
      standard="Hiwin HGR linear guideway",
      family="Hiwin HGR rail",
      size=spec.size,
      length_mm~,
      material="bearing steel",
      source="https://www.hiwin.com/linear-guideways.html | \{spec.size}: \{spec.width_mm} x \{spec.height_mm} mm, hole pitch \{spec.pitch_mm} mm, end distance \{spec.end_margin_mm} mm, counterbore \{spec.counterbore_diameter_mm} x \{spec.counterbore_depth_mm} mm, through hole \{spec.hole_diameter_mm} mm (\{spec.thread})",
    ),
    description="Hiwin \{spec.size} rail: catalogue rectangular section with real counterbored mounting holes at the published pitch.",
    features~,
  ).add_layer(top_node.shape_intent(), name="rail", color~)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-base",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=spec.width_mm,
        description="rail mounting face on -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-top",
        placement=@common.Placement::translation(0.0, 0.0, spec.height_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=spec.width_mm,
        description="rail top face on +Z",
      ),
    )
  let mut index = 0
  for x in positions {
    index += 1
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{index}",
        placement=@common.Placement::translation(x, 0.0, spec.height_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=spec.counterbore_diameter_mm,
        depth_mm=spec.counterbore_depth_mm,
        description="counterbored rail mounting hole (\{spec.thread})",
      ),
    )
  }
  Ok(out)
}

///|
/// hiwin_rect_loop returns a counter-clockwise rectangle.
fn hiwin_rect_loop(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, y0), (x1, y0)),
    @cad.SegmentLine((x1, y0), (x1, y1)),
    @cad.SegmentLine((x1, y1), (x0, y1)),
    @cad.SegmentLine((x0, y1), (x0, y0)),
  ]
}

///|
/// HiwinBlockSpec is the catalogue envelope and bolt pattern of one Hiwin HGH
/// carriage.
pub(all) struct HiwinBlockSpec {
  size : String
  width_mm : Double
  length_mm : Double
  height_mm : Double
  bolt_b_mm : Double
  bolt_c_mm : Double
  hole_diameter_mm : Double
  thread_diameter_mm : Double
  thread : String
}

///|
/// hiwin_block_spec returns the catalogue data for an HGH carriage.
///
/// Sources: Hiwin HGH15CA/HGH20CA dimension tables (block W x L x H and the
/// B x C mounting bolt pattern).
pub fn hiwin_block_spec(
  size : String,
) -> Result[HiwinBlockSpec, @common.SpecError] {
  match size {
    "HGH15CA" =>
      Ok({
        size: "HGH15CA",
        width_mm: 34.0,
        length_mm: 61.4,
        height_mm: 28.0,
        bolt_b_mm: 26.0,
        bolt_c_mm: 26.0,
        hole_diameter_mm: 3.3,
        thread_diameter_mm: 4.0,
        thread: "M4",
      })
    "HGH20CA" =>
      Ok({
        size: "HGH20CA",
        width_mm: 44.0,
        length_mm: 77.5,
        height_mm: 30.0,
        bolt_b_mm: 32.0,
        bolt_c_mm: 36.0,
        hole_diameter_mm: 4.2,
        thread_diameter_mm: 5.0,
        thread: "M5",
      })
    _ =>
      Err(
        @common.InvalidParameter(
          "unknown Hiwin block size (expected HGH15CA or HGH20CA)",
        ),
      )
  }
}

///|
/// hiwin_hgh_block builds a Hiwin HGH carriage envelope with real tapped bolt
/// holes and a real rail channel.
///
/// Frame: the block is centred on the origin in X and Y, its base plane (the
/// rail interface) is at `z = 0` and its top at `z = height_mm`. The rail
/// channel runs along X with the matching rail width and height. The four
/// tapped mounting holes are on the published B x C pattern and open on the top
/// face.
///
/// The carriage body is the catalogue envelope (W x L x H) with a rectangular
/// rail channel; the recirculating-ball details and the raceway profile are not
/// modelled.
pub fn hiwin_hgh_block(
  size~ : String = "HGH15CA",
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let spec = match hiwin_block_spec(size) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let rail_size = if spec.size == "HGH15CA" { "HGR15" } else { "HGR20" }
  let rail = match hiwin_rail_spec(rail_size) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let half_l = spec.length_mm / 2.0
  let half_w = spec.width_mm / 2.0
  let hole_radius = spec.hole_diameter_mm / 2.0
  let holes : Array[Array[@cad.ProfileSegment]] = []
  for sx in [-1.0, 1.0] {
    for sy in [-1.0, 1.0] {
      holes.push(
        @common.circle_loop(
          sx * spec.bolt_c_mm / 2.0,
          sy * spec.bolt_b_mm / 2.0,
          hole_radius,
        ),
      )
    }
  }
  let body = @cad.ExtrudedArcProfile::new(
      hiwin_rect_loop(-half_l, -half_w, half_l, half_w),
      spec.height_mm,
      holes~,
    )
    .as_shape()
    .with_name("block-body")
  // Channel for the rail, cut through along X.
  let margin = 1.0
  let channel = @cad.Cuboid::new(
      spec.length_mm + 2.0 * margin,
      rail.width_mm,
      rail.height_mm + margin,
    )
    .with_name("rail-channel")
    .translate(z=-margin)
  let cut = @cad.difference(body, [channel], name="carriage")
  let features = @common.FeatureRecord::new(
    modeled=["carriage-envelope", "tapped-bolt-pattern", "rail-channel"],
    approximated=[
      @common.Approximation::new(
        feature="carriage-body",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the carriage is the catalogue W x L x H envelope with a rectangular rail channel; the raceway profile and return caps are not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="recirculating-balls",
        reason="the ball recirculation and preload details are not modelled",
      ),
    ],
  )
  let name = "hiwin-\{spec.size}-block"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Hiwin \{spec.size} linear guideway carriage",
      standard="Hiwin HGH linear guideway",
      family="Hiwin HGH carriage",
      size=spec.size,
      material="bearing steel",
      source="https://www.hiwin.com/linear-guideways.html | \{spec.size}: block \{spec.width_mm} x \{spec.length_mm} x \{spec.height_mm} mm, mounting bolt pattern B x C \{spec.bolt_b_mm} x \{spec.bolt_c_mm} mm, \{spec.thread} tapped holes, for \{rail_size}",
    ),
    description="Hiwin \{spec.size} carriage envelope with the published B x C tapped bolt pattern and a real rail channel.",
    features~,
  ).add_layer(cut.shape_intent(), name="carriage", color~)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "block-top",
        placement=@common.Placement::translation(0.0, 0.0, spec.height_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=spec.width_mm,
        description="carriage top mounting face on +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "rail-channel",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=rail.width_mm,
        depth_mm=rail.height_mm,
        description="rail interface channel, running along +X",
      ),
    )
  let mut index = 0
  for sx in [-1.0, 1.0] {
    for sy in [-1.0, 1.0] {
      index += 1
      out = out.with_connector_unchecked(
        @common.MateConnector::new(
          "mount-hole-\{index}",
          placement=@common.Placement::translation(
            sx * spec.bolt_c_mm / 2.0,
            sy * spec.bolt_b_mm / 2.0,
            spec.height_mm,
          ),
          axis=(0.0, 0.0, 1.0),
          kind=@common.MateKind::Threaded,
          gender=@common.MateGender::Female,
          diameter_mm=spec.thread_diameter_mm,
          depth_mm=spec.height_mm,
          description="\{spec.thread} tapped carriage mounting hole",
        ),
      )
    }
  }
  Ok(out)
}

///|
/// hiwin_rail_family exposes the HGR rail sizes as a length-parametrised
/// design family.
pub fn hiwin_rail_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=400.0,
      min_mm=100.0,
      max_mm=4000.0,
      description="rail length",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="hiwin-hgr-rail",
      specs~,
      description="Hiwin HGR15/HGR20 rails with counterbored mounting holes.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        hiwin_hgr_rail(size="HGR15", length_mm=length)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for length in [160.0, 220.0, 340.0, 400.0, 460.0, 640.0, 1000.0] {
    out = match
      out.with_variant("\{@cad.fmt_double(length, None)}mm", [
        ("length", length),
      ]) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}

///|
/// hiwin_block_family exposes the HGH carriages as a design family.
pub fn hiwin_block_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = []
  let family = match
    @common.DesignFamily::new(
      name="hiwin-hgh-block",
      specs~,
      description="Hiwin HGH15CA/HGH20CA carriage envelopes.",
      build=fn(_parameters) { hiwin_hgh_block(size="HGH15CA") },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  out = match out.with_variant("HGH15CA", []) {
    Ok(next) => next
    Err(e) => return Err(e)
  }
  out = match out.with_variant("HGH20CA", []) {
    Ok(next) => next
    Err(e) => return Err(e)
  }
  Ok(out)
}
