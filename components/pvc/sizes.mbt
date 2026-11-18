///|
/// PvcSchedule selects the wall thickness schedule per ASTM D1785.
///
/// Both Schedule 40 and Schedule 80 share the same Iron Pipe Size (IPS)
/// outside diameters, so pipe of either schedule mates with the same socket
/// fittings.
#derive(Eq)
pub(all) enum PvcSchedule {
  Schedule40
  Schedule80
}

///|
/// PvcSchedule::label returns the human-readable schedule label.
pub fn PvcSchedule::label(self : PvcSchedule) -> String {
  match self {
    Schedule40 => "Schedule 40"
    Schedule80 => "Schedule 80"
  }
}

///|
/// PvcSchedule::tag returns a short uppercase token for part names.
pub fn PvcSchedule::tag(self : PvcSchedule) -> String {
  match self {
    Schedule40 => "SCH40"
    Schedule80 => "SCH80"
  }
}

///|
/// PvcSize carries nominal dimensions in millimetres for one IPS PVC pipe and
/// socket fitting trade size.
///
/// Outside diameters and pipe walls follow ASTM D1785; socket engagement
/// depths and center-to-seat lay lengths follow ASTM D2466 Schedule 40 socket
/// fittings.
pub(all) struct PvcSize {
  trade_size : String
  schedule : PvcSchedule
  /// ASTM D1785 IPS outside diameter.
  pipe_od_mm : Double
  /// Pipe wall thickness for the selected schedule.
  pipe_wall_mm : Double
  /// Pipe inside diameter (`pipe_od_mm - 2 * pipe_wall_mm`).
  pipe_id_mm : Double
  /// Socket bore accepting the pipe (`pipe_od_mm + bore_clearance_mm`).
  socket_bore_mm : Double
  /// Socket collar outside diameter.
  socket_outer_mm : Double
  /// Socket engagement depth from mouth to internal pipe-stop seat.
  socket_depth_mm : Double
  /// Internal through-bore diameter at the pipe-stop shoulder (Schedule 40 ID).
  through_bore_mm : Double
  /// Center-of-fitting to pipe-stop seat distance for 90-degree tees, elbows,
  /// and crosses (`G` lay length).
  center_to_seat_90_mm : Double
  /// Center-of-fitting to pipe-stop seat distance for 45-degree elbows (`J`).
  center_to_seat_45_mm : Double
}

///|
/// Default solvent-cement / prototyping slip clearance on socket bore (mm).
pub let pvc_default_bore_clearance_mm : Double = 0.25

///|
/// Default white colour for Schedule 40 PVC and industrial grey for Schedule 80.
pub fn pvc_default_color(schedule : PvcSchedule) -> @cad.Rgb {
  match schedule {
    Schedule40 => @cad.Rgb::new(0.95, 0.95, 0.96)
    Schedule80 => @cad.Rgb::new(0.48, 0.50, 0.53)
  }
}

///|
/// pvc_trade_sizes lists every supported IPS PVC trade size.
pub fn pvc_trade_sizes() -> Array[String] {
  ["1/2", "3/4", "1", "1-1/4", "1-1/2", "2"]
}

///|
/// pvc_size looks up ASTM D1785 / ASTM D2466 dimensions for one trade size.
///
/// Dimensions convert exact published inch tolerances/nominals at 25.4 mm/in:
///   (od_in, sch40_wall_in, sch80_wall_in, socket_depth_in,
///    socket_wall_factor, center_to_seat_90_in, center_to_seat_45_in)
pub fn pvc_size(
  trade_size : String,
  schedule~ : PvcSchedule = Schedule40,
  bore_clearance_mm~ : Double = pvc_default_bore_clearance_mm,
) -> Result[PvcSize, @common.SpecError] {
  if !@common.is_finite(bore_clearance_mm) || bore_clearance_mm < 0.0 {
    return Err(
      @common.InvalidParameter(
        "PVC socket bore clearance must be finite and non-negative",
      ),
    )
  }
  let raw = match trade_size {
    "1/2" => (0.840, 0.109, 0.147, 0.750, 0.140, 0.500, 0.250)
    "3/4" => (1.050, 0.113, 0.154, 0.875, 0.145, 0.562, 0.312)
    "1" => (1.315, 0.133, 0.179, 1.000, 0.170, 0.688, 0.375)
    "1-1/4" => (1.660, 0.140, 0.191, 1.125, 0.180, 0.875, 0.438)
    "1-1/2" => (1.900, 0.145, 0.200, 1.250, 0.190, 1.000, 0.500)
    "2" => (2.375, 0.154, 0.218, 1.375, 0.205, 1.250, 0.625)
    _ =>
      return Err(
        @common.InvalidSize(
          "unsupported PVC trade size '\{trade_size}' (supported: 1/2, 3/4, 1, 1-1/4, 1-1/2, 2)",
        ),
      )
  }
  let (od_in, wall40_in, wall80_in, depth_in, socket_wall_in, lay90_in, lay45_in
  ) = raw
  let mm = 25.4
  let pipe_od_mm = od_in * mm
  let sch40_wall_mm = wall40_in * mm
  let sch80_wall_mm = wall80_in * mm
  let pipe_wall_mm = match schedule {
    Schedule40 => sch40_wall_mm
    Schedule80 => sch80_wall_mm
  }
  let pipe_id_mm = pipe_od_mm - 2.0 * pipe_wall_mm
  let through_bore_mm = pipe_od_mm - 2.0 * sch40_wall_mm
  let socket_bore_mm = pipe_od_mm + bore_clearance_mm
  let socket_outer_mm = socket_bore_mm + 2.0 * (socket_wall_in * mm)
  let socket_depth_mm = depth_in * mm
  let center_to_seat_90_mm = lay90_in * mm
  let center_to_seat_45_mm = lay45_in * mm
  Ok({
    trade_size,
    schedule,
    pipe_od_mm,
    pipe_wall_mm,
    pipe_id_mm,
    socket_bore_mm,
    socket_outer_mm,
    socket_depth_mm,
    through_bore_mm,
    center_to_seat_90_mm,
    center_to_seat_45_mm,
  })
}
