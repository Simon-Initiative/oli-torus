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

## Accessibility And Responsiveness

Torus values accessible, responsive applications. UI changes should preserve or improve:

- keyboard operability
- semantic structure and screen-reader compatibility
- color contrast and visible focus states
- responsive layout and reflow behavior
- understandable validation, loading, empty, and error states

## Canonical References

- UI review guidance: `.review/ui.md`
- work-item docs often link the relevant Figma artifacts from `informal.md`, `prd.md`, or related planning files
