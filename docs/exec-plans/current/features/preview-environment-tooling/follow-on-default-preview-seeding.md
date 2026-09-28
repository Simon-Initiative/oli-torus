# Follow-on: Default Course Seeding for Pull-Request Previews

## Status

Deferred until the Torus preview-environment tooling PR lands. This is an informal follow-on
feature note, not an approved implementation phase or detailed design.

## Objective

Seed the bundled `oli_torus_getting_started_course` scenario once in every compatible
pull-request preview deployment. Remove the temporary PR-label opt-in after the preview release
artifact reliably contains `bin/seed`, `Oli.Seeding.Runtime`, and the bundled scenario.

## Proposed GitOps Changes

- Make course seeding part of the standard pull-request preview overlay instead of selecting a
  separate seeding overlay through the `preview-seeding` label.
- Remove the ApplicationSet label condition and always select the standard preview overlay.
- Move the retained course-seeding Job and its scenario configuration into that standard overlay,
  then remove the redundant seeding-specific overlay.
- Preserve the one-shot Job contract:
  - fixed Job identity;
  - sync wave `20`, after baseline setup and application readiness;
  - `backoffLimit: 0` and `restartPolicy: Never`;
  - no Argo CD hook annotation or successful-Job TTL; and
  - ignored pod-template drift so later image updates do not replay completed seeding.
- Keep `PREVIEW_QA_TOOLS_ENABLED` independent from CLI seeding. Add it to the standard preview
  configuration only if masquerade and mailbox access should also become universal preview
  capabilities. `bin/seed` itself must not require the flag.
- Reduce the preview AppProject's documented approved source paths to the remaining standard
  preview overlay.
- Update GitOps policy validation to enforce the unconditional preview path, standard-overlay seed
  Job, retained-Job protections, and removal of the label-based branch.
- Update the deployment handbook to describe automatic one-time seeding and deliberate recovery
  from a failed seed.

## Rollout Constraints

Merging the Torus feature does not make previously built preview images compatible. Each preview
image is built from its pull request's head commit, so an older open pull request may still lack
the release seeding code and bundled scenario. Before changing GitOps globally, update and rebuild
active pull-request branches against the merged Torus baseline, allow incompatible previews to
close, or otherwise recreate them with a compatible image.

Changing the shared overlay also causes all existing preview Applications to reconcile. If several
unseeded previews exist, their seed Jobs may start concurrently on shared cluster capacity. Perform
the cutover during a controlled period, remove stale previews first, and observe resource usage.

Apply first-time seeding to fresh preview databases. A failed run may leave partial mutations, and
an existing preview may contain manual or conflicting data. Recovery should recreate/reset the
ephemeral preview environment rather than blindly deleting and rerunning the retained Job. A Job
that failed before loading the seeding runtime is a narrow exception because it could not mutate
the database.

## Acceptance Checks

- A new unlabeled pull request creates a preview and automatically runs the bundled course seed
  after the application becomes ready.
- The seed Job completes with `result_code: "ok"`, and the Application settles at
  `Synced / Healthy`.
- The preview UI exposes the generated project, section, learners, progress, assessment attempts,
  and grades.
- A later commit and preview-image rollout do not recreate or rerun the completed seed Job.
- Closing the pull request removes the Application, namespace, retained Job, and preview data.
- A deliberately failed seed remains visible and does not retry automatically; the documented
  reset procedure restores a clean preview.
- Production and non-preview releases remain unable to invoke the preview release-seeding entry
  point.

## Activation Trigger

Begin this follow-on only after the Torus feature PR is merged and its preview release packaging
fix is present on the baseline used by new pull-request branches.
