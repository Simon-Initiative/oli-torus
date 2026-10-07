# Secure-delivery assessment policy foundation

`SectionResource.secure_delivery` stores a section-level boolean policy for graded
pages, including basic and adaptive assessments. It defaults to false and has no
student-exception override. Product duplication and publication updates preserve
the stored value. Course copy carries it when assessment settings are selected
and resets it otherwise; assessment-settings bulk apply does not copy it.

The domain API validates the editor, target, boolean value, and instance capability
before updating policy. `SUPPORTS_SECURE_DELIVERY` defaults to false. Disabling the
capability does not erase existing policy or prevent unrelated settings changes.

This PR is a data/settings foundation. It does not enforce secure launches or
restrict learner navigation. Instructor controls and their update events remain
unavailable for enabling policy through `Oli.Delivery.SecureAssessments.settings_available?/0`, even when
the environment capability is enabled. Session authorization and verified launch
integration must land before the internal `:secure_delivery_enforcement_ready`
application configuration is enabled. Disabling an existing policy remains allowed. It defaults to false and is enabled only by the focused UI tests in
this PR. No environment flag enables the readiness gate in this implementation.

The migration is reversible. To rehearse the policy migration in a disposable
database, run:

```sh
MIX_ENV=test mix run --no-start test/support/secure_delivery_migration_check.exs
```

The rehearsal refuses to reuse an existing database and verifies the default,
not-null constraint, and an up/down/up cycle. It never resets the application's
configured database.
