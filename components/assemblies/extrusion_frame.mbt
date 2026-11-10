///|
/// extrusion_frame builds a rectangular frame from 4 vertical posts and 8
/// horizontal rails of a generic T-slot profile.
///
/// This is a display/assembly envelope: the rails overlap the posts at the
/// corners. Corner brackets, end taps, and cut-to-fit joinery are not modeled.
/// Use a manufacturer's profile data and joint design before building a real
/// structure.
pub fn extrusion_frame(
  width_mm : Double,
  depth_mm : Double,
  height_mm : Double,
  profile : @profiles.TSlotProfile,
  detail~ : @common.DetailLevel = Simplified,
) -> Result[Assembly, @common.SpecError] {
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
  if width_mm <= pw || depth_mm <= ph || height_mm <= pw || height_mm <= ph {
    return Err(
      @common.InvalidParameter(
        "frame dimensions must exceed the profile's section dimensions",
      ),
    )
  }
  let posts = match @profiles.extrusion(profile, height_mm, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let rail_x_len = width_mm - pw
  let rail_y_len = depth_mm - ph
  let rails_x = match @profiles.extrusion(profile, rail_x_len, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let rails_y = match @profiles.extrusion(profile, rail_y_len, detail~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let name = "extrusion-frame-\{profile.name}-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(depth_mm, None)}x\{@cad.fmt_double(height_mm, None)}"
  let post_x = width_mm / 2.0 - pw / 2.0
  let post_y = depth_mm / 2.0 - ph / 2.0
  let z_bottom_x = pw / 2.0
  let z_top_x = height_mm - pw / 2.0
  let z_bottom_y = ph / 2.0
  let z_top_y = height_mm - ph / 2.0
  let mut assembly = Assembly::new(
    name~,
    description="Rectangular generic T-slot frame: four posts and eight overlapping rails. No brackets or machined joints.",
  )
  // Four vertical posts.
  for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)] {
    assembly = assembly.add(
      posts,
      placement=@common.Placement::translation(sx * post_x, sy * post_y, 0.0),
      instance_name="post-\{if sx < 0.0 { 'w' } else { 'e' }}\{if sy < 0.0 { 's' } else { 'n' }}",
    )
  }
  // Rails along X, front and back, bottom and top.
  for
    (sy, z, tag) in [
      (-1.0, z_bottom_x, "bottom-s"),
      (1.0, z_bottom_x, "bottom-n"),
      (-1.0, z_top_x, "top-s"),
      (1.0, z_top_x, "top-n"),
    ] {
    assembly = assembly.add(
      rails_x,
      placement=@common.Placement::at(
        -rail_x_len / 2.0,
        sy * post_y,
        z,
        ry=90.0,
      ),
      instance_name="rail-x-\{tag}",
    )
  }
  // Rails along Y, left and right, bottom and top.
  for
    (sx, z, tag) in [
      (-1.0, z_bottom_y, "bottom-w"),
      (1.0, z_bottom_y, "bottom-e"),
      (-1.0, z_top_y, "top-w"),
      (1.0, z_top_y, "top-e"),
    ] {
    assembly = assembly.add(
      rails_y,
      placement=@common.Placement::at(
        sx * post_x,
        -rail_y_len / 2.0,
        z,
        rx=-90.0,
      ),
      instance_name="rail-y-\{tag}",
    )
  }
  Ok(assembly)
}
