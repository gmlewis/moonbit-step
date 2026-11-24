///|
/// The Maker Store M5 low-profile screw head thickness, in millimetres.
let low_profile_head_height_mm : Double = 1.5

///|
/// The published Maker Store M5 low-profile screw head diameter (8.9 mm
/// +/- 0.3), in millimetres.
let low_profile_head_diameter_mm : Double = 8.9

///|
/// The 3 mm hex drive across flats of the Maker Store M5 low-profile screw, in
/// millimetres.
let low_profile_socket_af_mm : Double = 3.0

///|
/// The modelled socket depth of the low-profile head, in millimetres.
let low_profile_socket_depth_mm : Double = 1.0

///|
/// The small top-edge break of the low-profile head, in millimetres.
let low_profile_edge_mm : Double = 0.15

///|
/// The 45-degree tip break at the shank end, in millimetres.
let low_profile_tip_mm : Double = 0.5

///|
/// The published Maker Store M5 low-profile screw lengths, in millimetres.
pub let low_profile_lengths_mm : Array[Double] = [
  6.0, 8.0, 10.0, 12.0, 15.0, 20.0, 25.0, 27.0, 30.0, 35.0, 40.0, 45.0, 50.0, 55.0,
  60.0, 65.0,
]

///|
/// low_profile_screw builds a Maker Store `SCREWS-M5-LP` low-profile socket
/// screw.
///
/// Frame: the screw axis is +Z with the origin on the head underside (the
/// bearing face). The head occupies `z = 0 .. 1.5` and the shank
/// `z = -length .. 0`, so the screw is inserted along -Z.
///
/// Geometry follows the published part: an M5 x 0.8 thread, an **8.9 mm**
/// low-profile head only **1.5 mm** thick, and a 3 mm hex socket. The shank is a
/// plain nominal-diameter envelope (the thread is declared by a `Threaded`
/// connector); the head is a solid of revolution with a 0.15 mm top-edge break
/// and a blind hexagonal socket.
///
/// Source: https://makerstore.cc/product/m5-low-profile-screws/ (SKU
/// SCREWS-M5-LP; head thickness 1.5 mm, M5 x 0.8, 3 mm hex, lengths 6-65 mm;
/// head diameter 8.9 mm +/- 0.3 from the equivalent RM Components listing).
pub fn low_profile_screw(
  length_mm~ : Double = 16.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("low-profile screw length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if length_mm < 2.0 * low_profile_tip_mm {
    return Err(
      @common.InvalidDimension(
        "low-profile screw is too short for its tip break",
      ),
    )
  }
  let r = 5.0 / 2.0
  let dk_r = low_profile_head_diameter_mm / 2.0
  let k = low_profile_head_height_mm
  let edge = low_profile_edge_mm
  let tip = low_profile_tip_mm
  let segs : Array[@cad.RevSegment] = [
    @cad.RevLine((0.0, 0.0), (r - tip, 0.0)),
    @cad.RevLine((r - tip, 0.0), (r, tip)),
    @cad.RevLine((r, tip), (r, length_mm)),
    @cad.RevLine((r, length_mm), (dk_r, length_mm)),
    @cad.RevLine((dk_r, length_mm), (dk_r, length_mm + k - edge)),
    @cad.RevArc(
      (dk_r, length_mm + k - edge),
      (dk_r - edge, length_mm + k),
      (dk_r - edge, length_mm + k - edge),
    ),
    @cad.RevLine((dk_r - edge, length_mm + k), (0.0, length_mm + k)),
  ]
  let body = @cad.RevolvedProfile::new(segs)
  let floor_local = length_mm + k - low_profile_socket_depth_mm
  let socket = @cad.SocketedSolid::new(
    body, low_profile_socket_af_mm, floor_local,
  )
  let features = @common.FeatureRecord::new(
    modeled=[
      "low-profile-head", "blind-hex-socket", "head-top-edge-break", "shank-tip-chamfer",
    ],
    approximated=[
      @common.Approximation::new(
        feature="thread-envelope",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the M5 x 0.8 shank is a nominal-diameter envelope; the thread helix is declared by a Threaded connector",
      ),
    ],
    omitted=[],
  )
  let length_text = @cad.fmt_double(length_mm, None)
  let name = "SCREWS-M5-LP-\{length_text}"
  let component = @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Maker Store M5 low-profile screw (SCREWS-M5-LP) \{length_text} mm",
        standard="Maker Store low-profile head socket screw",
        family="Maker Store M5 low-profile screw",
        size="M5x\{length_text}",
        length_mm~,
        material="alloy steel, black oxide",
        source="https://makerstore.cc/product/m5-low-profile-screws/ | SKU SCREWS-M5-LP | M5 x 0.8, 1.5 mm low-profile head, 3 mm hex, 8.9 mm head diameter | lengths 6-65 mm",
      ),
      description="Maker Store M5 low-profile socket screw: 1.5 mm thick, 8.9 mm head with a 3 mm hex socket, and an M5 x 0.8 shank envelope.",
      features~,
    )
    .add_layer(socket.as_shape(), name="body", color~)
    .translate(z=-length_mm)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "head-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=low_profile_head_diameter_mm,
        description="head bearing face on the part surface, normal -Z",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "thread",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Male,
        diameter_mm=5.0,
        depth_mm=length_mm,
        description="M5 x 0.8 threaded shank",
      ),
    ),
  )
}

///|
/// low_profile_screw_family exposes the 16 published SCREWS-M5-LP lengths.
pub fn low_profile_screw_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=16.0,
      min_mm=6.0,
      max_mm=65.0,
      description="screw length under the head",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-m5-low-profile",
      specs~,
      description="Maker Store M5 low-profile socket screws, 6-65 mm.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        low_profile_screw(length_mm=length)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for length in low_profile_lengths_mm {
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
