# Design System Sources

These are the current baseline design-system references for Torus.

Use them as the first external design references when the implementation work touches shared UI patterns, token semantics, iconography, or reusable primitives.

They are not a guarantee that the codebase already matches them perfectly.
When the code and these references diverge, call out the mismatch explicitly instead of silently choosing one.

## Figma Sources

- Layout
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=2-25&p=f&t=e56gM9dw8D8Dg9px-0`

- Spacing
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=476-3011&p=f&t=e56gM9dw8D8Dg9px-0`

- Colors
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=5-31&p=f&t=e56gM9dw8D8Dg9px-0`

- Typography
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=2-22&p=f&t=e56gM9dw8D8Dg9px-0`

- Icons
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=2-24&p=f&t=e56gM9dw8D8Dg9px-0`

- Buttons
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=1007-140&t=e56gM9dw8D8Dg9px-0`

- Flash Messages
  - `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=4478-17891&p=f&t=e56gM9dw8D8Dg9px-0`

## How To Use These Sources

When a ticket or feature includes a specific Figma design for a concrete surface:
- use that feature-level Figma as the primary visual source of truth
- use these design-system references to map tokens, icons, and reusable primitives

When the ticket is about shared UI primitives or design-system alignment:
- use these references as the primary design source

## Icons Direction

Default icon lookup order:
- first, inspect the Torus design-system icon page at `node-id=2:24`
- if the needed icon exists there, treat that node as the primary icon source of truth
- only if the icon is not present there, inspect the feature-level Figma and extract the SVG from the feature node via MCP asset URLs
- if feature-level extraction requires descending into child vector nodes, document that explicitly instead of silently redrawing the icon

The current repo still has established icon modules outside `design_tokens/`.

Current waypoints:
- `lib/oli_web/icons.ex`
- `assets/src/components/misc/icons/Icons`

Target direction:
- shared icon access should gradually converge toward `design_tokens/icons`

Until that convergence happens:
- prefer extending the current canonical icon modules
- avoid introducing ad hoc local icon implementations
- note when a change would be a good candidate for future `design_tokens/icons` consolidation
