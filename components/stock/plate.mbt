///|
/// PlateHole is one circular through hole in a plate, in the plate's local
/// XY coordinates.
pub(all) struct PlateHole {
  x_mm : Double
  y_mm : Double
  diameter_mm : Double
}

///|
/// PlateSlot is one obround through slot in a plate, in the plate's local XY
/// coordinates. The slot's long axis is X.
pub(all) struct PlateSlot {
  x_mm : Double
  y_mm : Double
  length_mm : Double
  width_mm : Double
}

///|
/// plate_rect_loop returns a counter-clockwise rectangular outer loop.
fn plate_rect_loop(
  width_mm : Double,
  height_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let hw = width_mm / 2.0
  let hh = height_mm / 2.0
  [
    @cad.SegmentLine((-hw, -hh), (hw, -hh)),
    @cad.SegmentLine((hw, -hh), (hw, hh)),
    @cad.SegmentLine((hw, hh), (-hw, hh)),
    @cad.SegmentLine((-hw, hh), (-hw, -hh)),
  ]
}

///|
/// plate_circle_loop returns a counter-clockwise full circle as four arcs.
///
/// `ExtrudedArcProfile` merges a full circular loop into one analytic
/// cylindrical face, so plate holes are true cylinders rather than polygons.
fn plate_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), centre),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), centre),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), centre),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), centre),
  ]
}

///|
/// plate_slot_loop returns a counter-clockwise obround loop with its long axis
/// along X.
fn plate_slot_loop(
  cx : Double,
  cy : Double,
  length_mm : Double,
  width_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let r = width_mm / 2.0
  let lcx = cx - (length_mm / 2.0 - r)
  let rcx = cx + (length_mm / 2.0 - r)
  [
    @cad.SegmentLine((lcx, cy - r), (rcx, cy - r)),
    @cad.SegmentArc((rcx, cy - r), (rcx, cy + r), (rcx, cy)),
    @cad.SegmentLine((rcx, cy + r), (lcx, cy + r)),
    @cad.SegmentArc((lcx, cy + r), (lcx, cy - r), (lcx, cy)),
  ]
}

///|

///|
/// plate_impl validates and builds the plate body without connectors.
fn plate_impl(
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  holes : Array[PlateHole],
  slots : Array[PlateSlot],
  color : @cad.Rgb,
) -> Result[@common.Component, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("plate width", width_mm),
    @common.require_positive("plate height", height_mm),
    @common.require_positive("plate thickness", thickness_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  for i, hole in holes {
    match @common.require_positive("plate hole diameter", hole.diameter_mm) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if hole.diameter_mm / 2.0 >= width_mm / 2.0 ||
      hole.diameter_mm / 2.0 >= height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "plate hole \{i} diameter does not fit the plate",
        ),
      )
    }
    let radius = hole.diameter_mm / 2.0
    if hole.x_mm - radius < -width_mm / 2.0 ||
      hole.x_mm + radius > width_mm / 2.0 ||
      hole.y_mm - radius < -height_mm / 2.0 ||
      hole.y_mm + radius > height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "plate hole \{i} lies outside the plate boundary",
        ),
      )
    }
  }
  for i, slot in slots {
    match @common.require_positive("plate slot width", slot.width_mm) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if slot.length_mm < slot.width_mm {
      return Err(
        @common.InvalidParameter("plate slot length must be at least its width"),
      )
    }
    let r = slot.width_mm / 2.0
    let half_length = slot.length_mm / 2.0
    if slot.x_mm - half_length < -width_mm / 2.0 ||
      slot.x_mm + half_length > width_mm / 2.0 ||
      slot.y_mm - r < -height_mm / 2.0 ||
      slot.y_mm + r > height_mm / 2.0 {
      return Err(
        @common.InvalidDimension(
          "plate slot \{i} lies outside the plate boundary",
        ),
      )
    }
  }
  // Pairwise overlap checks: holes as circles, slots as capsules along X.
  for i, hole in holes {
    let hr = hole.diameter_mm / 2.0
    for j, other in holes {
      if j <= i {
        continue
      }
      let dx = hole.x_mm - other.x_mm
      let dy = hole.y_mm - other.y_mm
      let distance = (dx * dx + dy * dy).sqrt()
      if distance < (hole.diameter_mm + other.diameter_mm) / 2.0 {
        return Err(
          @common.InvalidParameter("plate holes \{i} and \{j} overlap"),
        )
      }
    }
    for j, slot in slots {
      let sr = slot.width_mm / 2.0
      let sx0 = slot.x_mm - (slot.length_mm / 2.0 - sr)
      let sx1 = slot.x_mm + (slot.length_mm / 2.0 - sr)
      let nearest_x = if hole.x_mm < sx0 {
        sx0
      } else if hole.x_mm > sx1 {
        sx1
      } else {
        hole.x_mm
      }
      let dx = hole.x_mm - nearest_x
      let dy = hole.y_mm - slot.y_mm
      if (dx * dx + dy * dy).sqrt() < hr + sr {
        return Err(
          @common.InvalidParameter("plate hole \{i} and slot \{j} overlap"),
        )
      }
    }
  }
  for i, slot in slots {
    let sr = slot.width_mm / 2.0
    let sx0 = slot.x_mm - (slot.length_mm / 2.0 - sr)
    let sx1 = slot.x_mm + (slot.length_mm / 2.0 - sr)
    for j, other in slots {
      if j <= i {
        continue
      }
      let or = other.width_mm / 2.0
      let ox0 = other.x_mm - (other.length_mm / 2.0 - or)
      let ox1 = other.x_mm + (other.length_mm / 2.0 - or)
      // Conservative: compare the two capsule segments on their centre lines.
      let ax0 = sx0
      let ax1 = sx1
      let bx0 = ox0
      let bx1 = ox1
      let gap = if ax1 < bx0 {
        bx0 - ax1
      } else if bx1 < ax0 {
        ax0 - bx1
      } else {
        0.0
      }
      let dy = slot.y_mm - other.y_mm
      if (gap * gap + dy * dy).sqrt() < sr + or {
        return Err(
          @common.InvalidParameter("plate slots \{i} and \{j} overlap"),
        )
      }
    }
  }
  let hole_loops = holes.map(fn(hole) {
    plate_circle_loop(hole.x_mm, hole.y_mm, hole.diameter_mm / 2.0)
  })
  let slot_loops = slots.map(fn(slot) {
    plate_slot_loop(slot.x_mm, slot.y_mm, slot.length_mm, slot.width_mm)
  })
  let body = @cad.ExtrudedArcProfile::new(
    plate_rect_loop(width_mm, height_mm),
    thickness_mm,
    holes=[..hole_loops, ..slot_loops],
  ).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["body", "through-holes", "through-slots"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="edge-chamfers",
        reason="no edge treatment is asserted",
      ),
      @common.Omission::new(
        feature="material-and-tolerances",
        reason="the plate is a nominal geometric blank",
      ),
    ],
  )
  let name = "plate-\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Plate \{@cad.fmt_double(width_mm, None)} x \{@cad.fmt_double(height_mm, None)} x \{@cad.fmt_double(thickness_mm, None)}",
      family="flat plate blank",
      size="\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}x\{@cad.fmt_double(thickness_mm, None)}",
      source="Parametric rectangular plate centered on the origin; hole and slot patterns are caller-supplied.",
    ),
    description="Rectangular flat plate blank centered on the XY origin with optional analytic circular through holes and obround through slots. No edge treatment or material tolerance is asserted.",
    features~,
  ).add_layer(body, name="body", color~)
  Ok(component.translate(z=-thickness_mm / 2.0))
}

///|
/// plate builds a rectangular flat plate with optional circular through holes
/// and obround through slots.
///
/// Geometry: the plate is centered on the XY origin and on `z = 0`, with its
/// faces at `z = +/- thickness / 2`. Holes and slots are through cuts in the
/// +Z direction and compile to analytic cylinders and slot caps. The plate is a
/// generic blank: it does not imply a standardized commercial part, and
/// hole/slot patterns are the caller's responsibility.
pub fn plate(
  width_mm : Double,
  height_mm : Double,
  thickness_mm : Double,
  holes~ : Array[PlateHole] = [],
  slots~ : Array[PlateSlot] = [],
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match plate_impl(width_mm, height_mm, thickness_mm, holes, slots, color) {
    Err(e) => Err(e)
    Ok(component) =>
      Ok(
        with_plate_connectors(
          component, width_mm, height_mm, thickness_mm, holes, slots,
        ),
      )
  }
}
