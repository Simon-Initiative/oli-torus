# MER-4082 - adaptive_duplication

## Jira Description

In Torus, users can duplicate basic pages within a project, but this functionality is **not available** for adaptive pages. Adding the ability to duplicate adaptive pages would streamline workflows, enabling authors to reuse and modify existing pages without having to recreate them from scratch.

## Duplication with Basic Pages

![](blob:https://media.staging.atl-paas.net/?type=file&localId=null&id=6c063cda-84af-440a-9c13-38fdd70a4819&&collection=&height=257&occurrenceKey=null&width=825&__contextId=null&__displayType=null&__external=false&__fileMimeType=null&__fileName=null&__fileSize=null&__mediaTraceId=null&url=null)

## No Duplication with Adaptive Pages

![](blob:https://media.staging.atl-paas.net/?type=file&localId=null&id=4d81785d-7b6e-4a8b-98a2-d25a1166056e&&collection=&height=208&occurrenceKey=null&width=850&__contextId=null&__displayType=null&__external=false&__fileMimeType=null&__fileName=null&__fileSize=null&__mediaTraceId=null&url=null)

# **Note from Darren**

Ensure that all internal references are being updated properly.

This ticket may need to be done in partnership with Devesh in order to ensure that all unique aspects of adaptive pages are covered.

# **User Story**

As an author I want to be able to duplicate pages I've already created in a project.

# Acceptance Criteria

## Positive

* Given the author created a project and an adaptive page
    * When they duplicate an adaptive page within a project
        * Then the adaptive pages is duplicated with all the contents and trapstate logic
        * Then all internal page references are kept and updated properly.

## Negative

* Given the author created a project with an adaptive page
    * When duplication cannot safely preserve activity content or internal references
        * Then duplication is blocked and no duplicate page is created.

# Design notes

N/A

## Darren Siegel Technical Guidance Comment

Technical guidance:

This is a FEATURE. Slug: adaptive_duplication

This needs to be guarded by a feature flag.

The current page duplication logic must be specialized between basic pages and adaptive pages - allowing for a completely different implementation for adaptive pages.

Duplicating an adaptive page requires duplicating all of the activities that comprise that adaptive page (similar to basic page duplication), but a key difference is that an adaptive page revision contents contains a sort of "table of contents" that lists all the activities (other resources that have revisions) that comprise the adaptive page. This table of contents maintains internal references.

Duplication then is a multi-step process: create new resources and new revisions for all of the activities and the page itself. Then ensure that these new identifiers are correctly captured in the page revision content.

Note to engineer: before generating a PRD and FDD, you must find actual JSON content of an adaptive page content and activity content JSON that illustrates this internal mapping in the page content. In the informal description that is given to spec_analyze, reference these documents and explain exactly how the mapping works.
