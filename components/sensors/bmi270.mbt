///|
/// Parametric SparkFun 6DoF IMU Breakout — BMI270 (Qwiic) (`SEN-22397` 1"×1"
/// and `SEN-22398` Qwiic Micro) derived directly from SparkFun's official
/// Eagle `.brd` layouts (`sparkfun/SparkFun_Qwiic_6DoF_BMI270`).
///
/// Pure analytic STEP (zero booleans):
/// - SparkFun red FR-4 PCB with exact analytic mounting holes (`ExtrudedArcProfile`)
/// - Bosch BMI270 LGA-14 IMU package (`2.5 × 3.0 × 0.8 mm`) with exact `"imu-origin"` datum
/// - Right-angle 4-pin Qwiic JST-SH (`SM04B-SRSS-TB`) connectors with clearance envelopes
/// - Contact-plane mate connectors for every mounting hole, PCB face, Qwiic port, and IMU frame

///|
/// Board form factor for the SparkFun Qwiic 6DoF IMU Breakout — BMI270.
pub(all) enum Bmi270FormFactor {
  /// Standard 1" × 1" Qwiic breakout (`SEN-22397`, 25.4 × 25.4 mm, 4 mounting holes, 2 Qwiic ports).
  Qwiic1x1
  /// Qwiic Micro breakout (`SEN-22398`, 7.62 × 19.05 mm, 1 mounting hole, 1 Qwiic port).
  QwiicMicro
}

///|
/// Parameters for the SparkFun BMI270 breakout board.
pub(all) struct Bmi270Params {
  form_factor : Bmi270FormFactor
  pcb_thickness_mm : Double
  mounting_hole_diam_mm : Double
  include_qwiic_connectors : Bool
  include_pth_holes : Bool
}

///|
/// Standard SparkFun Qwiic 1" × 1" BMI270 breakout (`SEN-22397`) parameters.
pub fn Bmi270Params::qwiic_1x1(
  pcb_thickness_mm~ : Double = 1.6,
  mounting_hole_diam_mm~ : Double = 3.3,
  include_qwiic_connectors~ : Bool = true,
  include_pth_holes~ : Bool = true,
) -> Result[Bmi270Params, @common.SpecError] {
  if pcb_thickness_mm <= 0.2 {
    return Err(@common.InvalidParameter("pcb_thickness_mm must be > 0.2 mm"))
  }
  if mounting_hole_diam_mm <= 0.5 || mounting_hole_diam_mm >= 5.0 {
    return Err(
      @common.InvalidParameter("mounting_hole_diam_mm must be in (0.5, 5.0)"),
    )
  }
  Ok({
    form_factor: Qwiic1x1,
    pcb_thickness_mm,
    mounting_hole_diam_mm,
    include_qwiic_connectors,
    include_pth_holes,
  })
}

///|
/// SparkFun Qwiic Micro BMI270 breakout (`SEN-22398`) parameters.
pub fn Bmi270Params::qwiic_micro(
  pcb_thickness_mm~ : Double = 1.6,
  mounting_hole_diam_mm~ : Double = 3.3,
  include_qwiic_connectors~ : Bool = true,
) -> Result[Bmi270Params, @common.SpecError] {
  if pcb_thickness_mm <= 0.2 {
    return Err(@common.InvalidParameter("pcb_thickness_mm must be > 0.2 mm"))
  }
  if mounting_hole_diam_mm <= 0.5 || mounting_hole_diam_mm >= 5.0 {
    return Err(
      @common.InvalidParameter("mounting_hole_diam_mm must be in (0.5, 5.0)"),
    )
  }
  Ok({
    form_factor: QwiicMicro,
    pcb_thickness_mm,
    mounting_hole_diam_mm,
    include_qwiic_connectors,
    include_pth_holes: false,
  })
}

///|
/// Computed mechanical layout of the SparkFun BMI270 breakout in board-centered
/// coordinates (`z = 0` is the bottom of the PCB, `+Z` is the component side).
pub(all) struct Bmi270Layout {
  width_mm : Double
  height_mm : Double
  pcb_thickness_mm : Double
  total_height_mm : Double
  mounting_holes_xy : Array[(Double, Double)]
  imu_center_xy : (Double, Double)
}

///|
/// Computes the exact mechanical layout from `Bmi270Params`.
pub fn bmi270_layout(params : Bmi270Params) -> Bmi270Layout {
  let qwiic_h = if params.include_qwiic_connectors { 2.95 } else { 0.8 }
  match params.form_factor {
    Qwiic1x1 =>
      {
        width_mm: 25.4,
        height_mm: 25.4,
        pcb_thickness_mm: params.pcb_thickness_mm,
        total_height_mm: params.pcb_thickness_mm + qwiic_h,
        mounting_holes_xy: @cad.PointPattern2D::rect(20.32, 20.32).points,
        imu_center_xy: (0.0, 0.0),
      }
    QwiicMicro =>
      {
        width_mm: 7.62,
        height_mm: 19.05,
        pcb_thickness_mm: params.pcb_thickness_mm,
        total_height_mm: params.pcb_thickness_mm + qwiic_h,
        mounting_holes_xy: [(0.0, 6.985)],
        imu_center_xy: (0.0, 0.635),
      }
  }
}

///|
/// Builds the SparkFun 6DoF IMU Breakout — BMI270 (Qwiic) as a reusable
/// `@common.Component` with exact analytic PCB, BMI270 IC, Qwiic JST-SH
/// connectors, and contact-plane mate connectors.
pub fn sparkfun_bmi270(
  params : Bmi270Params,
) -> Result[@common.Component, @common.SpecError] {
  let layout = bmi270_layout(params)
  let sparkfun_red = @cad.Rgb::new(0.76, 0.11, 0.13)
  let ic_charcoal = @cad.Rgb::new(0.14, 0.14, 0.16)
  let jst_ivory = @cad.Rgb::new(0.94, 0.93, 0.89)
  let corner_r = match params.form_factor {
    Qwiic1x1 => 1.5
    QwiicMicro => 1.0
  }

  let mut pcb_prof = @cad.ExtrudedArcProfile::new(
    @cad.arc_rounded_rect_loop(
      layout.width_mm,
      layout.height_mm,
      corner_radius_mm=corner_r,
    ),
    params.pcb_thickness_mm,
  ).with_pattern_holes(
    @cad.PointPattern2D::from_points(layout.mounting_holes_xy),
    params.mounting_hole_diam_mm,
  )

  if params.include_pth_holes && params.form_factor is Qwiic1x1 {
    // Two 1×6 0.1" (2.54 mm) PTH header rows at y = ±11.43 mm.
    let top_hdr = @cad.PointPattern2D::line(6, 2.54, center_y=11.43)
    let bot_hdr = @cad.PointPattern2D::line(6, 2.54, center_y=-11.43)
    pcb_prof = pcb_prof
      .with_pattern_holes(top_hdr, 1.0)
      .with_pattern_holes(bot_hdr, 1.0)
  }

  let (sku, variant_name) = match params.form_factor {
    Qwiic1x1 => ("SEN-22397", "sparkfun-bmi270-qwiic-1x1")
    QwiicMicro => ("SEN-22398", "sparkfun-bmi270-qwiic-micro")
  }
  let features = @common.FeatureRecord::new(
    modeled=[
      "fr4-pcb-with-analytic-mounting-holes", "bmi270-lga14-package", "qwiic-jst-sh-4pin-connectors",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="smd-passives-and-silkscreen",
        reason="0603 passives and copper traces are omitted for clean mechanical envelope",
      ),
    ],
  )
  let mut comp = @common.Component::new(
    name=variant_name,
    metadata=@common.Metadata::new(
      designation="SparkFun 6DoF IMU Breakout - BMI270 (Qwiic) (\{sku})",
      standard="SparkFun Qwiic",
      family="6-DoF IMU sensor breakout",
      size="\{@cad.fmt_double(layout.width_mm, Some(0.1))} x \{@cad.fmt_double(layout.height_mm, Some(0.1))} x \{@cad.fmt_double(layout.total_height_mm, Some(0.1))} mm",
      length_mm=layout.height_mm,
      source="Derived from official SparkFun Eagle .brd files (sparkfun/SparkFun_Qwiic_6DoF_BMI270).",
    ),
    description="SparkFun 6DoF IMU Breakout - BMI270 (Qwiic) mechanical envelope with exact mounting holes, Qwiic JST-SH headers, and BMI270 sensor datum.",
    features~,
  ).add_layer(pcb_prof.as_shape(), name="pcb", color=sparkfun_red)

  // Bosch BMI270 LGA-14 package: 2.5 x 3.0 x 0.8 mm centered at imu_center_xy.
  let (ix, iy) = layout.imu_center_xy
  let ic_shape = @cad.Cuboid::new(2.5, 3.0, 0.8)
  comp = comp.add_layer(
    ic_shape,
    name="bmi270-ic",
    color=ic_charcoal,
    placement=@common.Placement::translation(
      ix - 1.25,
      iy - 1.5,
      params.pcb_thickness_mm,
    ),
  )

  // Right-angle 4-pin Qwiic JST-SH connectors (SM04B-SRSS-TB: 6.0 x 4.25 x 2.95 mm).
  if params.include_qwiic_connectors {
    match params.form_factor {
      Qwiic1x1 => {
        // J1 (right, +X opening, 4.25 along X x 6.0 along Y) at x = +7.62, y = 0
        let jst_lr = @cad.Cuboid::new(4.25, 6.0, 2.95)
        comp = comp
          .add_layer(
            jst_lr,
            name="qwiic-right",
            color=jst_ivory,
            placement=@common.Placement::translation(
              7.62 - 2.125,
              -3.0,
              params.pcb_thickness_mm,
            ),
          )
          .add_layer(
            jst_lr,
            name="qwiic-left",
            color=jst_ivory,
            placement=@common.Placement::translation(
              -7.62 - 2.125,
              -3.0,
              params.pcb_thickness_mm,
            ),
          )
      }
      QwiicMicro => {
        // J1 (south, -Y opening, 6.0 along X x 4.25 along Y) at x = 0, y = -4.445
        let jst_ns = @cad.Cuboid::new(6.0, 4.25, 2.95)
        comp = comp.add_layer(
          jst_ns,
          name="qwiic-south",
          color=jst_ivory,
          placement=@common.Placement::translation(
            -3.0,
            -4.445 - 2.125,
            params.pcb_thickness_mm,
          ),
        )
      }
    }
  }

  // Contact-plane mate connectors.
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mount-bottom",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=layout.width_mm,
        description="Bottom face of PCB seating on standoffs",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mount-top",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          params.pcb_thickness_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=layout.width_mm,
        description="Top component face of PCB",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "imu-origin",
        placement=@common.Placement::translation(
          ix,
          iy,
          params.pcb_thickness_mm + 0.8,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        description="Bosch BMI270 silicon IMU coordinate origin",
      ),
    )

  for i in 0..<layout.mounting_holes_xy.length() {
    let (hx, hy) = layout.mounting_holes_xy[i]
    comp = comp.with_connector_unchecked(
      @common.MateConnector::new(
        "hole-\{i + 1}",
        placement=@common.Placement::translation(hx, hy, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.mounting_hole_diam_mm,
        depth_mm=params.pcb_thickness_mm,
        description="M3 / 4-40 mounting hole #\{i + 1}",
      ),
    )
  }

  if params.include_qwiic_connectors {
    let qz = params.pcb_thickness_mm + 1.475
    match params.form_factor {
      Qwiic1x1 =>
        comp = comp
          .with_connector_unchecked(
            @common.MateConnector::new(
              "qwiic-right",
              placement=@common.Placement::translation(9.745, 0.0, qz),
              axis=(1.0, 0.0, 0.0),
              kind=@common.MateKind::PlaneFace,
              description="Right 4-pin Qwiic JST-SH cable entry",
            ),
          )
          .with_connector_unchecked(
            @common.MateConnector::new(
              "qwiic-left",
              placement=@common.Placement::translation(-9.745, 0.0, qz),
              axis=(-1.0, 0.0, 0.0),
              kind=@common.MateKind::PlaneFace,
              description="Left 4-pin Qwiic JST-SH cable entry",
            ),
          )
      QwiicMicro =>
        comp = comp.with_connector_unchecked(
          @common.MateConnector::new(
            "qwiic-south",
            placement=@common.Placement::translation(0.0, -6.57, qz),
            axis=(0.0, -1.0, 0.0),
            kind=@common.MateKind::PlaneFace,
            description="South 4-pin Qwiic JST-SH cable entry",
          ),
        )
    }
  }

  Ok(comp)
}
