# Torus User Manual — Documentation Plan

Last updated: 2026-02-20

## Goal
Create a complete user-facing manual under `docs/manuals/user` for all personas who use Torus in production, including LMS/LTI users, independent/direct-delivery users, authors, and all admin levels.

## Primary Audiences
- Learners (students) in LTI and independent sections.
- Teaching staff in delivery contexts: instructors, TAs/graders/observers/mentors/managers/content developers.
- Course authors and collaborators.
- Administrators:
  - System admin
  - Account admin
  - Content admin
- Institutional/LTI operators managing registrations, deployments, and external tool setup.

## Scope
- In scope:
  - End-to-end user workflows for authoring, publishing, delivery, administration, and operations-facing UI tasks.
  - Persona-based instructions for both LTI and direct delivery modes.
  - Role-driven permissions and behavior differences.
  - AI, insights, datasets, payments, remix, ingest, branding, and support pathways.
- Out of scope:
  - Internal implementation details better suited for `docs/manuals/technical`.
  - Product roadmap/spec process documentation (`docs/features/**`, `docs/epics/**`) except as references.

## Source Analysis Summary
Plan grounded in repository sources:
- Routing and user surfaces: `lib/oli_web/router.ex`.
- Delivery and role behavior: `lib/oli/delivery/sections.ex`, `lib/oli_web/controllers/delivery_controller.ex`, `lib/oli_web/controllers/lti_controller.ex`, `lib/oli_web/controllers/launch_controller.ex`, `lib/oli_web/plugs/*.ex`.
- User-facing LiveViews and controllers:
  - Workspaces: `lib/oli_web/live/workspaces/**`
  - Sections/delivery dashboards: `lib/oli_web/live/sections/**`, `lib/oli_web/live/delivery/**`
  - Admin: `lib/oli_web/live/admin/**`, `lib/oli_web/live/users/**`, `lib/oli_web/live/products/**`, `lib/oli_web/live/publisher_live/**`, `lib/oli_web/live/gen_ai/**`, `lib/oli_web/live/features/**`, `lib/oli_web/live/ingest/**`
- Existing docs: `guides/lti/config.md`, `guides/lti/implementing.md`, `guides/activities/overview.md`, `guides/design/*.md`.
- LTI role vocabulary reference: `https://www.imsglobal.org/spec/lti/v1p3/#role-vocabularies`.

## LTI 1.3 Role Coverage (Manual Requirement)
The user manual must include a dedicated role vocabulary chapter with:
1. Full vocabulary reference groups from the spec:
- Institution roles
- System roles
- Context roles
- Context sub-roles
2. Torus support mapping based on runtime parsing (`Lti_1p3.Roles.*`) and usage in Torus:
- Currently parsed context principal roles: `Administrator`, `ContentDeveloper`, `Instructor`, `Learner`, `Mentor`, `Manager`, `Member`, `Officer`.
- Currently parsed platform roles include system and institution principal roles from `Lti_1p3.Roles.PlatformRoles`.
3. Explicitly documented gaps/unsupported handling in current behavior:
- Context sub-role URIs (for example `.../membership/Instructor#TeachingAssistant` and other context sub-role URIs) are not parsed as distinct roles.
- LTI Advantage system `TestUser` URI is not parsed by current platform-role mapping.
- Any unrecognized role URI is ignored during role ingestion.
4. User impact notes:
- How TA/Grader/Observer launches are effectively treated in Torus today.
- Which capabilities are controlled by Torus section-level instructor/admin checks versus LMS role labels.

## Handbook Information Architecture (Target Files)

1. `docs/manuals/user/README.md`
- Manual index, persona navigation, conventions, release notes.

2. `docs/manuals/user/01-getting-started.md`
- Sign-in paths, account types (author vs user), workspace overview, session basics.

3. `docs/manuals/user/02-roles-and-permissions.md`
- Torus role model (system/account/content admin, instructor, student, collaborator).

4. `docs/manuals/user/03-lti-role-vocabularies-and-support.md`
- Full LTI role vocabulary matrix and Torus supported/unsupported status.

5. `docs/manuals/user/04-lti-integration-and-launch.md`
- Institution registration, registrations/deployments, launch flow, LMS-specific considerations.

6. `docs/manuals/user/05-direct-delivery-and-independent-sections.md`
- Independent instructor flows, open-and-free sections, enrollment differences from LTI.

7. `docs/manuals/user/06-authoring-project-lifecycle.md`
- Project creation, curriculum/pages/activities/objectives/experiments/bibliography/review.

8. `docs/manuals/user/07-products-publishing-and-distribution.md`
- Products, publication, source materials, certificate settings, transfer/distribution patterns.

9. `docs/manuals/user/08-section-creation-and-configuration.md`
- Section creation (LTI/direct), section edit/manage, enrollment invites, LTI settings.

10. `docs/manuals/user/09-teaching-workflows.md`
- Instructor workflows: schedule/gating, assessment settings, grading, manual scoring, remix.

11. `docs/manuals/user/10-learner-experience.md`
- Student home/learn/assignments/practice/explorations/discussions/lesson/review/certificates.

12. `docs/manuals/user/11-dashboards-insights-and-datasets.md`
- Instructor dashboard, student dashboard, project insights, dataset jobs and exports.

13. `docs/manuals/user/12-payments-and-access.md`
- Paywall behavior, payment methods/codes/discounts, access troubleshooting.

14. `docs/manuals/user/13-ai-features.md`
- Learner/instructor AI touchpoints, section assistant conversations, GenAI config surfaces for admins.

15. `docs/manuals/user/14-admin-system-operations.md`
- Users/authors management, institutions/registrations/deployments, branding, external tools,
  publisher management, feature flags, logs/audit, telemetry/admin dashboards, MCP tokens.

16. `docs/manuals/user/15-ingest-and-import.md`
- Course ingest/upload, CSV import flows, error handling.

17. `docs/manuals/user/16-collaboration-and-communities.md`
- Collaboration spaces, invitations, communities and associated entities.

18. `docs/manuals/user/17-support-and-troubleshooting.md`
- Common failure paths, error interpretation, support escalation checklists.

19. `docs/manuals/user/glossary.md`
- User-facing term definitions.

20. `docs/manuals/user/release-changelog.md`
- Documentation delta log per release.

## Coverage Matrix Requirement
Each chapter must identify:
- Persona(s) addressed.
- Entry point routes/screens.
- Preconditions/permissions.
- Step-by-step tasks.
- Expected outcomes and common errors.
- Links to related chapters.

## Execution Plan

## Phase 0: Structure and Templates
- Create all files listed above as stubs with a consistent template.
- Define status labels (`draft`, `reviewing`, `published`) in `README.md`.
- Add a persona-to-chapter navigation table.
- Definition of Done:
  - Full skeleton exists under `docs/manuals/user`.

## Phase 1: Role and Access Foundation
- Author `02-roles-and-permissions.md` and `03-lti-role-vocabularies-and-support.md` first.
- Build role mapping table from:
  - IMS vocabulary
  - `deps/lti_1p3/lib/lti_1p3/roles/context_roles.ex`
  - `deps/lti_1p3/lib/lti_1p3/roles/platform_roles.ex`
  - Torus authorization checks in `lib/oli/delivery/sections.ex` and `lib/oli_web/plugs/**`.
- Document unsupported role/sub-role handling and operational implications.
- Definition of Done:
  - Every LTI role family is documented with support status.

## Phase 2: Onboarding and Delivery Mode Foundations
- Write `01-getting-started.md`, `04-lti-integration-and-launch.md`, `05-direct-delivery-and-independent-sections.md`.
- Include branching guidance by user type and delivery mode.
- Definition of Done:
  - New institutions/instructors can identify the correct setup path (LTI vs direct).

## Phase 3: Authoring and Publication Workflows
- Write `06-authoring-project-lifecycle.md` and `07-products-publishing-and-distribution.md`.
- Cover projects, activities, pages, curriculum, objectives, experiments, review/QA, publish.
- Definition of Done:
  - Authors can create, refine, publish, and manage products with clear prerequisites.

## Phase 4: Section and Teaching Operations
- Write `08-section-creation-and-configuration.md`, `09-teaching-workflows.md`, `12-payments-and-access.md`.
- Include enrollment, scheduling/gating, grading, remix, certificates, paywall/payment flows.
- Definition of Done:
  - Instructors/admins can run a section from setup through grading and access management.

## Phase 5: Learner and Insight Experiences
- Write `10-learner-experience.md`, `11-dashboards-insights-and-datasets.md`, `13-ai-features.md`.
- Cover student navigation, attempts/review, dashboards, insights, datasets, AI interactions.
- Definition of Done:
  - Learners and teaching staff can use analytics and AI features safely and correctly.

## Phase 6: Administration, Ingest, Collaboration, Support
- Write `14-admin-system-operations.md`, `15-ingest-and-import.md`, `16-collaboration-and-communities.md`, `17-support-and-troubleshooting.md`.
- Cover admin toolset: users/authors, institutions/LTI, branding, external tools, publishers,
  feature flags, logging/audit/monitoring, ingestion/import, and support playbooks.
- Definition of Done:
  - Admin runbook-level user guidance is complete across all admin types.

## Phase 7: Finalization and Publication
- Write `glossary.md` and `release-changelog.md`.
- Perform role-by-role walkthrough QA for:
  - system admin
  - account admin
  - content admin
  - author/collaborator
  - LTI instructor/TA/student
  - independent instructor/student
- Validate links, screenshots, and route references.
- Definition of Done:
  - Manual is coherent, navigable, and role-complete.

## Dependency and Parallelization Notes
- Phase 1 is a hard prerequisite for role-accurate downstream guidance.
- Phases 3 and 4 can run in parallel after Phase 2.
- Phases 5 and 6 can run in parallel after Phase 4 baseline is stable.

## Acceptance Criteria
- User manual exists under `docs/manuals/user` with complete chapter set.
- All major surfaced features in `router` have a home in at least one chapter.
- LTI role vocabulary chapter includes:
  - full spec role groups,
  - Torus support status,
  - unsupported role/sub-role notes,
  - user impact guidance.
- Admin coverage includes at minimum:
  - users/authors,
  - institutions/registrations/deployments,
  - branding,
  - datasets,
  - publishers,
  - GenAI feature config,
  - feature flags,
  - logs/audit/admin observability,
  - ingest/import.

## Risks and Mitigations
- Risk: Role semantics drift between LMS claims and Torus authorization behavior.
  - Mitigation: maintain a single support matrix with code references and periodic review.
- Risk: Manual becomes too technical for target users.
  - Mitigation: keep implementation details in technical manual; user manual stays workflow-first.
- Risk: Rapid feature updates create stale screenshots/steps.
  - Mitigation: add release-changelog updates and quarterly documentation audits.

## Suggested First Delivery Slice
1. Publish skeleton (`Phase 0`) plus `README.md`.
2. Complete `02-roles-and-permissions.md` and `03-lti-role-vocabularies-and-support.md`.
3. Complete `08-section-creation-and-configuration.md` and `09-teaching-workflows.md` next to unblock immediate operational use.
