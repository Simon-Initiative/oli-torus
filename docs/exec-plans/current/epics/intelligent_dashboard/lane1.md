# Lane 1 Visual Guide

### Incremental Tile Rendering with Async Oracle Loading
Motivation: instructors should start seeing useful dashboard content quickly, not wait for every backend query to finish. Diagram: shows async oracle loading and capability-by-capability tile rendering as results arrive.

```mermaid
sequenceDiagram
  autonumber
  participant U as Instructor
  participant LV as Dashboard LiveView
  participant C as Coordinator/DataSnapshot
  participant O1 as Oracle: Progress
  participant O2 as Oracle: Support
  participant O3 as Oracle: Objectives

  U->>LV: Select scope
  LV->>C: start scoped load
  C-->>LV: emit loading state

  par Async oracle loads
    C->>O1: load progress
    and
    C->>O2: load support
    and
    C->>O3: load objectives
  end

  O1-->>C: ready
  C-->>LV: projection ready: progress
  LV-->>U: render Progress tile now

  O2-->>C: ready
  C-->>LV: projection ready: support
  LV-->>U: render Support tile now

  O3-->>C: failed/late
  C-->>LV: projection failed/partial: objectives
  LV-->>U: show scoped error/partial state
```

### Reusable Core vs Instructor-Specific Components
Motivation: today’s Instructor Dashboard investment should be reusable for future dashboard products instead of forcing a rewrite. Diagram: shows the separation between reusable core `Oli.Dashboard.*` modules and instructor-specific `Oli.InstructorDashboard.*` modules.

```mermaid
flowchart LR
  subgraph Reusable["Reusable Core (any dashboard product)"]
    S1[Oli.Dashboard.Scope]
    S2[Oli.Dashboard.OracleContext]
    S3[Oli.Dashboard.OracleRegistry behavior]
    S4[Oli.Dashboard.LiveDataCoordinator]
    S5[Oli.Dashboard.Cache]
    S6[Oli.Dashboard.Snapshot.Assembler/Projections]
  end

  subgraph Instructor["Instructor-Specific"]
    I1[Oli.InstructorDashboard.OracleRegistry]
    I2[Oli.InstructorDashboard.Oracles.*]
    I3[Oli.InstructorDashboard.DataSnapshot]
    I4[Instructor tile capabilities]
  end

  subgraph Future["Future Dashboard Product"]
    F1[FutureProduct.OracleRegistry]
    F2[FutureProduct.Oracles.*]
    F3[FutureProduct projection consumers]
  end

  Instructor --> Reusable
  Future --> Reusable
  I1 --> I2 --> I3 --> I4
  F1 --> F2 --> F3
```

### Worked Example: Normal Clicks (Unit 1 -> Unit 2)
Motivation: normal navigation should feel immediate and always follow the instructor’s latest click. Diagram: shows `Unit 1 -> Unit 2` where the active request is preempted and the newest scope starts right away.

```mermaid
sequenceDiagram
  autonumber
  participant U as Instructor
  participant LV as LiveView
  participant C as Coordinator
  participant K as Cache
  participant O as OracleRuntime

  U->>LV: Select Unit 1
  LV->>C: request_scope_change(U1)
  C->>K: lookup_required(U1)
  K-->>C: partial_hit(hits, misses)
  C->>O: start_load(token_1, misses)
  C-->>LV: emit_loading(token_1)

  U->>LV: Select Unit 2
  LV->>C: request_scope_change(U2)
  C-->>C: preempt token_1
  C->>K: lookup_required(U2)
  C->>O: start_load(token_2, misses)
  C-->>LV: emit_loading(token_2)
```

### Worked Example: Scrub Mode for Rapid Clicking
Motivation: rapid scrubbing (traversing multiple scopes) should not overwhelm DB/runtime work or cause UI thrash while still feeling responsive. Diagram: shows the timer-window mechanism (`scrub_window_ms`, default `400ms`) and threshold (`scrub_threshold`, default `3`) that switch behavior from immediate preempt to one-active/one-queued replacement, then reset after window expiry.

```mermaid
sequenceDiagram
  autonumber
  participant U as Instructor
  participant LV as LiveView
  participant C as Coordinator
  participant B as Burst Window Counter

  Note over C,B: Defaults: scrub_window_ms=400, scrub_threshold=3

  U->>LV: t=0ms click A
  LV->>C: request_scope_change(A)
  C->>B: track_navigation_burst(now)
  B-->>C: count=1, scrub_mode=false
  C-->>C: start/preempt immediately (active=A)

  U->>LV: t=120ms click B
  LV->>C: request_scope_change(B)
  C->>B: track_navigation_burst(now)
  B-->>C: count=2, scrub_mode=false
  C-->>C: preempt active (active=B)

  U->>LV: t=260ms click C
  LV->>C: request_scope_change(C)
  C->>B: track_navigation_burst(now)
  B-->>C: count=3, scrub_mode=true
  C-->>C: keep active=B, queue C

  U->>LV: t=320ms click D
  LV->>C: request_scope_change(D)
  C->>B: track_navigation_burst(now)
  B-->>C: count=4, scrub_mode=true
  C-->>C: replace queued (C->D)

  U->>LV: t=900ms click E (outside 400ms window)
  LV->>C: request_scope_change(E)
  C->>B: track_navigation_burst(now)
  B-->>C: window expired -> count reset to 1, scrub_mode=false
  C-->>C: preempt active immediately, clear queued, active=E
```

### Worked Example: Stale Results Still Help Future Loads
Motivation: stale responses must never corrupt current UI state, but completed work should still provide future performance benefit. A response is considered stale when it arrives after the user has already navigated to a different scope (so that token is no longer active). Diagram: shows stale-token UI suppression with safe late cache write for the original scope.

```mermaid
sequenceDiagram
  autonumber
  participant O as OracleRuntime
  participant C as Coordinator
  participant K as Cache
  participant LV as LiveView

  O-->>C: oracle_result(token_1, U1, payload)
  C->>K: write_oracle(U1, payload)
  C-->>C: token_1 is stale vs active token_2
  C-->>LV: suppress UI apply
```

### Cache Read-Through Decision Path
Motivation: avoid recomputing data we already have and load only what is missing. Diagram: shows the full-hit / partial-hit / miss path and where runtime loading plus cache write-back happen.

```mermaid
flowchart TD
  START[lookup_required]
  FH{full hit?}
  PH{partial hit?}
  RH[return hits]
  APPLY[apply ready data]
  MISS[load misses]
  WR[write_oracle per completion]
  DONE[complete]

  START --> FH
  FH -- yes --> RH --> APPLY --> DONE
  FH -- no --> PH
  PH -- yes --> APPLY --> MISS --> WR --> DONE
  PH -- no --> MISS --> WR --> DONE
```

### `DataSnapshot.get_or_build/2` Flow (Current Design)
Motivation: keep snapshot orchestration deterministic and simpler for this call mode. Diagram: shows current `get_or_build/2` synchronous read-through flow (dependency resolution, cache lookup, runtime for misses/optional, cache write-back, assemble, project).

```mermaid
sequenceDiagram
  autonumber
  participant Caller as Caller
  participant DS as DataSnapshot.get_or_build
  participant R as OracleRegistry
  participant K as Cache
  participant O as OracleRuntime
  participant A as Snapshot.Assembler
  participant P as Snapshot.Projections

  Caller->>DS: get_or_build(scope_request)
  DS->>R: dependencies_for(consumer)
  DS->>K: lookup_required(scope, required_keys)
  DS->>O: load(misses + optional_keys)
  O-->>DS: oracle envelopes
  DS->>K: write_oracle(ready envelopes)
  DS->>A: assemble(scope, request_token, envelopes)
  A->>P: derive_all(snapshot)
  P-->>DS: projections + statuses
  DS-->>Caller: snapshot_bundle
```

### Incremental Rendering Without Global Blocking
Motivation: instructors should see ready information now instead of waiting for slow or failing capabilities. Diagram: shows ready/partial/failed projection states rendering independently without global blocking.

```mermaid
flowchart LR
  O1[Oracle A ready]
  O2[Oracle B ready]
  O3[Oracle C loading]
  O4[Oracle D failed]
  S[Snapshot]
  P1[Projection: progress = ready]
  P2[Projection: support = partial]
  P3[Projection: objectives = failed]
  UI1[Tile Progress renders now]
  UI2[Tile Support renders partial]
  UI3[Tile Objectives shows scoped error]

  O1 --> S
  O2 --> S
  O3 --> S
  O4 --> S
  S --> P1 --> UI1
  S --> P2 --> UI2
  S --> P3 --> UI3
```

### One Data Source for UI and CSV
Motivation: dashboard numbers and exported CSV numbers must stay semantically consistent. Diagram: shows both UI tiles and CSV export consuming the same snapshot bundle and dataset registry so they derive from the same scoped data contract.

```mermaid
flowchart LR
  SB[Snapshot Bundle]
  TILES[Dashboard Tiles]
  EXP[CsvExport.build_zip]
  REG[Dataset Registry]
  CSVS[CSV Files]
  ZIP[ZIP Output]

  SB --> TILES
  SB --> EXP
  EXP --> REG --> CSVS --> ZIP
```

### Revisit Cache Eligibility
Motivation: revisit acceleration should be fast but controlled, not applied to every flow. Diagram: shows explicit-entry eligibility gating (`course`/`container`) before revisit hits are used and remaining misses go to runtime.

```mermaid
sequenceDiagram
  autonumber
  participant LV as LiveView
  participant K as Cache
  participant RV as RevisitCache
  participant O as OracleRuntime

  LV->>K: lookup_required(scope, required)
  K-->>LV: misses
  LV->>K: lookup_revisit(scope, misses, explicit_entry?)
  alt explicit-entry eligible (course/container)
    K->>RV: fetch eligible misses
    RV-->>K: revisit_hits + revisit_misses
    K-->>LV: apply revisit_hits, load revisit_misses
  else ineligible
    K-->>LV: skip revisit lookup
  end
  LV->>O: load remaining misses
```
