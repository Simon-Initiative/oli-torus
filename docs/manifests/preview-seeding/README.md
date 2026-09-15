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
