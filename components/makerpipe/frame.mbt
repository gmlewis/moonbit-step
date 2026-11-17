///|
/// FrameItem is one row of a Maker Pipe frame cut list or bill of materials.
pub(all) struct FrameItem {
  role : String
  length_mm : Double
  count : Int32
}

///|
/// table_frame_cut_list computes a simple rectangular table frame.
///
/// Four legs are continuous through the eight 90 degree connectors; the four
/// X rails and four Y rails are cut between the post surfaces. No shelves,
/// diagonals, feet, or fasteners are included. Lengths are millimetres.
pub fn table_frame_cut_list(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  size : MakerPipeSize,
) -> Result[Array[FrameItem], @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("frame width", width_mm),
    @common.require_positive("frame depth", depth_mm),
    @common.require_positive("frame height", height_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let pipe_od = size.through_pipe_od_mm
  let x_rail = width_mm - pipe_od
  let y_rail = depth_mm - pipe_od
  if x_rail <= 0.0 || y_rail <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "frame width and depth must exceed the EMT outside diameter",
      ),
    )
  }
  let items : Array[FrameItem] = [
    { role: "leg", length_mm: height_mm, count: 4, },
    { role: "x-rail", length_mm: x_rail, count: 4, },
    { role: "y-rail", length_mm: y_rail, count: 4, },
    { role: "90-degree connector", length_mm: 0.0, count: 8, },
  ]
  Ok(items)
}
