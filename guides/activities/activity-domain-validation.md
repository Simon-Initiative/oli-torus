# Basic Page activity domain validation

Domain validation is an explicit stage after JSON Schema validation. The JSON validator remains structural and does not call the domain checker.

```elixir
with :ok <- Oli.Validation.validate_activity_schema(type_slug, model),
     :ok <- Oli.Validation.validate_activity_domain(type_slug, model) do
  # The same unchanged model can now be passed to creation.
end
```

`validate_activity_domain/2` returns `:ok` or `{:error, issues}`. Each `Oli.Validation.ActivityDomain.Issue` has string `code`, JSON Pointer `path`, bounded `message`, and `related_paths`. The service is pure: no persistence, ID rewriting, rule evaluation, network calls, or project authorization. Direct callers must first validate the schema; defensive shape and resource checks fail closed without running JSON Schema again. Legacy `validate_activity/1` is unchanged.

## Shared contracts

`lib/oli/validation/activity_contracts.ex` contains the exact manifest slug, schema name, and domain policy in one trusted catalog. All 16 Basic Page activity types have policies. Adaptive retains JSON Schema support but explicitly returns `unsupported_activity_type` from domain validation and these MCP creation/validation flows.

Automatic server response matching requires a terminal catch-all for MCQ, Ordering, CATA, Likert, Short Answer, Multi Input, Custom DND, Response Multi, Image Hotspot, and Virtual Lab. File Upload follows the same rule when its part is automatic; its manual default is exempt. Manually graded parts are exempt from the fallback requirement. Image Coding, OLI Embedded, Logic Lab, LTI External Tool, and participation-driven Directed Discussion use explicit delegated policies. Empty response arrays do not select or change policy. Supplied response rules are checked even for exempt activities/parts.

## Logical ID uniqueness

The domain walker indexes ID definitions across stems, choices, Likert items, inputs, generic rich-content nodes, part/response/hint/feedback/explanation objects, triggers, transformations, and transformation variable data. IDs are global within one submitted activity; integer `1` and string `"1"` are the same logical ID. Resource metadata and reference fields such as `partId`, `choiceIds`, and association targets are not definitions.

One inline stem `input_ref` may share its input definition's ID. Repeated input definitions or inline occurrences still fail. Likert permits the intended one-item/one-part shared identity, while duplicate items or parts fail. Rich-content extension objects, opaque math payloads, arbitrary metadata, LTI custom records, and XML strings are not recursively searched for IDs. Known rich-content children/captions and legacy editor-model envelopes are traversed.

A duplicate issue points to the repeated definition and includes the first location in `related_paths`. The validator never regenerates IDs or rewrites references.

## Response syntax and catch-all detection

Every supplied nonempty `rule` string uses the existing backend `Oli.Delivery.Evaluation.Rule.parse/1` and must be consumed completely. Known input-triggered parser exceptions, including unsupported unparenthesized operator chains, become `invalid_rule` issues. Bare `.*` is not valid backend DSL; the canonical fallback is `input like {.*}`.

Literal `like` regexes must compile but are never matched against sample answers. `@@variable@@` patterns are deferred to the existing transformation system; no variables are evaluated here. This is a syntax check, not a regex runtime-safety guarantee.

Missing or empty legacy rule strings are accepted only with structured `matchConfig`. A supplied nonempty stale string must still parse, but structured matching takes precedence when deciding whether the response is unconditional. `Oli.Math.MatchConfig.prepare/2` now owns the exact item-level merge previously private to `MathExpressionMatcher`; both delivery and domain validation use it. The domain checker decodes the effective configuration through `Oli.Math.Match.decode_config/1`, without inventing a math-expression schema or performing mathematical equivalence, sampling, or answer evaluation.

A final response is accepted as a catch-all when it has the canonical input wildcard AST or an active decoded `type: "always"` configuration. Response Multi also permits positive compound wildcard `input_ref` ASTs, as produced by grouping. Input-reference fallbacks are not accepted for scalar-input activity profiles. Negations, attempt conditions, and merely containing `.*` do not qualify. The classifier is conservative rather than a general proof engine for arbitrary equivalent regexes/Boolean expressions.

An invalid final matcher produces its primary syntax/configuration error without a redundant missing-fallback error. Empty automatic response tables produce `missing_terminal_catch_all`. Independent issues are aggregated in deterministic order, capped at 100.

The evaluator's existing selection behavior remains unchanged: highest-scoring matching response wins; an earlier matching response wins a score tie. This work does not convert evaluation to first-match semantics, require a particular fallback score, or enforce scoring consistency.

## MCP integration

`Oli.MCP.ActivityInput.validate_json/2` orchestrates explicit stages:

1. Bounded JSON decode and resource preflight.
2. `validate_activity_schema/2`; stop on failure.
3. `validate_activity_domain/2`; stop on failure.
4. Return the original decoded model for creation.

Both existing MCP tools use this pipeline. `activity_validation` / `activity_validation_tool` now requires `activity_type_slug` alongside `activity_json`; no type is inferred from model contents. The agent tool registry advertises the same required argument. `create_activity` / `create_activity_tool` already takes the type and now validates it before `ActivityEditor.create`. Existing project authorization still runs before creation. A blank factory stem/preview receives the existing generic title fallback instead of an empty title.

Failures retain readable MCP text and additionally expose a native `structuredContent` object:

```json
{
  "stage": "domain",
  "errors": [{
    "code": "duplicate_id",
    "path": "/choices/0/id",
    "message": "ID is already defined elsewhere in this activity",
    "related_paths": ["/stem/id"]
  }]
}
```

Stages are `json`, `schema`, and `domain`. Issue structs are converted to ordinary maps at this boundary for both the application JSON encoder and MCP's native JSON encoder. No changes were made to general authoring saves, ingest, or publishing validation.

## Resource limits and caching

Defaults are 4 MiB per encoded JSON request (and aggregate decoded key/string bytes), depth 128, 100,000 JSON nodes, 10,000 responses, 32 KiB per rule, 8 KiB per regex, and at most 100 returned issues. Nesting is checked before JSON decoding, including correct handling of quoted/escaped bracket characters. Node/depth/byte preflight occurs before JSON Schema validation. Direct domain calls also receive resource checks.

Static JSV schemas retain their existing build-once cache. User rules and effective match configurations are memoized only within the validation request; they never enter `persistent_term` or an unbounded shared cache. Input configuration lookup is indexed once per part using the same last-input selection as model parsing. Matcher memo keys use compact context tokens, so repeated cache hits do not rehash large shared item configurations. Diagnostics keep path segments until retained errors are encoded. Duplicate-ID buckets and diagnostic lists are bounded.

## Deferred checks

This stage does not establish activity readiness, ID-reference existence, external-resource availability, score consistency, expected-answer coverage, mathematical equivalence correctness, authorization, or runtime regex performance. It does not validate opaque custom content as a separate activity graph. Additional domain checks can be added to the domain service without changing JSON Schema validation or individual MCP endpoints.

## Verification

`test/oli/validation/activity_domain_test.exs` covers all 16 client factories, separate schema/domain behavior, duplicate IDs and binding multiplicity, parser exceptions, invalid regex, catch-all ASTs, evaluation-policy exemptions, structured-matcher precedence, effective item-level configuration, opaque ID payloads, deterministic diagnostics, and limits.

MCP tool and HTTP tests exercise actual stage-specific failures and verify that invalid schema/domain models create no revisions. Existing authorization tests and real successful creation remain covered. Delivery matching/evaluator tests verify that extracting shared preparation preserves matching and scoring behavior.
