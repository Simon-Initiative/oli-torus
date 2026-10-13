# Preview Course Seeding

This example adds the bundled `oli_torus_getting_started_course` scenario to a pull-request
preview as a one-time initialization Job. It is a deployment contract, not a complete environment
overlay: the owning GitOps repository supplies the real image tag, runtime Secret, service account,
namespace, and application Deployment.

## Development and Release Commands

Run the scenario in development while the Phoenix server is running:

```bash
mix seed scenarios run --name oli_torus_getting_started_course
```

The preview release exposes the same synchronous operation without a runtime feature flag:

```bash
./bin/seed scenarios run --name oli_torus_getting_started_course
```

`PREVIEW_QA_SEED_SCENARIO` selects the bundled scenario for deployment automation. The example
Kustomize replacement copies it into the final argument so it remains a discrete argument and is
never shell-interpolated. `PREVIEW_QA_TOOLS_ENABLED=true` is present in the example runtime
configuration for web-accessible masquerade and mailbox features; it does not control this Job.

Both commands use the same database as the running application. Run the application server before
starting either command so its normal background consumers can process the downstream work created
by learner simulation.

## Integrating the Job

On a fresh non-dev preview database, the GitOps-owned runtime Secret must provide both
`ADMIN_EMAIL` and `ADMIN_PASSWORD` to baseline `release-setup`. Its `priv/repo/seeds.exs` step
uses these values to create the active system administrator required by the bundled scenario's
`author: default_admin` ownership selector. If either variable is absent, baseline setup skips
admin creation and the scenario cannot resolve `default_admin`. Complete baseline setup before
running the seed Job; keep the credential values in the runtime Secret.

Copy or adapt these resources in the preview overlay, then align these placeholder references with
the application Deployment:

- Apply the same preview release image replacement to the Deployment and Job.
- Use the same runtime ConfigMap, runtime Secret, and service account names as the Deployment.
- Keep `automountServiceAccountToken: false`; the release command needs the workload identity but
  does not call the Kubernetes API.
- Keep the Job at a later Argo CD sync wave than the Deployment. Argo CD waits for the Deployment to
  become Healthy, which means its baseline `release-setup` init container completed and its server
  readiness probe passed, before starting the Job.
- Keep the fixed Job name, `restartPolicy: Never`, and `backoffLimit: 0`.
- Do not add a Job TTL. The completed Job and pod provide bounded namespace-lifetime status and logs.

The Job is intentionally not idempotent and Torus does not persist a separate seed-run marker. Its
completed Kubernetes object is the one-run marker for that preview namespace. Merge the fields in
`applicationset-patch.yaml` into the pull-request preview ApplicationSet. With
`RespectIgnoreDifferences=true` and `/spec/template` ignored for this fixed Job, a later application
image update or ordinary resync does not replace the completed Job or attempt to mutate its immutable
pod template. Automated pruning removes it when the pull-request Application and namespace are
deleted.

Ignoring the completed Job's pod template also means an image, runtime-reference, or pod-security
change does not update an existing preview's retained Job. Recreate that ephemeral preview
namespace when such a fix must be applied; the replacement namespace receives a fresh Job built
from the corrected template.

Render the public example before adapting it:

```bash
kubectl kustomize docs/manifests/preview-seeding
```

## Direct QA Login

Before the first seed run, configure the optional `PREVIEW_DEMO_USER_PASSWORD` key in the
GitOps-owned preview runtime Secret (`oli-torus-preview-runtime` in this example). The seed
Job already imports that Secret through `envFrom`; no password belongs in scenario YAML,
ConfigMaps, committed manifests, or command-line arguments. Use your deployment's existing
secret-management process to supply the value. Keep it separate from `ADMIN_PASSWORD`.

The password must meet the normal account policy: 12–72 characters and at most 72 UTF-8
bytes. An invalid nonempty value fails seeding before scenario mutations. A missing or empty
value preserves existing password-creation behavior. The setting takes effect only for
`MIX_ENV=preview` seed execution; development, test, CI E2E, production, and normal account
registration ignore it. It does not require `PREVIEW_QA_TOOLS_ENABLED`.

Open the preview through its usual deployment authentication, then use these Torus logins:

| Account | Email | Login path |
| --- | --- | --- |
| System administrator | Existing `ADMIN_EMAIL` (normally `admin@example.edu`) | `/authors/log_in` |
| Author | `author1@example.edu` | `/authors/log_in` |
| Instructor | `instructor1@example.edu` | `/instructors/log_in` |
| Students | `student1@example.edu`, `student2@example.edu`, `student3@example.edu` | `/users/log_in` |

The administrator continues using `ADMIN_PASSWORD`. All newly created demo accounts use
`PREVIEW_DEMO_USER_PASSWORD` when configured, including `simulated_instructor_1@example.edu`
and `simulated_learner_1@example.edu` through `simulated_learner_12@example.edu`. Newly seeded
preview accounts have confirmed emails. The author is a collaborator on the demo project;
the named instructor and students are enrolled in its section. Named students start without
simulated progress; the existing generated cohort retains its progress and grades.

Credentials are applied only on creation. Existing passwords, including passwordless reused
accounts and the bootstrap administrator, are never changed by this setting. Changing the
Secret does not rotate existing account passwords or replay a completed seed Job. Recreate
or deliberately reset an ephemeral preview to seed it with the new configuration; do not rerun
the one-shot scenario against existing data. Masquerade remains a separate QA workflow.

## Observation and Recovery

Watch the one-time run with the namespace used by the preview:

```bash
kubectl get job oli-torus-preview-seed -n <preview-namespace>
kubectl logs job/oli-torus-preview-seed -n <preview-namespace>
kubectl describe job oli-torus-preview-seed -n <preview-namespace>
```

A nonzero exit may follow partial committed mutations. Because automatic retry and reconciliation
are deliberately absent, do not simply delete and rerun the Job against the same data. Inspect its
bounded output, recreate the ephemeral preview namespace/database (or deliberately reset it), and
let Argo CD create a fresh Job against fresh data.

Automated preview initialization always uses fast simulation. Paced simulation is a foreground,
operator-invoked workflow for watching learners progress in real time; interrupting that command
stops its workers while preserving already committed progress.

Playwright remains independent. Its specifications continue creating isolated scenario fixtures
through their existing test-owned setup and do not depend on this bundled scenario or Job.
