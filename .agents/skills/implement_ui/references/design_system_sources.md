# Design System Sources

These are the current baseline design-system references for Torus.

Use them as the first external design references when the implementation work touches shared UI patterns, token semantics, iconography, or reusable primitives.

For repository conventions about shared primitives, `design_tokens/`, and incremental extraction policy, see `docs/design_tokens.md`.

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

## Scope Of This Reference

This file is intentionally operational, not normative.

Use it to answer:

- which Torus design-system Figma node should I inspect first?
- which design-system page defines buttons, icons, colors, or flash messages?
- when should feature-level Figma override design-system references as the primary visual source?

Do not use this file as the authority for:

- shared-vs-local component placement policy
- `design_tokens/` extraction rules
- incremental consolidation strategy

Those conventions belong in `docs/design_tokens.md`.
