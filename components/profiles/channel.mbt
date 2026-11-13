///|
/// ChannelSection is one strut-channel cross-section: a C-shaped section with
/// inward-returned front lips and a punched back wall.
///
/// The dimensions are millimetres. `width_mm` and `height_mm` are the outside
/// envelope, `thickness_mm` is the uniform wall, and `slot_width_mm` is the
/// front opening between the lips. `hole_diameter_mm`, `hole_pitch_mm`, and
/// `hole_start_mm` describe the back-wall hole pattern.
pub(all) struct ChannelSection {
  name : String
  width_mm : Double
  height_mm : Double
  thickness_mm : Double
  slot_width_mm : Double
  hole_diameter_mm : Double
  hole_pitch_mm : Double
  hole_start_mm : Double
}

///|
/// ChannelSection::p1000 returns a P1000-style 41.3 mm strut-channel section.
///
/// Values are the published 1-5/8 in channel boundary: a 41.3 mm square
/// envelope, a 2.6 mm (12 gauge) wall, a 22.2 mm (7/8 in) front opening, and
/// 14.3 mm (9/16 in) back-wall holes on 47.6 mm (1-7/8 in) centres with the
/// first hole 23.8 mm from the end. This is manufacturer geometry, not a
/// universal standard; a different strut brand or gauge will differ.
pub fn ChannelSection::p1000() -> ChannelSection {
  {
    name: "P1000-style-41.3",
    width_mm: 41.3,
    height_mm: 41.3,
    thickness_mm: 2.6,
    slot_width_mm: 22.2,
    hole_diameter_mm: 14.3,
    hole_pitch_mm: 47.6,
    hole_start_mm: 23.8,
  }
}

///|
/// ChannelSection::custom validates a caller-supplied strut-channel section.
pub fn ChannelSection::custom(
  name~ : String,
  width_mm~ : Double,
  height_mm~ : Double,
  thickness_mm~ : Double,
  slot_width_mm~ : Double,
  hole_diameter_mm~ : Double,
  hole_pitch_mm~ : Double,
  hole_start_mm~ : Double,
) -> Result[ChannelSection, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("channel width", width_mm),
    @common.require_positive("channel height", height_mm),
    @common.require_positive("channel wall thickness", thickness_mm),
    @common.require_positive("channel slot width", slot_width_mm),
    @common.require_positive("channel hole diameter", hole_diameter_mm),
    @common.require_positive("channel hole pitch", hole_pitch_mm),
    @common.require_non_negative("channel first hole offset", hole_start_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if 2.0 * thickness_mm >= height_mm || 2.0 * thickness_mm >= width_mm {
    return Err(
      @common.InvalidParameter("channel wall is too thick for its envelope"),
    )
  }
  if slot_width_mm >= width_mm - 2.0 * thickness_mm {
    return Err(
      @common.InvalidParameter(
        "channel slot leaves no front lip to carry a nut",
      ),
    )
  }
  if hole_diameter_mm >= width_mm {
    return Err(
      @common.InvalidParameter("channel hole does not fit the back wall"),
    )
  }
  Ok({
    name,
    width_mm,
    height_mm,
    thickness_mm,
    slot_width_mm,
    hole_diameter_mm,
    hole_pitch_mm,
    hole_start_mm,
  })
}

///|
/// ChannelSection::designation returns the section name used in part labels.
pub fn ChannelSection::designation(self : ChannelSection) -> String {
  self.name
}

///|
/// ChannelSection::cavity_height is the clear height inside the walls.
pub fn ChannelSection::cavity_height(self : ChannelSection) -> Double {
  self.height_mm - 2.0 * self.thickness_mm
}

///|
/// ChannelSection::material_area returns the exact cross-section area of the
/// C section: the outer rectangle minus the inner cavity and the slot channel
/// through the lips.
pub fn ChannelSection::material_area(self : ChannelSection) -> Double {
  let inner_w = self.width_mm - 2.0 * self.thickness_mm
  let inner_h = self.height_mm - 2.0 * self.thickness_mm
  self.width_mm * self.height_mm -
  inner_w * inner_h -
  self.slot_width_mm * self.thickness_mm
}

///|
/// channel_c_loop returns the full C section as a counter-clockwise line loop.
fn channel_c_loop(section : ChannelSection) -> Array[@cad.ProfileSegment] {
  let hw = section.width_mm / 2.0
  let hh = section.height_mm / 2.0
  let t = section.thickness_mm
  let hs = section.slot_width_mm / 2.0
  let points : Array[@cad.Vec2] = [
    (-hs, hh),
    (-hw, hh),
    (-hw, -hh),
    (hw, -hh),
    (hw, hh),
    (hs, hh),
    (hs, hh - t),
    (hw - t, hh - t),
    (hw - t, -hh + t),
    (-hw + t, -hh + t),
    (-hw + t, hh - t),
    (-hs, hh - t),
  ]
  let out : Array[@cad.ProfileSegment] = []
  for i in 0..<points.length() {
    out.push(@cad.SegmentLine(points[i], points[(i + 1) % points.length()]))
  }
  out
}

///|
/// channel_left_l_loop returns the left wall plus left front lip as a
/// counter-clockwise loop, for the punched-channel construction.
fn channel_left_l_loop(section : ChannelSection) -> Array[@cad.ProfileSegment] {
  let hw = section.width_mm / 2.0
  let hh = section.height_mm / 2.0
  let t = section.thickness_mm
  let hs = section.slot_width_mm / 2.0
  let points : Array[@cad.Vec2] = [
    (-hw + t, -hh + t),
    (-hw + t, hh - t),
    (-hs, hh - t),
    (-hs, hh),
    (-hw, hh),
    (-hw, -hh + t),
  ]
  let out : Array[@cad.ProfileSegment] = []
  for i in 0..<points.length() {
    out.push(@cad.SegmentLine(points[i], points[(i + 1) % points.length()]))
  }
  out
}

///|
/// channel_right_l_loop returns the right wall plus right front lip as a
/// counter-clockwise loop.
fn channel_right_l_loop(section : ChannelSection) -> Array[@cad.ProfileSegment] {
  let hw = section.width_mm / 2.0
  let hh = section.height_mm / 2.0
  let t = section.thickness_mm
  let hs = section.slot_width_mm / 2.0
  let points : Array[@cad.Vec2] = [
    (hw, -hh + t),
    (hw, hh),
    (hs, hh),
    (hs, hh - t),
    (hw - t, hh - t),
    (hw - t, -hh + t),
  ]
  let out : Array[@cad.ProfileSegment] = []
  for i in 0..<points.length() {
    out.push(@cad.SegmentLine(points[i], points[(i + 1) % points.length()]))
  }
  out
}

///|
/// channel_hole_loop returns a counter-clockwise circle in the (x, z) plane,
/// which the arc compiler turns into one analytic cylindrical hole.
fn channel_hole_loop(
  x : Double,
  z : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (x, z)
  [
    @cad.SegmentArc((x + radius, z), (x, z + radius), centre),
    @cad.SegmentArc((x, z + radius), (x - radius, z), centre),
    @cad.SegmentArc((x - radius, z), (x, z - radius), centre),
    @cad.SegmentArc((x, z - radius), (x + radius, z), centre),
  ]
}

///|
/// channel_back_rect_loop returns a counter-clockwise rectangle in the (x, z)
/// plane for the punched back wall.
fn channel_back_rect_loop(
  width_mm : Double,
  length_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let hw = width_mm / 2.0
  [
    @cad.SegmentLine((-hw, 0.0), (hw, 0.0)),
    @cad.SegmentLine((hw, 0.0), (hw, length_mm)),
    @cad.SegmentLine((hw, length_mm), (-hw, length_mm)),
    @cad.SegmentLine((-hw, length_mm), (-hw, 0.0)),
  ]
}

///|
/// ChannelSection::hole_positions returns the back-wall hole centres along the
/// cut length.
///
/// Holes sit on `hole_start + k * hole_pitch` and must leave at least
/// `hole_start` of material at both ends. A length shorter than two hole-start
/// offsets has no holes.
pub fn ChannelSection::hole_positions(
  self : ChannelSection,
  length_mm : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  if length_mm <= 0.0 {
    return out
  }
  let mut z = self.hole_start_mm
  while z <= length_mm - self.hole_start_mm + 1.0e-9 {
    out.push(z)
    z = z + self.hole_pitch_mm
  }
  out
}

///|
/// strut_channel builds a cut length of P1000-style strut channel.
///
/// Frame: the section is centred on the XY origin, the front opening faces +Y,
/// the back face is at `y = -height/2`, and the length runs along +Z from
/// `z = 0`. With `punched = true` the back wall carries the published hole
/// pattern and the section is built as three layered solids (back wall, left
/// wall plus lip, right wall plus lip). With `punched = false` the C section is
/// one extrusion.
///
/// The lips here are straight returns of wall thickness; the serrations and
/// shaped teeth of a particular strut brand are not modelled. This is
/// P1000-style manufacturer geometry, not a universal standard.
pub fn strut_channel(
  section : ChannelSection,
  length_mm : Double,
  punched~ : Bool = true,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("strut channel length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let holes = section.hole_positions(length_mm)
  if punched && holes.is_empty() {
    return Err(
      @common.InvalidParameter(
        "strut channel is too short for its hole pattern; use punched=false or a longer cut",
      ),
    )
  }
  let features = if punched {
    @common.FeatureRecord::new(
      modeled=[
        "body", "front-slot", "returned-lips", "back-wall", "back-wall-holes",
      ],
      approximated=[
        @common.Approximation::new(
          feature="lip-profile",
          kind=@common.ApproximationKind::EngineeringDefault,
          deviation_mm=0.0,
          control="straight wall-thickness lips; the brand's shaped lip teeth and serrations are not modelled",
        ),
      ],
      omitted=[
        @common.Omission::new(
          feature="end-treatment",
          reason="cut burrs, end caps, and tapped ends are not modelled",
        ),
        @common.Omission::new(
          feature="strength-and-rating",
          reason="geometry alone does not establish load capacity or structural suitability",
        ),
      ],
    )
  } else {
    @common.FeatureRecord::new(
      modeled=["body", "front-slot", "returned-lips"],
      approximated=[
        @common.Approximation::new(
          feature="lip-profile",
          kind=@common.ApproximationKind::EngineeringDefault,
          deviation_mm=0.0,
          control="straight wall-thickness lips; the brand's shaped lip teeth and serrations are not modelled",
        ),
      ],
      omitted=[
        @common.Omission::new(
          feature="back-wall-holes",
          reason="the unpunched channel has no hole pattern",
        ),
        @common.Omission::new(
          feature="end-treatment",
          reason="cut burrs, end caps, and tapped ends are not modelled",
        ),
        @common.Omission::new(
          feature="strength-and-rating",
          reason="geometry alone does not establish load capacity or structural suitability",
        ),
      ],
    )
  }
  let mut component = @common.Component::new(
    name="strut-channel-\{@cad.fmt_double(section.width_mm, None)}-L\{@cad.fmt_double(length_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Strut channel P1000-style \{@cad.fmt_double(section.width_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
      standard="Generic 41.3 mm strut channel (P1000-style manufacturer geometry, not a universal standard)",
      family="strut channel",
      size="\{@cad.fmt_double(section.width_mm, None)}x\{@cad.fmt_double(section.height_mm, None)}x\{@cad.fmt_double(section.thickness_mm, None)}",
      length_mm~,
      source="Published 1-5/8 in channel boundary: 41.3 mm envelope, 2.6 mm (12 ga) wall, 22.2 mm front opening, 14.3 mm holes on 47.6 mm centres. Other brands and gauges differ.",
    ),
    description="P1000-style C strut channel with returned front lips and, when punched, a back-wall hole pattern. Layered wall solids for the punched form. No serrated lip teeth, end treatment, or load rating is modelled.",
    features~,
  )
  if punched {
    let back = @cad.ExtrudedArcProfile::new(
      channel_back_rect_loop(section.width_mm, length_mm),
      section.thickness_mm,
      holes=holes.map(fn(z) {
        channel_hole_loop(0.0, z, section.hole_diameter_mm / 2.0)
      }),
    ).as_shape()
    let back_placement = @common.Placement::translation(
      0.0,
      -section.height_mm / 2.0 + section.thickness_mm,
      0.0,
    ).compose(@common.Placement::rotation_deg(90.0, 0.0, 0.0))
    let left = @cad.ExtrudedArcProfile::new(
      channel_left_l_loop(section),
      length_mm,
    ).as_shape()
    let right = @cad.ExtrudedArcProfile::new(
      channel_right_l_loop(section),
      length_mm,
    ).as_shape()
    component = component
      .add_layer(back, name="back-wall", color~, placement=back_placement)
      .add_layer(left, name="left-wall", color~)
      .add_layer(right, name="right-wall", color~)
  } else {
    let body = @cad.ExtrudedArcProfile::new(channel_c_loop(section), length_mm).as_shape()
    component = component.add_layer(body, name="body", color~)
  }
  let half_h = section.height_mm / 2.0
  let face_size = if section.width_mm < section.height_mm {
    section.width_mm
  } else {
    section.height_mm
  }
  component = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-open",
        placement=@common.Placement::translation(0.0, half_h, 0.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=section.slot_width_mm,
        depth_mm=length_mm,
        description="front opening between the lips; runs along +Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "back-face",
        placement=@common.Placement::translation(0.0, -half_h, 0.0),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="back face; outward normal is -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="negative-Z cut end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=face_size,
        description="positive-Z cut end",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "centerline",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        description="section centreline; runs along +Z",
      ),
    )
  if punched {
    for i, z in holes {
      component = component.with_connector_unchecked(
        @common.MateConnector::new(
          "hole-\{i + 1}",
          placement=@common.Placement::translation(0.0, -half_h, z),
          axis=(0.0, 1.0, 0.0),
          kind=@common.MateKind::CylindricalBore,
          gender=@common.MateGender::Female,
          diameter_mm=section.hole_diameter_mm,
          depth_mm=section.thickness_mm,
          description="punched back-wall hole; entered from the back face",
        ),
      )
    }
  }
  Ok(component)
}

///|
/// channel_nut builds a generic rectangular channel nut with a central nominal
/// thread bore.
///
/// Frame: the nut is centred on the origin; its width runs along X, its length
/// along Z, and its thickness along Y. The thread axis is -Y, so a screw enters
/// through the channel opening (+Y) and threads into the nut. The nut width
/// (across the opening) must be smaller than the channel opening so it can
/// enter, and the nut length must be larger than the opening so it bears on the
/// lips. The spring leaf, serrations, and thread form of a particular spring
/// nut are not modelled, and no grip or strength is claimed.
pub fn channel_nut(
  section : ChannelSection,
  thread_diameter_mm : Double,
  nut_length_mm~ : Double = 30.0,
  nut_width_mm~ : Double = 20.0,
  nut_thickness_mm~ : Double = 6.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("channel nut thread diameter", thread_diameter_mm),
    @common.require_positive("channel nut length", nut_length_mm),
    @common.require_positive("channel nut width", nut_width_mm),
    @common.require_positive("channel nut thickness", nut_thickness_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if nut_width_mm >= section.slot_width_mm {
    return Err(
      @common.InvalidParameter(
        "channel nut width must be smaller than the channel opening",
      ),
    )
  }
  if nut_length_mm <= section.slot_width_mm {
    return Err(
      @common.InvalidParameter(
        "channel nut length must exceed the channel opening so it bears on the lips",
      ),
    )
  }
  if nut_thickness_mm >= section.cavity_height() {
    return Err(
      @common.InvalidParameter("channel nut is thicker than the channel cavity"),
    )
  }
  if thread_diameter_mm / 2.0 >= nut_width_mm / 2.0 ||
    thread_diameter_mm / 2.0 >= nut_length_mm / 2.0 {
    return Err(
      @common.InvalidParameter("channel nut thread does not fit the nut"),
    )
  }
  let hw = nut_width_mm / 2.0
  let hl = nut_length_mm / 2.0
  let outer : Array[@cad.ProfileSegment] = [
    @cad.SegmentLine((-hw, -hl), (hw, -hl)),
    @cad.SegmentLine((hw, -hl), (hw, hl)),
    @cad.SegmentLine((hw, hl), (-hw, hl)),
    @cad.SegmentLine((-hw, hl), (-hw, -hl)),
  ]
  let thread_loop = vslot_circle_loop(0.0, 0.0, thread_diameter_mm / 2.0)
  let body = @cad.ExtrudedArcProfile::new(outer, nut_thickness_mm, holes=[
    thread_loop,
  ]).as_shape()
  let body_placement = @common.Placement::translation(
    0.0,
    nut_thickness_mm / 2.0,
    0.0,
  ).compose(@common.Placement::rotation_deg(90.0, 0.0, 0.0))
  let features = @common.FeatureRecord::new(
    modeled=["nut-body", "thread-bore", "front-face", "back-face"],
    approximated=[
      @common.Approximation::new(
        feature="thread-form",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the thread is a nominal cylindrical bore; no helix or thread class is modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="spring-leaf-and-serrations",
        reason="the nut is a plain block; the vendor spring leaf and lip teeth are not modelled",
      ),
      @common.Omission::new(
        feature="grip-and-strength",
        reason="geometry alone does not establish grip, slip torque, or load capacity",
      ),
    ],
  )
  let component = @common.Component::new(
    name="channel-nut-M\{@cad.fmt_double(thread_diameter_mm, None)}x\{@cad.fmt_double(nut_length_mm, None)}",
    metadata=@common.Metadata::new(
      designation="Generic channel nut M\{@cad.fmt_double(thread_diameter_mm, None)} x \{@cad.fmt_double(nut_length_mm, None)}",
      standard="Generic channel nut (not a vendor spring nut)",
      family="channel nut",
      size="M\{@cad.fmt_double(thread_diameter_mm, None)}",
      length_mm=nut_length_mm,
      source="Parametric channel nut: width \{@cad.fmt_double(nut_width_mm, None)} mm, length \{@cad.fmt_double(nut_length_mm, None)} mm, thickness \{@cad.fmt_double(nut_thickness_mm, None)} mm. Sized to enter the P1000-style opening and bear on the lips; no spring leaf or thread form is claimed.",
    ),
    description="Generic rectangular channel nut with a nominal central thread bore. Sized to enter the channel opening and bear on the lips; no spring leaf, serration, thread form, grip, or strength claim.",
    features~,
  ).add_layer(body, name="body", color~, placement=body_placement)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=@common.Placement::translation(
          0.0,
          nut_thickness_mm / 2.0,
          0.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=thread_diameter_mm,
        depth_mm=nut_thickness_mm,
        description="nominal thread bore; entered from the channel-opening side (+Y); no thread form is modelled",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-front",
        placement=@common.Placement::translation(
          0.0,
          nut_thickness_mm / 2.0,
          0.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=nut_width_mm,
        description="front face; outward normal is +Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-back",
        placement=@common.Placement::translation(
          0.0,
          -nut_thickness_mm / 2.0,
          0.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=nut_width_mm,
        description="back face; outward normal is -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "slot-engagement",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=nut_width_mm,
        depth_mm=nut_thickness_mm,
        description="insertion envelope through the channel opening; the nut length of \{@cad.fmt_double(nut_length_mm, None)} mm runs along the slot",
      ),
    ),
  )
}
