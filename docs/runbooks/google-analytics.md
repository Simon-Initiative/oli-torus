# Google Tag Manager and GA4 (MER-5292, MER-5307)

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
- When enabling GTM, also set `GOOGLE_ANALYTICS_MEASUREMENT_IDS` to every GA4
  measurement ID used by that container, comma-separated (for example
  `G-ABC123,G-DEF456`). Missing or malformed IDs fail boot. QA must list only its
  QA property IDs. The IDs let withdrawal disable already-loaded Google tags even
  inside an iframe where cookies are blocked; update this list alongside container
  changes and verify the destination IDs match in Tag Assistant.
- Optionally set `GOOGLE_TAG_MANAGER_AUTH` and `GOOGLE_TAG_MANAGER_PREVIEW` together
  for a GTM Environment. Copy values from its installation instructions (`env-N` for
  preview); the loader includes `gtm_cookies_win=x`. These values are browser-visible.
- Do not set an ID in production until MER-5307 consent preferences are deployed
  and this checklist passes. The application blocks the GTM loader until an explicit,
  unexpired version-2 analytics acceptance. Consent defaults are resolved server-side
  before GTM loads; advertising consent always remains denied. A blank
  `PRIVACY_POLICIES_URL` disables measurement even with a stored acceptance.
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
   After acceptance, the application queues one current-page event before the container
   loads. Navigations
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

The banner, desktop modal and mobile `/cookie-preferences` page use the same consent
module. Accept and Reject store a version-2 decision for 365 days, write the browser
cookie, persist signed-in user choices, and immediately update Consent Mode. A new
acceptance measures only the current sanitized page; pages visited while denied are
never replayed. LiveView navigation checks consent before adding a behavioral event.

On withdrawal the application immediately denies consent, blocks its event writer,
sets Google's `ga-disable-G-<measurement-id>` flag for configured IDs and IDs discovered
from GA4 cookies, and deletes host-only and current-host `_ga` / `_ga_*` cookies.
Parent-domain cookies are preserved because they may belong to sibling applications.
Removing legacy `cookie_domain: auto` cookies requires establishing Torus ownership
and a separately reviewed, validated domain allowlist; automatic ancestor-domain
cleanup is not supported. Reacceptance clears those disable flags. Keep GA4's standard
cookie names and host domain configuration, and list every measurement ID in deployment
configuration. Additional consent checks remain mandatory on every tag to prevent
subsequent denied pings.

The head bootstrap covers lessons without footers. An old or malformed decision
requires re-consent while retaining functional preferences. A banner close dismisses
only the current browser session and grants nothing. Signed-in database decisions
win over browser cookies. Concurrent saves carry a transient page request group and
sequence so an older acceptance cannot overwrite a later rejection; this metadata
stays in consent storage and never enters analytics. Metadata-free writes are also
ignored once a sequenced decision exists. At login a current browser
decision replaces an outdated
stored decision, and the database wins between two current decisions. Author-only
accounts continue using browser storage.

While a signed-in withdrawal is saving, `_cky_pending_consent` temporarily records
the denied preference and its original ordering metadata. The server treats a valid,
unexpired marker as denied even if the database still contains an older acceptance.
The head bootstrap also restores a marker from session storage before starting GTM,
covering LMS iframes that block cookies. This temporary state can only deny analytics;
it cannot grant consent. Once the matching decision is acknowledged, the marker is
removed and normal database precedence resumes.

HTTP errors, network failures and missing database acknowledgements retain that
protection. A shared unsaved notice offers Retry on the banner, desktop and mobile
paths, including after those preference UIs close. Retrying uses the original group,
sequence and expiration so it cannot become a newer decision than a subsequent save.
On a new page, pending withdrawal persistence is resumed automatically. Older request
successes or failures cannot clear a newer marker or replace its status.

Signed-in browsers with both cookie and session storage blocked keep measurement
disabled. When session storage is unavailable, a temporary `_cky_consent_storage`
necessary-cookie probe checks cookie availability and is removed immediately.

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
   be no Google request before acceptance, then exactly one async `gtm.js` request per full load.
3. On a fresh browser, confirm all four consent defaults are denied and no Google
   loader, GA `collect` request or `_ga*` cookie exists. Reject and reload: the
   version-2 decision must suppress the banner and keep requests blocked. Old
   unversioned choices must show the banner, preserving functional choices.
4. Accept using the banner on the QA property. Confirm the immediate consent update
   followed by one current-page event without reloading. Advertising consent remains
   denied. Reload: analytics defaults to granted before GTM loads. Navigate between
   different route templates. Confirm one GA4 page view per route
   change and none for tabs, filters, sorting, pagination or other same-route patches.
   Returning to a prior route should count once. Reconnects should not count again.
5. Inspect **all** GA requests, including initialization, session and engagement:
   `dl` must contain origin + template, `dt` a generic title, and `dr` be empty.
   Exercise reset-password, confirmation and invitation URLs, search queries,
   private course/page titles and LMS referrers. None may appear in any GA payload.
   Verify the QA measurement ID and that no request targets the production property.
6. Withdraw in both desktop and mobile preferences: verify immediate consent denial,
   GA disable flags, host-cookie deletion, and no further `collect` requests even after
   navigation, idle engagement and tab visibility changes. Confirm parent-domain
   cookies remain intact. Reaccept and verify one
   current-page event. Sign in from a new browser and verify the database choice.
   Check keyboard focus, 200% zoom, mobile and Chrome/Safari LMS iframe behavior.
   Verify system-admin traffic and Developer traffic filters before production enablement.
   Record the reviewed container version, owners, property IDs and QA evidence.
7. Delay a signed-in withdrawal POST, navigate before it completes, and confirm an
   older database grant cannot initialize GTM. Repeat with iframe cookies blocked
   and a pending marker in session storage. Exercise HTTP errors and network failure:
   the unsaved notice must offer Retry while tracking stays denied. A successful
   matching retry clears the marker; stale responses must not clear a newer choice.
   Confirm measurement stays disabled when both storage channels are unavailable.
8. Open Manage preferences from an undecided desktop banner and cancel. The banner
   must remain available, without a session dismissal cookie or implied consent.

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
[Google tag API](https://developers.google.com/tag-platform/gtagjs/reference),
[Basic Consent Mode](https://developers.google.com/tag-platform/security/guides/consent?consentmode=basic),
[Google Analytics opt-out](https://developers.google.com/tag-platform/security/guides/privacy).
