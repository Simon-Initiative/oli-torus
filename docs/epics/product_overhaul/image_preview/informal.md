# Image Preview (Informal Spec)

Source ticket: `MER-4052`  
Feature name: `image_preview`

## Intent

Provide reliable cover image previews in three system contexts:

- Student My Course page
- Course Picker
- Student Welcome page

## Core Technical Direction

The preview must render exactly as those target UIs render in production and must not drift over time.

To guarantee fidelity:

- Refactor the relevant LiveView/component markup into shared reusable templates/components.
- Use those shared rendering units both in the real destination UIs and in the preview feature.

## Why This Approach

- Screenshot-compositing approaches are brittle and drift when destination UIs evolve.
- Shared canonical templates ensure the preview and runtime surfaces stay synchronized by construction.

## Implementation Notes

- Identify the exact HTML/component boundaries for each target context.
- Extract to reusable template/component modules with stable inputs.
- Update existing target UIs to consume those shared modules before wiring preview rendering.
- Ensure styles and responsive behavior come from the same source as runtime views.

## Validation Focus

- Visual parity checks for all three contexts at common breakpoints.
- Regression checks proving changes to destination UI automatically reflect in preview output.
