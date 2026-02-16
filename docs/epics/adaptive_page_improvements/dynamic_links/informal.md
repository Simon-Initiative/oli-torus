# MER-5211 - dynamic_links

## Jira Description

## Summary

Basic pages currently support dynamic linking to other resources within the same project, where links are automatically updated based on the course section. This functionality is not yet available in **adaptive pages**, but it is essential for creating connected, seamless learning experiences.

We need to enable dynamic internal linking within adaptive pages, so that links to other pages in the same project are automatically updated when a course section is created.

## Why It Matters

This enables authors to build **modular, interconnected lessons** by referencing earlier or related content. Without this, authors must hardcode URLs (which break across environments) or avoid linking altogether.

## User Stories

As an author:

* I want to add in-screen hyperlinks that route students to other screens/resources in the same project/section.
* I want to select text and apply a hyperlink to another internal page using a simple interface.

As a student:

* I want internal links to take me to the right place in the course, but to open in a new tab.
* If the link is broken, I want to know what happened and return to where I was.

## Acceptance Criteria

### Positive

* Given that an author is editing text in an adaptive screen
    * When they select text and add a link
        * Then they can choose from available screens/resources in the same project using `resource_id` only (slug-based links are not allowed)

* Given a course section is created from a project
    * When dynamic links are included in adaptive pages
    * Then the links automatically resolve to the correct live section URLs

* Given a student clicks a dynamic link
    * Then the referenced screen or resource loads as expected

### Negative

* Given an author tries to delete a screen with active dynamic links pointing to it
    * Then the author is warned and shown which pages link to it

* Given a student clicks a broken dynamic link
    * Then they see a message with an option to return to the previous screen and report the issue

## Design notes

We'd like it to work similarly to Basic Pages.

# From Darren

At the authoring level, it crafts the link relative to the project, but at the course section runtime, it replaces that link relative to the course section. But for adaptive pages, it's entirely client-side.

## Darren Siegel Technical Guidance Comment

Additional technical guidance:

This is a FEATURE. Slug: dynamic_links

## Links to other pages in the course

The adaptive authoring work here will be to introduce a new authoring feature in the adaptive author the ability to create a link that points to another activity (screen) in the page. The link src or href must be constructed in the exact same way that basic page internal links are constructed (look that up) but basically it includes the resource_id of the page being linked to. We MUST use resource_id here and NOT slug because exporting and re-importing would break links (as revisions on import get all new slugs, but import handles a resource_id update for new ids). So adaptive links should do the same thing and use same structure.

Page import must be extended to rewrite these links when encountered during import. There is already code that does this for basic pages and activities, but adaptive activitys have a different structure for content. Make this REWRITE code flexible and parameterizable.

Then on delivery when we render a page and give it activity (screen) content (there are multiple places server-side where I believe this is done, "bulk activity fetch API" is one) we will server-side rewrite the activity content to update these links to be proper lesson links as defined in the router `/sections/:section_slug/lesson/:page_revision_slug`.

## Note to Developer

Find examples in JSON of actual regular hyperlinks in adaptive activity JSON (make one if you need to) so that you understand that structure and can plan out the two new link types. Review also the current BASIC page link structure for page to page links. Give all of that (plus your new link structures) to spec_analyze as part of this informal description.
