# Google Tag Manager and GA4 (MER-5292)

Product owns the GTM container and GA4 property. Engineering owns this installation;
DevOps owns deployment configuration. Confirm named owners and provide developers
Read + Preview access before rollout. Treat GTM publish access as production code
execution: tags can access student answers, account information and CSRF tokens.

## Deployment and coverage

- Leave `GOOGLE_TAG_MANAGER_ID` unset in dev, test, CI, e2e and preview deployments.
  Blank values also disable the installation. Invalid IDs fail boot; the format is
  `GTM-` followed by uppercase letters or digits.
- QA/staging must use a separate GA4 property. A GTM Environment alone does **not**
  isolate the destination property: configure its Google tag with the QA measurement
  ID and verify this in Tag Assistant and the network panel.
- Optionally set `GOOGLE_TAG_MANAGER_AUTH` and `GOOGLE_TAG_MANAGER_PREVIEW` together
  for a GTM Environment. Copy values from its installation instructions (`env-N` for
  preview); the loader includes `gtm_cookies_win=x`. These values are browser-visible.
- Do not set an ID in production until MER-5307 consent preferences are deployed
  and this checklist passes. This story defaults all four consent types to denied.
  Consent defaults alone do not prevent cookieless pings; the tags must be blocked
  until analytics consent is granted (Basic Consent Mode).
- Covered roots: `authoring` (including `default` and `workspace`), `delivery`
  (including student dashboards), and `chromeless` adaptive lessons. LTI-launched
  learning content uses these covered roots. Excluded roots: LTI registration,
  LTI redirect, `delivery_from_payment`, errors and emails. The card-entry route
  `/sections/:section_slug/payment/new` is also excluded, regardless of its root.
  These follow the story's proposed layout defaults; confirm them with product.

## Required container configuration

1. Enable Consent Overview. Every measurement tag, including the Google tag and
   GA4 Event tag, must **Require additional consent for tag to fire** with
   `analytics_storage`. Built-in consent checks alone allow cookieless pings and
   do not meet this rollout's Basic Consent Mode requirement.
2. Create Data Layer Variables (version 2) for `page_location`, `page_title`,
   `page_referrer`, `page_path`, `page_area` and `traffic_type`. Use these values
   exclusively; never use built-in Page URL, Page Path, Page Title or Referrer
   variables. `page_location` already contains origin + Phoenix route template;
   `page_title` is generic and `page_referrer` is always an empty string.
3. Configure the Google tag with `send_page_view=false`. Set `page_location`,
   `page_title` and `page_referrer` from those variables on the Google tag **and**
   on all GA4 event tags, so initialization and automatic GA events cannot fall
   back to browser URLs/titles. Set `traffic_type` from its variable too.
4. Use the custom event trigger `torus_page_view` to initialize the consent-gated
   Google tag and send a GA4 event named `page_view`. Ensure Google tag setup runs
   before the event (tag sequencing), still with the additional consent check.
   Do not add All Pages, Initialization or History Change measurement triggers.
   The application queues one initial event before the container loads. Navigations
   to a different route template add one event; same-template patches, slug changes,
   reconnects and duplicate mounts add none. This installation does not emit React
   internal navigation or custom activity events (MER-5306).
5. Set `cookie_domain` explicitly to the Torus hostname (never `auto`) to avoid
   collisions with other properties on the registrable domain. Set
   `cookie_flags` to `samesite=none;secure` for LMS iframes over HTTPS.
6. Prohibit Custom HTML and third-party tags without engineering/privacy review.
   Restrict publish rights and require review of every container version. No
   automatic URL capture, user IDs, course context, answers, search strings or
   user-provided data may be added by tags. Future custom events must use the
   writer in `assets/src/analytics/` and a reviewed sanitized contract.

MER-5307 must update stored consent before measurement and specify how to measure
the current page after granting consent. GTM does not replay a blocked page-view
event automatically. For this story's manual QA, grant consent, then navigate to
a different route template to generate a fresh event.

## Required GA4 property configuration

- Disable **all Enhanced Measurement** on the web stream, especially history-based
  page changes, site search, form interactions, file downloads and outbound clicks.
  Default page views and history tracking cause duplicate counts and leak raw URLs.
- Turn off Google Signals, ads personalization, user-provided data collection and
  optional data sharing. Use the minimum retention period unless product approves
  a documented need. Do not link advertising accounts as part of this installation.
- Register `page_area` as an event-scoped custom dimension if product needs it.
- Configure and activate the Internal traffic filter for `traffic_type=internal`.
  Torus marks system-admin author sessions internal on all environments. Other
  sessions use `external`, so prior internal context cannot persist in the data layer.
- Configure and activate the Developer traffic filter. Use `debug_mode=true` only
  for QA/debug sessions, with the isolated QA property. Verify filter behavior
  before activation because excluded data cannot be recovered.

## QA and rollout gate

1. With no ID, confirm there is no analytics head script, Google loader or GA
   collect request on any covered root. Verify excluded roots and card-entry pages
   stay excluded even when the QA ID is set. No noscript iframe should ever appear.
2. With the QA container, check authoring/workspace, instructor dashboard, student
   home, a basic lesson, chromeless adaptive lesson and an LMS iframe. There should
   be exactly one async `gtm.js` request per full load.
3. In Tag Assistant, confirm `analytics_storage`, `ad_storage`, `ad_user_data` and
   `ad_personalization` are denied **before** container initialization. Confirm no
   Google Analytics `collect` requests while denied, including cookieless pings.
4. On the QA property only, grant consent in the console:
   `window.gtag('consent', 'update', {analytics_storage: 'granted'})`.
   Navigate between different route templates. Confirm one GA4 page view per route
   change and none for tabs, filters, sorting, pagination or other same-route patches.
   Returning to a prior route should count once. Reconnects should not count again.
5. Inspect **all** GA requests, including initialization, session and engagement:
   `dl` must contain origin + template, `dt` a generic title, and `dr` be empty.
   Exercise reset-password, confirmation and invitation URLs, search queries,
   private course/page titles and LMS referrers. None may appear in any GA payload.
   Verify the QA measurement ID and that no request targets the production property.
6. Verify system-admin traffic and Developer traffic filters, consent revocation,
   and MER-5307's stored-choice/current-page behavior before production enablement.
   Record the reviewed container version, owners, property IDs and QA evidence.

Third-party cookie restrictions in Safari, Firefox and Chrome can fragment LMS
iframe sessions even with the cookie flags above. Expect unreliable persistent
client IDs; do not interpret these counts as unique students. Low-cardinality
launch context is deferred to MER-5306. A future CSP must account for GTM/GA hosts;
adding a container does not authorize arbitrary additional third-party hosts.

Rollback: unset `GOOGLE_TAG_MANAGER_ID` and restart the deployment. Existing open
tabs retain their already-loaded container until a full reload; unpublish/disable
measurement tags in GTM as well if immediate containment is required.

## Implementation references

- Runtime validation: `lib/oli/analytics/config.ex`, `config/runtime.exs`
- Sanitized routes and areas: `lib/oli_web/analytics.ex`
- Head component: `lib/oli_web/components/analytics.ex`
- Navigation hook: `lib/oli_web/live_session_plugs/analytics_page_view.ex`
- Sole data-layer writer and head bootstrap: `assets/src/analytics/`

Official references: [Consent Mode](https://developers.google.com/tag-platform/security/concepts/consent-mode),
[GTM additional consent checks](https://support.google.com/tagmanager/answer/10718549),
[Google tag API](https://developers.google.com/tag-platform/gtagjs/reference).
