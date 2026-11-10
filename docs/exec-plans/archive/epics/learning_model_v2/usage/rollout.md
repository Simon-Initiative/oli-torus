# Learning Model V2 Usage Rollout

## Deployment

Deploy this change with a full application restart. The restart is required to clear in-memory oracle, dashboard snapshot, and SectionResource depot entries created under earlier payload and projection contracts. Oracle implementation-version increments prevent newly computed payloads from colliding with old cache keys, but they do not replace the restart requirement.

Do not run a fleet-wide SectionResource backfill. Legacy Sections remain at their persisted migration version until first depot initialization. That access runs `SectionResourceMigration.ensure_current/1`, locks and rechecks the Section row, commits the projection and version together, and only then loads the depot table.

Existing Sections remain on the `naive` model. This rollout does not migrate a Section's `learning_model_version`; LKT-AOA reads activate only for Sections already created from an LKT-AOA project and supplied by the evaluated-attempt state pipeline.

## Observation and Retry

Monitor AppSignal for the `[:oli, :delivery, :proficiency, :provider]` telemetry span, grouped by bounded `model`, `operation`, and `outcome` metadata. Track duration plus requested, returned, defined, and unavailable counts. The metadata intentionally excludes Section, learner, objective, attempt, and raw-content identifiers.

Also monitor errors originating from `SectionResourceDepot.process_table_creation/1` and `SectionResourceMigration.ensure_current/1`. A failed JIT migration does not advance the version or populate the depot table; a later depot access retries the migration. Investigate repeated failures before retrying traffic, using the application error trace rather than adding learner or content identifiers to telemetry.

## Release Checks

- Confirm all application nodes restarted after deployment.
- Confirm no deployment-wide SectionResource backfill job or migration was scheduled.
- Exercise first depot access for a legacy-version test Section and confirm its marker advances only after projection success.
- Compare representative naive learner and instructor labels with the pre-release baseline.
- Confirm representative LKT-AOA objective values remain numeric through oracle projection and CSV serialization.
- Confirm AppSignal provider metadata contains only bounded counts and categorical model/operation/outcome fields.
