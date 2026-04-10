# Storage-Assisted Prototype Checkpoint

## Purpose

This note records the archival checkpoint for the storage-assisted and partial cookieless LTI launch prototype before the follow-on rollback work removes that feature set from Torus.

## Git Checkpoint

- Branch: `lti-launch-hardening-storage-assisted-prototype`
- Commit: `1111e73213a1cbff76878813ace9325bb2ff5e8b`

## What This Checkpoint Contains

- `lti_storage_target`-driven launch transport selection
- storage-assisted launch helper behavior
- database-backed `Oli.Lti.LaunchAttempt` and `Oli.Lti.LaunchAttempts`
- launch-attempt cleanup behavior
- signed post-launch landing continuation behavior
- feature-flag-controlled new-window fallback behavior

## Why This Checkpoint Is Archived

The prototype demonstrates that Torus can complete the storage-assisted LTI handshake, but it also confirms that Torus still depends on its own authenticated web-session model after launch. The resulting continuation design introduces additional security and complexity tradeoffs that are not justified for the foreseeable product direction.

The follow-on direction is to remove the storage-assisted and launch-attempt-based prototype surfaces while preserving the other hardening improvements from this branch.

## Restore Guidance

To inspect or restore this prototype state later:

```bash
git checkout lti-launch-hardening-storage-assisted-prototype
```

Or restore directly from the recorded commit:

```bash
git checkout 1111e73213a1cbff76878813ace9325bb2ff5e8b
```

## Related Work-Item Docs

- [prd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prd.md)
- [fdd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/fdd.md)
- [plan.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/plan.md)
