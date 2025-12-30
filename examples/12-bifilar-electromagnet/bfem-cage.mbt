///|
using @cad {type SceneNode, type Vec2, type Vec3}

///|
struct VerticalPostWedge {
  post : SceneNode
  top_p0 : Vec3
  top_p1 : Vec3
}

///|
struct VerticalWedge {
  wedge : SceneNode
  points : Array[Vec3]
}

///|
struct VerticalCylinder {
  cylinder : SceneNode
  points : Array[Vec3]
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
fn vertex_at(center : Vec3, radius : Double, angle : Double) -> Vec3 {
  (
    center.0 + radius * @math.cos(angle),
    center.1,
    center.2 + radius * @math.sin(angle),
  )
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
fn center_of_face(points : Array[Vec3]) -> Vec3 {
  let mut sum = (0.0, 0.0, 0.0)
  for pt in points {
    sum = (sum.0 + pt.0, sum.1 + pt.1, sum.2 + pt.2)
  }
  let count = points.length().to_double()
  (sum.0 / count, sum.1 / count, sum.2 / count)
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
  pos : Vec3,
  inner_radius : Double,
  start_angle : Double,
  normal_angle : Double,
  post_height : Double,
  wire_width : Double,
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
  {
    post,
    top_p0: (sx2, sy2, pos.2 + post_height),
    top_p1: (sx3, sy3, pos.2 + post_height),
  }
}

///|
/// make_wedge generates a vertical wedge.
/// It extrudes upward.
///
/// args:
///     pos -- vector(x,y,z) - lower origin corner of base face of vertical wedge
///     inner_radius -- inner radius of arc
///     start_angle -- start angle of arc
///     end_angle -- end angle of arc
///     radial_length -- radial length of wedge
///     height -- height of wedge
///
/// returns table of:
///     mesh - mesh of generated geometry
///     points -- vertices around the base circle
fn make_wedge(
  pos : Vec3,
  inner_radius : Double,
  start_angle : Double,
  end_angle : Double,
  radial_length : Double,
  height : Double,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> VerticalWedge {
  let sx4 = pos.0 + inner_radius * @math.cos(start_angle)
  let sy4 = pos.1 + inner_radius * @math.sin(start_angle)
  let sx2 = pos.0 + (inner_radius + radial_length) * @math.cos(start_angle)
  let sy2 = pos.1 + (inner_radius + radial_length) * @math.sin(start_angle)
  let sx5 = pos.0 + inner_radius * @math.cos(end_angle)
  let sy5 = pos.1 + inner_radius * @math.sin(end_angle)
  let sx6 = pos.0 + (inner_radius + radial_length) * @math.cos(end_angle)
  let sy6 = pos.1 + (inner_radius + radial_length) * @math.sin(end_angle)
  let points = [(sx5, sy5), (sx6, sy6), (sx2, sy2), (sx4, sy4)]
  let wedge = @cad.ExtrudedProfile::new(points, height)
    .with_name("vertical-wedge-r\{inner_radius}-a\{start_angle}")
    .with_color(color)
    .translate(z=pos.2)
  { wedge, points: points.map(fn(pt) { (pt.0, pt.1, pos.2) }) }
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
  pos : Vec3,
  radius : Double,
  segments : Int,
  height : Double,
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
  { cylinder, points: points.map(fn(pt) { (pt.0, pt.1, pos.2) }) }
}

///|
/// make_bfem_cage makes a wire cage around the bifilar electromagnet and wires up the coils.
fn make_bfem_cage(
  pos? : Vec3 = (0, 0, 0), // pos is lowered by wire_width/2
  size? : Vec3 = (10, 0, 10), // wire_width/2 + wire_gap is added to size.
  connector_length? : Double = 12,
  exit_wire_diameter? : Double = 1,
  exit_wire_separation? : Double = 4,
  front_thickness? : Double = 1,
  back_thickness? : Double = 1,
  radial_thickness? : Double = 2,
  inner_radius? : Double = 1,
  tolerance? : Double = 0.1,
  turns? : Double = 1,
  wire_gap? : Double = 1,
  wire_width? : Double = 1,
  segments? : Int = 36,
  num_pairs? : Int = 3,
) -> Array[@cad.SceneNode] {
  let npairs = num_pairs
  let num_pairs = num_pairs.to_double()
  let mut segments_per_rail = @math.ceil(0.5 * segments.to_double() / num_pairs).to_int()
  if segments_per_rail < 2 {
    segments_per_rail = 2
  }

  //
  let lower_z = pos.2 - wire_width / 2
  let coil_height = 2.0 * turns * (wire_width + wire_gap) + wire_width
  let extrude_height = coil_height + wire_gap + wire_width

  // let backbone = Primitives.line(vector(0,0,0), vector(0,1,0), 1)

  let rail_angle_delta = @math.PI / num_pairs
  let inner_radius = size.0 + wire_width / 2 + wire_gap
  let outer_radius = inner_radius + radial_thickness
  let inner_dtheta = @math.asin(wire_gap / (2 * inner_radius))
  let outer_dtheta = @math.asin(wire_gap / (2 * outer_radius))
  let delta_z = if num_pairs > 1 {
    (wire_gap + wire_width) / (num_pairs - 1)
  } else {
    0
  }

  //
  let new_point = fn(
    j : Int,
    start_angle : Double,
    angle_delta : Double,
    r : Double,
    points : Array[Vec2],
  ) -> Unit {
    let angle = start_angle + j.to_double() * angle_delta
    let x = pos.0 + r * @math.cos(angle)
    let y = pos.2 + r * @math.sin(angle)
    let point = (x, y)
    points.push(point)
  }

  // first, generate the long axial connectors
  let axial_connector_top_zs = Array::new(capacity=2 * npairs)
  let max_axial_connector_top_zs = extrude_height +
    lower_z +
    (num_pairs - 1) * delta_z
  let out_nodes = []
  for i in 0..<(2 * npairs) {
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
          extrude_height + 1.5 * wire_width + front_thickness + back_thickness,
        )
        .with_name("bfem-cage-axial-connector-0")
        .translate(z=lower_z - front_thickness)
      out_nodes.push(node)
    } else {
      let node = @cad.ExtrudedProfile::new(
          polygon,
          max_axial_connector_top_zs -
          lower_z +
          front_thickness +
          back_thickness,
        )
        .with_name("bfem-cage-axial-connector-\{i.to_int()}")
        .translate(z=lower_z - front_thickness)
      out_nodes.push(node)
    }
  }

  // Pre-calculate important values for all coil connectors
  let rotations = Array::new(capacity=npairs)
  let line_lengths = Array::new(capacity=npairs)
  let zs = Array::new(capacity=npairs)
  for i in 0..<npairs {
    let i = i.to_double()
    zs.push(lower_z + i * delta_z)
    // Create the connectors to the ends of the coils:
    rotations.push(-@math.PI * i / num_pairs)
    line_lengths.push((num_pairs - i) * (wire_width + wire_gap))
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

  //
  // now generate both front/bottom and back/top connectors to the helices
  for i in 0..<npairs {
    let z = zs[i] + wire_width
    let rotation = rotations[i]
    let line_length = line_lengths[i]
    let i = i.to_double()
    let inner_start_angle = -i * rail_angle_delta
    let inner_end_angle = -(i - 1) * rail_angle_delta - 2 * inner_dtheta
    let inner_angle_delta = (inner_end_angle - inner_start_angle) /
      segments_per_rail.to_double()
    let polygon = gen_points(inner_start_angle, inner_angle_delta)
    let connector_radius = inner_radius - line_length
    let connector_dtheta = @math.asin(wire_gap / (2 * connector_radius))
    let sx = pos.0 + connector_radius * @math.cos(rotation)
    let sy = pos.1 + connector_radius * @math.sin(rotation)

    // calculate the final point that will be wire_width away from the next wire
    // this is the front/bottom of the design

    let t_angle = rotation + @math.asin(wire_width / connector_radius)
    let tx = pos.0 + connector_radius * @math.cos(t_angle)
    let ty = pos.1 + connector_radius * @math.sin(t_angle)
    polygon.push((tx, ty))
    polygon.push((sx, sy))

    // this connects the bottom/front helix to the axial connector
    let bottom_thickness = z - lower_z + front_thickness
    let node = @cad.ExtrudedProfile::new(polygon, bottom_thickness)
      .with_name("bfem-cage-bottom-front-\{i.to_int()}")
      .translate(z=z - bottom_thickness)
    out_nodes.push(node)

    //...
  }

  //
  out_nodes
}

// NodeLibrary:addNodes(
//     {
//         BFEMCage = {
//             label = "Bifilar Electromagnet Cage",
//             op = function(inputs)
//                 let segments_per_rail = @math.ceil(segments / num_pairs / 2)
//                 if segments_per_rail < 2 then
//                     segments_per_rail = 2
//                 end

//                 let lower_y = pos.y - wire_width/2
//                 let coil_height = 2 * turns * (wire_width + wire_gap) + wire_width
//                 let extrude_height = coil_height + wire_gap + wire_width

//                 let backbone = Primitives.line(vector(0,0,0), vector(0,1,0), 1)

//                 let rail_angle_delta = @math.PI / num_pairs
//                 let inner_radius = size.0 + wire_width/2 + wire_gap
//                 let outer_radius = inner_radius + radial_thickness

//                 let inner_dtheta = @math.asin(wire_gap / (2 * inner_radius))
//                 let outer_dtheta = @math.asin(wire_gap / (2 * outer_radius))

//                 let delta_y = num_pairs > 1 and
//                     (wire_gap + wire_width) / (num_pairs - 1) or 0

//                 let function new_point(j, start_angle, angle_delta, r, y, points)
//                     let angle = start_angle + j * angle_delta
//                     let x = pos.0 + r * @math.cos(angle)
//                     let z = pos.z + r * @math.sin(angle)
//                     let point = vector(x, y, z) -- y is "up"
//                     table.insert(points, point)
//                 end

//                 -- first, generate the long axial connectors
//                 let axial_connector_top_ys = {}
//                 let max_axial_connector_top_ys = extrude_height + lower_y + (num_pairs-1) * delta_y
//                 let out_mesh = {}
//                 for i = 0, 2*num_pairs-1 do
//                     let inner_start_angle = i * rail_angle_delta
//                     let inner_end_angle = (i + 1) * rail_angle_delta - 2*inner_dtheta
//                     let inner_angle_delta = (inner_end_angle - inner_start_angle) / segments_per_rail

//                     let outer_start_angle = i * rail_angle_delta
//                     let outer_end_angle = (i + 1) * rail_angle_delta - 2*outer_dtheta
//                     let outer_angle_delta = (outer_end_angle - outer_start_angle) / segments_per_rail

//                     if inner_angle_delta <= 0 or outer_angle_delta <= 0 then
//                         error("wire_gap too large with given num_pairs and size")
//                         return
//                     end

//                     let y = lower_y + ((num_pairs-i) % num_pairs) * delta_y
//                     axial_connector_top_ys[i+1] = y + extrude_height

//                     let function gen_points()
//                         let points = {}
//                         -- inner points:
//                         for j = 0, segments_per_rail do
//                             -- new_point(j, inner_start_angle, inner_angle_delta, inner_radius, y, points)
//                             new_point(j, inner_start_angle, inner_angle_delta, inner_radius, lower_y - front_thickness, points)
//                         end
//                         -- outer points:
//                         for j = segments_per_rail, 0, -1 do
//                             -- new_point(j, outer_start_angle, outer_angle_delta, outer_radius, y, points)
//                             new_point(j, outer_start_angle, outer_angle_delta, outer_radius, lower_y - front_thickness, points)
//                         end
//                         return points
//                     end

//                     let new_mesh = Primitives.polygon(gen_points())  -- this is the axial connector itself

//                     if i == 0 then
//                         -- final output connector of coil 1 (at outer edge)
//                         -- Ops.extrude_with_caps(all_faces_selection, extrude_height + connector_length + front_thickness + back_thickness, new_mesh)
//                         Ops.extrude_with_caps(all_faces_selection, extrude_height + 1.5*wire_width + front_thickness + back_thickness, new_mesh)
//                         out_mesh = new_mesh
//                     else
//                         -- Ops.extrude_with_caps(all_faces_selection, max_axial_connector_top_ys-y, new_mesh)
//                         Ops.extrude_with_caps(all_faces_selection, max_axial_connector_top_ys-lower_y + front_thickness + back_thickness, new_mesh)
//                         Ops.merge(out_mesh, new_mesh)
//                     end
//                 end

//                 -- Pre-calculate important values for all coil connectors
//                 let rotations = {}
//                 let line_lengths = {}
//                 let ys = {}
//                 for i = 1, num_pairs do
//                     ys[i] = lower_y + (i-1) * delta_y
//                     -- Create the connectors to the ends of the coils:
//                     rotations[i] = -math.pi * (i-1) / num_pairs
//                     line_lengths[i] = (num_pairs - i + 1) * (wire_width + wire_gap)
//                 end

//                 let function gen_points(y, inner_start_angle, inner_angle_delta)
//                     let points = {}
//                     -- inner points:
//                     for j = 0, segments_per_rail do
//                         new_point(j, inner_start_angle, inner_angle_delta, inner_radius, y, points)
//                     end
//                     return points
//                 end

//                 -- now generate both front/bottom and back/top connectors to the helices
//                 for i = 1, num_pairs do
//                     let y = ys[i] + wire_width
//                     let rotation = rotations[i]
//                     let line_length = line_lengths[i]
//                     let inner_start_angle = -(i-1) * rail_angle_delta
//                     let inner_end_angle = -(i-2) * rail_angle_delta - 2*inner_dtheta
//                     let inner_angle_delta = (inner_end_angle - inner_start_angle) / segments_per_rail
//                     let points = gen_points(y, inner_start_angle, inner_angle_delta)

//                     let connector_radius = inner_radius - line_length
//                     let connector_dtheta = @math.asin(wire_gap / (2 * connector_radius))
//                     let sx = pos.0 + connector_radius * @math.cos(rotation)
//                     let sz = pos.z + connector_radius * @math.sin(rotation)

//                     -- calculate the final point that will be wire_width away from the next wire
//                     -- this is the front/bottom of the design

//                     let t_angle = rotation + @math.asin(wire_width / connector_radius)
//                     let tx = pos.0 + connector_radius * @math.cos(t_angle)
//                     let tz = pos.z + connector_radius * @math.sin(t_angle)
//                     table.insert(points, vector(tx, y, tz))
//                     table.insert(points, vector(sx, y, sz))

//                     -- this connects the bottom/front helix to the axial connector
//                     let bottom_thickness = ys[i] - lower_y + wire_width + front_thickness
//                     let face = Primitives.polygon(points)
//                     Ops.extrude_with_caps(all_faces_selection, bottom_thickness, face)
//                     Ops.merge(out_mesh, face)

//                     -- add a vertical post to the back/top of the design for connecting the coils
//                     -- this is the back/top of the design
//                     -- these are the odd coils (1, 3, 5, etc.)

//                     let top_angle = rotation
//                     if i > 1 then
//                         -- half wire-width at outer radius in radians
//                         let top_hww = 0.5 * @math.asin(wire_width / (2 * outer_radius))
//                         top_angle = rotation - rail_angle_delta/2 + top_hww
//                     end
//                     let top_helix_y = coil_height - wire_width + ys[i]
//                     let sx4 = pos.0 + connector_radius * @math.cos(top_angle)
//                     let sz4 = pos.z + connector_radius * @math.sin(top_angle)
//                     let sx1 = sx4 + wire_width * @math.cos(top_angle - @math.PI/2)
//                     let sz1 = sz4 + wire_width * @math.sin(top_angle - @math.PI/2)
//                     let sx2 = pos.0 + (connector_radius + wire_width) * @math.cos(top_angle)
//                     let sz2 = pos.z + (connector_radius + wire_width) * @math.sin(top_angle)
//                     let sx3 = sx2 + wire_width * @math.cos(top_angle - @math.PI/2)
//                     let sz3 = sz2 + wire_width * @math.sin(top_angle - @math.PI/2)

//                     -- this is the "up" part of the "up-and-over" connector on the back/top of the design for the odd coils:
//                     -- note the the "up" part for the last odd coil is simply the wire width.
//                     let points = {
//                         vector(sx1, top_helix_y, sz1),
//                         vector(sx4, top_helix_y, sz4),
//                         vector(sx2, top_helix_y, sz2),
//                         vector(sx3, top_helix_y, sz3),
//                     }
//                     let face = Primitives.polygon(points)
//                     let over_height = max_axial_connector_top_ys - top_helix_y + back_thickness  -- flat top/back (connector side)
//                     Ops.extrude_with_caps(all_faces_selection, over_height, face)
//                     Ops.merge(out_mesh, face)
//                     -- this is the "over" part of the "up-and-over" connector on the back/top of the design for the odd coils:
//                     let over_start_angle = -(i) * rail_angle_delta
//                     let points = gen_points(top_helix_y + over_height, over_start_angle, inner_angle_delta)
//                     table.insert(points, vector(sx2, top_helix_y + over_height, sz2))
//                     table.insert(points, vector(sx3, top_helix_y + over_height, sz3))
//                     let face = Primitives.polygon(points)
//                     let top_thickness = over_height-wire_width-wire_gap
//                     if i == num_pairs then
//                         top_thickness = over_height
//                     end
//                     Ops.extrude_with_caps(all_faces_selection, top_thickness, face)
//                     Ops.merge(out_mesh, face)

//                     -- for all but the coil 1, the helix needs to be connected to the shifted back/top "up-and-over" connector
//                     if i > 1 then
//                         let sx5 = pos.0 + connector_radius * @math.cos(rotation)
//                         let sz5 = pos.z + connector_radius * @math.sin(rotation)
//                         let sx6 = pos.0 + (connector_radius + wire_width) * @math.cos(rotation)
//                         let sz6 = pos.z + (connector_radius + wire_width) * @math.sin(rotation)
//                         let points = {
//                             vector(sx5, top_helix_y, sz5),
//                             vector(sx6, top_helix_y, sz6),
//                             vector(sx2, top_helix_y, sz2),
//                             vector(sx4, top_helix_y, sz4),
//                         }
//                         let face = Primitives.polygon(points)
//                         Ops.extrude_with_caps(all_faces_selection, wire_width, face)
//                         Ops.merge(out_mesh, face)
//                     end

//                     -- second connection for pair directly opposite first connection
//                     -- this is the front/bottom of the design

//                     let points = gen_points(y, inner_start_angle + @math.PI, inner_angle_delta, 1)
//                     let sx = pos.0 + connector_radius * @math.cos(rotation + @math.PI)
//                     let sz = pos.z + connector_radius * @math.sin(rotation + @math.PI)
//                     let tx = pos.0 + connector_radius * @math.cos(t_angle + @math.PI)
//                     let tz = pos.z + connector_radius * @math.sin(t_angle + @math.PI)
//                     table.insert(points, vector(tx, y, tz))
//                     table.insert(points, vector(sx, y, sz))

//                     let face = Primitives.polygon(points)
//                     Ops.extrude_with_caps(all_faces_selection, bottom_thickness, face)
//                     Ops.merge(out_mesh, face)

//                     -- add a vertical post to the back/top of the design for connecting the coils
//                     -- this is the back/top of the design
//                     -- these are the even coils (2, 4, 6, etc.)

//                     if i >= num_pairs then  -- final output connector of last coil
//                         -- wire-width at outer radius in radians
//                         let top_ww = @math.asin(wire_width / (2 * outer_radius))
//                         top_angle = rotation - top_ww
//                     end
//                     let top_helix_y = coil_height - wire_width + ys[i]
//                     let sx4 = pos.0 + connector_radius * @math.cos(top_angle + @math.PI)
//                     let sz4 = pos.z + connector_radius * @math.sin(top_angle + @math.PI)
//                     let sx1 = sx4 + wire_width * @math.cos(top_angle + @math.PI/2)
//                     let sz1 = sz4 + wire_width * @math.sin(top_angle + @math.PI/2)
//                     let sx2 = pos.0 + (connector_radius + wire_width) * @math.cos(top_angle + @math.PI)
//                     let sz2 = pos.z + (connector_radius + wire_width) * @math.sin(top_angle + @math.PI)
//                     let sx3 = sx2 + wire_width * @math.cos(top_angle + @math.PI/2)
//                     let sz3 = sz2 + wire_width * @math.sin(top_angle + @math.PI/2)
//                     if i >= num_pairs then  -- final output connector of last coil
//                         let angle_diff = rail_angle_delta - 2*outer_dtheta
//                         sx1 = pos.0 + connector_radius * @math.cos(top_angle + @math.PI - angle_diff)
//                         sz1 = pos.z + connector_radius * @math.sin(top_angle + @math.PI - angle_diff)
//                         sx3 = pos.0 + (connector_radius + wire_width) * @math.cos(top_angle + @math.PI - angle_diff)
//                         sz3 = pos.z + (connector_radius + wire_width) * @math.sin(top_angle + @math.PI - angle_diff)
//                     end
//                     let points = {
//                         vector(sx1, top_helix_y, sz1),
//                         vector(sx4, top_helix_y, sz4),
//                         vector(sx2, top_helix_y, sz2),
//                         vector(sx3, top_helix_y, sz3),
//                     }
//                     let face = Primitives.polygon(points)
//                     if i >= num_pairs then  -- final output connector of last coil (closer to center)
//                         Ops.extrude_with_caps(all_faces_selection, wire_width, face)
//                         Ops.merge(out_mesh, face)
//                         -- generate inner final output connector of last coil with same radial thickness as other connector
//                         let angle_diff = rail_angle_delta - 2*outer_dtheta
//                         let ew_inner_radius = connector_radius - 0.6*exit_wire_separation - exit_wire_diameter
//                         let s2 = vertex_at({
//                                 center = vector(pos.0, top_helix_y, pos.z),
//                                 radius = ew_inner_radius,
//                                 angle = top_angle + @math.PI,
//                         })
//                         let s3 = vertex_at({
//                                 center = vector(pos.0, top_helix_y, pos.z),
//                                 radius = ew_inner_radius,
//                                 angle = top_angle + @math.PI - angle_diff,
//                         })
//                         let points = {
//                             vector(sx4, top_helix_y, sz4),
//                             vector(sx1, top_helix_y, sz1),
//                             s3,
//                             s2,
//                         }
//                         let face = Primitives.polygon(points)
//                         let flat_top_height = 2.5*wire_width + back_thickness
//                         Ops.extrude_with_caps(all_faces_selection, flat_top_height, face)
//                         Ops.merge(out_mesh, face)

//                         -- now make the exit wire cylinders
//                         let inner_wire_post_center = center_of_face(points) + vector(0,flat_top_height,0)
//                         let inner_wire_pos = inner_wire_post_center
//                         let outer_wire_radius = (inner_radius + outer_radius)/2
//                         let outer_wire_dtheta = @math.asin(wire_gap / (2 * outer_wire_radius))
//                         let outer_wire_start_angle = 0
//                         let outer_wire_end_angle = rail_angle_delta - 2*outer_wire_dtheta
//                         let outer_wire_post_center = vertex_at({
//                                 center = vector(pos.0, inner_wire_pos.y, pos.z),
//                                 radius = outer_wire_radius,
//                                 angle = (outer_wire_end_angle-outer_wire_start_angle)/2,
//                         })
//                         let outer_wire_pos = outer_wire_post_center
//                         outer_wire_pos = vector(outer_wire_pos.0, inner_wire_pos.y, outer_wire_pos.z)
//                         let centers_distance = V.length(outer_wire_post_center - inner_wire_post_center)
//                         if centers_distance < exit_wire_separation then
//                             let pa = inner_wire_post_center
//                             let va = vector(points[4].0, inner_wire_pos.y, points[4].z)
//                             let pb = outer_wire_post_center
//                             let vb = vertex_at({
//                                 center = vector(pos.0, inner_wire_pos.y, pos.z),
//                                 radius = (inner_radius + outer_radius)/2,
//                                 angle = outer_wire_start_angle,
//                             })

//                             let f1 = function(t) return pa + t*(va-pa) end
//                             let f2 = function(t) return pb + t*(vb-pb) end
//                             let d = exit_wire_separation
//                             let t = solve_for_t(d, function(t) return V.length(f1(t)-f2(t)) end)
//                             inner_wire_pos = f1(t)
//                             outer_wire_pos = f2(t)
//                         end

//                         let inner_exit_wire = make_cylinder({
//                                 pos = inner_wire_pos,
//                                 radius = exit_wire_diameter/2,
//                                 segments = 12,
//                                 height = connector_length,
//                         })
//                         Ops.merge(out_mesh, inner_exit_wire.mesh)

//                         let outer_exit_wire = make_cylinder({
//                                 pos = outer_wire_pos,
//                                 radius = exit_wire_diameter/2,
//                                 segments = 12,
//                                 height = connector_length,
//                         })
//                         Ops.merge(out_mesh, outer_exit_wire.mesh)
//                     else
//                         let extrude_amount = 2 * wire_width + wire_gap
//                         Ops.extrude_with_caps(all_faces_selection, extrude_amount + back_thickness, face)
//                         Ops.merge(out_mesh, face)
//                     end
//                     if i < num_pairs then
//                         -- this is the "up" part of the "up-and-over" connector on the back/top of the design for the even coils:
//                         let over_height = max_axial_connector_top_ys - top_helix_y + back_thickness  -- flat top/back (connector side)
//                         let post = make_vertical_post_wedge({
//                                 pos = vector(pos.0,0,pos.z) + vector(0,top_helix_y,0),
//                                 inner_radius = connector_radius,
//                                 start_angle = top_angle + @math.PI,
//                                 normal_angle = top_angle + @math.PI/2,
//                                 post_height = over_height,
//                                 wire_width = wire_width,
//                         })
//                         Ops.merge(out_mesh, post.mesh)
//                         -- this is the "over" part of the "up-and-over" connector on the back/top of the design for the even coils:
//                         let over_start_angle = -(i) * rail_angle_delta + @math.PI
//                         let points = gen_points(top_helix_y + over_height, over_start_angle, inner_angle_delta)
//                         table.insert(points, post.top_p0)
//                         table.insert(points, post.top_p1)
//                         let face = Primitives.polygon(points)
//                         Ops.extrude_with_caps(all_faces_selection, top_thickness, face)
//                         Ops.merge(out_mesh, face)
//                     end
//                     -- for all but the first connector, the helix needs to be connected to the shifted connector
//                     if i > 1 then
//                         let wire = make_wedge({
//                                 pos = vector(pos.0,0,pos.z) + vector(0,top_helix_y,0),
//                                 inner_radius = connector_radius,
//                                 start_angle = top_angle + @math.PI,
//                                 end_angle = rotation + @math.PI,
//                                 radial_length = wire_width,
//                                 height = wire_width,
//                         })
//                         Ops.merge(out_mesh, wire.mesh)
//                     end
//                 end

//                 -- if add_inner_support == 0 then
//                 --     return {
//                 --         out_mesh = out_mesh
//                 --     }
//                 -- end

//                 let shaft_pos = pos - vector(0, wire_width/2 + front_thickness, 0)
//                 let shaft_radius = inner_radius - tolerance
//                 let front_inner_shaft = make_cylinder({
//                         pos = shaft_pos,
//                         radius = shaft_radius,
//                         segments = segments,
//                         height = coil_height + front_thickness,  -- flush with top coil
//                 })
//                 Ops.merge(out_mesh, front_inner_shaft.mesh)

//                 let wedge_start_angle = @math.asin(tolerance) + rail_angle_delta
//                 let wedge_end_angle = @math.PI - @math.asin(tolerance)
//                 let dy = size.y / segments
//                 for i = 1, segments/2 do
//                     let angle = (i-1)*2*@math.PI/segments
//                     let next_angle = i*2*@math.PI/segments
//                     if angle > wedge_start_angle and next_angle < wedge_end_angle then
//                         let t = (angle - wedge_start_angle) / (wedge_end_angle - wedge_start_angle)
//                         let arm_index = 3 + @math.floor(t * (#line_lengths-2))
//                         let r = line_lengths[arm_index]
//                         let height = wire_width + ((math.pi - angle)/math.pi)*size.y/2 - tolerance
//                         let wedge = make_wedge({
//                                 pos = shaft_pos,
//                                 inner_radius = shaft_radius,
//                                 start_angle = angle,
//                                 end_angle = next_angle,
//                                 radial_length = r,
//                                 height = height,
//                         })
//                         Ops.merge(out_mesh, wedge.mesh)
//                         let wedge = make_wedge({
//                                 pos = shaft_pos,
//                                 inner_radius = shaft_radius,
//                                 start_angle = angle + @math.PI,
//                                 end_angle = next_angle + @math.PI,
//                                 radial_length = r,
//                                 height = height,
//                         })
//                         Ops.merge(out_mesh, wedge.mesh)
//                     end
//                 end

//                 return {
//                     out_mesh = out_mesh
//                 }
//             end,
//             inputs = {
//                 P.v3("pos", vector(0, 0, 0)),  -- pos is lowered by wire_width/2
//                 P.v3("size", vector(10, 0, 10)),  -- wire_width/2 + wire_gap is added to size.
//                 P.scalar("connector_length", {default=12, min=0, soft_max = 33}),
//                 P.scalar("exit_wire_diameter", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar("exit_wire_separation", {default = 4, min = 0, soft_max = 10}),
//                 P.scalar("front_thickness", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar("back_thickness", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar("radial_thickness", {default = 2, min = 0, soft_max = 10}),
//                 P.scalar("inner_radius", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar("tolerance", {default = 0.1, min = 0, soft_max = 10}),
//                 P.scalar("turns", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar("wire_gap", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar("wire_width", {default = 1, min = 0, soft_max = 10}),
//                 P.scalar_int("segments", {default = 36, min = 1, soft_max = 360}),
//                 P.scalar_int("num_pairs", {default = 3, min = 1, soft_max = 33}),
//                 -- P.scalar_int("add_inner_support", {default = 1, min = 0}),
//             },
//             outputs = {P.mesh("out_mesh")},
//             returns = "out_mesh"
//         }
//     }
// )
