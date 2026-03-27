# Certificate Scenario Coverage Contract

Work item: `docs/exec-plans/current/epics/automated_testing/certificates`
Phase: `1 - Define Scenario Coverage Contract`

Source inputs:
- `docs/exec-plans/current/epics/automated_testing/certificates/regression-cert.md`
- `docs/exec-plans/current/epics/automated_testing/certificates/plan.md`
- Current certificate implementation and automated coverage review

## Purpose
This document converts the manual certificate regression matrix into an execution contract for scenario automation. Each manual row is assigned one of three dispositions:
- `Scenario now`: can be expressed with current `Oli.Scenarios` capability
- `Scenario after DSL expansion`: should be covered by scenarios, but current DSL/runtime support is insufficient
- `Retain non-scenario evidence`: should remain covered primarily by existing non-scenario tests because the expected result is browser rendering, PDF fidelity, or controller/UI delivery behavior

## Planned Scenario Files
- `test/scenarios/certificates/setup_and_section_copy.scenario.yaml`
- `test/scenarios/certificates/student_progress_pending_and_approval.scenario.yaml`
- `test/scenarios/certificates/distinction.scenario.yaml`
- `test/scenarios/certificates/section_customization_and_updates.scenario.yaml`
- `test/scenarios/certificates/certificates_test.exs`

## Missing Scenario Capabilities
- `certificate` directive to configure certificate settings on a product or section
- learner contribution support for:
  - discussion posts
  - public class notes
- scored-page learner workflow support suitable for certificate qualification
- `assert certificate` support for:
  - threshold progress counts
  - granted certificate state
  - distinction flag
  - granted certificate existence/absence
  - section certificate required-assessment snapshot
- instructor action support for:
  - approve certificate
  - deny certificate
- optional generic job-side-effect assertion if email/Oban coverage is pulled into scenarios

## Row Disposition

| Row | Manual case | Disposition | Planned automated evidence |
| --- | --- | --- | --- |
| `CERT SET UP A` | Enable certificate | Scenario after DSL expansion | `setup_and_section_copy.scenario.yaml` with `certificate` directive asserting enabled config exists |
| `CERT SET UP B` | Configure thresholds | Scenario after DSL expansion | `setup_and_section_copy.scenario.yaml` asserting persisted thresholds and required assessments |
| `CERT SET UP C` | Configure design titles | Retain non-scenario evidence plus scenario persistence assertion | Scenario should assert persisted title/subtitle data; LiveView tests remain authoritative for preview behavior |
| `CERT SET UP D` | Configure design admins | Retain non-scenario evidence plus scenario persistence assertion | Scenario should assert persisted admin fields; LiveView tests remain authoritative for preview behavior |
| `CERT SET UP E` | Configure design logo | Retain non-scenario evidence | Existing LiveView/PDF-oriented layers remain primary; no scenario image-upload/rendering target in Phase 1 |
| `CERT SET UP F` | Create cert section | Scenario after DSL expansion | `setup_and_section_copy.scenario.yaml` asserting section certificate matches product/template configuration |
| `CERT PROGRESS A` | View certificate default | Scenario after DSL expansion | `student_progress_pending_and_approval.scenario.yaml` asserting initial zero progress counts |
| `CERT PROGRESS B` | Notes requirement | Scenario after DSL expansion | same file, asserting notes progress before and after public class-note creation |
| `CERT PROGRESS C` | Assignment not good enough | Scenario after DSL expansion | same file, asserting required assignments remain incomplete/insufficient |
| `CERT PROGRESS D` | Pending certificate | Scenario after DSL expansion | same file, asserting pending state after thresholds met with instructor approval required |
| `CERT PROGRESS E` | Instructor view pending cert | Scenario after DSL expansion | same file, asserted as pending granted-certificate state visible in domain data rather than UI navigation |
| `CERT PROGRESS F` | Instructor consider deny | Scenario after DSL expansion | same file, instructor denial action and resulting denied state |
| `CERT PROGRESS G` | Instructor approval | Scenario after DSL expansion | same file, instructor approval action and resulting earned state |
| `CERT PROGRESS H` | Earned certificate | Scenario after DSL expansion | same file, earned state without distinction after approval |
| `CERT PROGRESS I` | View certificate | Retain non-scenario evidence plus scenario lifecycle assertion | Scenario should prove granted certificate exists with correct ownership/state; LiveView test remains authoritative for rendering/access page |
| `CERT PROGRESS J` | Download certificate | Retain non-scenario evidence plus scenario lifecycle assertion | Scenario should prove generated certificate artifact/job state; existing worker/controller tests remain primary for actual download behavior |
| `CERT PROGRESS K` | Earned distinction | Scenario after DSL expansion | `distinction.scenario.yaml` asserting distinction upgrade and final state |
| `CERT UPDATE A` | Add pages | Scenario after DSL expansion | `section_customization_and_updates.scenario.yaml` asserting added pages do not alter required assessment snapshot |
| `CERT UPDATE B` | Make update | Scenario after DSL expansion | same file, assert updated product certificate configuration persists |
| `CERT UPDATE C` | Update for new section | Scenario after DSL expansion | same file, assert new section picks up updated certificate requirements |
| `CERT UPDATE D` | No update for existing section | Scenario after DSL expansion | same file, assert old section preserves original requirement snapshot and remains completable |

## Representative Scenario Set

### 1. `setup_and_section_copy.scenario.yaml`
Purpose:
- cover certificate enablement/configuration at template level
- assert copied section certificate settings

Rows covered:
- `CERT SET UP A`
- `CERT SET UP B`
- `CERT SET UP F`
- partial persistence support for `CERT SET UP C/D`

### 2. `student_progress_pending_and_approval.scenario.yaml`
Purpose:
- cover initial progress, notes/discussion/assignment qualification, pending, deny, approve, and earned states

Rows covered:
- `CERT PROGRESS A`
- `CERT PROGRESS B`
- `CERT PROGRESS C`
- `CERT PROGRESS D`
- `CERT PROGRESS E`
- `CERT PROGRESS F`
- `CERT PROGRESS G`
- `CERT PROGRESS H`
- partial lifecycle support for `CERT PROGRESS I/J`

### 3. `distinction.scenario.yaml`
Purpose:
- isolate distinction-specific upgrade behavior from standard completion flow

Rows covered:
- `CERT PROGRESS K`

### 4. `section_customization_and_updates.scenario.yaml`
Purpose:
- prove section snapshot behavior under content customization and later product certificate changes

Rows covered:
- `CERT UPDATE A`
- `CERT UPDATE B`
- `CERT UPDATE C`
- `CERT UPDATE D`

## Assertion Strategy

### Assert as domain state in scenarios
- certificate enablement/configuration on template or section
- threshold values
- required-assessment snapshot
- counts for notes, discussions, and required assignments
- granted certificate existence
- granted certificate state: `pending`, `earned`, `denied`, or absent
- distinction flag
- stability of old-section vs new-section certificate requirements after product updates

### Assert as side effects in scenarios only if a generic mechanism is added
- queued instructor-notification mail jobs
- queued student notification or PDF generation jobs

### Retain as non-scenario evidence
- preview fidelity of certificate design modal/iframe
- actual PDF rendering details
- controller-level download responses
- browser navigation wording and page composition already covered by LiveView/controller tests

## Proposed YAML Shapes

### Certificate configuration
```yaml
- certificate:
    target: "certificate_product"
    enabled: true
    thresholds:
      required_discussion_posts: 0
      required_class_notes: 1
      min_percentage_for_completion: 50
      min_percentage_for_distinction: 75
      assessments_apply_to: "custom"
      scored_pages:
        - "Scored Page 1"
      requires_instructor_approval: true
    design:
      title: "Course Title"
      description: "Subtitle"
      admin_name1: "Admin One"
      admin_title1: "Dean"
```

### Learner certificate-relevant collaboration actions
```yaml
- discussion_post:
    student: "student_1"
    section: "cert_section"
    body: "My discussion contribution"

- class_note:
    student: "student_1"
    section: "cert_section"
    page: "Scored Page 1"
    body: "My class note"
```

### Certificate assertions
```yaml
- assert:
    certificate:
      section: "cert_section"
      student: "student_1"
      state: "pending"
      with_distinction: false
      progress:
        discussion_posts:
          completed: 1
          total: 1
        class_notes:
          completed: 1
          total: 1
        required_assignments:
          completed: 1
          total: 1
```

### Instructor certificate actions
```yaml
- certificate_action:
    instructor: "instructor_1"
    section: "cert_section"
    student: "student_1"
    action: "approve"
```

## Open Constraints
- Current `Oli.Scenarios` only supports `view_practice_page` and `answer_question`; it does not yet provide a graded-page workflow suitable for certificate qualification.
- Current `assert` support does not include certificate-specific assertions.
- The work item itself still lacks `prd.md`, `fdd.md`, and `requirements.yml`, so harness validation cannot pass until those planning inputs exist or the validation contract is intentionally adjusted.

## Phase 1 Done Check
- Every manual row has an automation disposition.
- Planned scenario files are named.
- Missing DSL capabilities are named.
- Expected domain-state vs side-effect vs non-scenario assertions are explicitly separated.
