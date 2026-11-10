///|
/// FrameView selects an orthographic or isometric diagnostic projection.
pub(all) enum FrameView {
  Top
  Front
  Side
  Iso
}

///|
/// FrameView::file_name returns the SVG file name for the view.
pub fn FrameView::file_name(self : FrameView) -> String {
  match self {
    Top => "frame-top.svg"
    Front => "frame-front.svg"
    Side => "frame-side.svg"
    Iso => "frame-iso.svg"
  }
}

///|
/// FrameView::title returns the human-readable view name.
pub fn FrameView::title(self : FrameView) -> String {
  match self {
    Top => "top view (X right, Y up)"
    Front => "front view (X right, Z up)"
    Side => "side view (Y right, Z up)"
    Iso => "isometric view"
  }
}

//|

///|
fn view_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

//|

///|
fn view_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

//|

///|
fn project_point(view : FrameView, p : @cad.Vec3) -> (Double, Double) {
  let (x, y, z) = p
  match view {
    Top => (x, y)
    Front => (x, z)
    Side => (y, z)
    Iso => ((x - y) * 0.8660254037844386, (x + y) * 0.5 - z)
  }
}

//|

///|
fn obb_corners(obb : @collision.Obb) -> Array[@cad.Vec3] {
  let (ax, ay, az) = obb.axes
  let (hx, hy, hz) = obb.half_extents
  let out : Array[@cad.Vec3] = []
  for sx in [-1.0, 1.0] {
    for sy in [-1.0, 1.0] {
      for sz in [-1.0, 1.0] {
        out.push(
          (
            obb.center.0 + sx * hx * ax.0 + sy * hy * ay.0 + sz * hz * az.0,
            obb.center.1 + sx * hx * ax.1 + sy * hy * ay.1 + sz * hz * az.1,
            obb.center.2 + sx * hx * ax.2 + sy * hy * ay.2 + sz * hz * az.2,
          ),
        )
      }
    }
  }
  out
}

//|

///|
fn projected_bbox(
  obb : @collision.Obb,
  view : FrameView,
) -> (Double, Double, Double, Double) {
  let mut x0 = 1.0e300
  let mut x1 = -1.0e300
  let mut y0 = 1.0e300
  let mut y1 = -1.0e300
  for p in obb_corners(obb) {
    let (x, y) = project_point(view, p)
    x0 = view_min(x0, x)
    x1 = view_max(x1, x)
    y0 = view_min(y0, y)
    y1 = view_max(y1, y)
  }
  (x0, x1, y0, y1)
}

//|

///|
fn view_bounds(
  members : Array[(String, Double, @collision.Obb)],
  view : FrameView,
) -> (Double, Double, Double, Double) {
  let mut x0 = 1.0e300
  let mut x1 = -1.0e300
  let mut y0 = 1.0e300
  let mut y1 = -1.0e300
  for (_, _, obb) in members {
    let (a0, a1, b0, b1) = projected_bbox(obb, view)
    x0 = view_min(x0, a0)
    x1 = view_max(x1, a1)
    y0 = view_min(y0, b0)
    y1 = view_max(y1, b1)
  }
  (x0, x1, y0, y1)
}

//|

///|
fn palette(i : Int32) -> String {
  let colors = [
    "#4e79a7", "#f28e2b", "#59a14f", "#b07aa1", "#76b7b2", "#edc948", "#ff9da7",
    "#9c755f", "#86bcb6", "#d37295", "#a0cbe8", "#8cd17d",
  ]
  colors[i % colors.length()]
}

//|

///|
fn is_colliding(collisions : Array[String], name : String) -> Bool {
  for c in collisions {
    if c == name {
      return true
    }
  }
  false
}

//|

///|
fn esc(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
}

//|

///|
fn member_index(
  members : Array[(String, Double, @collision.Obb)],
  name : String,
) -> Int32 {
  for i in 0..<members.length() {
    if members[i].0 == name {
      return i
    }
  }
  0
}

///|
/// frame_view_svg renders one diagnostic SVG for a frame member schedule.
///
/// Orthographic views draw each member's projected envelope as a filled
/// rectangle; the isometric view draws the member OBB wireframes. Colors are
/// stable per member, member IDs and cut lengths are labelled, and any pair
/// reported by the collision validator is stroked red and listed in the
/// caption.
pub fn frame_view_svg(
  members : Array[(String, Double, @collision.Obb)],
  collisions : Array[String],
  view : FrameView,
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
) -> String {
  let canvas = 1024.0
  let margin = 70.0
  let header = 80.0
  let caption = 60.0
  let (vx0, vx1, vy0, vy1) = view_bounds(members, view)
  let span_x = view_max(vx1 - vx0, 1.0e-9)
  let span_y = view_max(vy1 - vy0, 1.0e-9)
  let scale = view_min(
    (canvas - 2.0 * margin) / span_x,
    (canvas - header - caption - 2.0 * margin) / span_y,
  )
  let map_x = fn(x) { margin + (x - vx0) * scale }
  let map_y = fn(y) { header + margin + (vy1 - y) * scale }
  let lines : Array[String] = []
  lines.push(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\">",
  )
  lines.push(
    "<rect x=\"0\" y=\"0\" width=\"1024\" height=\"1024\" fill=\"#ffffff\"/>",
  )
  lines.push(
    "<text x=\"24\" y=\"34\" font-family=\"monospace\" font-size=\"22\" fill=\"#111\">" +
    esc(view.title()) +
    "</text>",
  )
  lines.push(
    "<text x=\"24\" y=\"60\" font-family=\"monospace\" font-size=\"14\" fill=\"#555\">" +
    "outside dimensions " +
    @cad.fmt_double(width_mm, None) +
    " x " +
    @cad.fmt_double(depth_mm, None) +
    " x " +
    @cad.fmt_double(height_mm, None) +
    " mm; member count " +
    members.length().to_string() +
    "</text>",
  )
  for (name, length, obb) in members {
    let color = palette(member_index(members, name))
    let colliding = is_colliding(collisions, name)
    let stroke = if colliding { "#d00000" } else { "#222222" }
    let stroke_width = if colliding { "3" } else { "1" }
    let fill = if colliding { "#ff0000" } else { color }
    let (a0, a1, b0, b1) = projected_bbox(obb, view)
    let label = name + " (" + @cad.fmt_double(length, None) + " mm)"
    match view {
      Iso => {
        let corners = obb_corners(obb)
        let edges = [
          (0, 1),
          (1, 3),
          (3, 2),
          (2, 0),
          (4, 5),
          (5, 7),
          (7, 6),
          (6, 4),
          (0, 4),
          (1, 5),
          (2, 6),
          (3, 7),
        ]
        for (i, j) in edges {
          let (x0, y0) = project_point(view, corners[i])
          let (x1, y1) = project_point(view, corners[j])
          lines.push(
            "<line x1=\"" +
            @cad.fmt_double(map_x(x0), None) +
            "\" y1=\"" +
            @cad.fmt_double(map_y(y0), None) +
            "\" x2=\"" +
            @cad.fmt_double(map_x(x1), None) +
            "\" y2=\"" +
            @cad.fmt_double(map_y(y1), None) +
            "\" stroke=\"" +
            stroke +
            "\" stroke-width=\"" +
            stroke_width +
            "\"/>",
          )
        }
        let (cx, cy) = project_point(view, obb.center)
        lines.push(
          "<text x=\"" +
          @cad.fmt_double(map_x(cx), None) +
          "\" y=\"" +
          @cad.fmt_double(map_y(cy), None) +
          "\" font-family=\"monospace\" font-size=\"10\" text-anchor=\"middle\" fill=\"#111\">" +
          esc(label) +
          "</text>",
        )
      }
      _ => {
        let sx0 = map_x(a0)
        let sx1 = map_x(a1)
        let sy0 = map_y(b1)
        let sy1 = map_y(b0)
        lines.push(
          "<rect x=\"" +
          @cad.fmt_double(sx0, None) +
          "\" y=\"" +
          @cad.fmt_double(sy0, None) +
          "\" width=\"" +
          @cad.fmt_double(sx1 - sx0, None) +
          "\" height=\"" +
          @cad.fmt_double(sy1 - sy0, None) +
          "\" fill=\"" +
          fill +
          "\" fill-opacity=\"0.35\" stroke=\"" +
          stroke +
          "\" stroke-width=\"" +
          stroke_width +
          "\"/>",
        )
        lines.push(
          "<text x=\"" +
          @cad.fmt_double((sx0 + sx1) / 2.0, None) +
          "\" y=\"" +
          @cad.fmt_double((sy0 + sy1) / 2.0 + 4.0, None) +
          "\" font-family=\"monospace\" font-size=\"10\" text-anchor=\"middle\" fill=\"#111\">" +
          esc(label) +
          "</text>",
        )
      }
    }
  }
  let caption_text = if collisions.is_empty() {
    "collision check: no positive-volume interpenetration reported"
  } else {
    "COLLISIONS: " + collisions.join(", ")
  }
  lines.push(
    "<text x=\"24\" y=\"1000\" font-family=\"monospace\" font-size=\"14\" fill=\"" +
    (if collisions.is_empty() { "#1a7f37" } else { "#d00000" }) +
    "\">" +
    esc(caption_text) +
    "</text>",
  )
  lines.push("</svg>")
  lines.join("\n") + "\n"
}

//|

///|
fn section_path(
  points : Array[@cad.Vec2],
  map_x : (Double) -> Double,
  map_y : (Double) -> Double,
) -> String {
  let parts : Array[String] = []
  for i in 0..<points.length() {
    let p = points[i]
    parts.push(
      (if i == 0 { "M" } else { "L" }) +
      @cad.fmt_double(map_x(p.0), None) +
      "," +
      @cad.fmt_double(map_y(p.1), None),
    )
  }
  parts.join(" ") + " Z"
}

///|
/// profile_section_svg renders the actual T-slot cross-section used by the
/// extrusion. It draws the outer boundary and the core bore with the
/// even-odd fill rule, so the four corner arrows and the slot cavities are
/// directly visible.
pub fn profile_section_svg(profile : @profiles.TSlotProfile) -> String {
  let draw_left = 70.0
  let draw_top = 120.0
  let draw_right = 630.0
  let draw_bottom = 740.0
  let outline = profile.outline()
  let holes = profile.holes()
  let mut min_x = 1.0e300
  let mut max_x = -1.0e300
  let mut min_y = 1.0e300
  let mut max_y = -1.0e300
  for p in outline {
    min_x = view_min(min_x, p.0)
    max_x = view_max(max_x, p.0)
    min_y = view_min(min_y, p.1)
    max_y = view_max(max_y, p.1)
  }
  let span = view_max(view_max(max_x - min_x, max_y - min_y), 1.0e-9)
  let scale = view_min(
    (draw_right - draw_left) / span,
    (draw_bottom - draw_top) / span,
  )
  let map_x = fn(x) { draw_left + (x - min_x) * scale }
  let map_y = fn(y) { draw_top + (max_y - y) * scale }
  let paths : Array[String] = [section_path(outline, map_x, map_y)]
  for hole in holes {
    paths.push(section_path(hole, map_x, map_y))
  }
  let lines : Array[String] = []
  lines.push(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"700\" height=\"780\" viewBox=\"0 0 700 780\">",
  )
  lines.push("<rect width=\"700\" height=\"780\" fill=\"#ffffff\"/>")
  lines.push(
    "<text x=\"24\" y=\"34\" font-family=\"monospace\" font-size=\"22\" fill=\"#111\">" +
    esc("T-slot section: " + profile.name) +
    "</text>",
  )
  lines.push(
    "<text x=\"24\" y=\"60\" font-family=\"monospace\" font-size=\"14\" fill=\"#555\">" +
    "section " +
    @cad.fmt_double(profile.width_mm, None) +
    " x " +
    @cad.fmt_double(profile.height_mm, None) +
    " mm; cavity " +
    @cad.fmt_double(profile.cavity_width_mm, None) +
    " mm; depth " +
    @cad.fmt_double(profile.slot_depth_mm, None) +
    " mm; bore " +
    @cad.fmt_double(profile.core_bore_diameter_mm, None) +
    " mm</text>",
  )
  lines.push(
    "<path d=\"" +
    paths.join(" ") +
    "\" fill=\"#b9c8dd\" fill-rule=\"evenodd\" stroke=\"#111\" stroke-width=\"1.5\"/>",
  )
  lines.push(
    "<text x=\"24\" y=\"770\" font-family=\"monospace\" font-size=\"13\" fill=\"#555\">" +
    "four corner arrows, four T-slots, one core bore</text>",
  )
  lines.push("</svg>")
  lines.join("\n") + "\n"
}
