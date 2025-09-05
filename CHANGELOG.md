# Changelog

This file documents changes to the environment and infrastructure for each release.

For a complete list of changes and release notes, please refer to the [GitHub repository's releases page](https://github.com/Simon-Initiative/oli-torus/releases).

If a PR is opened that adds a new environment config or requires infrastructure changes, please
update this file accordingly.

## 0.32.0

### Environment Configs

| Name      | Required | Description                                                                     |
| --------- | -------- | ------------------------------------------------------------------------------- |
| MEDIA_URL | Yes      | HTTP/HTTPS URL for media assets (Default http://localhost:9000/oli-torus-media) |

- `MEDIA_URL` is now set to the full URL including the scheme (http/https) and (optionally) the
  port. The default value for development is now `http://localhost:9000/oli-torus-media` which
  corresponds to a local S3/minio service. This value is still required to be set in production,
  typically to the URL of the production S3 bucket.

### Infrastructure Changes

- [ ] Update servers to use the new MEDIA_URL format

---

**Note:** Moving forward CHANGELOG.md will no longer track release dates, features or bug fixes. The main purpose
of this file will be to document changes to the environment and infrastructure.

---

## 0.25.1 (2023-10-13)

### Bug Fixes

- Fix an issue where admin attempting to create a new institution when an existing registration with the same issuer and client_id fails

### Environment

#### Infrastructure Changes

- [ ] Update deployment migration scripts to use `Oli.Release.migrate_and_seed` instead of `Oli.ReleaseTasks.migrate_and_seed`

## 0.25.0 (2023-10-5)

### Enhancements

- Ability to Archive Products and toggle display of "show archived" products
- "Available Date" setting for assessments added
- Extended the Revision History tool to allow access to hierarchy, objectives and editing of children attributes
- Markdown editing support in Basic Pages
- Project export now includes required survey and all products
- Assessments with zero activities can now be submitted
- Added search capability and role type indication in My Courses view
- Added tooltips that explain progress and proficiency calculations
- Expose student email address in Manage Enrollments
- Transfer student data, progress from one enrollment to another enrollment (in different section)
- Add better support for copy and paste of rich content (html, word, docs) into editor
- Add "enroll by email and role" feature
- Improved product and section creation performance
- New analytics infrastructure for tracking aggregate student performance
- Optimized raw data download feature

### Bug Fixes

- Fixed handling of super activity iframe size
- Fixed typo in enrollment modal window
- Removed creation of unnecessary grade update worker jobs
- Fixed scheduling bug related to times being reset
- Updated "customize curriculum" link text to be consistent
- Fixed drag and drop hints from obscuring feedback
- Fixed numeric list creation issue
- Prevent users from enrolling as guests when enrollment is required
- Fixed quiz scores tab horizontal scrolling from obscuring student name
- Fixed progress calculations in archived sections
- Fixed quiz score calculations for suspended students
- Fixed rendering of discussion posts in archived discussions
- Fixed dark mode issues in advanced author
- Fixed saving multiple new container additions during remix
- Fixed cash net in LTI iframe operation
- Fixed problem with repeated learning objectives in scored activities view
- Fixes table rendering when missing a caption inside of paged group
- Fixes drag and drop bugs related to attempt reset
- Fixes problem with deleting hints on multi-part activities
- Restores ctrl-z undo support
- Fixes several issues with MediaManager UI

## 0.24.5 (2023-9-12)

### Bug Fixes

- Corrects evaluation of student input with scientific notation that does not include a decimal point (e.g. 1e-9)
- Fixes a bug where customized assessment settings can revert when new publications apply an update to that graded page

### Enhancements

- Allow configuration of HTTP/HTTPS cowboy protocol options
- Expose settings related to configuring at runtime sizes and constraints on HTTP server header contents

### Environment Configs

```
HTTP_MAX_HEADER_NAME_LENGTH       (Optional) HTTP/HTTPS Maximum length of header names for Cowboy (Default 64)
HTTP_MAX_HEADER_VALUE_LENGTH      (Optional) HTTP/HTTPS Maximum length of header values for Cowboy (Default 4096)
HTTP_MAX_HEADERS                  (Optional) HTTP/HTTPS Maximum number of headers allowed per request for Cowboy (Default 100)

LOG_INCOMPLETE_HTTP_REQUESTS      (Optional) Log incomplete HTTP requests (Default true)
```

## 0.24.4 (2023-8-11)

### Bug Fixes

- Query performance for proficiency calculations
- Fix performance issue for learning proficiency calculation

### Configs

## 0.24.3 (2023-8-04)

### Bug Fixes

- Fix an issue in assessment review of multi inputs where text was being truncated
- Fix a couple issues related to custom drag and drop activities
- Fix an issue where explorations are not carried over during section creation from a product
- Prevent data loss from normalization of certain list items
- Fix deletion of hints on multi input activities
- Fix due date on assessment settings
- Fix activities due soon in recommended actions tab

### Enhancements

- Add the authoring capability to mark multiple targeted feedbacks as correct

## 0.24.2 (2023-7-27)

### Bug Fixes

- Improved handling of adaptive pages that have hard deadlines
- Added explanatory tooltips to the Assessment Settings UX
- Fixed a bug where Scheduler date/time labels disappeared
- Fixed a bug with handling gates without end dates
- Removed the background colors of the Dialog content element rendering
- Handle scientific notation with an explicit "+" sign in response evaluation
- Fix styling inconsistencies in Example content groups
- Ensure that course section creation inherits the cover image from a product
- Fix styling issues for dark mode rendering of the Likert activity
- Correct the link to the top-level discussion forum

## 0.24.1 (2023-7-21)

### Bug Fixes

- Fix an issue where scheduler can "drift" one day due to incorrect timezone handling
- Fix an issue where page to page links cannot be created
- Fix an issue with dark mode rendering of Discussion activity
- Fix an issue where deleting Learning Objectives can generate an error and reload the LO view in certain circumstances
- Fix an issue related to dark mode rendering of the block insert menu

## 0.24.0 (2023-7-20)

### Bug Fixes

- Fix a bug in displaying the All Products view
- Tech support modal initialization issues
- Legacy migration fixes
- Normalize whitespace upon rule evaluation of activities
- Multi input dropdown now allows shuffling of individual parts
- Allow previewing of gated resources
- Fix an issue with page links and course flow related to pages outside hierarchy
- Always show hints in unscored pages even after attempt evaluations

### Enhancements

- Various authoring bug fixes and enhancements
- Instructor dashboard top level navigation, reports and content views
- Student dashboard views
- Adaptive flowchart authoring
- Add edit page links to product view
- Soft scheduling controls for suggested by, in class activity on, and due by
- Add support for scored pages time limit, grace period, late start, late submit and auto submit
- Require start and end datetimes for sections
- Password protected attempt starts
- Instructor and student onboarding wizards
- Student progress CSV downloads
- Allow payment bypass for a particular student
- Enable selection of all pages including ones outside the hierarchy in remix
- Add ability to jump to a specific page in delivery
- Add system configurable persistent login sessions

### Environment Configs

```
VENDOR_PROPERTY_SUPPORT_EMAIL         (optional) specify an email address where users can contact the support team
ALWAYS_USE_PERSISTENT_LOGIN_SESSIONS  (optional) when set to 'true', the system will always login authors and users as
                                                 a persistent session i.e. "Remember me" (expires after 30 days inactivity)
```

## 0.23.0 (2023-3-30)

### Enhancements

- Add ability to author polygonal image hotspots with mouse
- Soft scheduling
- New UX
- Improved collaborative space management capabilities
- Exploration pages

## 0.22.1 (2023-1-5)

### Bug Fixes

- Fix an issue with dynamic questions and variables that contain " or \
- Removes global state caching to fix problems with a class of adaptive pages

## 0.22.0 (2022-12-20)

### Bug Fixes

- Fix an issue with duplicate part ids on ingest
- Fix some performance issues related to published resources trigger
- Allow admin users to review adaptive page attempts
- Fix an issue with table layouts
- Fix an issue where ordering choices were not ordered correctly in review
- Fix an issue with popup audio element
- Fix an issue where command button submitted multiple choice
- Fix an issue where legacy block LaTeX were not rendered correctly
- Fix an issue where mixed-case collaborator emails would fail
- Fix an issue where multiple active publications can occur

### Enhancements

- Add tab for authoring 'explanation' feedback to all activities
- Add support for definition element
- Add support for dialog element
- Add support for vlab activity type
- Add support for explanation feedback (legacy multiple feedbacks)
- Add all activities view
- Add support for conjugation element
- Add support for activity page links
- Remove submit button and automatically submit multiple choice questions in formative
- Add playback speed control to video elements
- Add support for alternatives/alternative
- Add activity/question numbering in graded pages
- Upload media as content-addressable in S3 storage
- Allow components in adaptive editor to be resized
- Add support for collaboration spaces
- Upgrade to Phoenix LiveView 0.18
- Optimize webpack to improve development compile times
- Add client side reporting to appsignal for core and adaptive authoring.
- Updated hint logic to be consistent across core-lesson question types and allow requesting hints for auto-submit questions.

## 0.21.5 (2022-09-01)

### Bug Fixes

- Fix an issue where activity content containing backslashes prior to parser escaping breaks evaluation
- Fix an issue where survey reset wasn't working properly

## 0.21.4 (2022-08-23)

### Bug Fixes

- Fix an issue where content cant be removed if there is only one top-level element

### Enhancements

- Add support for inline 'term' markup
- Add support for branching activities and page automation
- Improve toolbar styles and usability
- Add ability to browse all pages in a course project
- Add Math input question type

## 0.21.3 (2022-08-05)

### Bug Fixes

- Fix an issue where scroll wheel changes the value of numeric input
- Fix an issue where underlined and strikethrough text were not being rendered
- Fix an issue where guest user_id is blank in datashop export
- Allow insertion of tables, iframes and all other elements in stem, choices and feedback
- Change 'Submit Assessment' button to 'Submit Answers'

### Enhancements

- Product ingestion support

## 0.21.2 (2022-07-20)

### Bug Fixes

- Fix a problem with handling groups and surveys

## 0.21.1 (2022-07-19)

### Bug Fixes

- Fix a problem with activity bank selections

## 0.21.0 (2022-07-15)

### Bug Fixes

- Fix an issue where activity bank styles were not rendering properly
- Fix an issue where question STEM isn't displayed in ordering answer key
- Fix an issue with the insertion menu visibility in dark mode

### Enhancements

- Survey delivery support
- Legacy Custom Drag and Drag activity support
- Improve the way activity bank edit locks are presented to a user
- Add proper datashop session id tracking
- Add ability to set bullet-style on ordered and unordered lists

## 0.20.1 (2022-07-07)

### Bug Fixes

- Fix an issue related to session cookies

## 0.20.0 (2022-06-30)

### Bug Fixes

- Restore ability to edit title of basic pages
- Fix an issue where formatting toolbar covers content
- Prevent deletion of non-empty curriculum containers
- Fix an issue where analytics weren't properly including remixed sections

### Enhancements

- Provide more context in the browser tab
- Improve the learning objective selection dropdown
- Improve authoring improvement insights UI
- Improve content and activity insertion menu
- Dynamic question infrastructure

## 0.19.4 (2022-06-09)

### Bug Fixes

- Improve performance of DataShop export
- Fix an issue where multi-input activity inputs were being duplicated
- Fix an issue where table headers were misaligned in the insights view
- Fix an issue where table caption rendering throws an internal server error
- Allow deletion of objective to cascade through to banked activities

### Enhancements

- Allow for broader range of number of attempts, including unlimited, for scored pages
- Add survey authoring support (behind feature flag)
- Add File Upload activity
- Simplify objective creation, improve attachment UX

## 0.19.3 (2022-05-17)

### Bug Fixes

- Fix an issue where paging in Activity Bank did not preserve filtered logic
- Fix link editing
- Fix an issue where delivery styles were not being applied correctly
- Fix an issue where table editor options dropdown was hidden behind editor

### Enhancements

- Add content groups and paging support

## 0.19.2 (2022-05-13)

### Bug Fixes

- Fix an issue where get connected button on publish page doesn't work

## 0.19.1 (2022-05-03)

### Bug Fixes

- Fix an issue where multiple user accounts linked to a single author results in an internal server error

## 0.19.0 (2022-05-03)

### Bug Fixes

- Fix inability to search in projects and users view
- Properly handle the case that a section invite link leads to an unavailable
  section
- Fix empty hints showing up in delivery mode
- Fix table styling when words overflow bounds
- Fix popup content editing
- Fix image alt text rendering
- Add tooltips to insights table headers, add keyboard navigation
- Change ordering question interaction after activity is submitted
- Fix cross-project activity deletion bug

### Enhancements

- Allow for student-specific gating exceptions
- Display containers as pages with a table of contents
- Logic-based gating
- Allow learning objective attachment to pages
- Instructor review of completed graded attempts
- Allow gates to be defined in products
- Hide subsequent purpose types for activities when the same purpose type is
  used in a series
- Allow students to pay and apply codes during a grace period
- Activity SDK
- Add editor settings for Image, Webpage (iframe), Youtube elements
- Support rich text (formatting, etc.) in page content captions

## 0.18.4 (2022-02-24)

### Bug Fixes

- Improve performance of initial page visits by introducing bulk insertions of
  attempts
- Fix enrollments view rendering problem in sections that require payment
- Ensure score can never exceed out of for graded pages
- Ensure multiple payment attempts is handled correctly
- Handle cases where recaptcha payload is missing
- Ensure user_id is unique in DataShop export
- Only highlight failed grade sync cells when section is an LMS section
- Fix adding image/audio in page editor
- Fix add resource content positioning issues
- Only allow admins to edit paywall settings

### Enhancements

- Optimize rendering and storage by allowing attempts to only store transformed
  models when necessary
- Adds support for Legacy OLI custom activities

### Release Notes

- Set up support for Legacy OLI activities as follows:
  - Check out a copy of the repo
    https://github.com/Simon-Initiative/torus_superactivity to a local folder
  - Configure torus oli.env file to include a variable named
    SUPER_ACTIVITY_FOLDER and set the variable to point to the folder above,
    e.g. SUPER_ACTIVITY_FOLDER=torus/superactivity
  - Ensure the folder is readable to the running torus instance

### Environment Configs

```
SUPER_ACTIVITY_FOLDER    local folder location of static support files for Legacy activities
```

## 0.18.3 (2021-12-27)

### Bug Fixes

- Fix bug preventing rendering of student progress view

## 0.18.2 (2021-12-17)

### Bug Fixes

- Improved robustness of grade passback implementation
- Fix bug related to missing title assign in preview mode

### Enhancements

## 0.18.1 (2021-12-17)

### Bug Fixes

- Fix a bug where open and free sections could not be created from products
- Fix a bug where payment codes were not displayed

### Enhancements

## 0.18.0 (2021-12-16)

### Bug Fixes

- Fix a bug that prevented editing internal links when only one other page
  exists
- Fix a bug that prevented content from being added during remix
- Fix a bug that prevented payment processing for product-less paid sections
- Fix a bug that allowed paid status of a section to be toggled off
- Fix a bug that resulted in products being able to be created with invalid
  grace period days
- Fix Open and Free section creation when done through the admin panel
- Fix an issue where LTI 1.3 deployments should represent individual
  institutions
- Move LTI 1.3 registrations listing to live view table with search, sorting and
  paging
- Fix LMS course section creation to properly set the blueprint reference
- Fix a bug where null deployment id results in empty string in pending
  registration form
- Fix a bug where immediately removing a new activity leaves it visible to the
  system
- Fix an issue where selecting the actual checkbox in select source list doesn't
  work
- Updates the labelling of options in the project visibility view

### Enhancements

- Send total points available during LMS line item creation
- LMS Lite functionality. Admins can allow delivery users to create sections
  through OLI by toggling their ability to "create sections" and adding the
  "independent learner" role in the admin interface. These "independent
  instructors" can then create sections with a start/end date that are private
  and require an invitation to join. Instructors can invite students by creating
  an invite link from the section management portal -- any student with this
  link can enroll automatically.
- Add support for configurable vendor properties
- Allow default brand to be changed via release env var
- Display course section and course project slug identifiers
- Allow sections created from free products to have their payment settings
  edited

## 0.17.0 (2021-11-30)

### Bug Fixes

- Add student input parsing to show student responses in datashop export
- Change datashop session id to not reflect the user

### Enhancements

- Gating and Scheduling

## 0.16.0 (2021-11-19)

### Bug Fixes

- Fix issue with bulk line item grade sync

### Enhancements

- Allow instructors to manually send one student grade to LMS

## 0.15.0 (2021-11-18)

### Bug Fixes

- Fix bug that prevented deletion of authors that have locked resource revisions
- Fix an issue related to next previous page links that causes 500 internal
  server error on advanced authoring pages
- Fix a bug that prevented MultiInput activities with dropdowns from evaluating
  correctly
- Fix a bug that prevented SingleResponse activities from properly restoring
  student state
- Fix a bug that was preventing manual grade sync from executing

### Enhancements

- Instructor "Preview" mode

## 0.14.6 (2021-11-08)

### Bug Fixes

- Fix the rendering of HTML special characters within activities
- Fix an issue where email was always being required regardless of
  independent_learner and guest status

## 0.14.5 (2021-11-05)

### Bug Fixes

- Improve error logging
- Determine author's initials in a more robust manner

### Enhancements

- New Popup page element

## 0.14.4 (2021-11-04)

### Bug Fixes

- Fix an issue where simultaneous section creations can result in more than one
  active sections for a given context
- Fix an issue with sorting by title in open and free source selection table

### Enhancements

### Release Notes

**OpenSSL 1.1.1 Upgrade Required**

Releases are now built using openssl11-devel for erlang which means that OpenSSL
1.1.1 is required to be installed on the deployment target for all future
releases.

```
# centos
sudo yum install openssl11
```

### Environment Configs

The following environment configs are now available for AppSignal integration.
All are required for AppSignal support. If none are specified, AppSignal
integration will be disabled.

```
APPSIGNAL_OTP_APP       (Optional) AppSignal integration OTP app. Should be set to "oli".
APPSIGNAL_PUSH_API_KEY  (Optional) AppSignal API Key
APPSIGNAL_APP_NAME      (Optional) AppSignal app name. e.g. "Torus"
APPSIGNAL_APP_ENV       (Optional) AppSignal environment. e.g. "prod"

```

## 0.14.3 (2021-11-01)

### Bug Fixes

- Fix problem with accessing course product remix

## 0.14.2 (2021-10-28)

### Bug Fixes

- Make score display in gradebook more robust
- Fix page editor text selection from resetting when a save triggers
- Fix formatting toolbar tooltips not showing
- Fix formatting toolbar format toggling
- Fix insertion toolbar positioning
- Fix insertion toolbar tooltips not disappearing after inserting content
- Fix insertion toolbar tooltips not showing
- Fix an issue where the button for inserting a table would move around unless
  the mouse was positioned in just the right way

## 0.14.1 (2021-10-28)

### Bug Fixes

- Fix an issue with Apply Update button and move content updates to async worker
- Fix text editor issue where image resizing didn't work from right drag handle
- Fix text editor issue where link editing tooltip could overlap with formatting
  toolbar
- Fix an issue where previewing a project with no pages crashes
- Fix some issues related to searching and viewing sortable tables
- Fix an issue where activity submissions would not display activity feedback

### Enhancements

- New Admin landing page
- New Instructor Course Section overview page
- Allow LMS and System admins to unlink LMS section
- Gradebook and graded page per student details with instructor centered grade
  override
- Student specific progress display

## 0.14.0 (2021-10-13)

### Bug Fixes

- Fix a style issue with the workspace footer
- Prevent objectives used in selections from being deleted
- Fix an issue where modals misbehaved sporadically
- Move "Many Students Wonder" from activity styling to content styling
- Fix an issue where nonstructural section resources were missing after update
- Add analytics download fields
- Add datashop timestamps for seconds
- Fix datashop bugs with missing <level> elements caused by deleted pages not
  showing in the container hierarchy
- Fix an issue where minor updates were not properly updating section resource
  records

### Enhancements

- Add multi input activity
- Add multi input model validation
- Add advanced section creation remix
- Allow for section creation from course products
- Add analytics / insights data export button
- Add ability for an admin to browse all course sections
- Add server driven paged, sortable table for project list
- Add ability to remix materials from multiple projects
- Fix insert content popup in page editor
- Add blackboard LTI 1.3 configuration instructions

### Release Notes

The following environment configs are now available:

```
PAYMENT_PROVIDER        (Optional) Sets the paywall payment provider. Current available options are 'stripe' or 'none'
STRIPE_PUBLIC_SECRET    (Required if PAYMENT_PROVIDER=stripe)
STRIPE_PRIVATE_SECRET   (Required if PAYMENT_PROVIDER=stripe)

BLACKBOARD_APPLICATION_CLIENT_ID  (Optional) Blackboard registered application Client ID. Enables LTI 1.3 integration
                                  with blackboard instances and allows torus to provide configuration instructions.
```

## 0.13.8 (2021-10-07)

### Bug Fixes

- Handle titles of activities correctly in analytics download

## 0.13.7 (2021-10-06)

### Bug Fixes

- Fix datashop export dataset name, missing skills

## 0.13.6 (2021-10-04)

### Bug Fixes

- Add ability to download raw analytic data

## 0.13.5 (2021-10-04)

### Bug Fixes

- Fix an issue where a selection fact change can break the page

## 0.13.4 (2021-10-03)

### Bug Fixes

- Fix an issue where a page can be duplicated within a container

## 0.13.3 (2021-09-30)

### Bug Fixes

- Fix an issue where generating resource links for tag types throws a server
  error

## 0.13.2 (2021-09-17)

### Bug Fixes

- Fix activity choice icon selection in authoring
- Fix targeted feedback not showing in delivery
- Fix delivered activity choice input size changing with content
- Fix an issue related to LTI roles and authorization

## 0.13.1 (2021-09-14)

### Bug Fixes

- Fix an issue where platform roles were failing to update on LTI launch
- Fix an issue that prevents projects page from loading when a project has no
  collaborators

## 0.13.0 (2021-09-07)

### Bug Fixes

- Fix an issue where changing the title of a page made the current slug invalid
- Properly handle ordering activity submission when no student interaction has
  taken place
- Fix various UI issues such as showing outline in LMS iframe, email templates
  and dark mode feedback
- Fix an issue where the manage grades page displayed an incorrect grade book
  link
- Removed unecessary and failing javascript from project listing view
- Restore ability to realize deeply nested activity references within adaptive
  page content
- Fix an issue in admin accounts interface where manage options sometimes appear
  twice
- Allow graded adaptive pages to render the prologue page
- Allow Image Coding activity to work properly within graded pages

### Enhancements

- Add infrastructure for advanced section creation, including the ability to
  view and apply publication updates
- Enable banked activity creation and editing
- Add user-defined tag infrastructure and incorporate in banked activity editing
- Allow filtering of deleted projects as an admin
- Add the ability for an admin to delete user and author accounts

## 0.12.9 (2021-08-20)

### Bug Fixes

- Fix an issue where unlimited collaborator emails could be sent at once

### Enhancements

- Allow for submission of graded pages without answering all questions
- Add API support for bulk activity updating

## 0.12.8 (2021-08-11)

### Bug Fixes

- Fix iframe rendering when elements contain captions (webpage, youtube)
- Fix iframe rendering in activities
- Fix an issue where mod key changes current selection
- Standardize padding and headers across all pages
- Fix an issue where users with social logins have null sub
- Fix an issue where Update Line Items was failing

### Enhancements

- Redesign overview page, change language
- Allow multiple comma-separated collaborators to be added at once

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
- Fix page editor content block rendering issue in Firefox - increase block
  contrast
- Fix problem in Firefox where changing question tabs scrolls to top of page

### Enhancements

## 0.12.2 (2021-07-21)

### Bug Fixes

- Fix an issue where deleting multiple choice answers could put the question in
  a state where no incorrect answer is found
- Fix an issue where activities do not correctly restore their "in-progress"
  state from student work
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

- Add ability to generate and download a course digest from existing course
  projects
- Redesign check all that apply, multiple choice, short answer, and ordering
  activities
- Merge activity editing into the page editor
- Redesign the workspace header to include view title, help and user icons
- Clearly separate the hierarchy navigation and page editing links in curriculum
  editor
- Implement smaller sized left hand navigation pane

## 0.11.1 (2021-6-16)

### Bug fixes

- Fix an issue preventing deletion of projects whose names contain special
  characters
- Fix an issue related to persisting sessions across server restarts
- Fix an issue where modals and rearrange were broken in curriculum view
- Fix an issue where toggling multiple choice answer correctness could cause
  submission failures

## 0.11.0 (2021-6-15)

### Enhancements

- Image coding: disable submit button before code is run
- Allow setting of arbitrary content from upload JSON file in revision history
  tool
- Add ability for independent learners to create accounts, sign in and track
  progress

### Bug fixes

- Image coding: remove extra space at end of printed lines (problem for regexp
  grading)
- Fix issues related to exporting DataShop events for courses that contain
  hierarchies
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
- Add support for disabling answer choice shuffling in multiple choice, check
  all that apply, ordering questions
- Add support for moving curriculum items
- Allow analytic snapshot creation to run asynchronous to the rest of the
  attempt finalization code

### Bug fixes

- Fix help and logo links on register institution page, change help form to
  modal
- Add missing database indexes, rework resolver queries
- Fix ability to request hints
- Fix content editing after drag and drop in resource editors
- Fix internal links in page preview mode
- Fix projects view project card styling
- Fix problem with inputs causing clipping in Firefox
- Fix problem with difficulty selecting and focusing in Firefox
- Fix problem where containers with no children were rendered as pages in
  delivery
- Fix some style inconsistencies in delivery and dark mode
- Fix an issue where reordering a curriculum item could result in incorrect n-1
  position

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
- Use section slugs instead of ids in storage service URLs for delivery
  endpoints
- Fix a crash when an existing logged-in user accesses the Register Institution
  page
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
- Change how ids are determined in ingestion to avoid problems with unicode
  characters
- Scope lock messages to a specific project
- (Developer) Auto format Elixir code
- Fix attempts sort order
- Fix feedback in live preview and page preview
- Remove unused "countries_json" configuration variable
- Image coding activity: clarify author solution entry UI

## 0.7.2 (2021-3-30)

### Bug fixes

- Fix an issue where administrators cannot configure a section without
  instructor role
- Fix an issue where publishing or duplicating courses would cause save errors
  in page and activity editors
- Fix keyboard deletion with media items
- Add extra newline after an iframe/webpage is inserted into an editor

## 0.7.1 (2021-3-24)

### Bug fixes

- Fix an issue where slug creation allowed some non-alphanumeric chars

## 0.7.0 (2021-3-23)

### Enhancements

- Add the ability for an activity to submit client side evaluations
- Change project slug determiniation during course ingestion to be server driven
- Add the ability to limit what activities are available for use in particular
  course projects
- Add the ability to duplicate a project on the course overview page

### Bug fixes

- Fix an issue where cancelling a curriculum deletion operation still deleted
  the curriculum item
- Fix an issue where the projects table did not sort by created date correctly
- Fix an issue where activity text that contained HTML tags rendered actual HTML
- Fix an issue where pasting text containing newlines from an external source
  crashes the editor
- Fix an issue with null section slugs and deployment id in existing sections
- Fix an issue where large images can obscure the Review mode UI
- Fix an issue where accessibility warnings for pages with multiple images only
  show the first image

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
- Fix an issue where creating an institution with the same url as multiple
  existing institutions creates another new institution

## 0.5.0 (2021-1-12)

### Enhancements

- Improved LTI workflow for new institutions
- Add support for embedding images in structured content editors by external URL
  and by pasting a copied image
- Ordering activity
- Add support for user help requests capture and forward to email or help desk

### Bug fixes

- Fix a broken link to external learning objectives content

## 0.4.1 (2021-1-4)

### Bug fixes

- Fix an issue where new local activities were not being registered on
  deployment

## 0.4.0 (2021-1-4)

### Enhancements

- Add support for check all that apply activity

### Bug fixes

- Fix an issue where special characters in a course slug broke breadcrumb
  navigation in editor
- Fix some silently broken unit tests

## 0.3.0 (2020-12-10)

### Enhancements

- Improved objectives page with new "break down" feature
- Add API documentation

### Bug fixes

- Fix an LTI 1.3 issue where launch was using kid to lookup registration instead
  of issuer and client id

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
