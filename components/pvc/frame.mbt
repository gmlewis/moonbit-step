///|
/// PvcFrameItem is one row of a PVC frame cut list / bill of materials.
pub(all) struct PvcFrameItem {
  role : String
  trade_size : String
  length_mm : Double
  count : Int32
}

///|
/// pvc_box_frame_cut_list computes exact cut lengths for a rectangular box frame
/// assembled from 8 furniture-grade 3-way corner elbows (`corner_3way`).
///
/// Outside frame dimensions (`width_mm`, `depth_mm`, `height_mm`) run between
/// corner fitting centerlines (`center_to_seat_90_mm` offset from each pipe
/// end to the corner hub center). Each pipe therefore spans `axis_span - 2 *
/// center_to_seat_90_mm` between the opposite pipe-stop shoulders.
pub fn pvc_box_frame_cut_list(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  size : PvcSize,
) -> Result[Array[PvcFrameItem], @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("PVC frame width", width_mm),
    @common.require_positive("PVC frame depth", depth_mm),
    @common.require_positive("PVC frame height", height_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let deduction = 2.0 * size.center_to_seat_90_mm
  let x_len = width_mm - deduction
  let y_len = depth_mm - deduction
  let z_len = height_mm - deduction
  if x_len <= 0.0 || y_len <= 0.0 || z_len <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "frame width, depth, and height must exceed twice center_to_seat_90_mm (\{@cad.fmt_double(deduction, None)} mm)",
      ),
    )
  }
  Ok([
    { role: "x-rail", trade_size: size.trade_size, length_mm: x_len, count: 4, },
    { role: "y-rail", trade_size: size.trade_size, length_mm: y_len, count: 4, },
    { role: "z-post", trade_size: size.trade_size, length_mm: z_len, count: 4, },
    {
      role: "corner-3way",
      trade_size: size.trade_size,
      length_mm: 0.0,
      count: 8,
    },
  ])
}

///|
fn add_placed_layers(
  target : @common.Component,
  part : @common.Component,
  placement : @common.Placement,
  prefix : String,
) -> @common.Component {
  let mut out = target
  for i, layer in part.layers() {
    out = out.add_layer(
      layer.shape,
      name="\{prefix}-\{i}",
      color=layer.color,
      placement=@common.Placement::compose(placement, layer.placement),
    )
  }
  out
}

///|
/// pvc_box_frame_assembly builds a complete 3D PVC box frame assembly
/// (`8` 3-way corner elbows and `12` cut pipes) spanning `[0, width_mm]` x
/// `[0, depth_mm]` x `[0, height_mm]` between corner centerlines.
pub fn pvc_box_frame_assembly(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  size : PvcSize,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  match pvc_box_frame_cut_list(width_mm, depth_mm, height_mm, size) {
    Err(e) => Err(e)
    Ok(items) => {
      let x_len = items[0].length_mm
      let y_len = items[1].length_mm
      let z_len = items[2].length_mm
      let pipe_x = match pvc_pipe(size, x_len, detail~, color?) {
        Ok(p) => p
        Err(e) => return Err(e)
      }
      let pipe_y = match pvc_pipe(size, y_len, detail~, color?) {
        Ok(p) => p
        Err(e) => return Err(e)
      }
      let pipe_z = match pvc_pipe(size, z_len, detail~, color?) {
        Ok(p) => p
        Err(e) => return Err(e)
      }
      let corner = match corner_3way(size, detail~, color?) {
        Ok(c) => c
        Err(e) => return Err(e)
      }
      let seat = size.center_to_seat_90_mm
      let mut out = @common.Component::new(
        name="pvc-box-frame-\{size.trade_size}-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(depth_mm, None)}x\{@cad.fmt_double(height_mm, None)}",
        metadata=pvc_fitting_metadata(
          size,
          "PVC box frame \{size.trade_size} in (\{size.schedule.label()})",
          "PVC prototype box frame",
          "\{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(depth_mm, None)} x \{@cad.fmt_double(height_mm, None)} mm centerline",
        ),
        description="Complete 3D rectangular PVC prototype frame consisting of 8 corner_3way fittings and 12 cut pipe rails/posts.",
        features=@common.FeatureRecord::new(
          modeled=["corner-3way-fittings", "x-rails", "y-rails", "z-posts"],
          approximated=[],
          omitted=[
            @common.Omission::new(
              feature="solvent-cement-fillet",
              reason="assembled dry-fit nominal envelope without cement bead",
            ),
          ],
        ),
      )
      // Place all 8 3-way corner fittings oriented inward toward the box interior.
      let corners : Array[(Double, Double, Double, @common.Placement)] = [
        (0.0, 0.0, 0.0, @common.Placement::identity()),
        (width_mm, 0.0, 0.0, @common.Placement::rotation_z(90.0)),
        (width_mm, depth_mm, 0.0, @common.Placement::rotation_z(180.0)),
        (0.0, depth_mm, 0.0, @common.Placement::rotation_z(270.0)),
        (
          0.0,
          0.0,
          height_mm,
          @common.Placement::compose(
            @common.Placement::rotation_z(90.0),
            @common.Placement::rotation_x(180.0),
          ),
        ),
        (
          width_mm,
          0.0,
          height_mm,
          @common.Placement::compose(
            @common.Placement::rotation_z(180.0),
            @common.Placement::rotation_x(180.0),
          ),
        ),
        (
          width_mm,
          depth_mm,
          height_mm,
          @common.Placement::compose(
            @common.Placement::rotation_z(270.0),
            @common.Placement::rotation_x(180.0),
          ),
        ),
        (0.0, depth_mm, height_mm, @common.Placement::rotation_x(180.0)),
      ]
      for i, cdef in corners {
        let (cx, cy, cz, rot) = cdef
        let pl = @common.Placement::compose(
          @common.Placement::translation(cx, cy, cz),
          rot,
        )
        out = add_placed_layers(out, corner, pl, "corner-\{i}")
      }
      // Four X rails (pipes along +X, rotated +90 deg about +Y from +Z).
      let rot_to_x = @common.Placement::rotation_y(90.0)
      for
        idx, yz in [
          (0.0, 0.0),
          (depth_mm, 0.0),
          (0.0, height_mm),
          (depth_mm, height_mm),
        ] {
        let pl = @common.Placement::compose(
          @common.Placement::translation(seat, yz.0, yz.1),
          rot_to_x,
        )
        out = add_placed_layers(out, pipe_x, pl, "x-rail-\{idx}")
      }
      // Four Y rails (pipes along +Y, rotated -90 deg about +X from +Z).
      let rot_to_y = @common.Placement::rotation_x(-90.0)
      for
        idx, xz in [
          (0.0, 0.0),
          (width_mm, 0.0),
          (0.0, height_mm),
          (width_mm, height_mm),
        ] {
        let pl = @common.Placement::compose(
          @common.Placement::translation(xz.0, seat, xz.1),
          rot_to_y,
        )
        out = add_placed_layers(out, pipe_y, pl, "y-rail-\{idx}")
      }
      // Four Z posts (pipes along +Z).
      for
        idx, xy in [
          (0.0, 0.0),
          (width_mm, 0.0),
          (0.0, depth_mm),
          (width_mm, depth_mm),
        ] {
        let pl = @common.Placement::translation(xy.0, xy.1, seat)
        out = add_placed_layers(out, pipe_z, pl, "z-post-\{idx}")
      }
      Ok(add_origin(out))
    }
  }
}
