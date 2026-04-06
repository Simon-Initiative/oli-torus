# Template Preview (Informal Spec)

Source ticket: `MER-4053`  
Feature name: `template_preview`

## Intent

Enable authors to preview a template using the real student delivery experience with minimal implementation overhead.

## Core Technical Direction

Fastest reliable path is to leverage existing section/delivery behavior directly:

- Treat template/product as the underlying section entity already used in code.
- Ensure the current user has a student enrollment in that template-section.
- If no enrollment exists, create one.
- Open a new browser window to that section's student home/delivery entrypoint.

## Why This Approach

- Avoids building a parallel preview stack.
- Reuses mature delivery rendering and permission logic.
- Minimizes implementation complexity and reduces divergence risk.

## Implementation Notes

- Add a preview action handler from Template Overview.
- Enrollment-upsert should be idempotent and safe for repeat usage.
- Preserve existing author identity while granting student access for preview context.
- Route directly to the section home page in delivery mode.

## Validation Focus

- First preview click for non-enrolled author creates enrollment and opens delivery.
- Subsequent preview clicks do not create duplicate enrollments.
- Preview view matches real student experience for the same template-section.
