///|
/// mot_edis_b_section_data returns the measured section geometry for a MotEDis
/// B-type series: the half outer loop, the central bore, and an optional corner
/// cavity.
priv struct BSectionData {
  size_mm : Double
  half : Array[BSeg]
  core : Array[BSeg]
  corner : Array[BSeg]
  slot_opening_mm : Double
}

///|
/// mot_edis_b_section_data looks up the measured B-type section.
///
/// The three sections were measured clean-room from the MotEDis vendor STEP
/// sections (`motedis-profile-20x20-b-type-slot-6`, `P30_N8_B`,
/// `Motedis_Profile 40x40 B-Type slot 10`). The enclosed outer areas are
/// 190.981, 439.005 and 880.456 mm2.
fn mot_edis_b_section_data(
  series : String,
) -> Result[BSectionData, @common.SpecError] {
  match series.trim().to_owned() {
    "20" =>
      Ok({
        size_mm: 20.0,
        half: mot_edis_b20_half(),
        core: mot_edis_b20_core(),
        corner: [],
        slot_opening_mm: 6.0,
      })
    "30" =>
      Ok({
        size_mm: 30.0,
        half: mot_edis_b30_half(),
        core: mot_edis_b30_core(),
        corner: mot_edis_b30_corner(),
        slot_opening_mm: 8.0,
      })
    "40" =>
      Ok({
        size_mm: 40.0,
        half: mot_edis_b40_half(),
        core: mot_edis_b40_core(),
        corner: mot_edis_b40_corner(),
        slot_opening_mm: 10.0,
      })
    other =>
      Err(
        @common.InvalidSize(
          "unsupported MotEDis B-type series: \{other}; supported: 20, 30, 40",
        ),
      )
  }
}

///|
/// b_segments converts measured segments into profile segments.
fn b_segments(segs : Array[BSeg]) -> Array[@cad.ProfileSegment] {
  segs.map(fn(seg) {
    match seg {
      BLine(ax, ay, bx, by) => @cad.SegmentLine((ax, ay), (bx, by))
      BArc(ax, ay, bx, by, cx, cy, _r) =>
        @cad.SegmentArc((ax, ay), (bx, by), (cx, cy))
    }
  })
}

///|
/// b_rotate rotates measured segments about the section origin by `turns`
/// quarter turns counter-clockwise.
fn b_rotate(segs : Array[BSeg], turns : Int32) -> Array[@cad.ProfileSegment] {
  let rot = fn(x : Double, y : Double) -> (Double, Double) {
    match turns % 4 {
      0 => (x, y)
      1 => (-y, x)
      2 => (-x, -y)
      _ => (y, -x)
    }
  }
  segs.map(fn(seg) {
    match seg {
      BLine(ax, ay, bx, by) => {
        let (rax, ray) = rot(ax, ay)
        let (rbx, rby) = rot(bx, by)
        @cad.SegmentLine((rax, ray), (rbx, rby))
      }
      BArc(ax, ay, bx, by, cx, cy, _r) => {
        let (rax, ray) = rot(ax, ay)
        let (rbx, rby) = rot(bx, by)
        let (rcx, rcy) = rot(cx, cy)
        @cad.SegmentArc((rax, ray), (rbx, rby), (rcx, rcy))
      }
    }
  })
}

///|
/// b_snap_loop closes a loop exactly: every segment ends where the next begins.
fn b_snap_loop(segs : Array[@cad.ProfileSegment]) -> Array[@cad.ProfileSegment] {
  let n = segs.length()
  let out : Array[@cad.ProfileSegment] = []
  for i in 0..<n {
    let next = segs[(i + 1) % n]
    let start = match next {
      @cad.SegmentLine(a, _) => a
      @cad.SegmentArc(a, _, _) => a
    }
    out.push(
      match segs[i] {
        @cad.SegmentLine(s, _) => @cad.SegmentLine(s, start)
        @cad.SegmentArc(s, _, c) => @cad.SegmentArc(s, start, c)
      },
    )
  }
  out
}

///|
/// mot_edis_b_full_loop builds a closed section loop from its measured half:
/// the second half is the 180-degree rotation, then the junctions are snapped.
fn mot_edis_b_full_loop(half : Array[BSeg]) -> Array[@cad.ProfileSegment] {
  let first = b_segments(half)
  let second = b_rotate(half, 2)
  let combined : Array[@cad.ProfileSegment] = []
  for seg in first {
    combined.push(seg)
  }
  for seg in second {
    combined.push(seg)
  }
  b_snap_loop(combined)
}

///|
/// mot_edis_b_profile builds a MotEDis B-type T-slot extrusion from its measured
/// section.
///
/// Frame: the profile is centred on the XY origin and runs along +Z from
/// `z = 0` to `z = length_mm`. The outer section, central bore and (for the 30
/// and 40 series) four corner cavities are exact measured loops with real
/// analytic arcs; the four T-slots are part of the outer loop, so the flat STEP
/// is already one closed profile (no nominal boolean).
///
/// The measured B-type slot has a stepped lip; the section is reproduced from
/// the vendor STEP rather than a simplified slot table, so opening, undercut,
/// depth and corner radii are all as published.
pub fn mot_edis_b_profile_of(
  series : String,
  length_mm~ : Double = 100.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("MotEDis B-type profile length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let data = match mot_edis_b_section_data(series) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let outer = mot_edis_b_full_loop(data.half)
  let holes : Array[Array[@cad.ProfileSegment]] = [
    b_snap_loop(b_segments(data.core)),
  ]
  if data.corner.length() > 0 {
    for turns in 0..<4 {
      holes.push(b_rotate(data.corner, turns))
    }
  }
  let shape = @cad.ExtrudedArcProfile::new(outer, length_mm, holes~).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["measured-b-slot-section", "central-bore", "corner-cavities"],
    approximated=[],
    omitted=[],
  )
  let size = @cad.fmt_double(data.size_mm, None)
  let name = "mot-edis-b\{series}-\{@cad.fmt_double(length_mm, None)}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="MotEDis B-type \{size}x\{size} profile (\{@cad.fmt_double(length_mm, None)} mm)",
      standard="MotEDis B-type metric T-slot (slot \{@cad.fmt_double(data.slot_opening_mm, None)})",
      family="MotEDis B-type profile",
      size~,
      length_mm~,
      material="aluminium, natural anodized",
      source="https://www.motedis.com/en/B-Type-slot-\{series}/Slot-profiles | B-type \{size}x\{size}, slot \{@cad.fmt_double(data.slot_opening_mm, None)} | section measured clean-room from the MotEDis vendor STEP",
    ),
    description="MotEDis B-type \{size}x\{size} T-slot profile with the measured stepped-lip slot section, central bore and corner cavities.",
    features~,
  ).add_layer(shape, name="profile", color~)
  let half = data.size_mm / 2.0
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=data.size_mm,
        description="-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=data.size_mm,
        description="+Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "core-bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=half - 2.0,
        depth_mm=length_mm,
        description="central core bore",
      ),
    ),
  )
}

///|
/// mot_edis_b_family exposes the three B-type sections with length presets.
pub fn mot_edis_b_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=500.0,
      min_mm=50.0,
      max_mm=3000.0,
      description="profile length",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="mot-edis-b",
      specs~,
      description="MotEDis B-type 20/30/40 T-slot profiles with measured sections.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        mot_edis_b_profile_of("20", length_mm=length)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for length in [100.0, 250.0, 500.0, 1000.0, 1500.0, 1980.0] {
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
