# Secure Artifact Downloads - Functional Design Document

## 1. Executive Summary
This design separates Torus object-storage usage into two explicit classes: public assets and private downloadable artifacts. Public assets continue to use the current direct-URL model. Private artifacts move to a Torus-authorized download contract backed by private object storage and short-lived signed redirect URLs. The initial migration targets the sensitive flows found in the codebase review: project exports, learner file-upload artifacts, support screenshots, and generated datasets. The core implementation introduces a provider-neutral private artifact service instead of extending the existing public-media helper. That keeps MinIO/S3 compatibility centralized while avoiding regressions in authoring media.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001 through FR-008 from `requirements.yml`.
  - Initial implementation scope covers project export, learner file-upload artifacts, and support screenshots.
  - Public media flows remain on the existing public path.
- Non-functional requirements:
  - Private artifacts must not rely on public-read ACLs.
  - Signed access must be generated on demand and be short-lived.
  - The design must support AWS S3 and MinIO/path-style endpoints.
- Assumptions:
  - ExAws plus current runtime configuration can support request signing against both AWS S3 and S3-compatible endpoints.
  - The application can authorize artifact access from existing project/section/attempt ownership data without a new permissions model.
  - It is acceptable to migrate sensitive flows incrementally rather than rewriting all historical storage callers at once.
  - Browser-reachable presigned GET URLs are a hard requirement for supported deployments; Torus will not proxy object bytes.

## 3. Repository Context Summary
- What we know:
  - [`lib/oli/utils/s3_storage.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/utils/s3_storage.ex) is a public-media helper. It uploads with `{:acl, :public_read}` and returns `media_url`-based direct URLs.
  - [`lib/oli/authoring/project_export_worker.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/authoring/project_export_worker.ex) uses that helper for project export ZIP files and persists the resulting URL via [`lib/oli/authoring/course.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/authoring/course.ex).
  - [`lib/oli/delivery/attempts/artifact.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/delivery/attempts/artifact.ex) uploads learner artifacts with `public_read` and returns direct URLs consumed by [`assets/src/components/activities/file_upload/FileUploadDelivery.tsx`](/Users/eliknebel/Developer/oli-torus-2/assets/src/components/activities/file_upload/FileUploadDelivery.tsx).
  - [`lib/oli_web/components/tech_support_live.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/components/tech_support_live.ex) uploads screenshots through the same public helper.
  - [`lib/oli/analytics/datasets.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/analytics/datasets.ex) exposes direct dataset lookup URLs and fetches dataset manifests whose chunk entries are rendered as direct download links by [`lib/oli_web/live/workspaces/course_author/dataset_details_live.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/live/workspaces/course_author/dataset_details_live.ex).
  - Public asset flows remain intentionally public in modules such as [`lib/oli/authoring/media_library.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/authoring/media_library.ex), [`lib/oli_web/controllers/brand_controller.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/controllers/brand_controller.ex), and curriculum/product/section image upload callers that depend on direct URL listing.
  - Runtime config already includes endpoint/scheme/port/host variants for MinIO-oriented local development in [`config/dev.exs`](/Users/eliknebel/Developer/oli-torus-2/config/dev.exs) and generic S3 config in [`config/runtime.exs`](/Users/eliknebel/Developer/oli-torus-2/config/runtime.exs).

Inventory and classification:

| Classification | Artifact category | Current locations | Scope |
|---|---|---|---|
| Public asset | Media library files | `Oli.Authoring.MediaLibrary` | Out of secure-download scope |
| Public asset | Branding logos/favicons | `OliWeb.BrandController` | Out of secure-download scope |
| Public asset | Product/section/course-author uploaded images | `details_view`, `overview_view`, `details_live` | Out of secure-download scope |
| Public asset | Curriculum poster images / intro videos | `OptionsModalContent`, `S3Storage.list_file_urls/1` | Out of secure-download scope |
| Public asset | Legacy superactivity media | `LegacySuperactivityController` | Out of secure-download scope |
| Private artifact | Project export ZIPs | `ProjectExportWorker` | In scope |
| Private artifact | Learner file-upload artifacts | `Attempts.Artifact`, file upload delivery UI | In scope |
| Private artifact | Support screenshots / attachments | `TechSupportLive` | In scope |
| Private artifact | Dataset lookup JSON files | `Datasets.lookup_url/1` | In scope |
| Private artifact | Dataset manifests and generated chunk/result files | `Datasets.fetch_manifest/1`, `DatasetDetailsLive` | In scope |
| Private artifact | Analytics snapshot downloads | `latest_analytics_snapshot_url` fields | In scope when surfaced |
| Private artifact | Datashop snapshot downloads | `latest_datashop_snapshot_url` fields | In scope when surfaced |
| Internal private storage | xAPI JSONL bundles | `XAPI.S3Uploader` | Out of download-service scope |
| Internal private storage | Generic text/blob storage | `Delivery.TextBlob.Storage` | Out of download-service scope |

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Introduce a new private-artifact boundary under `lib/oli/storage/`:

| Module | Responsibility | Notes |
|---|---|---|
| `Oli.Storage.ObjectRef` | Canonical reference for private objects. | Fields: `provider`, `bucket`, `key`, `filename`, `content_type`, `disposition`, `visibility`, optional `metadata`. |
| `Oli.Storage.Provider` | Behaviour for upload, presign, and stream operations. | Keeps S3-compatible details behind one contract. |
| `Oli.Storage.S3CompatProvider` | ExAws-backed implementation for AWS S3 and compatible endpoints. | Uses runtime endpoint/region/path-style config. |
| `Oli.Storage.PrivateArtifacts` | High-level service for `put_private/3` and `download_target/2`. | Main feature integration point. |
| `OliWeb.PrivateArtifactController` | Authorize request, resolve object ref, then redirect to signed URL. | Stable application URL surface. |

Keep `Oli.Utils.S3Storage` and public asset callers unchanged. Do not retrofit secure-download logic into that helper.

Feature integrations:
- Project export:
  - worker uploads via `PrivateArtifacts.put_private/3`
  - persist object reference fields instead of a durable public URL
  - UI points to Torus route like `/authoring/projects/:slug/export/latest`
- Generated datasets:
  - lookup JSON, manifest, and result chunk files are treated as private artifacts
  - dataset details UI links point to Torus routes rather than direct object URLs
  - manifest payloads exposed to the UI must contain stable Torus-managed download targets, not raw object URLs
- Learner file uploads:
  - upload via `PrivateArtifacts.put_private/3`
  - return a stable Torus URL in API response, not a signed provider URL
  - current file metadata shape can continue to expose `url`, but that `url` becomes an app route
- Support screenshots:
  - upload via `PrivateArtifacts.put_private/3`
  - help dispatch payloads carry Torus-authenticated screenshot links
  - screenshot links resolve through the same private-artifact redirect service for both email and Freshdesk

### 4.2 State & Data Flow
Primary private download flow:

1. Feature uploads artifact through `PrivateArtifacts.put_private/3`.
2. Service writes object without public ACL and returns `ObjectRef`.
3. Feature persists durable reference data:
   - project export: store reference fields on project (new columns)
   - generated datasets: store or derive reference data for lookup files, manifests, and result chunks before exposing download links
   - learner artifact: derive stable route from attempt identifiers and filename, return that route to client
   - support screenshot: keep reference in the support workflow payload and generate stable Torus support-attachment routes
4. User clicks stable Torus URL.
5. Phoenix controller/LiveView action authorizes current user against owning resource.
6. App asks `PrivateArtifacts.download_target/2` for `{:redirect, signed_url, expires_at}`.
7. App redirects response to client.

Signed URL generation is intentionally request-time only. Signed URLs are never stored in the database or persisted into learner attempt state.

Stable learner artifact route pattern:
- `/sections/:section_slug/activity_attempt/:activity_attempt_guid/part_attempt/:part_attempt_guid/artifact/:filename`
- The route handler reconstructs the deterministic object key from the guids and filename using the same path convention as the uploader.

### 4.3 Lifecycle & Ownership
- Public assets remain owned by existing public-media code paths.
- Private artifact ownership lives with the feature domain:
  - project export owned by authoring/project
  - learner artifact owned by delivery/attempt
  - support screenshot owned by help/support workflow
- `PrivateArtifacts` owns storage provider details and signing behavior.
- Phoenix controllers/LiveViews own authorization and HTTP response transport.
- The provider contract owns endpoint normalization, path-style handling, and provider-specific signing details.

### 4.4 Alternatives Considered
- Make all S3 uploads private and serve everything through signed URLs.
  - Rejected because Torus intentionally uses public media URLs for authoring and delivery assets, and many callers assume direct URL listing and embed behavior.
- Store signed URLs directly in the database.
  - Rejected because signed URLs expire and would break project export status and learner saved-state links.
- Proxy all downloads through Torus always.
  - Rejected because large-file egress and app-node bandwidth would become an unnecessary bottleneck, and this work item explicitly does not support app-mediated streaming fallback.
- Use bucket policy changes only without application route changes.
  - Rejected because the app currently persists direct URLs; storage policy alone does not solve durable access for expiring credentials.

## 5. Interfaces
- Provider behaviour:
```elixir
put_private(scope, filename, body_or_path, opts) ::
  {:ok, %ObjectRef{}} | {:error, term()}

download_target(object_ref, opts) ::
  {:ok, {:redirect, String.t(), DateTime.t()}} | {:error, term()}
```

- Project export integration:
```elixir
generate_project_export(project) :: {:ok, job()} | {:error, term()}
resolve_latest_project_export(project, current_author) ::
  {:ok, %ObjectRef{}} | {:error, :not_found | :forbidden}
```

- Learner artifact integration:
```elixir
upload(section_slug, activity_attempt_guid, part_attempt_guid, file_name, file_contents) ::
  {:ok, stable_route :: String.t()} | {:error, term()}
```

- Runtime config shape:
  - provider module
  - private bucket name
  - endpoint host/scheme/port
  - region
  - path-style boolean
  - signed URL TTL

## 6. Data Model & Storage
- New runtime storage class split:
  - public asset bucket/path: existing `s3_media_bucket_name` and `media_url` usage
  - private artifact bucket/path: new bucket config, or private prefix within the same provider-managed bucket if operations prefers that

- Project export schema changes:
  - replace or supplement `latest_export_url` with durable reference data such as:
    - `latest_export_bucket`
    - `latest_export_key`
    - `latest_export_filename`
    - optional `latest_export_content_type`
  - keep `latest_export_timestamp`
  - migration strategy:
    - populate new fields for newly generated exports
    - retain old `latest_export_url` as fallback for historical records until cleanup

- Generated datasets:
  - stop surfacing provider URLs from lookup-file helpers and manifest chunk entries
  - introduce a Torus-owned reference format for:
    - lookup file
    - manifest
    - each generated chunk/result file
  - if result manifests currently embed raw object URLs, add a translation layer before rendering them to users

- Learner file-upload artifacts:
  - no DB migration required for first slice if the stable route can be reconstructed from existing identifiers and persisted as `url` in attempt state
  - underlying object key remains deterministic: `artifacts/<section>/<activity>/<part>/<filename>`

- Support screenshots:
  - replace public URLs in support payloads with Torus-authenticated screenshot links
  - email provider renders linked screenshots from Torus routes instead of direct object URLs
  - Freshdesk provider includes Torus-authenticated screenshot links in the ticket description/body

## 7. Consistency & Transactions
- Artifact upload and metadata persistence should behave as “upload then persist reference”.
- For project export:
  - upload private object
  - persist object reference on project
  - broadcast available status after persistence succeeds
- If persistence fails after upload, log orphaned object metadata for later cleanup rather than exposing an unusable artifact.
- Download authorization is evaluated per request, so access changes take effect immediately even for previously generated artifacts.

## 8. Caching Strategy
N/A. Signed URLs should be generated on demand and not cached beyond normal request scope. Browser caching remains controlled by the artifact response headers and provider defaults.

## 9. Performance & Scalability Posture
- Preferred mode is authorize then redirect to provider-signed URL, which keeps artifact bytes off Phoenix nodes.
- Authorization plus signing should be lightweight relative to artifact generation time.
- Deployments that cannot support browser-reachable presigned redirect URLs are out of scope for this design.

## 10. Failure Modes & Resilience
- Provider signing failure:
  - return deterministic error
  - emit telemetry including artifact type
- Missing object:
  - surface not found
  - clear stale export metadata only through explicit maintenance flow, not inline
- Unauthorized access:
  - return forbidden without leaking object existence details where appropriate
- Expired signed URL:
  - client retries the stable Torus route and receives a fresh redirect target
- Historical project record with only public URL:
  - serve existing URL until regenerated or migrated

## 11. Observability
- Telemetry events:
  - `[:oli, :storage, :private_artifact, :upload, :stop]`
  - `[:oli, :storage, :private_artifact, :download, :authorize]`
  - `[:oli, :storage, :private_artifact, :download, :redirect]`
  - `[:oli, :storage, :private_artifact, :download, :exception]`
- Metadata:
  - artifact type
  - outcome
  - duration
- Logs:
  - include object key only when operationally necessary
  - never log signed query strings or credentials

## 12. Security & Privacy
- Private artifacts are uploaded without public-read ACLs.
- Access is mediated by Torus authorization, not by obscurity of object paths.
- Signed URLs are ephemeral and generated after authorization.
- Provider secrets remain in runtime config only.
- Public and private storage paths are intentionally separated to reduce accidental exposure and review ambiguity.
- This design is compatible with MinIO and other S3-compatible providers because it treats AWS S3 signing as a protocol-level capability, not an AWS-only product assumption.
- This design only supports providers and deployments where the browser can successfully reach the presigned redirect URL.

## 13. Testing Strategy
- Unit tests:
  - object reference normalization
  - S3-compatible presign URL generation inputs
  - deterministic attempt-artifact route reconstruction
- ExUnit integration tests:
  - project export private upload + secure download flow
  - unauthorized project export access denial
  - dataset details page resolves lookup and result file downloads through Torus-managed routes
  - unauthorized dataset artifact access denial
  - learner artifact upload response returns stable Torus route
  - learner/instructor artifact download authorization rules
  - support email rendering includes Torus-authenticated screenshot links instead of public object URLs
  - Freshdesk ticket payload includes Torus-authenticated screenshot links instead of public object URLs
  - historical project export fallback when only legacy URL exists
- LiveView/controller tests:
  - overview export button resolves through new route
  - file upload API response contract remains compatible with current frontend expectations
- Manual:
  - verify MinIO local flow using path-style endpoint config
  - verify public media-library assets still embed and list normally

## 14. Backwards Compatibility
- Public media code paths remain unchanged.
- Project export keeps legacy URL fallback for already-generated exports until they are regenerated under the new model.
- Learner file-upload UI can remain compatible if `url` stays a string, even though it becomes a Torus route instead of a direct object URL.
- Analytics/datashop export URL fields remain untouched until those features are confirmed active again.
- Analytics/datashop export URL fields should adopt the same private-artifact contract when those download surfaces are activated.

## 15. Risks & Mitigations
- Risk: feature teams may keep using `Oli.Utils.S3Storage` for new sensitive artifacts.
  - Mitigation: document and enforce separate helpers for public assets vs private artifacts.
- Risk: deterministic object-key routes may leak filename/path structure.
  - Mitigation: route still requires authorization, and optional opaque IDs can be introduced later if threat modeling requires less guessable paths.
- Risk: MinIO or another S3-compatible provider behaves differently for redirect-style signed URLs.
  - Mitigation: make redirect-style presigned URL behavior part of deployment acceptance criteria and supported-environment requirements.
- Risk: support screenshots may need more lifecycle controls than generic artifact storage.
  - Mitigation: treat support attachments as a first adopter of the private storage policy, with retention controls added separately if needed.

## 16. Open Questions & Follow-ups
- Confirm whether project export should use new dedicated columns or a reusable embedded/object-ref field pattern.
- Consider a follow-up audit to identify any remaining direct `public_read` usage that should be classified explicitly as public asset vs private artifact.

## 17. References
- [`lib/oli/utils/s3_storage.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/utils/s3_storage.ex)
- [`lib/oli/authoring/project_export_worker.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/authoring/project_export_worker.ex)
- [`lib/oli/authoring/course.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/authoring/course.ex)
- [`lib/oli/delivery/attempts/artifact.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/delivery/attempts/artifact.ex)
- [`lib/oli_web/controllers/api/attempt_controller.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/controllers/api/attempt_controller.ex)
- [`assets/src/components/activities/file_upload/FileUploadDelivery.tsx`](/Users/eliknebel/Developer/oli-torus-2/assets/src/components/activities/file_upload/FileUploadDelivery.tsx)
- [`lib/oli_web/components/tech_support_live.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/components/tech_support_live.ex)
- [`lib/oli/analytics/datasets.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/analytics/datasets.ex)
- [`lib/oli_web/live/workspaces/course_author/dataset_details_live.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/live/workspaces/course_author/dataset_details_live.ex)
- [`lib/oli/authoring/media_library.ex`](/Users/eliknebel/Developer/oli-torus-2/lib/oli/authoring/media_library.ex)
- [`config/dev.exs`](/Users/eliknebel/Developer/oli-torus-2/config/dev.exs)
- [`config/runtime.exs`](/Users/eliknebel/Developer/oli-torus-2/config/runtime.exs)
