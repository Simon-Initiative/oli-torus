# Google Analytics event catalog (MER-5306)

Torus sends a small catalog of product events to Google Tag Manager (GTM) for aggregate
navigation and feature-adoption analysis by role, course and activity type. This document is the
reference for product and for GTM configuration. Installation, consent and QA are covered in
`docs/runbooks/google-analytics.md`.

The single definition is `priv/analytics/event_catalog.json`. Change events, parameters and
values there, then update this document; `test/oli_web/analytics/catalog_test.exs` fails if the
document misses any of them. Adding a value, such as a new `feature_name`, requires a catalog
change and review.

## Relationship to Torus telemetry

`lib/oli/analytics/xapi/*` remains the authoritative learner-state pipeline: page views, attempt
evaluations, tutor messages and video statements. GA is for aggregate product and navigation
analytics only. GA counts will **not** match xAPI because of consent, ad blockers and LMS iframe
cookie loss. Treat GA as directional and never reconcile the two.

## How events are emitted

All events go through the writer in `assets/src/analytics/index.ts`, the only code that writes
to `window.dataLayer`.

- **Server (LiveView):** `OliWeb.Analytics.track(socket, name, params)` validates against the
  catalog and pushes `analytics:track`. `OliWeb.Analytics.js_track(js, name, params)` does the
  same from a JS command, for UI actions that never reach the server.
- **Browser:** `track({name, params})` from `assets/src/analytics/track.ts`. Its type is a
  discriminated union derived from the catalog, so unknown events, values or parameters fail
  type checking. It is safe to import from any bundle.
- **Writer:** context parameters are always resolved on the server and added by the writer.
  Emitters only supply event parameters. Parameters that are not catalogued for the event, invalid
  values and context parameters are dropped with a warning (Elixir logger; browser console outside
  production). Uncatalogued events are not sent.

Each event has exactly one designated emitter, listed below, so LiveView and React never both
report the same action.

## Context parameters

Resolved by `OliWeb.Analytics` from assigns that are already loaded, with no extra database
queries. They are published with the MER-5292 page-view context (head bootstrap and the LiveView
`handle_params` hook), and the `torus_page_view` push also carries `user_role`, `course_id` and
`page_type`. On hard-loaded prologue, lesson, adaptive lesson and review pages, the head context
already includes `page_type`, taken from the revision `OliWeb.Plugs.RedirectByAttemptState`
resolves, so the first page view is typed before LiveView connects.

| Parameter | Values |
| --- | --- |
| `user_role` | See the rules below. Omitted when nobody is signed in. |
| `page_area` | `delivery`, `instructor`, `authoring`, `admin`, `public` (MER-5292 route areas) |
| `course_id` | Base project ID of the course design: `section.base_project_id` in delivery, `project.id` in authoring. Never a section, cohort or slug. |
| `page_type` | Lesson pages only: `practice`, `graded`, `adaptive`, `exploration`, `other` |
| `entry_point` | `course_entered` only: `lti` for LMS accounts, `direct` for independent accounts, guests and administrators |

`user_role` rules, in order:

1. `admin`: an author with an administrator system role, or the administration area.
2. `author`: the authoring area, or a template preview.
3. `instructor`: the instructor area, or an instructor preview of a course section. Preview
   routes are only authorized for instructors and administrators.
4. `guest`: a guest user.
5. `learner`: any other signed-in user.

An instructor who opens learner pages outside preview is reported as `learner`, because the
section's context roles are not loaded on those pages and the role is resolved without queries.

`page_type`: `adaptive` (advanced delivery, graded or not), then `graded`, then `exploration`
(exploration purpose), then `practice` for other pages and `other` for any other resource.

## Events

Every event also carries `user_role` and `page_area`.

| Event | When it fires | Parameters | Designated emitter |
| --- | --- | --- | --- |
| `course_entered` | First time a user reaches a delivery or instructor page of a course in a browser-tab session. | `course_id`, `entry_point` | Writer, from the page context |
| `page_entered` | User opens a lesson page. | `course_id`, `page_type` | `OliWeb.Delivery.Student.LessonLive` for basic pages; the adaptive delivery app (`assets/src/apps/delivery`) for adaptive pages |
| `page_completed` | Learner submits (finalizes) a graded page. Practice-page completion and finalization of expired attempts are not reported. | `course_id`, `page_type` | `LessonLive` `finalize_attempt`; `assets/src/apps/delivery/layouts/deck/LessonFinishedDialog.tsx` |
| `attempt_submitted` | Learner successfully submits an activity or part attempt, after the API succeeds. | `course_id`, `page_type`, `activity_type` | `assets/src/phoenix/activity_bridge.ts`; `assets/src/apps/delivery/store/features/adaptivity/actions/triggerCheck.ts` |
| `hint_viewed` | Learner receives a hint. Requests that succeed after the last hint, with nothing to show, do not count. | `course_id`, `page_type`, `activity_type` | `assets/src/phoenix/activity_bridge.ts` |
| `video_started` | First play of a video on a page view. | `course_id`, `page_type`, `video_source` | `assets/src/components/video_player/VideoPlayer.tsx`, `assets/src/components/youtube_player/YoutubePlayer.tsx`, `assets/src/hooks/video_player.ts` (Learn page intro videos) |
| `video_completed` | Video reaches its end, the same trigger as xAPI `video_completed`. | `course_id`, `page_type`, `video_source` | Same as `video_started` |
| `feature_used` | User completes a meaningful feature action. | `feature_name`, `feature_area`, `course_id`, `page_type` | See the feature table |
| `file_link_clicked` | User clicks a file link in lesson content. | `course_id`, `file_type` | Writer, delegated click listener on `#page_content` |

Parameter values:

- `activity_type`: the activity registration slug, such as `oli_multiple_choice`; letters,
  digits, `_` and `-` only, at most 64 characters.
- `video_source`: `hosted` (Torus player) or `youtube`.
- `file_type`: `pdf`, `doc`, `slides`, `sheet` (including CSV), `image`, or `other` for any
  other media library file. Links count when the file extension is known or the link points to
  the media library. Only the type is sent, never the URL or file name.

### Features

`feature_area` is derived from `feature_name` by the writer; emitters never send it. Its values
are `ai_assistant`, `navigation`, `notes`, `preview` and `authoring`.

| `feature_name` | `feature_area` | When it fires | Emitter |
| --- | --- | --- | --- |
| `dot_opened` | `ai_assistant` | Learner opens DOT. | `OliWeb.Dialogue.WindowLive` (JS command) |
| `dot_question_submitted` | `ai_assistant` | Learner sends a question to DOT. | `WindowLive` |
| `outline_opened` | `navigation` | Learner opens the lesson outline panel. | `LessonLive` |
| `notes_opened` | `notes` | Learner opens the lesson notes panel. | `LessonLive` |
| `search_used` | `navigation` | Learner starts searching on the Learn page; refining the same search does not count again. | `OliWeb.Delivery.Student.LearnLive` |
| `filter_used` | `navigation` | Learner changes the Assignments filter. | `OliWeb.Delivery.Student.AssignmentsLive` |
| `preview_launched` | `preview` | Instructor or author preview starts, once per browser-tab session and course. | Writer, from the page context |
| `template_preview_launched` | `preview` | Template preview starts, once per browser-tab session and template. | Writer, from the page context |
| `author_publish_clicked` | `authoring` | Author clicks Publish. | `OliWeb.Workspaces.CourseAuthor.PublishLive` |

## Rules enforced by the writer

- **Consent:** nothing is pushed until analytics consent is granted and GTM is configured. After
  withdrawal nothing is pushed. Events are never queued or replayed.
- **Previews:** in instructor, author and template previews, only `feature_used` events whose
  `feature_area` is `preview` are sent. Learner events never mix with preview traffic.
- **Course entry and preview launch** are remembered in session storage per browser tab. Where an
  LMS iframe blocks session storage they count once per full page load instead.
- **Stale values:** every push sets all catalogued parameter keys, with `undefined` for those that
  do not apply. GTM merges pushes into one data model, so this prevents an earlier event's
  `activity_type`, for example, from being attributed to a later event.

## Privacy

Never sent: names, emails, usernames, `user_id`, `author_id`, LMS/LTI subject IDs, `section_id`
or section slug, `resource_id` or revision slug, attempt GUIDs, `datashop_session_id`, free text,
learning content, responses, titles, URLs, file names, search terms, scores, correctness, attempt
numbers and hint numbers. Item-level learner state stays in the xAPI pipeline. GA's own client-ID
cookie is governed by MER-5307.

`course_id` is the single, deliberate exception to "no raw IDs": it identifies a course design,
not a person or cohort. Residual risk: `course_id` with `user_role=instructor` could single out
an instructor when a course design is used by a single section. This is accepted. GA4 reporting
thresholds do not apply because Google Signals stays disabled.

## Not in this catalog

- `page_exited` was dropped: GA4 engagement time covers the need, and exit tracking is
  unreliable inside LMS iframes.
- Practice-page completion needs a server completion signal and is deferred.
- Adaptive pages do not report `hint_viewed`. The Learn page's YouTube intro videos report
  `video_started` when playback is requested, and cannot report completion because the plain
  embed exposes no player events.
- Follow-up stories: enrollment and payment funnel (`payment_started`, `payment_succeeded`,
  `payment_failed`, measured around the excluded card-entry page), authoring publish-flow steps
  beyond `author_publish_clicked`, adaptive screen navigation (`adaptive_screen_changed` by screen
  index only) and coarse UX performance (load failures, render errors, time-to-visible buckets).

The open questions in MER-5306 were implemented with their proposed defaults; confirm them with
product before rollout.
