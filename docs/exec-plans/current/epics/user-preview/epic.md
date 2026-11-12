# User Preview November 2026 — Technical product overview

Epic/source: [MER-6158](https://eliterate.atlassian.net/browse/MER-6158) and the existing local overview
Review: product decisions accepted; Step 1 overview pending operator acceptance; Step 2 pending
Filing: pending; no Jira writes authorized

## Outcomes and scope

Instructors need to distinguish instructor tools from the student experience, discover the view switcher, switch views without losing their location, and inspect gated content without changing student access. Authors need a current single-page preview, direct bank-question preview, clear preview limitations, and a way to inspect the latest published course without manually building a test section.

The scope covers instructor perspectives and guidance, contextual notes and gated-content inspection, working authoring page and bank-question previews, limitation messages, and a student-only published-course preview from Review and Publish. Existing permissions, authoring preview contracts, and student delivery remain in force. The nine requirements below describe product outcomes; Story boundaries will be decided in Step 2.

Excluded: Publish-table redesign, support for unavailable page-preview activities, display of drafts in full-course preview, changes to student gating through preview bypass, and broader bank editor/filter redesign. Prototype-only behavior is excluded under Q1; the Make prototype remains inaccessible. The handoff’s written guidance criteria support R-009, while its detailed Figma placement still needs visual review during child UI analysis.

### Source evidence

| Source | Evidence and limits |
| --- | --- |
| [MER-6158](https://eliterate.atlassian.net/browse/MER-6158) | Links the handoff, design file, and Make prototype. No comments or child tickets are recorded in the available intake evidence. A current Jira read is unavailable because the CLI cannot resolve the Jira host; recheck the epic and children before filing. |
| [User Preview Overhaul — Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit) | Defines the eight feature areas, including Instructor Guidance on Switching Views, their acceptance criteria, accessibility requirements, and exclusions. Scope decisions in this overview govern implementation. Embedded Figma chips are not available as usable URLs through the connector. Switcher guidance behavior is supported by the written criteria; its frames require visual review during child UI analysis. |
| [Figma Handoff 2026](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13117) | The reviewed frames below establish layouts, preview banners, notes, gating states, and Review card states. Static frames do not establish interactive behavior beyond what they depict. |
| [Figma Make prototype](https://www.figma.com/make/gUx8oHNz23gIenz8htAL7C/Check-Prompt-Progress) | Inaccessible and excluded from the evidence base under Q1. Prototype-only interactions are unverified and outside the committed requirements. |
| `AGENTS.md`, `harness.yml`, [docs/ISSUE_TRACKING.md](docs/ISSUE_TRACKING.md) | Repository contracts, small-scope implementation, Jira approval/read-back requirements, and capability defaults. Feature flags, new telemetry, and additional performance requirements default to exclusion. |
| [docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/prd.md](docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/prd.md) | Existing MER-5617 scope: basic-page instructor shell, return context, authorization, no learner-progress side effects, and preservation of adaptive preview. Defines the implementation contracts this epic must preserve. |

### Design evidence

All frame links refer to the same User Preview Overhaul file.

| Area | Frames | What they establish |
| --- | --- | --- |
| Instructor/student views | [Instructor Interface](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-14126), [student page](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-14996) | Perspective selector, return action, and student-facing page layout. |
| Gating and notes | [Restricted](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-15826), [bypassed](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=529-11932), [instructor](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-15942) | Restriction message, reversible bypass, retained explanation, example bank-selection note, and settings links. |
| Author page preview | [Page preview](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13987) | Student page styling without course navigation and a persistent exit banner. The banner label is Page Preview (Q7). |
| Author bank preview | [Bank controls](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=534-12632), [standalone question](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13190) | Per-question Preview action, surrounding action styling, and isolated question with exit banner. Q5 excludes broader editor/filter redesign; Q7 names the banner Question Preview. |
| Preview limitations | [Information tooltip](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13208) | Indicator near affected content with explanatory text. The handoff supplies more specific messages. |
| Published course preview | [Never published](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=546-53431), [published](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=545-51964), [draft changes](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=546-54200), [existing template](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=553-14997), [Learn](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=563-30474) | Review card states, version/draft notices, course navigation, and primary exit action. Perspective switching is not shown in these course-preview frames; see Q2. |

### Agreed terminology

| Context | Visible label |
| --- | --- |
| Working authoring page | Page Preview |
| Individual bank question | Question Preview |
| Published course | Full Course Preview |
| Instructor perspective selector | Instructor View / Student Preview |

Follow the designs and use ordinary sentence casing for buttons changed by this epic: Page preview, Preview page, Show restricted view, Open full course preview, Preview published course, Go to Publish, View revision, and Edit title. Retain Publish as the name of the destination page. Preserve ordinary sentence casing in explanatory messages. The table names the preview contexts; button labels use sentence casing (Q7). Unrelated UI is outside scope.

## Product requirements

### R-001: Switch instructor perspectives without losing context

- Preview entry from course content, Customize Content, or Manage exposes a selector labeled with the active perspective. Confirm concrete entry-point mappings against existing routes during child analysis; the handoff's names do not exactly match the current return-context labels.
- Switching perspective preserves the current course page. Navigating or switching does not replace the original Return to [origin] destination.
- Student delivery and instructor Student Preview share the existing non-prefixed course routes, including `/sections/:section_slug/lesson/:revision_slug`; both render a student view of the materials. Instructor View uses `/sections/:section_slug/instructor/...`, replacing the existing `/preview/...` prefix across lesson, Learn, container, and adaptive-page routes. Switching perspectives preserves the resource and original return context. Course links in Student Preview stay on ordinary delivery URLs; Instructor View links retain `/instructor/...` (Q8).
- Instructor View and Student Preview are available to instructors in the requested section and authors with an admin role. Admin access does not require an instructor enrollment in that section. An instructor role in another section alone does not grant access. Keep actual user/author identity and roles for authorization while explicitly applying student presentation in Student Preview; ordinary students receive no instructor selector or controls. Preserve separate author Page Preview, Question Preview, and Full Course Preview routes and behavior, including existing template-preview sessions. Student Preview uses existing persistent attempt and progress storage for the current authenticated user (instructor or admin author). An admin author without a user account uses the existing section hidden instructor identity; that fallback may share saved state with other admins. There is no automatic reset (Q9).
- Return takes the user to that original location. Existing safe-return validation and fallback behavior remain intact.
- Hide the instructor preview header and perspective selector while managing an activity-bank selection because there is no equivalent student view. Retain a local back control to the containing course page. Returning restores the header and selector, with focus on the opener or a logical fallback (Q4).
- The selector exposes its accessible name, current choice, and expanded state; supports keyboard operation and Escape; and restores focus to its trigger when dismissed. View changes are announced. Switching retains selector focus when available.

- Sources and artifacts: [MER-6158](https://eliterate.atlassian.net/browse/MER-6158), [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [instructor frame](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-14126), [student frame](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-14996); Q4, Q7, Q8 below.

### R-002: Explain instructor preview content

- Show a nearby note labeled Instructor preview note for activity-bank selections. Explain that the displayed question is an example of what students may receive and identify any instructor-only action. Keep unrelated content free of the note.
- Notes follow reading order, are programmatically labeled, and do not take focus or announce as alerts. Interactive actions have descriptive names and visible focus. Students receive neither the notes nor instructor-only controls in visible markup or the accessibility tree.

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [bank-selection note](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=529-11932); Q7 below.

### R-003: Inspect restricted content without changing access

- Restricted Student Preview shows the student restriction message and an Instructor preview note with Preview page. Activating it reveals content and changes the action to Show restricted view; activating that restores the restriction message. Keep focus on the toggle, prevent hidden content from retaining focus, and announce the state change.
- Instructor View shows an informational banner linking to Assessment settings and Advanced gating tool. The bypass applies only to the instructor preview: it grants no student access, changes no gating settings, and completes no prerequisites. Students never receive the bypass or notes.

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [restricted](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-15826), [bypassed](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=529-11932), and [instructor](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-15942) frames; Q8 below.

### R-004: Preview a working authoring page

- The page editor’s secondary Page preview button opens the working page in current student styling, with a sticky Page Preview banner and exit action. Exit returns to the originating authoring page and restores focus to its preview action.
- Exclude previous/next navigation, course back navigation, the course outline, DOT, and instructor notes. Keep the banner usable on long pages, narrow screens, and at increased zoom.

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [page-preview frame](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13987); Q7 below.

### R-005: Preview a bank question in isolation

- Each bank question has a secondary Preview button that opens only that question in student styling, under a sticky Question Preview banner with exit. No course-page placement is required.
- Exit preserves bank search, filters, list position, and focus on the selected question’s Preview button. Preview does not modify the question.
- Edit, Copy, View revision, and Edit title adopt consistent design-system controls without changing behavior or permissions. Repeated controls identify their question; decorative icons are hidden from assistive technology. Broader editor and filter redesign remains outside this epic (Q5).

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [bank controls](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=534-12632) and [standalone question](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13190) frames; Q5, Q7 below.

### R-006: Explain verified page-preview limitations

All nine content types below are in scope (Q6). Embedded-activity failure messaging is conditional, and alternatives retain their strategy-specific explanations. Static code findings support these distinctions; targeted author-page runtime verification is required before implementation acceptance.

| Content | Required message/behavior |
| --- | --- |
| LTI external tool | You cannot interact with this tool in page preview. |
| File upload | File uploads are not available in page preview. |
| Directed discussion | Posting to discussions is not available in page preview. |
| Logic Lab | You can open this lab in page preview, but scores are not recorded. |
| Activity reports | This is sample data. Actual activity reports are not available in page preview. |
| OLI embedded activities | If a preview session cannot be created: Preview is not available for this activity. |
| Surveys | After submitting this survey in page preview, you cannot reset it here. |
| Alternatives | Preserve the existing strategy-specific explanation of the tabs or preference selector and how the configured policy selects content for students. Do not replace it with the handoff's generic all-alternatives message. |
| Page collaborative spaces | Labeled placeholder: Collaborative spaces are not available in page preview. |

- Put an information trigger beside affected content or its placeholder. Distinguish unavailable content, limited interaction, and sample data. Do not mark ordinary working scored activities unsupported or block review of the rest of the page.
- The trigger is a keyboard-focusable button with a descriptive name and `aria-describedby`. The tooltip opens on focus or hover, remains visible while focused/hovered unless dismissed, and closes with Escape without moving focus. Tooltips contain no interactive controls.
- Placeholders stay in normal reading order. Preserve supported evaluation, reset, hint, and embedded-preview behavior rather than disabling it to match a generic warning.
- Verify all nine types in authoring page preview before implementation acceptance, including supported interactions and embedded-session failure. This scope communicates limitations; it does not add support for unavailable functionality. Any runtime finding that requires a product-scope change returns for a decision.

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [information-tooltip frame](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=484-13208); Q6 below.

### R-007: Preview the latest published course

| Project state | Review card | Actions |
| --- | --- | --- |
| Never published | Explain that publication is required. | Go to Publish |
| Published without draft changes | Identify the version and explain that published content is used. | Open full course preview |
| Published with draft changes | Identify the version and count excluded draft changes. | Primary Open full course preview; secondary Go to Publish |

- Preserve automated review, existing review behavior, and the chart while updating the Review layout.
- Both Review and the new Preview published course action beside the latest Publish version open the same latest published version on Learn. Draft content is excluded. Preserve the existing Publish table.
- Base course navigation and exit behavior on the existing template-preview experience, with a Full Course Preview banner and a primary exit button. Author full-course preview is student-only and has no perspective selector. Full Course Preview has no dependency on the R-001 perspective selector (Q2).
- Publication details and draft counts are readable text, not color-only signals. Associate the card heading programmatically. Keep navigation keyboard accessible and provide an accessible return to authoring. Announce dynamic card updates without stealing focus; communicate a new-tab launch if that implementation is chosen.
- Reuse one dedicated review section per project. Before launch, refresh it to the latest published version. Retain existing template-preview identity and progress behavior: progress may persist, authors using the shared hidden identity may share state, and refreshing the section may affect other open previews. No automatic reset or new per-author isolation is included (Q3).

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [Review states](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=546-53431), [template preview](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=553-14997), and [Learn](https://www.figma.com/design/S8qAFhjjlnRyTHCg2Dyb8p/User-Preview-Overhaul?node-id=563-30474) frames; Q2, Q3, Q7 below.

### R-008: Keep preview controls accessible and authorized

All changed controls, notes, navigation, and tooltips must support keyboard operation, visible focus, descriptive accessible names, screen-reader state, and reflow at narrow widths and increased zoom. Instructors in the requested section and authors with an admin role may access instructor perspectives; ordinary students and users without those permissions must not receive instructor controls or notes. Keep existing project authorization for author previews and preserve safe return destinations. Each preview-specific requirement above adds its relevant focus, announcement, and failure behavior.

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), [MER-6158](https://eliterate.atlassian.net/browse/MER-6158), [AGENTS.md](AGENTS.md); Q4, Q7, Q8 below.

### R-009: Guide first-time instructors to the view switcher

- On the first entry to Instructor View after this feature releases, show a dismissible callout anchored to the instructor view dropdown and highlight the dropdown. Show the exact message: “Switch between instructor view and student preview.” The guidance belongs to Instructor View where the selector is present; do not show it in bank-selection management, which hides the selector under Q4, or in author previews.
- Provide a clearly labeled, keyboard-accessible dismiss control with an accessible name such as “Dismiss preview guidance.” Dismissal removes both the callout message and the dropdown highlight. The dropdown remains usable while the guidance is visible.
- Save dismissal for the instructor’s account, not for a course, browser, or session. After dismissal, subsequent visits across courses, sessions, and devices do not show the callout again. Merely displaying the callout is not dismissal.
- Escape dismisses when focus is within the callout. Make the message available to screen readers without automatically moving focus. Keep focus visible and unobscured; if dismissal removes the focused control, move focus to the instructor view dropdown.
- The written criteria define guidance behavior. Detailed placement and styling require review of the guidance Figma frame during child UI analysis. The handoff specifies no additional technical constraints for this feature.

- Sources and artifacts: [Design Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit), Instructor Guidance on Switching Views criteria; Q4, Q8 below. Guidance-frame visual placement awaits child UI analysis.

## Technical approach

### Observed repository behavior

| Area | Current implementation and consequence |
| --- | --- |
| Instructor shell | [lib/oli_web/components/delivery/layouts.ex](lib/oli_web/components/delivery/layouts.ex) renders a static Instructor view label and return action. [lib/oli_web/live/delivery/instructor/preview_lesson_live.ex](lib/oli_web/live/delivery/instructor/preview_lesson_live.ex) owns the basic-page shell. Add perspective selection to this existing surface rather than introduce a second independent instructor shell. |
| Ordinary instructor delivery | Ordinary lesson routes currently mount `Delivery.Student.LessonLive` for enrolled instructors as well as students. [lib/oli_web/live_session_plugs/init_page.ex](lib/oli_web/live_session_plugs/init_page.ex) initializes learner page context, and [lib/oli/delivery/page/page_context.ex](lib/oli/delivery/page/page_context.ex) tracks access and invokes the attempt lifecycle. Content audience and notes still recognize the instructor role. Q8 keeps these URLs for student presentation and requires instructor Student Preview to suppress instructor-only material without changing the user’s actual enrollment role. |
| Instructor routes | [lib/oli_web/router.ex](lib/oli_web/router.ex) and [lib/oli_web/delivery/instructor/preview_routes.ex](lib/oli_web/delivery/instructor/preview_routes.ex) currently use `/sections/:section_slug/preview/...` for Instructor View. Q8 renames that prefix to `/instructor/...`; Student Preview uses ordinary delivery URLs. Update helpers, generated links, and authorization redirects together. Legacy `/preview/...` links redirect to the corresponding Instructor View route under the same authorization checks for section instructors and admin authors; they do not define a separate Student Preview route family. |
| Return navigation | [lib/oli_web/delivery/instructor/preview_return.ex](lib/oli_web/delivery/instructor/preview_return.ex) resolves Customize Content, Assessment Settings, and Overview, sanitizes destinations, and falls back to section remix. `preview_routes.ex` and existing preview pages propagate navigation state. Preserve these contracts while adding perspective state. |
| Bank management | [lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex](lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex) currently renders the instructor header and a local back path. Hide the instructor preview header and perspective selector here; retain local back navigation and restore the containing page’s header and focus on return (Q4). |
| Preview side effects | [lib/oli_web/delivery/instructor/preview_page_context.ex](lib/oli_web/delivery/instructor/preview_page_context.ex) builds basic-page instructor content without learner visits, attempts, submissions, scoring records, or progress events. Preserve that existing contract. It is distinct from a template launch into student delivery. |
| Authorization | [lib/oli_web/plugs/authorize_section_preview.ex](lib/oli_web/plugs/authorize_section_preview.ex) currently permits section instructors or admins, redirects enrolled students to delivery, and rejects other unauthorized access. Q8 preserves access for instructors in the requested section and authors with an admin role, and requires both Instructor View and Student Preview to support those actors. Other existing permissions, including author full-course project authorization, remain unchanged. |
| Author page rendering | [lib/oli_web/controllers/resource_controller.ex](lib/oli_web/controllers/resource_controller.ex) resolves the working publication and supplies activity-bank selections. [lib/oli_web/templates/resource/page_preview.html.heex](lib/oli_web/templates/resource/page_preview.html.heex) still has a Preview Mode message, window-close exit, and previous/next navigation. Update this shell while retaining its working-draft semantics and selection-error feedback. Advanced delivery has a separate preview path that must remain compatible. |
| Activity preview evaluation | [assets/src/phoenix/activity_bridge.ts](assets/src/phoenix/activity_bridge.ts) handles author-preview evaluation, reset, hints, and client evaluations. [assets/src/data/persistence/activity.ts](assets/src/data/persistence/activity.ts) sends evaluation to `/project/test/evaluate`. Do not assume the instructor's read-only activity presentation and the author's interactive page preview are interchangeable. |
| Full-course launch | [lib/oli/delivery/template_preview.ex](lib/oli/delivery/template_preview.ex) currently accepts an active blueprint and authorizes its author/admin. It uses an existing user with student enrollment or a hidden instructor identity. [lib/oli_web/controllers/products_controller.ex](lib/oli_web/controllers/products_controller.ex) sets preview session/return state and launches the section root. This is reusable groundwork, but does not by itself establish a dedicated latest-publication review section for an arbitrary project. |
| Publication and Review UI | [lib/oli_web/live/projects/publish_view.ex](lib/oli_web/live/projects/publish_view.ex) already loads the latest/working publications and computes their diff. [lib/oli_web/live/qa/qa_live.ex](lib/oli_web/live/qa/qa_live.ex) owns automated review and its display. Reuse those publication semantics and preserve review functions when adding the card and launch actions. |
| Saved dismissal | [lib/oli/accounts.ex](lib/oli/accounts.ex) provides persisted `get_user_preference` and `set_user_preference` operations. [lib/oli/accounts/schemas/user_preferences.ex](lib/oli/accounts/schemas/user_preferences.ex) defines the embedded preference fields, including a dismissed instructor warning; [lib/oli_web/live/sections/assessment_settings/settings_live.ex](lib/oli_web/live/sections/assessment_settings/settings_live.ex) uses that preference. R-009 can reuse this account-level pattern with a dedicated guidance preference. |

Q8 keeps ordinary delivery URLs for students and instructor Student Preview, with Instructor View isolated under its own prefix. Student Preview needs explicit student presentation across audience filtering, notes, activity rendering, and gating; hiding instructor controls alone is insufficient. Real students must not receive instructor preview controls, notes, or gating bypasses. Existing author template-preview behavior remains separate. These findings come from code inspection, not runtime verification. Q9 retains ordinary persistent attempt and progress behavior for Student Preview. An admin author without a user account uses the existing hidden instructor identity, subject to validating its route and enrollment wiring during child analysis.

### Preliminary verification of limitation claims

- LTI has an explicit `author_preview` noninteractive branch in [assets/src/components/activities/lti_external_tool/LTIExternalToolDelivery.tsx](assets/src/components/activities/lti_external_tool/LTIExternalToolDelivery.tsx) with an existing warning. Activity reports use sample data in [lib/oli/rendering/report/html.ex](lib/oli/rendering/report/html.ex).
- OLI embedded activities attempt to create preview sessions in [assets/src/components/activities/oli_embedded/OliEmbeddedDelivery.tsx](assets/src/components/activities/oli_embedded/OliEmbeddedDelivery.tsx); unavailable messaging must be conditional, not a blanket unsupported label.
- Alternatives already have tabs or a preference selector plus strategy-specific explanations in [lib/oli/rendering/alternatives.ex](lib/oli/rendering/alternatives.ex) and [lib/oli/rendering/alternatives/html.ex](lib/oli/rendering/alternatives/html.ex). The generic all-alternatives message should not erase those distinctions.
- Surveys: [lib/oli/authoring/editing/page_editor.ex](lib/oli/authoring/editing/page_editor.ex) builds the author-preview context without overriding the empty `resettable_surveys` default in [lib/oli/rendering/context.ex](lib/oli/rendering/context.ex). [lib/oli/rendering/survey/html.ex](lib/oli/rendering/survey/html.ex) passes that value to [assets/src/components/delivery/SurveyControls.tsx](assets/src/components/delivery/SurveyControls.tsx), which only renders Reset when `canReset` is true. This supports the no-reset message for the current page-preview context.
- Logic Lab: [assets/src/components/activities/logic_lab/LogicLabDelivery.tsx](assets/src/components/activities/logic_lab/LogicLabDelivery.tsx) handles score and save messages only in delivery mode, supporting the distinction between opening a lab and recording scores in author preview.
- File upload: the author page constructs preview activity state rather than persisted attempts. [assets/src/components/activities/file_upload/FileUploadDelivery.tsx](assets/src/components/activities/file_upload/FileUploadDelivery.tsx) calls a section/attempt-based upload endpoint through [assets/src/data/persistence/state/intrinsic.ts](assets/src/data/persistence/state/intrinsic.ts); it has no author-preview upload path. This supports the unavailable-upload message, but the rendered control/error behavior still needs runtime verification.
- Directed discussion: its delivery component uses section-backed APIs through [assets/src/components/activities/directed-discussion/discussion/discussion-service.ts](assets/src/components/activities/directed-discussion/discussion/discussion-service.ts), while the author page supplies project context. The read-only instructor-preview component is a different rendering path and does not prove author-page behavior. Verify the author-page presentation and failed posting behavior during implementation; do not add discussion-posting support under this epic.
- Page collaborative spaces: the basic author-page preview template does not render a page collaboration surface. The labeled placeholder must use the page's collaboration configuration to appear only where relevant.
- These are static code findings, not end-to-end test results. Runtime behavior is unverified. Targeted verification must cover all nine content types in the author-page context before their implementation is accepted, including supported behavior and embedded-session failures.

### Review-section behavior

Use one reusable, dedicated review section per project, refreshed to the latest publication on launch (Q3). Reuse existing template-preview identity and progress behavior, including its shared hidden identity where applicable. This avoids requiring a new section for every launch or author. The project-to-review-section association and launch refresh must support this behavior; their schema and transaction details belong to child analysis and architecture. Automatic progress reset, new per-author isolation, retention mechanisms, and background synchronization jobs are outside scope.

### Proposed implementation approach

Reuse existing preview shells, route helpers, authorization, renderers, and publication queries. Keep perspective, original return context, and local gating-bypass state distinct so changing one cannot silently change the others. Build notes and limitation indicators with existing design-system patterns. These are implementation proposals for later child analysis, not requirements for a new preview framework.

For R-009, propose a dedicated persisted user preference for dismissal, defaulting to not dismissed for existing and new instructors. No separate table, generic onboarding framework, or browser-only dismissal store is needed based on current evidence. Verify persistence failure and stale account reads during child analysis; do not treat an unsuccessful write as a saved dismissal.

For R-001, reuse persistent page visits and attempts under the current authenticated user account. For an admin author without a user account, reuse the existing section hidden instructor identity. The ordinary delivery route currently requires a user and performs enrollment checks, so child analysis must verify the identity and routing changes needed for admins, including admins with a user account but no student enrollment. Preserve authorization based on the actual author or instructor, rather than treating the preview identity as the permission source. Do not add automatic reset or temporary attempt storage.

No additional telemetry, feature-flag rollout, or numerical performance target is proposed. Required accessibility, security, and publication contracts come from the handoff and repository evidence above, with the Q8 access rule for section instructors and admin authors explicitly recorded. The existing instructor preview's no-learner-side-effect contract remains distinct from full-course preview's retained template-preview progress behavior.

## Open decisions

No product decision remains open. The overview still needs explicit operator acceptance before decomposition. The Make prototype is excluded from the evidence base (Q1), and broader bank UI redesign is outside this epic (Q5). Runtime verification under Q6 remains an implementation requirement.

| ID | Decision and consequence | State / owner / next point |
| --- | --- | --- |
| Q1 | Use the written handoff, static designs, and repository evidence. The inaccessible Make prototype supplies no committed requirements; do not infer prototype-only interactions. | Accepted evidence exclusion; does not block decomposition. Reassess scope if prototype evidence becomes available. |
| Q2 | Author Full Course Preview is student-only, with no instructor perspective or selector. Instructor perspective switching is scoped to R-001; R-007 does not depend on it. | Accepted. |
| Q3 | Reuse one dedicated review section per project, refresh it to the latest publication on launch, and retain template-preview identity/progress behavior. No automatic reset or new per-author isolation. Progress may persist, authors may share hidden-identity state, and refresh may affect open previews. | Accepted; schema and transaction details belong to child analysis. |
| Q4 | Hide the instructor preview header and selector in activity-bank selection management. Keep local back navigation that restores the containing page’s header, selector, and focus on the opener or a logical fallback. | Accepted. |
| Q5 | Limit bank UI work to Preview and design-system controls for Edit, Copy, View revision, and Edit title. Broader question-editor and filter redesign is outside this epic. | Deferred scope is non-blocking. Product/UX owns any separate bank UI effort; no delivery commitment is included here. |
| Q6 | Cover all nine R-006 content types. Show embedded-activity unavailability only on preview-session failure; retain strategy-specific alternatives explanations and supported interactions. Verify all nine types in author-page context before implementation acceptance. | Accepted scope; runtime verification is pending implementation. Product-scope changes require review. |
| Q7 | Use Page Preview, Question Preview, and Full Course Preview for the respective preview contexts, and Instructor View / Student Preview for the selector. Follow the designs and use ordinary sentence casing on buttons. Unrelated UI is outside scope. | Accepted. |
| Q8 | Student delivery and instructor Student Preview share ordinary course URLs and render student materials. Instructor View uses `/sections/:section_slug/instructor/...`; legacy `/preview/...` links redirect there. Both views allow section instructors and admin authors; admins need no section instructor enrollment. Preserve actual identities/roles and separate author preview behavior. The related delivery must cover navigation, authorization, and regression checks. | Accepted; decomposition and Jira write approval are pending. |
| Q9 | Student Preview keeps persistent attempts and progress under the current authenticated user account. An admin author without a user account uses the existing section hidden instructor identity; admins using that fallback may share saved state. There is no automatic reset. Author Full Course Preview keeps its separate Q3 policy. | Accepted. Child analysis verifies admin route and enrollment wiring without changing this behavior. |

### Decision log

- 2026-11-09 — Q1: Proceed from the written handoff and static Figma designs without inferring behavior from the inaccessible Make prototype.
- 2026-11-09 — Q2–Q6: Keep Full Course Preview student-only; reuse one review section per project and existing template-preview identity/progress behavior; hide the switcher in bank management; defer broader bank editor/filter redesign; cover all nine page-preview limitation types with targeted runtime verification.
- 2026-11-11 — Q7: Use context-specific preview names and sentence casing for changed buttons.
- 2026-11-11 — Q8: Use ordinary delivery routes for Student Preview and an `/instructor/...` prefix for Instructor View; permit section instructors and admin authors.
- 2026-11-11 — R-009: Include first-entry switcher guidance with durable per-instructor dismissal.
- 2026-11-12 — Q9: Keep persistent Student Preview attempts/progress under the current user or the hidden instructor fallback for an admin author without a user account; do not reset automatically.

## Child work items

Pending Step 1 overview acceptance. No Step 2 decomposition is approved.

## Lanes

Pending overview approval and Step 2 decomposition.

## Jira filing and next work

Jira filing is pending and requires a separate exact-payload review and explicit write approval. After overview acceptance, decompose requirements, analyze coverage, review Stories and lanes, and then prepare filing drafts. The next work item for `harness-analyze` will be selected after Step 2 approval and Jira filing.
