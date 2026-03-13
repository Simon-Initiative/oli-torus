# Secure Artifact Downloads - Product Requirements Document

## 1. Overview
Torus currently supports several download flows by uploading artifacts to S3-compatible object storage and exposing direct object URLs. Some of those artifacts contain project internals, learner submissions, or support attachments that should not be publicly discoverable. This work item defines a provider-neutral private-download pattern for sensitive artifacts while preserving intentionally public media behavior.

## 2. Background & Problem Statement
Current code paths use direct S3 object URLs as the product-facing download contract. Shared helpers upload with public-read ACLs and return stable public URLs. That pattern works for public media, but it is not acceptable for sensitive downloadable artifacts such as project exports and learner-uploaded files.

The codebase review identified these relevant areas:
- `Oli.Utils.S3Storage` uploads files with `public_read` and returns `media_url`-based direct URLs.
- `Oli.Authoring.ProjectExportWorker` uploads project export ZIP files through `Oli.Utils.S3Storage.put/3` and persists the resulting URL on `projects.latest_export_url`.
- `Oli.Delivery.Attempts.Artifact` uploads learner file-upload artifacts with `public_read` and returns a direct URL to the client.
- `OliWeb.Components.TechSupportLive` uploads support screenshots through the shared S3 helper, which makes those screenshots public today.
- `Oli.Analytics.Datasets` stores dataset lookup files and result manifests in S3, and `OliWeb.Workspaces.CourseAuthor.DatasetDetailsLive` renders direct links to the lookup file and generated result files.
- Public media flows such as media library assets, branding assets, poster images, intro videos, and legacy superactivity media also use public URLs and must remain supported.

Current S3 artifact inventory:

| Classification | Artifact category | Current code paths | Desired posture |
|---|---|---|---|
| Public asset | Media library files | `Oli.Authoring.MediaLibrary` | Remain public |
| Public asset | Branding logos and favicons | `OliWeb.BrandController` | Remain public |
| Public asset | Product, section, and related uploaded images | `products/details_view`, `sections/overview_view`, `course_author/products/details_live` | Remain public |
| Public asset | Curriculum poster images and intro videos | `curriculum/entries/options_modal` | Remain public |
| Public asset | Legacy superactivity media | `OliWeb.LegacySuperactivityController` | Remain public |
| Private artifact | Project export ZIPs | `Oli.Authoring.ProjectExportWorker` | Migrate to private-artifact service |
| Private artifact | Learner file-upload artifacts | `Oli.Delivery.Attempts.Artifact` | Migrate to private-artifact service |
| Private artifact | Support screenshots / attachments | `OliWeb.Components.TechSupportLive` | Migrate to private-artifact service |
| Private artifact | Generated dataset lookup files | `Oli.Analytics.Datasets.lookup_url/1` | Migrate to private-artifact service |
| Private artifact | Generated dataset manifests and result chunk files | `Oli.Analytics.Datasets.fetch_manifest/1`, `DatasetDetailsLive` | Migrate to private-artifact service |
| Private artifact | Analytics snapshot downloads | `projects.latest_analytics_snapshot_url` persistence surface | Migrate to private-artifact service when active |
| Private artifact | Datashop snapshot downloads | `projects.latest_datashop_snapshot_url` persistence surface | Migrate to private-artifact service when active |
| Internal private storage | xAPI JSONL bundles | `Oli.Analytics.XAPI.S3Uploader` | Out of scope for end-user download service |
| Internal private storage | Generic blob/text storage | `Oli.Delivery.TextBlob.Storage` | Out of scope unless user download is added |

The primary product problem is to secure sensitive artifact downloads without breaking authoring and delivery surfaces that intentionally rely on public media URLs. The solution must also work for AWS S3 and S3-compatible providers such as self-hosted MinIO in development and production.

## 3. Goals & Non-Goals
### Goals
- Secure sensitive downloadable artifacts so they are no longer publicly readable by object URL alone.
- Support on-demand downloads through short-lived signed URLs delivered via Torus-managed redirect flows.
- Preserve intentionally public media behavior for existing public asset workflows.
- Introduce a reusable storage/download pattern that can be adopted by current and future artifact-producing features.
- Support AWS S3 and S3-compatible providers, including MinIO, through runtime configuration rather than AWS-only assumptions.
- Cover generated dataset downloads and related lookup/manifest files as private artifacts.

### Non-Goals
- Replacing all object storage usage in Torus with a single private-only model.
- Reworking internal analytics/xAPI storage that is not part of end-user artifact download flows.
- Delivering a full migration of every historical object in one step.
- Changing the authoring/media-library UX for intentionally public assets in this work item.

## 4. Users & Use Cases
- Authors: generate a project export and download it later without the artifact being publicly accessible.
- Instructors and students: access uploaded learner-file artifacts through authorized Torus flows without relying on permanent public object URLs.
- Support staff: review uploaded screenshots or attachments through authorized access rather than public bucket exposure.
- Operators: run the same secure artifact pattern against AWS S3 in hosted environments and MinIO or another S3-compatible service in local/dev or self-hosted deployments.

## 5. UX / UI Requirements
- Existing download entry points should remain familiar to users; the security change should not require them to manually copy or refresh storage URLs.
- Project export UI should still show a stable “Download Latest Export” action after generation completes.
- Learner file-upload UI should still render downloadable file links and previews when the current user is authorized.
- Expired signed URLs must not surface as broken saved state; Torus should provide a fresh download path transparently.
- Error states should distinguish between missing artifact, expired artifact, and unauthorized access.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Security & Privacy:
  - Sensitive artifacts must be stored without public-read ACL semantics.
  - Download access must be authorized by Torus before provider access is granted.
  - Signed URLs, when used, must be short-lived and generated on demand rather than stored as durable product data.
- Reliability:
  - Authorized users can still download artifacts when using S3-compatible providers that support presigning.
- Performance:
  - Authorization plus redirect/signing should add minimal latency compared with current direct-link behavior.
- Operations:
  - Runtime configuration must support endpoint, scheme, port, region, bucket, and path-style options needed by MinIO and similar providers.

## 9. Data, Interfaces & Dependencies
- A reusable private-download storage abstraction is needed above ExAws/S3-specific calls.
- Feature integrations must distinguish between public assets and private downloadable artifacts.
- Project export and generated dataset persistence must stop depending on long-lived direct object URLs.
- Learner artifact download contracts must support durable application URLs or equivalent stable references instead of expiring provider URLs stored in state.
- Dependencies include ExAws S3 signing/request support, Phoenix routes/controllers/LiveView actions, and existing runtime object-storage config in `config/runtime.exs`.

## 10. Repository & Platform Considerations
- Torus already supports S3-compatible local development via MinIO-oriented config in `config/dev.exs`.
- The current shared helper `Oli.Utils.S3Storage` is biased toward public media, so secure downloads should not be built by mutating that helper into a one-size-fits-all abstraction.
- Project export currently persists download URL state on the `projects` schema; a secure design requires storing a durable object reference instead of a signed URL.
- File-upload delivery currently persists URL strings in learner attempt state and uses them directly for preview/download. That contract must be updated carefully to avoid expired-link regressions.
- Backend changes should be centered in `lib/oli/` contexts, with controllers/LiveViews handling authorization and transport concerns in `lib/oli_web/`.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit success/failure telemetry for secure artifact download authorization and redirect/stream outcomes.
- Track signed-download generation failures by provider and artifact type.
- Track secure artifact upload counts by artifact type and visibility mode.
- Success signal: project exports and learner artifacts are downloadable by authorized users while no longer relying on public object URLs.

## 13. Risks & Mitigations
- Risk: changing the shared S3 helper globally could break public media behavior.
  - Mitigation: introduce separate public-asset and private-artifact integration paths.
- Risk: expiring signed URLs can break persisted learner state.
  - Mitigation: persist stable Torus routes or object references, and generate signed URLs only at access time.
- Risk: some S3-compatible deployments may be misconfigured for browser-reachable presigned URLs.
  - Mitigation: make browser-reachable presigned redirect behavior a hard environment requirement for supported providers.
- Risk: existing database fields store public URLs, not object references.
  - Mitigation: migrate secure artifact features feature-by-feature, beginning with project export, dataset downloads, and file-upload artifacts.

## 14. Open Questions & Assumptions
### Open Questions

### Assumptions
- AWS S3 and current MinIO environments can support SigV4-style request signing through ExAws-compatible configuration.
- Supported deployments will provide browser-reachable presigned GET URLs; Torus will not proxy artifact bytes as a fallback.
- Public media flows remain intentionally public and should not be migrated in this work item.
- Project export, generated dataset downloads, and file-upload artifacts are the highest-priority sensitive flows based on the current codebase review.
- Support screenshots will be surfaced to both email and Freshdesk via Torus-authenticated links that redirect to presigned URLs.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for provider-neutral signing/download services.
  - Controller/LiveView tests for authorized and unauthorized private download access.
  - Regression tests for project export generation/status and learner file-upload retrieval behavior.
  - Provider-configuration tests covering AWS-style hostnames and MinIO/path-style endpoints.
- Manual validation:
  - Generate a project export and confirm the stored artifact is not publicly readable.
  - Download a learner-uploaded file as an authorized user and verify refresh/revisit still works after link expiry windows.
  - Validate public media-library and branding flows remain unchanged.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
