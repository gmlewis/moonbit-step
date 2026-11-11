///|
/// FrameMemberRole identifies how a member participates in a frame joint.
pub(all) enum FrameMemberRole {
  /// Full-height vertical corner post.
  Post
  /// Horizontal rail running along X.
  RailX
  /// Horizontal rail running along Y.
  RailY
}

///|
/// FrameMemberRole::to_string returns a stable display token.
pub fn FrameMemberRole::to_string(self : FrameMemberRole) -> String {
  match self {
    Post => "post"
    RailX => "rail-x"
    RailY => "rail-y"
  }
}

///|
/// FrameMember is one cut-to-length extrusion in a rectangular frame.
///
/// `start` and `end` are the extrusion-axis endpoints in the assembly frame,
/// with the profile section centred on the axis. `cut_length_mm` is the exact
/// cut length; the component's local +Z axis runs from `start` to `end`.
pub(all) struct FrameMember {
  id : String
  role : FrameMemberRole
  profile : @profiles.TSlotProfile
  cut_length_mm : Double
  start : @cad.Vec3
  end : @cad.Vec3
  placement : @common.Placement
}

//|

///|
fn frame_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

//|

///|
fn frame_min_rail_span(
  axis : String,
  value : Double,
  profile_dimension : Double,
) -> Result[Unit, @common.SpecError] {
  let minimum = 2.0 * profile_dimension
  if value <= minimum {
    Err(
      @common.InvalidParameter(
        "\{axis} (\{value} mm) must exceed twice the profile section dimension (\{minimum} mm) so the rails have a positive cut length",
      ),
    )
  } else {
    Ok(())
  }
}

///|
/// extrusion_frame_members computes the member schedule for a rectangular
/// frame.
///
/// Frame semantics (documented compatibility decision):
/// - `width_mm`, `depth_mm`, and `height_mm` are **overall outside
///   dimensions**, including the profile section.
/// - Four vertical posts occupy the corners and run the full height.
/// - X rails run between the post inner faces and have cut length
///   `width - 2 * profile_width`; Y rails have cut length
///   `depth - 2 * profile_height`.
/// - The origin is at the outside bottom corner of the frame's bounding box
///   only in the sense that the overall bounds are centred in X and Y and rest
///   on `z = 0`. X is width, Y is depth, Z is height; the frame is
///   right-handed.
/// - Joints are square butt contacts at post inner faces (no mitres, brackets,
///   or end machining). No member overlaps another with positive volume.
///
/// This is a generic engineering envelope, not a manufacturer-specific framing
/// system.
///
/// `width_mm`, `depth_mm`, and `height_mm` are overall outside dimensions.
pub fn extrusion_frame_members(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  profile : @profiles.TSlotProfile,
) -> Result[Array[FrameMember], @common.SpecError] {
  let (pw, ph) = profile.size()
  match @common.require_positive("frame width", width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("frame depth", depth_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("frame height", height_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match frame_min_rail_span("frame width", width_mm, pw) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match frame_min_rail_span("frame depth", depth_mm, ph) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match frame_min_rail_span("frame height", height_mm, frame_max(pw, ph)) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let rail_x_len = width_mm - 2.0 * pw
  let rail_y_len = depth_mm - 2.0 * ph
  let post_x = width_mm / 2.0 - pw / 2.0
  let post_y = depth_mm / 2.0 - ph / 2.0
  let z_bottom_x = pw / 2.0
  let z_top_x = height_mm - pw / 2.0
  let z_bottom_y = ph / 2.0
  let z_top_y = height_mm - ph / 2.0
  let members : Array[FrameMember] = []
  // Four full-height corner posts.
  for
    (sx, sy, id) in [
      (-1.0, -1.0, "post-ws"),
      (1.0, -1.0, "post-es"),
      (1.0, 1.0, "post-en"),
      (-1.0, 1.0, "post-wn"),
    ] {
    let x = sx * post_x
    let y = sy * post_y
    members.push({
      id,
      role: Post,
      profile,
      cut_length_mm: height_mm,
      start: (x, y, 0.0),
      end: (x, y, height_mm),
      placement: @common.Placement::translation(x, y, 0.0),
    })
  }
  // Rails along X, front and back, bottom and top. Rotating +90 degrees about
  // Y maps the local extrusion axis +Z to world +X.
  for
    (sy, z, id) in [
      (-1.0, z_bottom_x, "rail-x-bottom-s"),
      (1.0, z_bottom_x, "rail-x-bottom-n"),
      (-1.0, z_top_x, "rail-x-top-s"),
      (1.0, z_top_x, "rail-x-top-n"),
    ] {
    let y = sy * post_y
    members.push({
      id,
      role: RailX,
      profile,
      cut_length_mm: rail_x_len,
      start: (-rail_x_len / 2.0, y, z),
      end: (rail_x_len / 2.0, y, z),
      placement: @common.Placement::at(-rail_x_len / 2.0, y, z, ry=90.0),
    })
  }
  // Rails along Y, left and right, bottom and top. Rotating -90 degrees about
  // X maps the local extrusion axis +Z to world +Y.
  for
    (sx, z, id) in [
      (-1.0, z_bottom_y, "rail-y-bottom-w"),
      (1.0, z_bottom_y, "rail-y-bottom-e"),
      (-1.0, z_top_y, "rail-y-top-w"),
      (1.0, z_top_y, "rail-y-top-e"),
    ] {
    let x = sx * post_x
    members.push({
      id,
      role: RailY,
      profile,
      cut_length_mm: rail_y_len,
      start: (x, -rail_y_len / 2.0, z),
      end: (x, rail_y_len / 2.0, z),
      placement: @common.Placement::at(x, -rail_y_len / 2.0, z, rx=-90.0),
    })
  }
  Ok(members)
}

///|
/// extrusion_frame builds a rectangular frame from 4 vertical posts and 8
/// horizontal rails of a generic T-slot profile.
///
/// Each rail is cut to the clear span between the post inner faces, so the
/// assembly contains no unintended positive-volume interpenetration. The
/// joints are square butt contacts; corner brackets, end taps, and fasteners
/// are not modeled.
///
/// `width_mm`, `depth_mm`, and `height_mm` are overall outside dimensions.
/// See `extrusion_frame_members` for the full frame semantics.
pub fn extrusion_frame(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  profile : @profiles.TSlotProfile,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[Assembly, @common.SpecError] {
  let members = match
    extrusion_frame_members(width_mm, depth_mm, height_mm, profile) {
    Err(e) => return Err(e)
    Ok(m) => m
  }
  let posts = match @profiles.extrusion(profile, height_mm, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let rail_x_len = width_mm - 2.0 * profile.width_mm
  let rail_y_len = depth_mm - 2.0 * profile.height_mm
  let rails_x = match @profiles.extrusion(profile, rail_x_len, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let rails_y = match @profiles.extrusion(profile, rail_y_len, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let name = "extrusion-frame-\{profile.name}-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(depth_mm, None)}x\{@cad.fmt_double(height_mm, None)}"
  let mut assembly = Assembly::new(
    name~,
    description="Rectangular generic T-slot frame: four full-height corner posts and eight rails cut to the clear span between post inner faces. Square butt joints; no brackets or machined joints. Overall outside dimensions.",
  )
  for part in members {
    let component = match part.role {
      Post => posts
      RailX => rails_x
      RailY => rails_y
    }
    assembly = assembly.add(
      component,
      placement=part.placement,
      instance_name=part.id,
    )
  }
  Ok(assembly)
}
