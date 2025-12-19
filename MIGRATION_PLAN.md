# MIGRATION PLAN: MoonBit CAD Package Refactoring

This plan outlines the steps to transform the `cad` package from an eager STEP generator into a high-level, fluent 3D modeling DSL.

## Phase 1: Foundational Types & Scene Graph
- [x] **Define high-level `Shape` types**: Move current `Solid` enum definitions into a more structured hierarchy.
- [x] **Create `SceneGraph` node**: Define a node that contains a shape, its transformation matrix (or simple T/R/S), and metadata (name, color).
- [x] **Refactor `Design` struct**:
    - [x] Change `Design` to store a `Array[SceneNode]` instead of an eager `@repository.Repository`.
    - [x] Keep metadata like `name` and `description` in `Design`.

## Phase 2: Abstracting STEP Boilerplate
- [ ] **Create `StepContext` helper**:
    - [ ] Move the 200+ lines of "Product structure", "Units", and "Representation context" boilerplate into a reusable module.
    - [ ] Implement a `StandardContext` that can be initialized once per STEP file.
- [ ] **Unify "Add to Repo" logic**:
    - [ ] Create a robust `InternalRepoBuilder` that handles ID management and deduplication of Directions/Vectors/Points.

## Phase 3: The Fluent API (Builder Pattern)
- [x] **Implement Builder for `Cuboid`**:
    - [x] `Cuboid::new(x, y, z)`
    - [x] `.with_name(String)`
    - [x] `.with_color(Rgb)`
- [ ] **Implement Builder for `ExtrudedProfile`**:
    - [ ] `ExtrudedProfile::new(outer_loop, height)`
- [x] **Add Transformation Combinators**:
    - [x] `Shape::translate(x?, y?, z?) -> Shape`
    - [x] `Shape::rotate(axis, angle) -> Shape` (Future-proofing)

## Phase 4: Decentralized Compilers
- [ ] **Create `compiler_cuboid.mbt`**: Move cuboid-to-STEP logic here. It should take a `Cuboid` intent and a `StepContext` and return the B-Rep entities.
- [ ] **Create `compiler_extrusion.mbt`**: Move extrusion logic here.
- [ ] **Create `compiler_chamfer_block.mbt`**: Move calibration block logic here.

## Phase 5: The "Assembly" Engine
- [ ] **Implement `Design::compile() -> @repository.Repository`**:
    - [ ] This function iterates over the `SceneGraph`.
    - [ ] It initializes the `StandardContext`.
    - [ ] It calls the respective compilers for each shape.
    - [ ] It links the resulting B-Rep solids into the final `ShapeDefinitionRepresentation`.

## Phase 6: API Cleanup & Examples
- [ ] **Update `cad.mbt`**: Remove the massive legacy functions once the compilers are stable.
- [ ] **Update Examples**:
    - [ ] Refactor `01-hello-cube` to use the new fluent API.
    - [ ] Refactor `02-calibration-chamfer-block`.
- [ ] **Verify with OCCT**: Run `./scripts/validate_with_occt.sh` on all generated samples to ensure no regression in STEP validity.

## Maintenance Notes
- **Principle**: Never mutate the `@repository.Repository` directly in high-level CAD calls.
- **Principle**: Keep intent (what the user wants) strictly separate from the geometry kernels (how STEP represents it).
- **Principle**: Use `Double` for all dimensions to maintain precision.
