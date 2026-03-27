# Delivery Flows

Use this reference when a test case has `domain: delivery`.

## Primary Jobs In Delivery
- open a section home
- enter learner-visible content
- verify course navigation and page rendering
- confirm published content is accessible to the intended role

## Common Navigation Pattern
1. Enter the delivery environment.
2. Open the intended section or launch into it from the provided URL.
3. Confirm section-level navigation is visible.
4. Open a learner-visible page from the navigation.
5. Wait for the content body to render before asserting success.

## Key UI Landmarks
- section title or section home heading
- learner or instructor delivery navigation
- page body with published instructional content
- controls for moving between pages or modules

## What Usually Counts As Success
- the section home loads without runtime or authorization errors
- a content page opens inside the delivery surface
- learner-visible navigation and content are both present

## What Usually Counts As Failure
- being redirected into authoring instead of delivery
- section access problems
- empty or broken content rendering
- content pages that never finish loading

## Delivery Smoke Interpretation
For shallow smoke cases, do not submit graded work or traverse long activity sequences unless the case says to do so. The main objective is usually to confirm:
- section access
- learner-facing page access
- visible navigation and content rendering
