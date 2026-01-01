///|
using @cad {type SceneNode, type Vec2, type Vec3}

///|
struct VerticalPostWedge {
  post : SceneNode
  top_p0 : Vec2
  top_p1 : Vec2
}

///|
struct VerticalWedge {
  wedge : SceneNode
  // points : Array[Vec2]
}

///|
struct VerticalCylinder {
  cylinder : SceneNode
  // points : Array[Vec2]
}

///|
/// solve_for_t solve the provided function for t where 0<=t<=1.
/// If the solution can't be found, t=2 or t=-1 are returned to signify an error.
fn solve_for_t(d : Double, f : (Double) -> Double) -> Double {
  let d1 = f(1)
  if d > d1 {
    return 2
  }
  let d0 = f(0)
  if d < d0 {
    return -1
  }
  let mut t = 0.5
  let mut dt = 0.25
  for {
    let err = f(t) - d
    if err.abs() < 0.005 {
      return t
    }
    if err > 0 {
      t = t - dt
    } else {
      t = t + dt
    }
    dt = dt / 2
  }
}

///|
/// vertex_at generates a vertex at an angle and radius.
///
/// args:
///     center -- center of circle
///     radius -- radius of vertex
///     angle  -- angle of of vertex in radians
///
/// returns:
///     vertex -- (as a vector)
fn vertex_at(center~ : Vec2, radius~ : Double, angle~ : Double) -> Vec2 {
  (center.0 + radius * @math.cos(angle), center.1 + radius * @math.sin(angle))
}

///|
/// center_of_face returns the center point of a face.
///
/// args:
///     points -- table of points (vectors)
///
///
/// returns:
///     vector -- represents center of face
fn center_of_face(points : Array[Vec2]) -> Vec2 {
  let mut sum = (0.0, 0.0)
  for pt in points {
    sum = (sum.0 + pt.0, sum.1 + pt.1)
  }
  let count = points.length().to_double()
  (sum.0 / count, sum.1 / count)
}

///|
/// make_vertical_post_wedge generates a vertical wire post wedge at a given radius and start_angle.
/// It extrudes upward.
///
/// args:
///     pos -- vector(x,y,z) - lower origin corner of base face of vertical post
///     inner_radius -- inner radius of vertical wire post
///     start_angle -- start angle of wire post
///     normal_angle -- 90 degree rotation of start_angle in the outward direction
///     post_height -- height of wire post
///     wire_width -- width and depth of wire post at the inner_radius
///
/// returns table of:
///     mesh -- mesh of generated geometry
///     top_p0 -- corner vertex of top connection edge
///     top_p1 -- other vertex of top connection edge
fn make_vertical_post_wedge(
  pos~ : Vec3,
  inner_radius~ : Double,
  start_angle~ : Double,
  normal_angle~ : Double,
  post_height~ : Double,
  wire_width~ : Double,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> VerticalPostWedge {
  let sx4 = pos.0 + inner_radius * @math.cos(start_angle)
  let sy4 = pos.1 + inner_radius * @math.sin(start_angle)
  let sx1 = sx4 + wire_width * @math.cos(normal_angle)
  let sy1 = sy4 + wire_width * @math.sin(normal_angle)
  let sx2 = pos.0 + (inner_radius + wire_width) * @math.cos(start_angle)
  let sy2 = pos.1 + (inner_radius + wire_width) * @math.sin(start_angle)
  let sx3 = sx2 + wire_width * @math.cos(normal_angle)
  let sy3 = sy2 + wire_width * @math.sin(normal_angle)
  let points = [(sx1, sy1), (sx4, sy4), (sx2, sy2), (sx3, sy3)]
  let post = @cad.ExtrudedProfile::new(points, post_height)
    .with_name("vertical-post-wedge-r\{inner_radius}-a\{start_angle}")
    .with_color(color)
    .translate(z=pos.2)
  { post, top_p0: (sx2, sy2), top_p1: (sx3, sy3) }
}

///|
/// make_wedge generates a vertical wedge.
/// It extrudes upward.
fn make_wedge(
  pos~ : Vec3,
  inner_radius~ : Double,
  start_angle~ : Double,
  end_angle~ : Double,
  radial_length~ : Double,
  height~ : Double,
  color? : @cad.Rgb = @cad.Rgb::red(),
  name? : String = "vertical-wedge-r\{inner_radius}-a\{start_angle}",
  trim_last_edge? : Bool = false,
  wire_gap? : Double = 0.0, // only used if trim_last_edge is true
) -> VerticalWedge {
  let mut sx4 = pos.0 + inner_radius * @math.cos(start_angle)
  let mut sy4 = pos.1 + inner_radius * @math.sin(start_angle)
  if trim_last_edge {
    let trim_angle = start_angle + @math.asin(wire_gap / inner_radius)
    sx4 = pos.0 + inner_radius * @math.cos(trim_angle)
    sy4 = pos.1 + inner_radius * @math.sin(trim_angle)
  }
  let sx2 = pos.0 + (inner_radius + radial_length) * @math.cos(start_angle)
  let sy2 = pos.1 + (inner_radius + radial_length) * @math.sin(start_angle)
  let sx5 = pos.0 + inner_radius * @math.cos(end_angle)
  let sy5 = pos.1 + inner_radius * @math.sin(end_angle)
  let sx6 = pos.0 + (inner_radius + radial_length) * @math.cos(end_angle)
  let sy6 = pos.1 + (inner_radius + radial_length) * @math.sin(end_angle)
  let points = [(sx5, sy5), (sx6, sy6), (sx2, sy2), (sx4, sy4)]
  let wedge = @cad.ExtrudedProfile::new(points, height)
    .with_name(name)
    .with_color(color)
    .translate(z=pos.2)
  { wedge, } // points }
}

///|
/// make_cylinder makes a n-sided vertical cylinder at the given position with the height and radius.
///
/// args:
///     pos -- vector(x,y,z) - center of cylinder base
///     radius -- radius of cylinder
///     segments -- number of radial segments
///     height -- height of cylinder
///
/// returns table of:
///     mesh -- mesh of generated geometry
///     points -- vertices around the base circle
fn make_cylinder(
  pos~ : Vec3,
  radius~ : Double,
  segments~ : Int,
  height~ : Double,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> VerticalCylinder {
  let points = []
  for i in 1..=segments {
    let angle = -2.0 * @math.PI * i.to_double() / segments.to_double() // face downward
    let x = pos.0 + radius * @math.cos(angle)
    let y = pos.1 + radius * @math.sin(angle)
    points.push((x, y))
  }
  let cylinder = @cad.ExtrudedProfile::new(points, height)
    .with_name("vertical-cylinder-r\{radius}")
    .with_color(color)
    .translate(z=pos.2)
  { cylinder, } // points }
}

///|
/// make_bfem_cage makes a wire cage around the bifilar electromagnet and wires up the coils.
/// It also returns an optional support structure to hold the coils.
fn make_bfem_cage(
  size~ : Vec3,
  params~ : Params,
) -> (Array[@cad.SceneNode], Array[@cad.SceneNode]) {
  let red_cage_wire_support_info = Array::new(capacity=params.num_pairs)
  let green_cage_wire_support_info = Array::new(capacity=params.num_pairs)
  let npairs = params.num_pairs
  let num_pairs = npairs.to_double()
  let mut segments_per_rail = @math.ceil(
    0.5 * params.num_segs.to_double() / num_pairs,
  ).to_int()
  if segments_per_rail < 2 {
    segments_per_rail = 2
  }

  //
  let lower_z = params.pos.2 - params.wire_width / 2
  let coil_height = 2.0 *
    params.vert_turns *
    (params.wire_width + params.wire_gap) +
    params.wire_width
  let extrude_height = coil_height + params.wire_gap + params.wire_width
  let rail_angle_delta = @math.PI / num_pairs
  let inner_radius = size.0 + params.wire_width / 2 + params.wire_gap
  let outer_radius = inner_radius + params.radial_thickness
  let inner_dtheta = @math.asin(params.wire_gap / (2 * inner_radius))
  let outer_dtheta = @math.asin(params.wire_gap / (2 * outer_radius))
  let delta_z = (params.wire_gap + params.wire_width) / (num_pairs - 1)

  //
  let new_point = fn(
    j : Int,
    start_angle : Double,
    angle_delta : Double,
    r : Double,
    points : Array[Vec2],
  ) -> Unit {
    let angle = start_angle + j.to_double() * angle_delta
    let x = params.pos.0 + r * @math.cos(angle)
    let y = params.pos.1 + r * @math.sin(angle)
    let point = (x, y)
    points.push(point)
  }

  // first, generate the long axial connectors
  let axial_connector_top_zs = Array::new(capacity=2 * npairs)
  let max_axial_connector_top_zs = extrude_height +
    lower_z +
    (num_pairs - 1) * delta_z
  let wire_nodes = []
  let support_nodes = []
  for i in 0..<(2 * npairs) {
    let ni = i + 1
    let i = i.to_double()
    let inner_start_angle = i * rail_angle_delta
    let inner_end_angle = (i + 1) * rail_angle_delta - 2 * inner_dtheta
    let inner_angle_delta = (inner_end_angle - inner_start_angle) /
      segments_per_rail.to_double()
    //
    let outer_start_angle = i * rail_angle_delta
    let outer_end_angle = (i + 1) * rail_angle_delta - 2 * outer_dtheta
    let outer_angle_delta = (outer_end_angle - outer_start_angle) /
      segments_per_rail.to_double()
    //
    if inner_angle_delta <= 0 || outer_angle_delta <= 0 {
      abort("wire_gap too large with given num_pairs and size")
    }
    //
    let z = lower_z + (num_pairs - i) % num_pairs * delta_z
    axial_connector_top_zs.push(z + extrude_height)
    //
    let polygon = Array::new(capacity=segments_per_rail * 2 + 2)
    // inner points:
    for j in 0..=segments_per_rail {
      new_point(j, inner_start_angle, inner_angle_delta, inner_radius, polygon)
    }
    // outer points:
    for j in 0..=segments_per_rail {
      new_point(
        segments_per_rail - j,
        outer_start_angle,
        outer_angle_delta,
        outer_radius,
        polygon,
      )
    }
    //
    if i == 0 {
      // final output connector of coil 1 (at outer edge)
      let node = @cad.ExtrudedProfile::new(
          polygon,
          extrude_height +
          1.5 * params.wire_width +
          params.front_thickness +
          params.back_thickness,
        )
        .with_name("bfem-cage-axial-connector-0")
        .translate(z=lower_z - params.front_thickness)
      wire_nodes.push(node.with_color(@cad.Rgb::red()))
    } else {
      let node = @cad.ExtrudedProfile::new(
          polygon,
          max_axial_connector_top_zs -
          lower_z +
          params.front_thickness +
          params.back_thickness,
        )
        .with_name("bfem-cage-axial-connector-\{i.to_int()}")
        .translate(z=lower_z - params.front_thickness)
      let color = if ni <= npairs {
        @cad.Rgb::green()
      } else if ni == npairs + 1 {
        @cad.Rgb::orange() // half-way transition from even to odd coils
      } else {
        @cad.Rgb::red()
      }
      wire_nodes.push(node.with_color(color))
    }
  }

  // Pre-calculate important values for all coil connectors
  // rotations represents the angle around the coil where the connector starts
  let rotations = Array::new(capacity=npairs)
  let line_lengths = Array::new(capacity=npairs)
  let zs = Array::new(capacity=npairs)
  for i in 0..<npairs {
    let i = i.to_double()
    zs.push(lower_z + i * delta_z)
    // Create the connectors to the ends of the coils:
    rotations.push(-@math.PI * i / num_pairs)
    line_lengths.push((num_pairs - i) * (params.wire_width + params.wire_gap))
  }

  //
  let gen_points = fn(inner_start_angle, inner_angle_delta) {
    let points = Array::new(capacity=segments_per_rail + 1)
    // inner points:
    for j in 0..=segments_per_rail {
      new_point(j, inner_start_angle, inner_angle_delta, inner_radius, points)
    }
    return points
  }

  // now generate both front/bottom and back/top connectors to the helices
  for i in 0..<npairs {
    let z = zs[i] + params.wire_width
    let rotation = rotations[i]
    let line_length = line_lengths[i]
    let ni = i + 1
    let i = i.to_double()
    let inner_start_angle = -i * rail_angle_delta
    let inner_end_angle = -(i - 1) * rail_angle_delta - 2 * inner_dtheta
    let inner_angle_delta = (inner_end_angle - inner_start_angle) /
      segments_per_rail.to_double()
    let polygon = gen_points(inner_start_angle, inner_angle_delta)
    let connector_radius = inner_radius - line_length
    let connector_dtheta = @math.asin(params.wire_gap / (2 * connector_radius))
    let sx = params.pos.0 + connector_radius * @math.cos(rotation)
    let sy = params.pos.1 + connector_radius * @math.sin(rotation)

    // calculate the final point that will be params.wire_width away from the next wire
    // this is the front/bottom of the design

    let t_angle = rotation + @math.asin(params.wire_width / connector_radius)
    let tx = params.pos.0 + connector_radius * @math.cos(t_angle)
    let ty = params.pos.1 + connector_radius * @math.sin(t_angle)
    polygon.push((tx, ty))
    polygon.push((sx, sy))

    // Save this info so that the cage can be `tolerance` away from these wires:
    if ni > 1 {
      let end_angle = rotations[ni - 2] -
        @math.asin(params.wire_gap / connector_radius)
      let start_angle = if ni < npairs {
        rotations[ni - 1] - 0.1 // temporary debugging hack
      } else {
        rotations[ni - 1]
      }
      red_cage_wire_support_info.push({
        inner_radius: connector_radius,
        start_angle,
        end_angle,
      })
    }

    // this connects the bottom/front helix to the axial connector
    let bottom_thickness = z - lower_z + params.front_thickness
    let node = @cad.ExtrudedProfile::new(polygon, bottom_thickness)
      .with_name("bfem-cage-bottom-front-\{i.to_int()}")
      .translate(z=z - bottom_thickness)
    wire_nodes.push(node.with_color(@cad.Rgb::red()))

    // add a vertical post to the back/top of the design for connecting the coils
    // this is the back/top of the design
    // these are the odd coils (1, 3, 5, etc.)
    let mut top_angle = rotation
    if i > 0 {
      // half wire-width at outer radius in radians
      let top_hww = 0.5 * @math.asin(params.wire_width / (2 * outer_radius))
      top_angle = rotation - rail_angle_delta / 2 + top_hww
    }
    let top_helix_z = z + coil_height - 2 * params.wire_width
    let sx4 = params.pos.0 + connector_radius * @math.cos(top_angle)
    let sy4 = params.pos.1 + connector_radius * @math.sin(top_angle)
    let sx1 = sx4 + params.wire_width * @math.cos(top_angle - @math.PI / 2)
    let sy1 = sy4 + params.wire_width * @math.sin(top_angle - @math.PI / 2)
    let sx2 = params.pos.0 +
      (connector_radius + params.wire_width) * @math.cos(top_angle)
    let sy2 = params.pos.1 +
      (connector_radius + params.wire_width) * @math.sin(top_angle)
    let sx3 = sx2 + params.wire_width * @math.cos(top_angle - @math.PI / 2)
    let sy3 = sy2 + params.wire_width * @math.sin(top_angle - @math.PI / 2)

    // this is the "up" part of the "up-and-over" connector on the back/top of the design for the odd coils:
    // note the the "up" part for the last odd coil is simply the wire width.
    let polygon = [(sx1, sy1), (sx4, sy4), (sx2, sy2), (sx3, sy3)]
    let over_height = max_axial_connector_top_zs -
      top_helix_z +
      params.back_thickness // flat top/back (connector side)
    let node = @cad.ExtrudedProfile::new(polygon, over_height)
      .with_name("bfem-cage-odd-top-back-\{i.to_int()}")
      .translate(z=top_helix_z)
    wire_nodes.push(node.with_color(@cad.Rgb::red()))

    // this is the "over" part of the "up-and-over" connector on the back/top of the design for the odd coils:
    let over_start_angle = -(i + 1) * rail_angle_delta
    let polygon = gen_points(over_start_angle, inner_angle_delta)
    polygon.push((sx2, sy2))
    polygon.push((sx3, sy3))
    let top_thickness = if i == num_pairs {
      over_height
    } else {
      over_height - params.wire_width - params.wire_gap
    }
    let node = @cad.ExtrudedProfile::new(
        polygon,
        top_thickness - params.wire_gap,
      )
      .with_name("bfem-cage-over-\{i.to_int()}")
      .translate(z=top_helix_z + over_height - top_thickness + params.wire_gap)
    wire_nodes.push(node.with_color(@cad.Rgb::red()))

    // for all but the first coil, the helix needs to be connected to the shifted back/top "up-and-over" connector
    if i > 0 {
      let sx5 = params.pos.0 + connector_radius * @math.cos(rotation)
      let sy5 = params.pos.1 + connector_radius * @math.sin(rotation)
      let sx6 = params.pos.0 +
        (connector_radius + params.wire_width) * @math.cos(rotation)
      let sy6 = params.pos.1 +
        (connector_radius + params.wire_width) * @math.sin(rotation)
      let polygon = [(sx5, sy5), (sx6, sy6), (sx2, sy2), (sx4, sy4)]
      let node = @cad.ExtrudedProfile::new(polygon, params.wire_width)
        .with_name("bfem-cage-top-connector-\{i.to_int()}")
        .translate(z=top_helix_z)
      wire_nodes.push(node.with_color(@cad.Rgb::red()))
    }

    // second connection for pair directly opposite first connection
    // this is the front/bottom of the design
    let polygon = gen_points(inner_start_angle + @math.PI, inner_angle_delta)
    let sx = params.pos.0 + connector_radius * @math.cos(rotation + @math.PI)
    let sy = params.pos.1 + connector_radius * @math.sin(rotation + @math.PI)
    let tx = params.pos.0 + connector_radius * @math.cos(t_angle + @math.PI)
    let ty = params.pos.1 + connector_radius * @math.sin(t_angle + @math.PI)
    polygon.push((tx, ty))
    polygon.push((sx, sy))
    let node = @cad.ExtrudedProfile::new(polygon, bottom_thickness)
      .with_name("bfem-cage-second-bottom-front-\{i.to_int()}")
      .translate(z=z - bottom_thickness)
    wire_nodes.push(node.with_color(@cad.Rgb::green()))

    // Save this information so that the cage can be `tolerance` away from these wires:
    if ni > 1 {
      let end_angle = rotations[ni - 2] -
        @math.asin(params.wire_gap / connector_radius) +
        @math.PI
      let start_angle = @math.PI +
        (if ni < npairs {
          rotations[ni - 1] - 0.1 // temporary debugging hack
        } else {
          rotations[ni - 1]
        })
      green_cage_wire_support_info.push({
        inner_radius: connector_radius,
        start_angle,
        end_angle,
      })
    }

    // add a vertical post to the back/top of the design for connecting the coils
    // this is the back/top of the design
    // these are the even coils (2, 4, 6, etc.)

    if ni >= npairs {
      // final output connector of last coil
      top_angle = rotation - connector_dtheta
    }
    let top_helix_z = z + coil_height - 2 * params.wire_width
    let sx4 = params.pos.0 + connector_radius * @math.cos(top_angle + @math.PI)
    let sy4 = params.pos.1 + connector_radius * @math.sin(top_angle + @math.PI)
    let mut sx1 = sx4 + params.wire_width * @math.cos(top_angle + @math.PI / 2)
    let mut sy1 = sy4 + params.wire_width * @math.sin(top_angle + @math.PI / 2)
    let sx2 = params.pos.0 +
      (connector_radius + params.wire_width) * @math.cos(top_angle + @math.PI)
    let sy2 = params.pos.1 +
      (connector_radius + params.wire_width) * @math.sin(top_angle + @math.PI)
    let mut sx3 = sx2 + params.wire_width * @math.cos(top_angle + @math.PI / 2)
    let mut sy3 = sy2 + params.wire_width * @math.sin(top_angle + @math.PI / 2)
    if ni >= npairs { // final output connector of last coil
      let angle_diff = rail_angle_delta - 2 * outer_dtheta
      sx1 = params.pos.0 +
        connector_radius * @math.cos(top_angle + @math.PI - angle_diff)
      sy1 = params.pos.1 +
        connector_radius * @math.sin(top_angle + @math.PI - angle_diff)
      sx3 = params.pos.0 +
        (connector_radius + params.wire_width) *
        @math.cos(top_angle + @math.PI - angle_diff)
      sy3 = params.pos.1 +
        (connector_radius + params.wire_width) *
        @math.sin(top_angle + @math.PI - angle_diff)
    }
    let polygon = [(sx1, sy1), (sx4, sy4), (sx2, sy2), (sx3, sy3)]

    //
    if ni >= npairs { // final output connector of last coil (closer to center)
      let node = @cad.ExtrudedProfile::new(polygon, params.wire_width)
        .with_name("bfem-cage-even-final-last-coil-\{i.to_int()}")
        .translate(z=top_helix_z)
      wire_nodes.push(node.with_color(@cad.Rgb::green()))
      // generate inner final output connector of last coil with same radial thickness as other connector
      let angle_diff = rail_angle_delta - 2 * outer_dtheta
      let ew_inner_radius = connector_radius -
        0.6 * params.exit_wire_separation -
        params.exit_wire_diameter
      let s2 = vertex_at(
        center=(params.pos.0, params.pos.1),
        radius=ew_inner_radius,
        angle=top_angle + @math.PI,
      )
      let s3 = vertex_at(
        center=(params.pos.0, params.pos.1),
        radius=ew_inner_radius,
        angle=top_angle + @math.PI - angle_diff,
      )
      let polygon = [(sx4, sy4), (sx1, sy1), s3, s2]
      let flat_top_height = 2.5 * params.wire_width + params.back_thickness
      let node = @cad.ExtrudedProfile::new(polygon, flat_top_height)
        .with_name("bfem-cage-even-flat-top-final-last-coil-\{i.to_int()}")
        .translate(z=top_helix_z)
      wire_nodes.push(node.with_color(@cad.Rgb::green()))

      // now make the exit wire cylinders
      if !params.nowires {
        let inner_wire_post_center = center_of_face(polygon) // + vector(0,0,flat_top_height)
        let mut inner_wire_pos = inner_wire_post_center
        let outer_wire_radius = (inner_radius + outer_radius) / 2
        let outer_wire_dtheta = @math.asin(
          params.wire_gap / (2 * outer_wire_radius),
        )
        let outer_wire_start_angle = 0.0
        let outer_wire_end_angle = rail_angle_delta - 2 * outer_wire_dtheta
        let outer_wire_post_center = vertex_at(
          center=(params.pos.0, params.pos.1), // , inner_wire_pos.y),
          radius=outer_wire_radius,
          angle=(outer_wire_end_angle - outer_wire_start_angle) / 2,
        )
        let mut outer_wire_pos = outer_wire_post_center
        // outer_wire_pos = (outer_wire_pos.0, outer_wire_pos.1) // , inner_wire_pos.y
        let centers_distance = vector_length(
          outer_wire_post_center, inner_wire_post_center,
        )
        if centers_distance < params.exit_wire_separation {
          let pa = inner_wire_post_center
          let va = (polygon[3].0, polygon[3].1) //, inner_wire_pos.y)
          let pb = outer_wire_post_center
          let vb = vertex_at(
            center=(params.pos.0, params.pos.1), // , inner_wire_pos.y),
            radius=(inner_radius + outer_radius) / 2,
            angle=outer_wire_start_angle,
          )

          //
          let f1 = fn(t) {
            (pa.0 + t * (va.0 - pa.0), pa.1 + t * (va.1 - pa.1))
          }
          let f2 = fn(t) {
            (pb.0 + t * (vb.0 - pb.0), pb.1 + t * (vb.1 - pb.1))
          }
          let d = params.exit_wire_separation
          let t = solve_for_t(d, fn(t) { vector_length(f1(t), f2(t)) })
          inner_wire_pos = f1(t)
          outer_wire_pos = f2(t)
        }
        let inner_exit_wire = make_cylinder(
          pos=(
            inner_wire_pos.0,
            inner_wire_pos.1,
            top_helix_z + flat_top_height,
          ),
          radius=params.exit_wire_diameter / 2,
          segments=12,
          height=params.connector_length,
        )
        // Ops.merge(out_mesh, inner_exit_wire.mesh)
        wire_nodes.push(inner_exit_wire.cylinder.with_color(@cad.Rgb::green()))
        let outer_exit_wire = make_cylinder(
          pos=(
            outer_wire_pos.0,
            outer_wire_pos.1,
            top_helix_z + flat_top_height,
          ),
          radius=params.exit_wire_diameter / 2,
          segments=12,
          height=params.connector_length,
        )
        // Ops.merge(out_mesh, outer_exit_wire.mesh)
        wire_nodes.push(outer_exit_wire.cylinder.with_color(@cad.Rgb::red()))
      }
    }

    //
    if ni < npairs {
      // this is the "up" part of the "up-and-over" connector on the back/top of the design for the even coils:
      let post = make_vertical_post_wedge(
        pos=(params.pos.0, params.pos.1, params.pos.2 + top_helix_z),
        inner_radius=connector_radius,
        start_angle=top_angle + @math.PI,
        normal_angle=top_angle + @math.PI / 2,
        post_height=over_height,
        wire_width=params.wire_width,
      )
      wire_nodes.push(post.post.with_color(@cad.Rgb::green()))
      // this is the "over" part of the "up-and-over" connector on the back/top of the design for the even coils:
      let over_start_angle = -(i + 1) * rail_angle_delta + @math.PI
      let polygon = gen_points(over_start_angle, inner_angle_delta)
      polygon.push(post.top_p0)
      polygon.push(post.top_p1)
      let node = @cad.ExtrudedProfile::new(
          polygon,
          top_thickness - params.wire_gap,
        )
        .with_name("bfem-cage-even-over-top-coil-\{i.to_int()}")
        .translate(
          z=top_helix_z + over_height - top_thickness + params.wire_gap,
        )
      wire_nodes.push(node.with_color(@cad.Rgb::green()))
    }
    // for all but the first connector, the helix needs to be connected to the shifted connector
    if ni > 1 {
      let wire = make_wedge(
        pos=(params.pos.0, params.pos.1, top_helix_z),
        inner_radius=connector_radius,
        start_angle=top_angle + @math.PI,
        end_angle=rotation + @math.PI,
        radial_length=params.wire_width,
        height=params.wire_width,
      )
      wire_nodes.push(wire.wedge.with_color(@cad.Rgb::green()))
    }
  }

  //
  if !params.nosupport {
    // Finally, add support structures
    let shaft_pos = (
      params.pos.0,
      params.pos.1,
      params.pos.2 - params.wire_width / 2 - params.front_thickness,
    )
    let shaft_radius = params.inner_diam / 2 - params.tolerance
    let front_inner_shaft = make_cylinder(
      pos=shaft_pos,
      radius=shaft_radius,
      segments=params.num_segs,
      // height=coil_height + params.front_thickness + params.back_thickness, // flush with top coil
      height=extrude_height +
        1.5 * params.wire_width +
        params.front_thickness +
        params.back_thickness +
        params.connector_length,
    )
    support_nodes.push(front_inner_shaft.cylinder.with_color(@cad.Rgb::blue()))

    //
    for idx, info in red_cage_wire_support_info {
      let height = params.wire_width -
        info.end_angle / @math.PI * size.2 / 2 -
        params.tolerance
      let trim_last_edge = idx == red_cage_wire_support_info.length() - 1
      add_support(
        idx,
        "red",
        info,
        shaft_pos~,
        shaft_radius~,
        height~,
        params~,
        support_nodes~,
        trim_last_edge~,
      )
    }
    for idx, info in green_cage_wire_support_info {
      let height = params.wire_width +
        (@math.PI - info.end_angle) / @math.PI * size.2 / 2 -
        params.tolerance
      let trim_last_edge = idx == green_cage_wire_support_info.length() - 1
      add_support(
        idx,
        "green",
        info,
        shaft_pos~,
        shaft_radius~,
        height~,
        params~,
        support_nodes~,
        trim_last_edge~,
      )
    }
  }

  //
  (wire_nodes, support_nodes)
}

///|
struct SupportInfo {
  inner_radius : Double
  start_angle : Double
  end_angle : Double
}

///|
fn add_support(
  idx : Int,
  name : String,
  info : SupportInfo,
  shaft_pos~ : Vec3,
  shaft_radius~ : Double,
  height~ : Double,
  params~ : Params,
  support_nodes~ : Array[@cad.SceneNode],
  trim_last_edge~ : Bool,
) -> Unit {
  let radial_length = info.inner_radius - shaft_radius - params.tolerance
  let support = make_wedge(
    pos=shaft_pos,
    inner_radius=shaft_radius,
    start_angle=info.start_angle,
    end_angle=info.end_angle,
    radial_length~,
    height~,
    name="bfem-cage-\{name}-support-\{idx}",
    trim_last_edge~,
    wire_gap=params.wire_gap,
  )
  support_nodes.push(support.wedge.with_color(@cad.Rgb::blue()))
}

///|
fn vector_length(a : Vec2, b : Vec2) -> Double {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  (dx * dx + dy * dy).sqrt()
}
