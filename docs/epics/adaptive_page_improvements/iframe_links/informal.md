# MER-5212 - iframe_links

## Jira Description

Enable authors to embed **iframes** in Adaptive Pages where the `src` is a **dynamic reference** to another screen or resource in the same project. These links must resolve correctly at runtime based on the course section context.

### Why It Matters

This allows authors to **embed live content** from other parts of the course - like other lessons - *inside an iframe*, and avoid using hardcoded links that may break or can only be used in one course section.

### User Stories

**As an author:**

* I want to embed another page/resource in an iframe by referencing its ID or slug.
* I want the iframe to dynamically point to the correct URL in a live section.
* I want validation to warn me if the referenced resource is missing or invalid.

**As a student:**

* I want iframes to display live course content from other pages/resources.
* I want the iframe to work across all environments without breaking.

### Acceptance Criteria

#### Positive

* Given an author is editing an adaptive screen
    * When they insert an iframe
    * Then they can set the `src` using a reference to another screen/resource (ID or slug)

* Given a course section is created from a project
    * When the iframe uses a dynamic reference
    * Then the `src` resolves to the correct runtime URL in the live course

* Given a student views a page with a dynamic iframe
    * Then the embedded content displays correctly

#### Negative

* Given the iframe points to a deleted or invalid reference
    * Then the author is warned in authoring
    * And the student sees a clear error or fallback message in delivery

### Design Notes

* May need additional UI in the iframe component config panel to allow dynamic reference selection.

## Darren Siegel Technical Guidance Comment

Technical Guidance:

This is a FEATURE. slug: iframe_links

This feature should be implemented AFTER dynamic_links (MER-5211). The rewriting logic and approach and link structure approach used in dynamic_links will be extended to support Adaptive Page iframe part components.

New authoring UX will be built according to requirements in this ticket to create these new structured links. We likely can only support links to PAGES not links to SCREENS (activities) within pages. The link structure MUST only store resource_id, not revision slug. Same runtime replacement and creation of full lesson links as in dynamic_link feature.
