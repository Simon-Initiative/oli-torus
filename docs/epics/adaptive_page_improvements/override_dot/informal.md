# MER-4943 - override_dot

## Jira Description

# User Story

As an author, I want to be able to toggle DOT visibility on adaptive pages, even when they are scored, because some scored adaptive pages are formative assessments and DOT should be available to the learner.

# Acceptance Criteria

## Positive Acceptance Criteria

* Given a **scored adaptive page**
    * When a user opens the page configuration UI (e.g., Page Options modal or Advanced Authoring Panel)
        * Then they see an option to **Enable DOT on this page** (default: unchecked)

* Given the option is **enabled**
    * When a learner views the page
        * Then **DOT is visible and accessible** to the learner during the activity

* Given the option is **disabled** (default)
    * When a learner views the page
        * Then **DOT remains hidden**, consistent with the current behavior for scored adaptive pages

## Negative Acceptance Criteria

* Given a **non-adaptive page** or a **non-scored adaptive page**
    * When a user configures the page
        * Then **DOT behavior remains unchanged**, and no new toggle appears

* Given no changes made to a scored adaptive page
    * When a learner views it
        * Then **DOT remains hidden by default**

## Design Notes

* Add a toggle or checkbox to the authoring UI labeled: "Enable DOT on this page"
* Location:
    * **Advanced Author Lesson Panel** inside the adaptive page editor, underneath "Enable Dark Mode"

**Student Interface**

![](blob:https://media.staging.atl-paas.net/?type=file&localId=null&id=db5c9209-5ecc-4546-b76d-061b1e0d6104&&collection=&height=505&occurrenceKey=null&width=713&__contextId=null&__displayType=null&__external=false&__fileMimeType=null&__fileName=null&__fileSize=null&__mediaTraceId=null&url=null)
![](blob:https://media.staging.atl-paas.net/?type=file&localId=null&id=8ce44bed-ebf9-4cd0-b6c0-a13b2477ed47&&collection=&height=467&occurrenceKey=null&width=848&__contextId=null&__displayType=null&__external=false&__fileMimeType=null&__fileName=null&__fileSize=null&__mediaTraceId=null&url=null)

## Darren Siegel Technical Guidance Comment

Technical guidance:

This is a FEATURE. Slug: override_dot

We need to make this option work for both basic pages and adaptive pages, for both practice and scored contexts.

Approach: Add a new option in authoring page options modal (from curriculum and from All Pages) "Enable AI Assistant (DOT)"

For Adaptive, Scored pages this value defaults to UNCHECKED

For Adaptive, Practice pages this value defaults to CHECKED

For Basic, Scored pages this value defaults to UNCHECKED

For Basic, Practice pages this value defaults to CHECKED

This will require a new Revision attribute: "ai_enabled" (boolean), and a new SectionResource attribute "ai_enabled". The logic that populates new Revisions based on a previous in Authoring must be updated. The logic that populates attrs in SectionResource records from Revisions must be updated. A good way to track down all places to update is to search code base for OTHER attributes that are common to Revision and SectionResource (e.g. max_attempts). Finally, the check in page rendering as to whether or not DOT (ai assistant) is enabled has to take into account BOTH this new setting and the overall section level setting.
