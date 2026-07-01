# MER-5052 - student_responses

## Jira Description

## User Story

As an instructor, I want to see student responses for adaptive page screens in Instructor Insights and Analytics, so that I can review how students answered each question or interacted with native components - similar to how responses are shown for basic pages.

Currently, in basic pages, student responses appear in a table below the question details. However, visibility is inconsistent - responses sometimes only load for numeric components. For adaptive pages, this visibility should be expanded and reliable, displaying student responses for all supported native component types.

## Acceptance Criteria

### Positive Acceptance Criteria

Given an instructor is viewing an adaptive page in Instructor Insights and Analytics:

* When the instructor clicks on a screen within that adaptive page
    * Then the screen renders as expected, and below the rendering, a student responses table appears showing all recorded responses for supported components.

* Given a screen contains supported component types
    * When the instructor opens it
        * Then each component displays the student's recorded response(s) with proper formatting and labeling.

Supported component types (MVPs marked with *):

* Number *
* Text *
* Multiline Text *
* Multiple Choice Question (MCQ) *
* Dropdown
* Fill in the Blank (FITB)
* Numeric Slider
* Text Slider

Adaptive page responses should display in the same table format used for basic pages to maintain consistency across page types.

### Negative Acceptance Criteria

* Given an adaptive page screen contains iframed or external components (e.g., simulations, third-party widgets)
    * When viewing student responses
        * Then those responses are not displayed at this time. (Future enhancement possible.)

* Given an instructor views a basic page
    * When viewing student responses
        * Then behavior remains unchanged.

## Darren Siegel Technical Guidance Comment

This is a FEATURE. slug: student_responses

The work here will be to first inspect how these adaptive evaluated responses are being captured right now, today in the ResourceSummary and more importantly ResponseSummary aggregation tables. Those are the tables that I believe are directly queried right now to populate basic page student response tables in these UIs.

From there, we have two paths ahead of us: 1) Current adaptive page capture in those aggregated tables is sufficient to meet this feature's needs. 2) Current capture is NOT sufficient.

In the case of (2) we have to make the necessary post-evaluation SummaryAnalytics pipeline adjustments to properly capture adaptive page student responses.

Then we make the changes to correctly post-process adaptive page responses in the ResponseSummary related querying in ScoredActivities and PracticeActivities infra so that they correctly render and correctly are labeled by the different types (the type bucketing likely involves link to the part definition in the activity revision, do this very carefully - a naive join here could be disastrous).
