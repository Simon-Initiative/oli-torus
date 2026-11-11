# Phase 7 Manual QA Notes

## New Math Expression Authoring

1. Create a Short Answer activity and choose the `math_expression` input type.
2. Add a full-credit response with `matchConfig` algebraic equivalence, expected `1/2`, and exact form `simplified_fraction`.
3. Add a partial-credit response with algebraic equivalence expected `1/2` and no exact-form requirement.
4. Add an always-match fallback response.
5. Save the activity and inspect the saved model: new `math_expression` responses should contain `matchConfig` and should not serialize `rule`.

## Preview And Delivery

1. In author preview, submit `1/2`; verify full-credit feedback.
2. Submit `2/4`; verify partial-credit feedback for equivalent but unsimplified input.
3. Submit an invalid expression; verify authored fallback feedback and no raw parser diagnostics.
4. Publish the project, create or update a section, and answer as a learner to verify the same score and feedback behavior in delivery.

## Unit-Aware Matching

1. Create a `math_expression` Short Answer response with unit-aware expected value `10 m/s` and allowed convertible units `m/s` and `km/hr`.
2. Preview and deliver `36 km/hr`; verify full credit.
3. Preview and deliver a non-equivalent value such as `35 km/hr`; verify fallback feedback.

## Editing Legacy Numeric And Math

1. Open an existing Short Answer or Multi Input activity using legacy `numeric` or `math` input types.
2. Make an authoring edit and save.
3. Verify the saved input type becomes `math_expression`.
4. Verify converted responses contain `matchConfig` and omit `rule` where conversion is supported.
5. Verify text and dropdown responses still save with normal rules.

## Unedited Legacy Runtime Compatibility

1. Use an old published `numeric` activity that still has `inputType: "numeric"` and rule-backed responses.
2. Answer a matching value in delivery and verify the original score and feedback.
3. Use an old published `math` activity that still has `inputType: "math"` and direct LaTeX equality rules.
4. Answer the matching LaTeX string in delivery and verify the original score and feedback.

## Privacy And Diagnostics

1. Trigger invalid math submissions in preview and delivery.
2. Confirm learner-visible feedback uses authored feedback only.
3. Review logs for the workflow and confirm raw student answers, raw expected answers, sampled assignments, and raw parser diagnostics are not logged by default.
