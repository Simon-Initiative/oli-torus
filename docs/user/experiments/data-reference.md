# Experiment Data and Key Reference

This reference describes the JSON stored in S3 and its normalized ClickHouse representation. See
[Native Experiment Data Guide](README.md) for the conceptual model and the
[Glossary](glossary.md) for term definitions.

## Example xAPI JSON

S3 files are JSONL: the following formatted object would occupy one line in the actual file. This
example is an evaluated activity carrying a weighted-random outcome attribution.

```json
{
  "actor": {
    "account": {
      "homePage": "https://torus.example.edu",
      "name": "12345"
    },
    "objectType": "Agent"
  },
  "verb": {
    "id": "http://adlnet.gov/expapi/verbs/evaluated"
  },
  "object": {
    "id": "https://torus.example.edu/activity_attempt/activity-guid",
    "definition": {
      "type": "http://oli.cmu.edu/extensions/activity_attempt"
    },
    "objectType": "Activity"
  },
  "context": {
    "extensions": {
      "http://oli.cmu.edu/extensions/section_id": 2001,
      "http://oli.cmu.edu/extensions/project_id": 1001,
      "http://oli.cmu.edu/extensions/publication_id": 3001,
      "http://oli.cmu.edu/extensions/enrollment_id": 501,
      "http://oli.cmu.edu/extensions/activity_attempt_guid": "activity-guid",
      "http://oli.cmu.edu/extensions/activity_attempt_number": 2,
      "http://oli.cmu.edu/extensions/page_attempt_guid": "page-guid",
      "http://oli.cmu.edu/extensions/page_attempt_number": 1,
      "http://oli.cmu.edu/extensions/activity_id": 8001,
      "http://oli.cmu.edu/extensions/activity_revision_id": 8101,
      "http://oli.cmu.edu/extensions/experiment_attributions": [
        {
          "key": "outcome:activity_attempt:801:assignment:404",
          "role": "rollup",
          "attribution_type": "outcome",
          "experiment_id": 101,
          "experiment_uuid": "11111111-2222-3333-4444-555555555555",
          "condition_id": 303,
          "condition_code": "condition-a",
          "assignment_id": 404,
          "assignment_key": "101:601:501",
          "assignment_scope": "intervention",
          "algorithm": "weighted_random",
          "policy_version": "weighted_random:v1",
          "intervention_id": 601,
          "intervention_key": "7001:alternatives-1",
          "section_id": 2001,
          "project_id": 1001,
          "publication_id": 3001,
          "enrollment_id": 501,
          "activity_attempt_id": 801,
          "resource_attempt_id": 901,
          "activity_resource_id": 8001,
          "score": 1.0,
          "out_of": 2.0,
          "recorded_at": "2026-08-20T13:45:00Z"
        }
      ]
    }
  },
  "result": {
    "score": {
      "raw": 1.0,
      "max": 2.0,
      "scaled": 0.5
    },
    "completion": true,
    "success": false
  },
  "timestamp": "2026-08-20T13:45:00Z"
}
```

The attribution above has no `reward_value`. In ClickHouse it becomes `NULL`, not `1.0`.

## Event-to-record mapping

| Application event | Common xAPI statement type | Attribution type | Statement role | Notes |
| --- | --- | --- | --- | --- |
| Condition assigned during page preparation | No dedicated xAPI statement | — | — | The assignment is persisted in PostgreSQL. Assignment telemetry is operational only; it does not itself create an S3 or ClickHouse row. |
| Selected experiment content shown | `page_viewed` | `exposure` | `exposure` | Includes `content_revision_id`, actual intervention, and exposure time. |
| Evaluated part attempt | `part_attempt` | `outcome` | `outcome` | Direct evidence; includes score and attempt identity. |
| Evaluated activity attempt | `activity_attempt` | `outcome` | `rollup` | Same outcome evidence attached to the activity statement. |
| Evaluated page attempt | `page_attempt` | `outcome` | `rollup` | Same outcome evidence attached to the page statement. |
| Thompson reward recorded | part/activity/page attempt or dedicated assessment evidence statement | `reward` | `reward` or `rollup` | Includes explicit `reward_value`, `reward_source`, and `outcome_key`. |
| Thompson posterior updated | No dedicated xAPI statement | — | — | The update is persisted by the experiment runtime and emits bounded operational telemetry. The ClickHouse schema can represent `policy_update`, but the current telemetry path does not create an xAPI row. |
| Video played, paused, seeked, or completed in selected content | video statement | `assignment` | `media_interaction` | Creates the currently supported assignment-attribution row and ties the interaction to the selected assignment/intervention. It is not an outcome or reward. |

The `role` answers “how is this evidence used on this xAPI statement?” The `attribution_type` answers “what
kind of evidence is this?” A rolled-up activity or page therefore has `role = 'rollup'` and
`attribution_type = 'outcome'` or `'reward'`.

### Direct evidence and rollup copies

One evaluated part can produce three related xAPI statements:

| xAPI statement type | `experiment_role` | `attribution_type` | Interpretation |
| --- | --- | --- | --- |
| `part_attempt` | `outcome` | `outcome` | Direct outcome evidence created by the evaluated part. |
| `activity_attempt` | `rollup` | `outcome` | The same logical outcome attached to its parent activity statement. |
| `page_attempt` | `rollup` | `outcome` | The same logical outcome attached to its parent page statement. |

Rewards follow the same pattern: the direct statement uses `experiment_role = 'reward'`, while
copies on parent statements use `experiment_role = 'rollup'`; all retain
`attribution_type = 'reward'`.

Rollups support analysis at the activity or page level without claiming that the parent evaluation
created a new outcome or reward. Choose one xAPI statement type or the applicable direct role before counting
evidence. Each attached ClickHouse row has its own `attribution_hash`, so counting distinct
`attribution_hash` values does not collapse a direct row and its rollup copies into one logical event.

## Key formats

Keys are stable idempotency or identity strings. Treat the full string as the durable identifier;
parse components only for diagnostics or when the format below is explicitly required.

### `assignment_key`

Intervention-scoped assignment:

```text
<experiment_id>:<intervention_id>:<enrollment_id>
101:601:501
```

Components:

- `experiment_id`: experiment definition database ID.
- `intervention_id`: the concrete experiment placement/intervention.
- `enrollment_id`: the learner's pseudonymous identity in the section.

Section-enrollment-scoped weighted-random assignment:

```text
v2:section_enrollment:<experiment_id>:<section_id>:<enrollment_id>
v2:section_enrollment:101:2001:501
```

This scope chooses one condition for the enrollment across placements in that experiment. Thompson
Sampling does not support this scope.

### `intervention_key`

```text
<page_resource_id>:<content_element_id>
7001:alternatives-1
```

The page resource identifies the page containing the placement. `content_element_id` identifies
the Alternatives element within that page. Because the element identifier is a string, split only
on the first colon if parsing is unavoidable.

### Attribution `key`

Every attribution payload has a `key`. ClickHouse combines it with the raw event hash to derive
`attribution_hash`.

Common outcome key:

```text
outcome:activity_attempt:<activity_attempt_id>:assignment:<assignment_id>
```

Common reward key:

```text
reward:activity_attempt:<activity_attempt_id>:assignment:<assignment_id>
```

Assessment reward evidence:

```text
assessment_reward:<assessment_reward_id>
```

Assignment attribution normally uses `assignment_key` as its attribution `key`. Exposure keys use:

```text
assignment:<assignment_id>:placement:<page_resource_id>:<content_element_id>
```

They are stable for that assignment/content exposure.
Policy updates use their recorded policy-update key, with a fallback derived from the reward key.

### Hash keys

```text
raw_events.event_hash = SHA-256(exact persisted xAPI JSON bytes)
experiment_attributions.raw_event_hash = raw_events.event_hash
experiment_attributions.attribution_hash = SHA-256(raw_event_hash + ":" + attribution.key)
```

Use these hashes as opaque identifiers for joins and deduplication. They cannot be decoded back
into the original event or attribution data.

## `raw_events` reference

The most useful experiment-analysis columns are:

| Column | Meaning |
| --- | --- |
| `event_hash` | Stable hash of the exact source statement bytes; primary raw-event join key. |
| `event_version` | Replacement/version timestamp used by `ReplacingMergeTree`. |
| `timestamp` | Event occurrence time from xAPI. |
| `inserted_at` | ClickHouse ingestion time. |
| `source_file`, `source_etag`, `source_line` | S3/Lambda provenance when available; nullable for direct ingestion. |
| `event_type` | Normalized xAPI statement type: for example `page_viewed`, `activity_attempt`, `page_attempt`, `part_attempt`, or `video`. |
| `verb_id` | Full xAPI verb URI. |
| `section_id`, `project_id`, `publication_id` | Delivery and content scope. |
| `enrollment_id` | Pseudonymous participant identity; nullable for historical or non-attempt events. |
| `activity_attempt_guid`, `activity_attempt_number` | Activity-attempt identity and sequence. |
| `page_attempt_guid`, `page_attempt_number` | Parent page-attempt identity and sequence. |
| `activity_id`, `activity_revision_id` | Activity resource and revision identity. |
| `score`, `out_of`, `scaled_score` | Attempt performance from the xAPI statement. |
| `success`, `completion` | xAPI result flags. |
| `page_id`, video columns, part-attempt columns | Statement-specific context; nullable for other statement types. |

The source S3 statement can contain the full xAPI actor and sensitive learner account information.
ClickHouse does not project the full actor: `raw_events.user_id` comes from xAPI
`actor.account.name`, and `raw_events.home_page` comes from `actor.account.homePage`. These are
identifiers, not the complete actor object. The separately projected response and feedback columns
may still contain sensitive learner data. Use all such fields only under the applicable data-access
and research approvals.

## `experiment_attributions` reference

| Column | Meaning |
| --- | --- |
| `raw_event_hash` | Join to `raw_events.event_hash`. |
| `attribution_hash` | Stable identity for one attribution attached to one raw event. |
| `event_version`, `inserted_at` | Replacement and ingestion timestamps. |
| `source_file`, `source_etag`, `source_line` | Source-object provenance when available. |
| `raw_event_type` | Normalized type of the containing xAPI statement; matches `raw_events.event_type`. |
| `timestamp` | Containing xAPI statement timestamp. |
| `section_id`, `project_id`, `publication_id`, `enrollment_id` | Scoped experiment context. |
| `experiment_role` | Statement role: `assignment`, `exposure`, `outcome`, `reward`, `policy_update`, `rollup`, or `media_interaction`. |
| `attribution_type` | Evidence type: `assignment`, `exposure`, `outcome`, `reward`, or `policy_update`. |
| `experiment_id`, `experiment_uuid` | Internal and portable experiment identities. |
| `condition_id`, `condition_code` | Assigned condition identities. Prefer code for readable output and ID for stable joins within one database. |
| `assignment_id`, `assignment_key`, `assignment_scope` | Assignment identity and scope. |
| `algorithm`, `policy_version` | Allocation algorithm and version. |
| `content_revision_id` | Revision shown for exposure evidence; normally null on outcomes. |
| `intervention_id`, `intervention_key` | Concrete placement/intervention identity. |
| `resource_attempt_id` | Related page/resource attempt when supplied. |
| `assessment_binding_id`, `assessment_page_resource_id` | Assessment-to-experiment reward binding evidence. |
| `disposition` | Assessment reward handoff disposition. |
| `reward_threshold`, `normalized_score` | Explicit assessment reward inputs. |
| `page_revision_id` | Page revision used by assessment reward evidence. |
| `reward_value` | Explicit policy reward only; `NULL` means no reward evidence and `0.0` is a real reward value. |
| `reward_source` | Producer-defined origin such as `activity_attempt:full_credit` or `assessment_page:normalized_score`. |

Not every payload field is projected into ClickHouse. The S3 xAPI source is the authoritative
record when a bounded attribution field such as the outcome's `score`, `out_of`, `recorded_at`, or
`outcome_key` is not a ClickHouse column.
