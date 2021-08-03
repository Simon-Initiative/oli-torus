# Changelog

## Unreleased

### Bug Fixes

### Enhancements

- Redesign overview page, change language

## 0.12.7 (2021-08-02)

### Bug Fixes

- Fix styling issues including darkmode

## 0.12.6 (2021-07-29)

### Bug Fixes

- Fix an issue with timestamps containing microseconds

## 0.12.5 (2021-07-29)

### Bug Fixes

- Fix an issue when creating snapshots for insights

## 0.12.4 (2021-07-27)

### Bug Fixes

- Updated research consent form

## 0.12.3 (2021-07-23)

### Bug Fixes

- Fix datashop export content model parsing
- Fix incorrect table column alignment on Insights page
- Truncate "relative difficulty" on Insights page
- Change wording on "Break down objective" modal
- Make "Break down objective" explanation image responsive
- Fix page editor content block rendering issue in Firefox - increase block contrast
- Fix problem in Firefox where changing question tabs scrolls to top of page

### Enhancements

## 0.12.2 (2021-07-21)

### Bug Fixes

- Fix an issue where deleting multiple choice answers could put the question in a state where no incorrect answer is found
- Fix an issue where activities do not correctly restore their "in-progress" state from student work
- Fix an issue where images and audio could not be added to activiites

## 0.12.1 (2021-07-12)

### Bug Fixes

- Fix an issue where activities do not render correctly in delivery mode

### Enhancements

## 0.12.0 (2021-07-12)

### Bug fixes

- Fix an issue with image coding activity in preview
- Persist student code in image coding activity

### Enhancements

- Add ability to generate and download a course digest from existing course projects
- Redesign check all that apply, multiple choice, short answer, and ordering activities
- Merge activity editing into the page editor
- Redesign the workspace header to include view title, help and user icons
- Clearly separate the hierarchy navigation and page editing links in curriculum editor
- Implement smaller sized left hand navigation pane

## 0.11.1 (2021-6-16)

### Bug fixes

- Fix an issue preventing deletion of projects whose names contain special characters
- Fix an issue related to persisting sessions across server restarts
- Fix an issue where modals and rearrange were broken in curriculum view
- Fix an issue where toggling multiple choice answer correctness could cause submission failures

## 0.11.0 (2021-6-15)

### Enhancements

- Image coding: disable submit button before code is run
- Allow setting of arbitrary content from upload JSON file in revision history tool
- Add ability for independent learners to create accounts, sign in and track progress

### Bug fixes

- Image coding: remove extra space at end of printed lines (problem for regexp grading)
- Fix issues related to exporting DataShop events for courses that contain hierarchies
- Fix an issue with the torus logo in dark mode
- Fix to support rich text content with empty models
- Fix to properly identify the correct choice in multiple choice activities
- Fix internal authoring links

## 0.10.0 (2021-6-2)

### Enhancements

- Add support for detecting problematic database queries
- Allow adaptive pages to render without application chrome
- Save cookie preferences in delivered courses
- Add support for page content grouping
- Add image resizing
- Introduce load testing support
- Expose telemetry metrics for Prometheus metrics scraping
- Add support for course package delete
- Add support for disabling answer choice shuffling in multiple choice, check all that apply, ordering questions
- Add support for moving curriculum items
- Allow analytic snapshot creation to run asynchronous to the rest of the attempt finalization code

### Bug fixes

- Fix help and logo links on register institution page, change help form to modal
- Add missing database indexes, rework resolver queries
- Fix ability to request hints
- Fix content editing after drag and drop in resource editors
- Fix internal links in page preview mode
- Fix projects view project card styling
- Fix problem with inputs causing clipping in Firefox
- Fix problem with difficulty selecting and focusing in Firefox
- Fix problem where containers with no children were rendered as pages in delivery
- Fix some style inconsistencies in delivery and dark mode
- Fix an issue where reordering a curriculum item could result in incorrect n-1 position

## 0.9.0 (2021-4-22)

### Enhancements

- Add OpenAPI docs for user state service
- Enable OpenAPI docs on all environments at /api/v1/docs
- Add ability to change images in pages and activities
- Add extrinsic user state at the resource attempt level
- Add bulk fetch endpoint for retrieving collection of activity attempts
- Add sequential page navigation to editor and full course preview
- Enable ecto repository stats in live dashboard
- Add ability to unlink a course section from an LMS
- Image code activity: use syntax highlighting code editor

### Bug fixes

- Support page-to-page links during course ingestion
- Use section slugs instead of ids in storage service URLs for delivery endpoints
- Fix a crash when an existing logged-in user accesses the Register Institution page
- Activity feedback fixes and unit tests
- Remove support for image floating to fix display issues in text editors
- Change activity rule, outcome modeling for use in adaptive activities
- Fix an issue when creating section allows multiple sections to be created
- Improved rendering robustness when content elements are missing key attributes
- Disable access to OpenAPI docs in production

## 0.8.0 (2021-4-12)

### Enhancements

- Add multi-project support to Revision History tool
- Add Open and Free section support
- Feature flag support
- Add research and cookie consent support
- Extrinsic user state endpoints

### Bug fixes

- Fix analytics / insights to not show parent course analytics after duplication
- Remove help link in preview mode
- Fix security vulnerability
- Account for ingested pages that have missing objectives
- Fix check all that apply + ordering activity submission in published projects
- Fix issue where long lines in code blocks in activities overflow
- Change how ids are determined in ingestion to avoid problems with unicode characters
- Scope lock messages to a specific project
- (Developer) Auto format Elixir code
- Fix attempts sort order
- Fix feedback in live preview and page preview
- Remove unused "countries_json" configuration variable
- Image coding activity: clarify author solution entry UI

## 0.7.2 (2021-3-30)

### Bug fixes

- Fix an issue where administrators cannot configure a section without instructor role
- Fix an issue where publishing or duplicating courses would cause save errors in page and activity editors
- Fix keyboard deletion with media items
- Add extra newline after an iframe/webpage is inserted into an editor

## 0.7.1 (2021-3-24)

### Bug fixes

- Fix an issue where slug creation allowed some non-alphanumeric chars

## 0.7.0 (2021-3-23)

### Enhancements

- Add the ability for an activity to submit client side evaluations
- Change project slug determiniation during course ingestion to be server driven
- Add the ability to limit what activities are available for use in particular course projects
- Add the ability to duplicate a project on the course overview page

### Bug fixes

- Fix an issue where cancelling a curriculum deletion operation still deleted the curriculum item
- Fix an issue where the projects table did not sort by created date correctly
- Fix an issue where activity text that contained HTML tags rendered actual HTML
- Fix an issue where pasting text containing newlines from an external source crashes the editor
- Fix an issue with null section slugs and deployment id in existing sections
- Fix an issue where large images can obscure the Review mode UI
- Fix an issue where accessibility warnings for pages with multiple images only show the first image

## 0.6.1 (2021-3-3)

### Bug fixes

- Fix an issue where existing sections might not be found on LTI launch

## 0.6.0 (2021-3-3)

### Enhancements

- Add LTI 1.3 platform launch support
- Add support for project visibility control
- Add storage, media, and objectives service API implementations
- Move LTI 1.3 functionality to external Lti_1p3 library
- Add support for preview mode in graded assessments

### Bug fixes

- Replace use of context_id in favor of the unique course section slug
- Allow Slack hook URL to be unspecified during LMS LTI registration
- Prevent LTI launch to an iframe to avoid third-party cookie issues
- Honor the current location when inserting block content (YouTube, images, etc)
- Remove foreign key constraint that tied a user to an institution
- Do not display stale locks in Curriculum view
- Ensure error messages always visible in page and activity editors
- Remove ability to cancel activity creation during objective selection

## 0.5.1 (2021-1-13)

### Bug fixes

- Fix missing status 201 handling on Freshdesk API call
- Fix an issue where creating an institution with the same url as multiple existing institutions creates another new institution

## 0.5.0 (2021-1-12)

### Enhancements

- Improved LTI workflow for new institutions
- Add support for embedding images in structured content editors by external URL and by pasting a copied image
- Ordering activity
- Add support for user help requests capture and forward to email or help desk

### Bug fixes

- Fix a broken link to external learning objectives content

## 0.4.1 (2021-1-4)

### Bug fixes

- Fix an issue where new local activities were not being registered on deployment

## 0.4.0 (2021-1-4)

### Enhancements

- Add support for check all that apply activity

### Bug fixes

- Fix an issue where special characters in a course slug broke breadcrumb navigation in editor
- Fix some silently broken unit tests

## 0.3.0 (2020-12-10)

### Enhancements

- Improved objectives page with new "break down" feature
- Add API documentation

### Bug fixes

- Fix an LTI 1.3 issue where launch was using kid to lookup registration instead of issuer and client id

## 0.2.0 (2020-12-10)

### Enhancements

- LTI v1.3 launch support
- Grade passback via LTI AGS
- "Check all that apply" activity
- Improved editing UI
- Course hierarchy support
- New account email verification, password reset
- Collaborator and user invitation
- Course ingestion

### Bug fixes

- Fix "best" scoring strategy to calculate max points correctly

## 0.1.0 (2020-7-24)

- Initial release
