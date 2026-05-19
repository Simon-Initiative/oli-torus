# Product Overhaul Epic Overview

Epic: `MER-4032`  
Name: Product / Organization Overhaul

## Summary

This epic renames "Product" concepts to "Course Section Template(s)" and modernizes template authoring and management flows. It also includes delivery and remix correctness fixes needed to support template-specific content and behavior.

## Objectives

- Align terminology and UX with the new template model.
- Improve template overview capabilities (previews, usage, defaults, metadata).
- Fix known remix and curriculum numbering defects.
- Support template-scoped course structure extensions needed for future evolution.

## Actionable Work Items (To Do / Analyzing)

- `MER-4048` Change "Product" to "Templates"
- `MER-4052` Cover Image Updates
- `MER-4053` Template Preview Capabilities
- `MER-4054` Course Section Defaults
- `MER-4055` Removing and reintroducing a page does not show
- `MER-4056` Ability to restrict products' public access
- `MER-4057` Remixing/Customize Content Updates
- `MER-4058` Breadcrumb leading to wrong page in templates/products
- `MER-4059` Display curriculum item numbers
- `MER-4061` Manage Source Materials Badge Template Overview
- `MER-4062` View Product/Template Usage
- `MER-4679` Product Overview Page Updates
- `MER-5260` Display curriculum item numbers exclusions

## Feature-Spec Required Tracks

- `image_preview` (`MER-4052`)
- `template_preview` (`MER-4053`)
- `add_containers` (`MER-4057`)

## Technical Themes

- Preserve parity between author/admin template UX and existing section UX.
- Reuse existing section and enrollment mechanics where possible.
- Protect publishing/update correctness with targeted TDD-first fixes.
- Introduce and enforce revision scoping so template/section resources remain isolated.
