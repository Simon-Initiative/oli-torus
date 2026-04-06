# Design

## Principles

This document refers to UX and product design, not technical design.

Torus feature development is expected to involve design and product collaboration. UX research, interaction design, and visual design should come from the design/product team, with Figma used as the primary design artifact and handoff surface for feature work.

Core design principles for Torus:

- accessible by default, with a strong expectation of WCAG 2.1 AA-level behavior
- responsive across supported screen sizes and input modes
- clear and understandable for users with different levels of learning-engineering familiarity
- consistent across authoring, delivery, and administrative surfaces
- grounded in real instructional workflows rather than generic CRUD UI patterns

## Working Model

- use Figma as the primary source for UX and visual design artifacts
- involve the design/product team in feature development, especially for new flows or major UX changes
- treat accessibility and responsive behavior as first-class design requirements, not late polish
- keep implementation aligned with approved design intent, but raise mismatches or usability issues early rather than silently diverging

## Torus UI Skill

Torus keeps a local `implement_ui` skill for Figma-driven UI implementation work. This skill is Torus-specific and is not part of the shared Harness skill set.

Use it as supporting input when a Jira ticket or user request includes Figma links or another concrete design source and the task requires implementation work that should stay aligned with approved visual design. It should inform token mapping, icon sourcing, reusable component decisions, and file targets before coding begins.

When a Torus implementation ticket includes Figma links or another concrete UI design source, `implement_ui` should be considered before coding starts.

When a Torus feature is being specced from a ticket that already includes Figma links or another concrete UI design source, `implement_ui` should also be considered during spec creation so the feature pack captures the relevant visual-system decisions early.

When that work introduces or reshapes a cross-feature primitive such as a button, icon button, badge, pill, tab trigger, or simple feedback surface, `implement_ui` should also state explicitly whether the result belongs in `design_tokens/` and whether `/dev/design_tokens` must be updated as part of the implementation.

## Accessibility And Responsiveness

Torus values accessible, responsive applications. UI changes should preserve or improve:

- keyboard operability
- semantic structure and screen-reader compatibility
- color contrast and visible focus states
- responsive layout and reflow behavior
- understandable validation, loading, empty, and error states

## Canonical References

- UI review guidance: `.review/ui.md`
- Shared primitive adoption model: `docs/design_tokens.md`
- work-item docs often link the relevant Figma artifacts from `informal.md`, `prd.md`, or related planning files
