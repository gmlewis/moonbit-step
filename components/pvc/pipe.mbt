///|
/// PVC_PIPE_CHAMFER_MM is the outer deburr chamfer leg applied to both cut pipe
/// ends when detail is `Detailed` or `FullyModeled`.
const PVC_PIPE_CHAMFER_MM : Double = 0.5

///|
/// pvc_pipe builds a cut-to-length Schedule 40 or Schedule 80 PVC pipe along +Z
/// from z = 0 to z = length_mm.
///
/// The outside diameter follows ASTM D1785 IPS sizing so Schedule 40 and
/// Schedule 80 pipes share identical mating sockets; `end-a` and `end-b` carry
/// CylindricalShaft connectors sized for `snap_connectors` insertion into any
/// fitting socket.
pub fn pvc_pipe(
  size : PvcSize,
  length_mm : Double,
  detail~ : @common.DetailLevel = Simplified,
  color? : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("PVC pipe length", length_mm) {
    Err(e) => Err(e)
    Ok(_) => {
      let policy = @common.DetailPolicy::for_level(detail)
      let chamfer = if policy.include_small_features {
        let max_c = (size.pipe_od_mm - size.pipe_id_mm) * 0.25
        let len_cap = length_mm * 0.2
        let c1 = if PVC_PIPE_CHAMFER_MM < max_c {
          PVC_PIPE_CHAMFER_MM
        } else {
          max_c
        }
        if c1 < len_cap {
          c1
        } else {
          len_cap
        }
      } else {
        0.0
      }
      let body = if chamfer > 0.0 {
        @cad.RevolvedProfile::chamfered_tube(
          size.pipe_od_mm,
          size.pipe_id_mm,
          length_mm,
          outer_bottom_chamfer=chamfer,
          outer_top_chamfer=chamfer,
        ).as_shape()
      } else {
        @cad.RevolvedProfile::tube(size.pipe_od_mm, size.pipe_id_mm, length_mm).as_shape()
      }
      let modeled = ["body", "outside-cylinder", "inside-cylinder"]
      if chamfer > 0.0 {
        modeled.push("end-chamfer")
      }
      let part_color = match color {
        Some(c) => c
        None => pvc_default_color(size.schedule)
      }
      let len_tok = @cad.fmt_double(length_mm, None)
      let component = @common.Component::new(
        name="pvc-pipe-\{size.trade_size}-\{size.schedule.tag().to_lower()}-\{len_tok}",
        metadata=@common.Metadata::new(
          designation="PVC \{size.schedule.label()} \{size.trade_size} in x \{len_tok} mm",
          standard="ASTM D1785 IPS pipe dimensions",
          family="PVC pipe",
          size="\{size.trade_size} \{size.schedule.tag()}",
          material="rigid PVC",
          length_mm~,
          source="ASTM D1785: OD \{@cad.fmt_double(size.pipe_od_mm, None)} mm, wall \{@cad.fmt_double(size.pipe_wall_mm, None)} mm",
        ),
        description="Cut-length \{size.schedule.label()} PVC pipe along +Z with ASTM D1785 IPS outside and inside diameters and CylindricalShaft spigot mates at both ends.",
        features=@common.FeatureRecord::new(modeled~, approximated=[], omitted=[
          @common.Omission::new(
            feature="ink-marking",
            reason="printed pipe sidewall lettering is non-geometric",
          ),
          @common.Omission::new(
            feature="pressure-rating",
            reason="geometry alone does not establish hydraulic pressure rating",
          ),
        ]),
      ).add_layer(body, name="body", color=part_color)
      Ok(add_origin(add_pipe_connectors(component, size, length_mm)))
    }
  }
}
