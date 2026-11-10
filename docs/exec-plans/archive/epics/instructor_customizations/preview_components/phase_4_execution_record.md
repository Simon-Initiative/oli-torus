# Phase 4 Execution Record

## Scope

Implemented the seven activity-specific preview UIs on top of the shared preview foundation:

- wired real preview components into the seven `preview-entry.ts` entrypoints
- implemented read-only preview bodies and expanded detail tabs for:
  - Multiple Choice
  - Check All That Apply
  - Ordering
  - Likert
  - Multi Input
  - Image Hotspot
  - Directed Discussion
- added frontend tests covering shared preview rendering plus the activity-specific behaviors that most directly exercise this phase:
  - MCQ answer-key rendering
  - Multi Input selected-part-sensitive details
  - Directed Discussion participation/hints tabs

## Implementation Notes

- Choice-based previews now share a common detail-tab path through `StandardDetailTabs.tsx`, which composes:
  - answer key
  - correct/incorrect feedback
  - targeted feedback
  - hints
  - explanation
- `Ordering` uses the same tab infrastructure but swaps in an ordered readonly answer-key summary.
- `Likert` uses the conservative shared expanded-state treatment documented in the FDD:
  - read-only table body
  - `Hints`
  - `Explanation`
- `Multi Input` keeps details tied to the currently selected part and supports mixed input-type activities by switching the answer-key surface when the selected part changes.
- `Directed Discussion` stays intentionally read-only and narrow:
  - stem
  - placeholder post composer
  - `Participation`
  - `Hints`
- `Image Hotspot` renders a static image overlay with numbered hotspot shapes and uses the shared detail surfaces for answer key, hints, and explanation.

## Review Notes

- Round 1 findings:
  - empty authored hints/explanations were being treated as populated because the preview filters only checked rich-text array length
  - `Multi Input` answer-key details were missing the correct/incorrect feedback panels present in the other preview families
- Round 1 fixes:
  - switched hint/explanation emptiness checks to `toSimpleText(...).trim()`
  - added `Correct Feedback` and `Incorrect Feedback` panels to `Multi Input`
- Round 2 findings:
  - no additional issues found in the final self-review pass

## Validation

- `cd assets && ./node_modules/.bin/eslint src/components/activities/common/preview/PreviewAnswerKeyPanel.tsx src/components/activities/common/preview/PreviewChoiceList.tsx src/components/activities/common/preview/PreviewExplanationPanel.tsx src/components/activities/common/preview/PreviewHintsPanel.tsx src/components/activities/common/preview/PreviewOrderedChoiceList.tsx src/components/activities/common/preview/PreviewQuestionStem.tsx src/components/activities/common/preview/PreviewResponsePanels.tsx src/components/activities/common/preview/PreviewRichText.tsx src/components/activities/common/preview/StandardDetailTabs.tsx src/components/activities/multiple_choice/MultipleChoicePreview.tsx src/components/activities/check_all_that_apply/CheckAllThatApplyPreview.tsx src/components/activities/ordering/OrderingPreview.tsx src/components/activities/likert/LikertPreview.tsx src/components/activities/multi_input/MultiInputPreview.tsx src/components/activities/image_hotspot/ImageHotspotPreview.tsx src/components/activities/directed-discussion/DirectedDiscussionPreview.tsx src/components/activities/multiple_choice/preview-entry.ts src/components/activities/check_all_that_apply/preview-entry.ts src/components/activities/ordering/preview-entry.ts src/components/activities/likert/preview-entry.ts src/components/activities/multi_input/preview-entry.ts src/components/activities/image_hotspot/preview-entry.ts src/components/activities/directed-discussion/preview-entry.ts test/activities/preview/activity_previews_test.tsx`
- `cd assets && ./node_modules/.bin/jest test/activities/preview/activity_previews_test.tsx test/activities/preview/preview_foundation_test.tsx --runInBand`
- `mix test test/oli/rendering/activity/html_test.exs test/oli/rendering/activity/plaintext_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
  - passed with the existing test-environment inventory-recovery warning already seen elsewhere in the suite

## Result

Phase 4 is complete:

- the seven Jira-scoped activities now render through first-class preview components
- the preview UI remains read-only and avoids authoring controls
- special-case behavior for `Multi Input`, `Directed Discussion`, and conservative `Likert` expanded handling is covered

The next phase is mixed-page hardening and final regression verification.
