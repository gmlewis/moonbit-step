///|
/// Assembly::placed_shapes materialises every component layer as a world-space
/// oriented bounding box for geometric validation.
pub fn Assembly::placed_shapes(
  self : Assembly,
) -> Array[@collision.PlacedShape] {
  let out : Array[@collision.PlacedShape] = []
  for item in self.items {
    out.push_iter(
      @collision.placed_shapes(
        item.instance_name,
        item.component,
        item.placement,
      ).iter(),
    )
  }
  out
}

///|
/// Assembly::collision_reports classifies every pair of distinct component
/// instances as clearance, contact, or collision.
///
/// The classification uses a narrow-phase separating-axis test on oriented
/// bounding boxes. Bounding-box overlap alone is not reported as a collision.
pub fn Assembly::collision_reports(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
  policy~ : @collision.ContactPolicy = @collision.ContactPolicy::none(),
) -> Array[@collision.CollisionReport] {
  @collision.pair_reports(self.placed_shapes(), tol~, policy~)
}

///|
/// Assembly::collisions returns only unintended positive-volume overlaps.
///
/// The test uses each layer's oriented bounding box. For a non-convex section
/// (a T-slot profile or a bore) a reported overlap may be an envelope overlap
/// that the actual material clears; it never reports clearance for a real
/// overlap. Pass the same `policy` used for `collision_reports`; a permitted
/// pair is an `InterferenceFit` and is excluded here.
pub fn Assembly::collisions(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
  policy~ : @collision.ContactPolicy = @collision.ContactPolicy::none(),
) -> Array[@collision.CollisionReport] {
  self.collision_reports(tol~, policy~).filter(fn(r) { r.is_collision() })
}

///|
/// Assembly::contacts returns only the pairs that meet within tolerance.
pub fn Assembly::contacts(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Array[@collision.CollisionReport] {
  self.collision_reports(tol~).filter(fn(r) { r.is_contact() })
}

///|
/// Assembly::interference_fits returns only declared permitted overlaps.
pub fn Assembly::interference_fits(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
  policy~ : @collision.ContactPolicy = @collision.ContactPolicy::none(),
) -> Array[@collision.CollisionReport] {
  self
  .collision_reports(tol~, policy~)
  .filter(fn(r) { r.is_interference_fit() })
}

///|
/// Assembly::disconnected_instances returns the instance names that are not
/// reachable through contact or overlap from the largest connected group.
///
/// A floating member has no contact with the rest of the assembly. The check is
/// purely geometric and does not assume the generator's intended joint list.
/// It is independent of insertion order: starting from the first instance (the
/// previous behaviour) reported the connected majority as disconnected when the
/// first item happened to be the floating one. If no instance touches any
/// other, every instance is reported.
pub fn Assembly::disconnected_instances(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Array[String] {
  let names = self.component_names()
  let n = names.length()
  if n <= 1 {
    return []
  }
  let reports = self.collision_reports(tol~)
  let visited = Array::make(n, false)
  let components : Array[Array[Int32]] = []
  for start in 0..<n {
    if visited[start] {
      continue
    }
    let component : Array[Int32] = [start]
    visited[start] = true
    let mut head = 0
    while head < component.length() {
      let current = component[head]
      head = head + 1
      for report in reports {
        let connected = report.kind is @collision.CollisionKind::Contact ||
          report.kind is @collision.CollisionKind::Collision ||
          report.kind is @collision.CollisionKind::InterferenceFit
        if connected {
          let other = if report.instance_a == names[current] {
            report.instance_b
          } else if report.instance_b == names[current] {
            report.instance_a
          } else {
            ""
          }
          if other != "" {
            match index_of_name(names, other) {
              Some(k) =>
                if !visited[k] {
                  visited[k] = true
                  component.push(k)
                }
              None => ()
            }
          }
        }
      }
    }
    components.push(component)
  }
  // The largest component is the main assembly. Ties keep the earliest
  // component, which is deterministic.
  let mut main_index = 0
  for i in 1..<components.length() {
    if components[i].length() > components[main_index].length() {
      main_index = i
    }
  }
  let main = components[main_index]
  if main.length() == 1 {
    // No instance is connected to any other, so none forms a main body.
    return names.copy()
  }
  let in_main = Array::make(n, false)
  for index in main {
    in_main[index] = true
  }
  let out : Array[String] = []
  for i in 0..<n {
    if !in_main[i] {
      out.push(names[i])
    }
  }
  out
}

///|
/// Assembly::is_connected reports whether every instance is reachable through
/// contacts or overlaps.
pub fn Assembly::is_connected(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Bool {
  self.disconnected_instances(tol~).is_empty()
}

//|

///|
fn index_of_name(names : Array[String], name : String) -> Int32? {
  for i in 0..<names.length() {
    if names[i] == name {
      return Some(i)
    }
  }
  None
}
