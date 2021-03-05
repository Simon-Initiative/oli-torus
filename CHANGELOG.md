# Changelog

## 0.6.1 (2021-3-3)

### Bug fixes
  - Fixes an issue where existing sections might not be found on LTI launch

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
  - Fix some silently broken  unit tests

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

