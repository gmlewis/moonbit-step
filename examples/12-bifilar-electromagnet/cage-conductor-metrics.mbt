///|
/// Cage/exits conductor metrics (non-geometry utilities).
///
/// This file intentionally keeps analysis/estimation code separate from the
/// cage geometry construction in bfem-cage.mbt.

///|
/// ConductorTotals accumulates simple DC-ish metrics for prismatic conductors.
///
/// Units:
/// - length_mm: sum of conductor lengths in mm (for extrusions, the extrude height)
/// - volume_mm3: sum of volumes in mm^3
/// - mm_over_mm2: sum of (length_mm / area_mm2), used for Rdc estimates
struct ConductorTotals {
  length_mm : Double
  volume_mm3 : Double
  mm_over_mm2 : Double
  segments : Int
}

///|
struct CageConductorMetrics {
  cage : ConductorTotals
  exit_wires : ConductorTotals
}

///|
fn totals_zero() -> ConductorTotals {
  { length_mm: 0.0, volume_mm3: 0.0, mm_over_mm2: 0.0, segments: 0 }
}

///|
fn totals_add_prism(
  t : ConductorTotals,
  area_mm2 : Double,
  height_mm : Double,
) -> ConductorTotals {
  if area_mm2 <= 0.0 || height_mm <= 0.0 {
    return t
  }
  {
    length_mm: t.length_mm + height_mm,
    volume_mm3: t.volume_mm3 + area_mm2 * height_mm,
    mm_over_mm2: t.mm_over_mm2 + height_mm / area_mm2,
    segments: t.segments + 1,
  }
}

///|
fn polygon_area_mm2(points : Array[Vec2]) -> Double {
  if points.length() < 3 {
    return 0.0
  }
  let mut sum = 0.0
  let n = points.length()
  for i in 0..<n {
    let j = (i + 1) % n
    sum = sum + points[i].0 * points[j].1 - points[j].0 * points[i].1
  }
  (0.5 * sum).abs()
}

///|
fn circle_polygon_area_mm2(radius : Double, segments : Int) -> Double {
  if radius <= 0.0 || segments < 3 {
    return 0.0
  }
  let pts = []
  for i in 1..=segments {
    let angle = -2.0 * @math.PI * i.to_double() / segments.to_double()
    pts.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
  polygon_area_mm2(pts)
}

///|
pub fn estimate_bfem_cage_conductors(
  size~ : Vec3,
  params~ : Params,
) -> CageConductorMetrics {
  let ctx = make_cage_context(size, params)
  let mut cage = totals_zero()
  let mut exit_wires = totals_zero()

  // axial connectors
  for i in 0..<(2 * ctx.npairs) {
    let i_d = i.to_double()
    let inner_start_angle = i_d * ctx.rail_angle_delta
    let inner_end_angle = (i_d + 1) * ctx.rail_angle_delta -
      2 * ctx.inner_dtheta
    let inner_angle_delta = (inner_end_angle - inner_start_angle) /
      ctx.segments_per_rail.to_double()
    let outer_start_angle = i_d * ctx.rail_angle_delta
    let outer_end_angle = (i_d + 1) * ctx.rail_angle_delta -
      2 * ctx.outer_dtheta
    let outer_angle_delta = (outer_end_angle - outer_start_angle) /
      ctx.segments_per_rail.to_double()
    if inner_angle_delta <= 0 || outer_angle_delta <= 0 {
      abort("wire_gap too large with given num_pairs and size")
    }
    let polygon = Array::new(capacity=ctx.segments_per_rail * 2 + 2)
    for j in 0..=ctx.segments_per_rail {
      push_arc_point(
        ctx.center,
        inner_start_angle,
        inner_angle_delta,
        ctx.inner_radius,
        j,
        polygon,
      )
    }
    for j in 0..=ctx.segments_per_rail {
      push_arc_point(
        ctx.center,
        outer_start_angle,
        outer_angle_delta,
        ctx.outer_radius,
        ctx.segments_per_rail - j,
        polygon,
      )
    }
    let area = polygon_area_mm2(polygon)
    let height = if i == 0 {
      ctx.extrude_height +
      1.5 * params.wire_width +
      params.front_thickness +
      params.back_thickness
    } else {
      ctx.max_axial_connector_top_zs -
      ctx.lower_z +
      params.front_thickness +
      params.back_thickness
    }
    cage = totals_add_prism(cage, area, height)
  }

  // connector pre-calcs (same as make_bfem_cage)
  let rotations = Array::new(capacity=ctx.npairs)
  let line_lengths = Array::new(capacity=ctx.npairs)
  let zs = Array::new(capacity=ctx.npairs)
  for i in 0..<ctx.npairs {
    let i_d = i.to_double()
    zs.push(ctx.lower_z + i_d * ctx.delta_z)
    rotations.push(-@math.PI * i_d / ctx.num_pairs)
    line_lengths.push(
      (ctx.num_pairs - i_d) * (params.wire_width + params.wire_gap),
    )
  }

  // helix connectors + exit wires
  for i in 0..<ctx.npairs {
    let ni = i + 1
    let i_d = i.to_double()
    let z = zs[i] + params.wire_width
    let rotation = rotations[i]
    let line_length = line_lengths[i]
    let inner_start_angle = -i_d * ctx.rail_angle_delta
    let inner_end_angle = -(i_d - 1) * ctx.rail_angle_delta -
      2 * ctx.inner_dtheta
    let inner_angle_delta = (inner_end_angle - inner_start_angle) /
      ctx.segments_per_rail.to_double()

    // front/bottom red connector
    let polygon = gen_inner_arc_points(
      ctx, inner_start_angle, inner_angle_delta,
    )
    let connector_radius = ctx.inner_radius - line_length
    let t_angle = rotation + @math.asin(params.wire_width / connector_radius)
    let tx = params.pos.0 + connector_radius * @math.cos(t_angle)
    let ty = params.pos.1 + connector_radius * @math.sin(t_angle)
    let sx = params.pos.0 + connector_radius * @math.cos(rotation)
    let sy = params.pos.1 + connector_radius * @math.sin(rotation)
    polygon.push((tx, ty))
    polygon.push((sx, sy))
    let area = polygon_area_mm2(polygon)
    let bottom_thickness = z - ctx.lower_z + params.front_thickness
    cage = totals_add_prism(cage, area, bottom_thickness)

    // back/top red post (rectangle area ~ wire_width^2)
    let mut top_angle = rotation
    if i_d > 0 {
      let top_hww = 0.5 * @math.asin(params.wire_width / (2 * ctx.outer_radius))
      top_angle = rotation - ctx.rail_angle_delta / 2 + top_hww
    }
    let top_helix_z = z + ctx.coil_height - 2 * params.wire_width
    let over_height = ctx.max_axial_connector_top_zs -
      top_helix_z +
      params.back_thickness
    cage = totals_add_prism(
      cage,
      params.wire_width * params.wire_width,
      over_height,
    )

    // back/top red over (arc polygon + 2 points)
    let over_start_angle = -(i_d + 1) * ctx.rail_angle_delta
    let polygon = gen_inner_arc_points(ctx, over_start_angle, inner_angle_delta)
    let sx4 = params.pos.0 + connector_radius * @math.cos(top_angle)
    let sy4 = params.pos.1 + connector_radius * @math.sin(top_angle)
    let sx2 = params.pos.0 +
      (connector_radius + params.wire_width) * @math.cos(top_angle)
    let sy2 = params.pos.1 +
      (connector_radius + params.wire_width) * @math.sin(top_angle)
    let sx3 = sx2 + params.wire_width * @math.cos(top_angle - @math.PI / 2)
    let sy3 = sy2 + params.wire_width * @math.sin(top_angle - @math.PI / 2)
    polygon.push((sx2, sy2))
    polygon.push((sx3, sy3))
    let area = polygon_area_mm2(polygon)
    let top_thickness = if i_d == ctx.num_pairs {
      over_height
    } else {
      over_height - params.wire_width - params.wire_gap
    }
    cage = totals_add_prism(cage, area, top_thickness - params.wire_gap)

    // red helix link (only for i > 0)
    if i > 0 {
      let sx5 = params.pos.0 + connector_radius * @math.cos(rotation)
      let sy5 = params.pos.1 + connector_radius * @math.sin(rotation)
      let sx6 = params.pos.0 +
        (connector_radius + params.wire_width) * @math.cos(rotation)
      let sy6 = params.pos.1 +
        (connector_radius + params.wire_width) * @math.sin(rotation)
      let polygon = [(sx5, sy5), (sx6, sy6), (sx2, sy2), (sx4, sy4)]
      let area = polygon_area_mm2(polygon)
      cage = totals_add_prism(cage, area, params.wire_width)
    }

    // front/bottom green connector (opposite)
    let polygon = gen_inner_arc_points(
      ctx,
      inner_start_angle + @math.PI,
      inner_angle_delta,
    )
    let sx = params.pos.0 + connector_radius * @math.cos(rotation + @math.PI)
    let sy = params.pos.1 + connector_radius * @math.sin(rotation + @math.PI)
    let tx = params.pos.0 + connector_radius * @math.cos(t_angle + @math.PI)
    let ty = params.pos.1 + connector_radius * @math.sin(t_angle + @math.PI)
    polygon.push((tx, ty))
    polygon.push((sx, sy))
    let area = polygon_area_mm2(polygon)
    cage = totals_add_prism(cage, area, bottom_thickness)

    // even / green back-top segments
    let connector_dtheta = @math.asin(params.wire_gap / (2 * connector_radius))
    let mut top_angle2 = top_angle
    if ni >= ctx.npairs {
      top_angle2 = rotation - connector_dtheta
    }
    // outer final connector rectangle (only on last pair)
    if ni >= ctx.npairs {
      cage = totals_add_prism(
        cage,
        params.wire_width * params.wire_width,
        params.wire_width,
      )
      // inner flat-top output connector
      let flat_top_height = 2.5 * params.wire_width + params.back_thickness
      // polygon area is not constant; approximate with its actual quad area
      let angle_diff = ctx.rail_angle_delta - 2 * ctx.outer_dtheta
      let sx4 = params.pos.0 +
        connector_radius * @math.cos(top_angle2 + @math.PI)
      let sy4 = params.pos.1 +
        connector_radius * @math.sin(top_angle2 + @math.PI)
      let sx1 = params.pos.0 +
        connector_radius * @math.cos(top_angle2 + @math.PI - angle_diff)
      let sy1 = params.pos.1 +
        connector_radius * @math.sin(top_angle2 + @math.PI - angle_diff)
      let ew_inner_radius = connector_radius -
        0.6 * params.exit_wire_separation -
        params.exit_wire_diameter
      let s2 = vertex_at(
        center=(params.pos.0, params.pos.1),
        radius=ew_inner_radius,
        angle=top_angle2 + @math.PI,
      )
      let s3 = vertex_at(
        center=(params.pos.0, params.pos.1),
        radius=ew_inner_radius,
        angle=top_angle2 + @math.PI - angle_diff,
      )
      let polygon = [(sx4, sy4), (sx1, sy1), s3, s2]
      let area = polygon_area_mm2(polygon)
      cage = totals_add_prism(cage, area, flat_top_height)

      // exit wires: two vertical cylinders
      if !params.nowires {
        let r = params.exit_wire_diameter / 2
        let area = circle_polygon_area_mm2(r, 12)
        exit_wires = totals_add_prism(exit_wires, area, params.connector_length)
        exit_wires = totals_add_prism(exit_wires, area, params.connector_length)
      }
    }
    if ni < ctx.npairs {
      // green vertical post: square cross-section
      cage = totals_add_prism(
        cage,
        params.wire_width * params.wire_width,
        over_height,
      )

      // green over part: arc polygon + 2 points
      let over_start_angle = -(i_d + 1) * ctx.rail_angle_delta + @math.PI
      let polygon = gen_inner_arc_points(
        ctx, over_start_angle, inner_angle_delta,
      )
      // post.top_p0 and post.top_p1 correspond to (sx2,sy2) and (sx3,sy3)
      // for the even coil post at angle top_angle2+PI.
      let sx2 = params.pos.0 +
        (connector_radius + params.wire_width) *
        @math.cos(top_angle2 + @math.PI)
      let sy2 = params.pos.1 +
        (connector_radius + params.wire_width) *
        @math.sin(top_angle2 + @math.PI)
      let sx3 = sx2 + params.wire_width * @math.cos(top_angle2 + @math.PI / 2)
      let sy3 = sy2 + params.wire_width * @math.sin(top_angle2 + @math.PI / 2)
      polygon.push((sx2, sy2))
      polygon.push((sx3, sy3))
      let area = polygon_area_mm2(polygon)
      cage = totals_add_prism(cage, area, top_thickness - params.wire_gap)
    }
    if ni > 1 {
      // green helix link wedge (quadrilateral swept in Z)
      let start_angle = top_angle2 + @math.PI
      let end_angle = rotation + @math.PI
      let sx5 = params.pos.0 + connector_radius * @math.cos(end_angle)
      let sy5 = params.pos.1 + connector_radius * @math.sin(end_angle)
      let sx6 = params.pos.0 +
        (connector_radius + params.wire_width) * @math.cos(end_angle)
      let sy6 = params.pos.1 +
        (connector_radius + params.wire_width) * @math.sin(end_angle)
      let sx2 = params.pos.0 +
        (connector_radius + params.wire_width) * @math.cos(start_angle)
      let sy2 = params.pos.1 +
        (connector_radius + params.wire_width) * @math.sin(start_angle)
      let sx4 = params.pos.0 + connector_radius * @math.cos(start_angle)
      let sy4 = params.pos.1 + connector_radius * @math.sin(start_angle)
      let polygon = [(sx5, sy5), (sx6, sy6), (sx2, sy2), (sx4, sy4)]
      let area = polygon_area_mm2(polygon)
      cage = totals_add_prism(cage, area, params.wire_width)
    }
  }
  { cage, exit_wires }
}
