# Payment Codes — Epic Design

Status: Proposed · Updated: 2026-11-10

This is the single technical design for the stories in `docs/exec-plans/current/epics/payment-codes/plan.md`. Product behavior comes from `docs/exec-plans/current/epics/payment-codes/handoff.md`, with the refinements stated here. This document is grounded in repository inspection; no production data or Figma frames were inspected.

## Existing implementation

| Area | Evidence and implication |
| --- | --- |
| Payment model | `lib/oli/delivery/paywall/payment.ex`: codes are integer values on deferred payments, formatted with Crockford Base32; redemption sets enrollment and application date. Keep this model and encoding. |
| Generation | `lib/oli/delivery/paywall.ex`: `create_payment_codes/2` creates up to 500 payments transactionally and returns a payment list. Add a batch within that transaction. |
| Entry points | `lib/oli_web/live/products/payments_view.ex`, `lib/oli_web/controllers/payment_controller.ex`, and `lib/oli_web/controllers/api/payment_controller.ex` all create codes. Route every entry point through the new implementation. The API authenticates payment-enabled API keys, not necessarily human admins. |
| Downloads | The LiveView's “Download last created” currently queries the latest N payments. Batch identity can make this exact without changing its label or visible workflow. |
| Uniqueness | `priv/repo/migrations/20210920141807_add_paywall_infra.exs` already defines the unique code index. Keep it; handle collisions and incomplete random candidate sets gracefully. |
| Ownership | `transfer_payment_codes/2` changes payment section IDs; `update_payments_for_enrollment/3` also changes them during enrollment transfers. A payment's section ID is not reliable immutable issuance provenance. |
| Redemption | `redeem_code/3` checks unused state and value/currency, not template equality. It reads and subsequently updates without a shared lock. Preserve eligibility rules while making competing writes safe. |
| Invalidation/deletion | Payment invalidation changes `type` to `:invalidated`. Payments have cascading section/enrollment deletion FKs. Do not conflate invalidation with availability or accidentally alter existing deletion behavior. |

## Data model

Add `Oli.Delivery.Paywall.PaymentCodeBatch` and table `payment_code_batches`:

| Field | Meaning |
| --- | --- |
| `id` | Standard primary key |
| `section_id` | FK to the template in `sections`; batch management owner |
| `name` | Required trimmed text, proposed maximum 255 characters; duplicate names allowed |
| `created_by_author_id` | Nullable FK to `authors`; actual authenticated admin for browser creation |
| `source` | `admin`, `api`, `legacy`, or `system`; makes unavailable creator metadata explicit |
| `created_at` | Business creation time; nullable for historical batches whose actual creation time is unknown |
| `request_id` | Nullable unique UUID for retry-safe named creation |
| `inserted_at`, `updated_at` | Normal persistence timestamps; migration time is not historical issuance time |

Add `payments.payment_code_batch_id` (nullable FK) and `payments.code_enabled` (boolean, non-null, default `true`). The FK is nullable for ordinary direct/bypass payments. All code-bearing payments must belong to a batch after backfill, including invalidated code payments; enforce a conditional check on non-null `code`. Availability applies only to codes. Keep `type`, value, generation date, code, and redemption fields intact.

Index `payments.payment_code_batch_id` and batch `(section_id, created_at, id)`. Backfill groups by resolved template ID to produce one historical batch per template; do not impose permanent uniqueness on historical batch ownership because later transfers may bring several historical batches into one template. Keep the existing unique payment-code index. Add further search indexes only after measuring representative query plans.

Use restrictive deletion of a batch while payments reference it. Keep batch-to-template deletion behavior compatible with the existing template lifecycle: prefer retaining the batch with nullable owner on physical template deletion (`ON DELETE SET NULL`), displaying “Not available,” rather than adding a new blocker to section deletion. New creation still requires a valid template. Author deletion sets creator to null. These choices do not promise recovery of payment rows already deleted by existing cascades.

Batch ownership is authoritative for new management queries. Enrollment transfers may continue updating payment fields for existing consumers, but must preserve batch membership and ownership. An explicit template-code transfer moves complete source batches to the target in the same transaction as the existing payment transfer. Preserve batch names, creator, timestamps, and code values; do not merge batches with matching names. Lock source and target template rows in stable ID order, and use the same source-template lock during generation so concurrent creation cannot leave a partly transferred batch. Include batch members whose payment section changed during an enrollment transfer; do not infer batch membership from `payments.section_id` after migration.

## Migration and historical backfill

Generate the migration with `mix ecto.gen.migration add_payment_code_batches` during PC-01 implementation. Define explicit `up/0` and `down/0`; do not rely on current application schemas in migration SQL.

The **same migration that creates the table** must:

1. Add the table, availability column, nullable batch FK, and indexes.
2. Resolve the template for every existing code-bearing payment, including redeemed and invalidated codes and codes for inactive templates. Use `payments.section_id` directly when it identifies a template. For a delivery-section reference, inspect its `blueprint_id` as a candidate; because redemption is value-based, this is not proof of the original issuing template. Preflight must explicitly resolve/approve such mappings. Never silently substitute the redemption template or group by project title.
3. Create exactly one `Legacy Codes` batch per resolved template with codes. Set source to `legacy`, creator and business creation time to null. Do not invent an admin, original batch date, or original batch price. Preserve each payment's generation date and amount.
4. Attach every existing code to its template's historical batch with set-based updates. Leave payments without codes unbatched. Preserve all code values and payment/redemption data.
5. Assert zero unassigned code rows, unchanged payment count and values, and exactly one historical batch per resolved template at this point; then enforce the conditional batch requirement.

Preflight reports counts, duplicate-code anomalies, missing section references, non-template section references, and inconsistent redemption fields. Unknown ownership is a release blocker requiring an explicit data mapping, not a reason to drop records or manufacture a template. It is possible the original issuer is no longer recoverable; record an approved current management owner if that occurs. This is the principal uncertainty until production data is inspected.

`down/0` drops the conditional check, payment FK/columns, indexes, and batch table in dependency order, preserving original payment rows and code values. Verify up/down/up against representative historical fixtures. Reversing the migration discards batch metadata and availability, so it is a rehearsal/development rollback, not the routine production recovery strategy.

### First deployment and compatibility

PC-01 is one deployable story containing schema, backfill, all writer changes, and the deployment procedure. Additive fields allow existing readers to run during migration. Old writers cannot satisfy the new batch requirement or identify generation requests as batches; a normal unrestricted rolling deployment is therefore insufficient.

Use a coordinated deployment: pause code generation across browser and API entry points, explicit template-code transfers, and enrollment transfers that rewrite payment ownership; drain in-flight operations, run preflight/backfill, deploy all writer instances, verify invariants, then reopen writes. Establish the concrete traffic/job controls during implementation and rehearse them; do not assume a new application flag can control an old release. SQL DDL may briefly block other payment writes; measure migration lock duration and use bounded lock/statement timeouts. If pause or lock budgets cannot be met, revise this deployment approach before shipping, rather than moving backfill to a later ticket.

Normal rollback keeps the additive schema and batches. Returning to pre-PC-01 writers requires keeping affected writes paused or providing a compatible patch; it is not a safe blind application rollback. After PC-05, every serving version must also enforce disabled-code rejection. Do not roll redemption back to a version that ignores availability.

## Creation and payment state

Introduce a batch-aware creation service in `Oli.Delivery.Paywall`, returning `{:ok, %{batch: batch, payments: payments}}`. Preserve `create_payment_codes/2` as a compatibility adapter returning its existing payment list and errors. Browser callers pass the authenticated author through an extended adapter; API callers retain payment-key authorization and record `source = api` with no invented human creator.

Within one transaction, validate template/quantity/name, insert the batch, generate unique codes, and insert exactly the requested number of payments with that batch ID. Failures roll back both parent and children. Handle collisions against the existing unique index and duplicate candidates with bounded whole-transaction retry; return a controlled failure if retries are exhausted. No background generation service is needed for at most 2,500 codes; benchmark that bound.

PC-01 retains the existing 500-code limit and automatically supplies a readable batch name for legacy callers. PC-02 exposes required names and 1–2,500 validation through the new service; the existing API adapter retains its documented 500 limit and response contract. A submission UUID persists through retries of the named modal and is protected by the batch unique index. A repeated UUID returns the existing result only for the same authorized scope, actor, and inputs; mismatches fail. Disable repeated submits as well. This avoids duplicate batches after an uncertain response, not just partial inserts.

The existing “Download last created” must refer to the exact created batch held in that user's LiveView state, using an authorized batch download endpoint and the existing text format. Preserve old download/API response contracts for other callers. PC-02 adds richer CSV export separately.

| Display status | Derivation | Allowed management action |
| --- | --- | --- |
| Unused | Deferred, enabled, no enrollment or application date | Deactivate |
| Deactivated | Deferred, disabled, no redemption | Reactivate |
| Redeemed | Deferred with consistent redemption evidence | None; explain disabled action |
| Invalidated | Existing `type = invalidated` code payment | None; never reactivate through this feature |

The fourth status is a proposed compatibility extension to the handoff's three states. Keep invalidated codes visible/exportable and distinguish them from redeemed or reusable codes. Unexpected partially populated redemption fields fail closed for redemption/actions and display an unavailable/inconsistent state until repaired. Never count them as unused. Total counts include every code; redeemed + unused need not equal total because disabled/invalidated records also exist.

PC-01 makes redemption transactional: lock the enrollment and payment in a documented consistent order, recheck prior payment, code type, availability, unused state, and value/currency, then apply. Serialize competing redemptions for the same enrollment as well as the same code. PC-05 state changes lock the payment and recheck state inside the transaction. If redemption wins, deactivation fails; if deactivation wins, redemption fails. Reactivation cannot revive an invalidated or redeemed payment. Existing paid access is unaffected. Preserve the current invalid-code response for disabled codes.

## Shared queries, exports, and UI

Keep business logic in the Paywall context, using small batch/query helpers if needed. Define server-controlled scope as `{:template, template_id}` or `:global`. The UI cannot elevate scope through query parameters. Shared operations browse batches, browse codes, export a batch/query, and change availability. Every endpoint and LiveView event enforces authorization; ordinary authenticated authors are not automatically authorized admins. Preserve the existing payment-key API as a separate integration capability.

Queries use SQL pagination and deterministic ordering with ID tie-breakers, aggregate batch counts in SQL, and preload/join redemption users and sections without per-row queries. Derive “Redeemed for” from the enrollment's course section, not the template. Handle absent associations with text rather than broken links.

- Batch search matches batch name or an associated formatted code, using `EXISTS` to avoid duplicate rows. Normalize code case and separators consistently; escape literal wildcard characters in text search. Carry the query into detail only when code matching caused the result; name-only matches must still open a useful full detail view.
- Detail search matches code text. Highlight escaped matching text. Query parameters preserve parent search, filters, page, and sort on return; accept only local, validated return destinations.
- Filters combine with search using AND: inclusive date range in the displayed timezone, creator, and code status. Global adds template selection. Validate date order and reset pagination after criteria changes. Unknown historical creation time is excluded by date bounds and is labeled “Not available”; creator selection supports unavailable historical/API metadata.
- Batch-row downloads export the whole batch. Detail downloads use the same normalized query without pagination, including matches on every page. Reauthorize template and batch membership on every download. CSV includes code, status, template, batch ID/name, creation metadata, original code amount/currency, and redemption information. Escape CSV correctly and protect text fields against spreadsheet formula execution. Stream/chunk large historical exports; the 2,500 creation limit is not an export limit.
- Batch “Cost” shows current template cost, as requested by the handoff; code amount remains the redemption authority. Do not represent a mixed historical batch as having a single original issuance price.

From PC-02, place reusable batch table, code table, creation modal, status badge, download controls, and later search/filter/action components in a shared payment-code UI namespace. Components receive scope, rows, capabilities, and navigation/event callbacks; they do not query the database or hard-code template URLs. Template and global LiveViews are thin route/auth/state wrappers. Reuse `OliWeb.Common` table/paging patterns where suitable. Global shows the Template column and selector; template scope omits them. Use established Tailwind/component patterns for new UI.

PC-02 must retain access to existing direct/bypass/invalidated payment auditing through a separate existing-payments view or section on Manage Payments; replacing a mixed payment table with code batches must not silently remove that support workflow.

Every UI increment includes its own keyboard, semantic table, labeled input, focus restoration, loading/error/empty state, and narrow-screen verification. Follow `.agents/ui-workflow/README.md` during Figma-backed implementation. PC-06 reuses delivered components and mutation/export services; it adds the admin entry point, global scope, template column/filter, and cross-template navigation. Creation remains on the selected template's Manage Payments page.

## Verification boundaries

Extend existing Paywall, controller/API, and LiveView tests rather than creating a new framework. Relevant starting points are `test/oli/delivery/paywall_test.exs`, `test/oli_web/controllers/payment_controller_test.exs`, `test/oli_web/controllers/api/payment_controller_test.exs`, and `test/oli_web/live/payments_live_test.exs`. Include migration fixtures and concurrency tests with independently committed database connections, not a single shared sandbox transaction that hides races.

Measure migration duration, 2,500-code creation, paged search/count queries, and historical-batch export against representative volumes before the story that introduces each behavior ships. Authorization tests include direct URL/event requests, template/batch mismatch, and unauthorized downloads. No new cache, queue, generic reporting subsystem, or parallel UI implementation is required.
