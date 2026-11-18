# Multiple choice JSON Schema feasibility prototype

## Result and scope

A complete structural schema for the authored MCQ model is feasible with the
existing Draft 7 infrastructure. The prototype covers the current V2 model and
legacy unversioned V1 models, with recursive rich-content validation throughout.
Ordering, CATA, and Likert companion schemas are documented in
`guides/activities/choice-family-json-schemas.md`. This implementation does not
enable new automatic validation at save, ingest, delivery, or MCP
boundaries. Existing `Oli.Validation.validate_activity/1` behavior is unchanged.

Use the explicit, library-independent API:

```elixir
Oli.Validation.validate_activity_schema("oli_multiple_choice", model)
# :ok | {:error, [{message, json_pointer_path}, ...]}
```

Unknown activity types return an error. The caller supplies the type because
MCQ and check-all-that-apply can have similar shapes; inferring it from `choices`
would select the wrong contract for other activities.

For a complete Activity export, use the composed export schema:

```elixir
root = Oli.Utils.SchemaResolver.resolve("multiple-choice-activity.schema.json")
Oli.Utils.JSONValidation.validate(root, exported_activity)
```

The model schema validates authored data, not delivery payloads whose response
feedback or authoring data has been pruned.

## Reuse graph

All schemas live under `priv/schemas/v0-1-0/`:

```text
multiple-choice-activity.schema.json
  -> activity.schema.json                    existing export envelope
  -> multiple-choice.schema.json             MCQ-specific structure
       -> activity-components.schema.json
            content / response / part / transformation / trigger
            content.content -> rich-text
              array ------------------------------+
              legacy {model: array} ---------------+
                                                    v
content-block.schema.json.children -> content-element.schema.json#/$defs/rich-text
                                        -> the existing shared element definitions
```

There are no copied paragraph, list, media, table, code, formula, or semantic
content definitions in either activity schema. Basic Page blocks and both
activity rich-text representations reference the exact same array definition.

The activity `content` component supplies the surrounding ID, editor choice,
and text direction. It is reused for:

- `stem.content`
- `choices[].content`
- `authoring.parts[].hints[].content`
- `authoring.parts[].responses[].feedback.content`
- `authoring.parts[].explanation.content`

The shared activity components separate reusable structure from MCQ-specific
policy. Future activity schemas can reference these components and the same
rich-content entry point. Their activity-specific fields and constraints still
need independent investigation; the components are not a claim that those
activity types are already supported.

## Model coverage and compatibility

The sources are the actual `defaultMCModel` factory, `mCModel` creation helper,
V1/V2 interfaces and migration, common authoring actions, activity model parsers,
and existing export fixtures.

The MCQ model requires a stem, at least one choice, and exactly one authored part,
matching the editor/delivery use of `parts[0]`. It permits a one-choice editing
state and empty text, content arrays, hints, targeted mappings, and variable data.
Part responses require IDs, rule strings, numeric scores, and feedback. Scoring
strategies, grading approaches, nullable point overrides, transformations,
activity triggers, optional explanation, and targeted-feedback tuples are checked.
Shuffle and variable-substitution transformations have separate field requirements.
Trigger reference fields are typed according to the trigger kind.

V2 has `authoring.version: 2` and requires a targeted-mapping array. Unversioned V1
may omit it. The schema does not mutate or migrate either version. It accepts the
legacy `{model: [...], selection: ...}` rich-text envelopes found in older exports;
the wrapped array is recursively validated by the same shared definition as
modern arrays. IDs for the activity's structured components are nonempty strings;
IDs on rich-text elements retain the shared Basic Page compatibility rules.

MCQ model, authoring, component wrappers, responses, parts, transformations,
variables, triggers, and the MCQ export envelope reject unknown fields. Typos such
as `explanaton` are validation errors even though explanation itself is optional.
The inherited `ActivityModelSchema` metadata fields are shared through
`activity-components.schema.json#/$defs/model-metadata`. Its root `content` and
`activityType` fields remain opaque as declared by the client's `any` types; they
do not select the validator. The generic Activity envelope's
listed fields remain allowed; new extensions need explicit schema declarations.
The generic envelope's dynamic metadata payloads (such as objectives keyed by
part ID) retain their existing contract.

Choice `frequency` is an explicit choice-only extension. Its other fields reference
the shared content component's property schemas, which avoids the Draft 7 problem
of extending an already closed object through `allOf`. Legacy rich-text envelopes
explicitly support optional nullable `selection`, with typed anchor/focus points;
unknown selection/point fields are rejected. Shared Basic Page rich-text element
extension compatibility remains unchanged. This closes MCQ structure without
silently changing other consumers of the shared element schema.

This remains structural validity rather than a publish-readiness or
grading-correctness guarantee. No domain/reference/rule checks were added.

The prototype passes all seven checked-in MCQ export fixtures, both at the model
and export-envelope level. This is fixture compatibility evidence, not a production
corpus audit or a guarantee about every historical/custom MCQ representation.

## Runtime behavior

JSV remains encapsulated in `Oli.Utils.JSONValidation`. Callers select a named
schema and receive an opaque validator. The existing cache stores the complete
built graph per schema-registry revision. Repeated validation does not read JSON
schema files, resolve references over HTTP, or rebuild validators. Changes to
registered schema files invalidate the referenced-schema cache revision.

JSV's builder deduplicates validators by reference key within the built root.
All five MCQ rich-content locations therefore use the same compiled content
validators within that MCQ graph. Page and MCQ roots are independently cached;
source-schema reuse does not mean every separately built root shares one global
compiled node table. Each submitted content location must still be inspected.

The shared content type dispatcher uses a balanced conditional tree instead of
checking every unrelated element branch. This evaluates logarithmically many
schema branches and avoids recursively evaluating irrelevant descendants. JSV
still scans candidate values for enum membership, so this is not a claim of
logarithmic total dispatch work. It preserves the existing accepted Basic Page content shapes.

## Dispatcher maintenance

The balanced shared dispatcher is generated from annotated concrete element
schemas, not maintained by editing its branches. See
`guides/ingest/basic-page-json-contract.md` for the maintenance procedure.

```bash
mix oli.generate_content_dispatcher
mix oli.generate_content_dispatcher --check
```

The generator and consistency check run only during development/tests. Consumers
continue using the checked-in JSON and cached validators; no runtime generation
or extra schema reads are introduced. ExUnit detects stale output, unclassified
concrete elements, ambiguous variants, and context enums referring to unknown types.

## Reproducible measurements

```bash
mix oli.benchmark_mcq_schema test/support/fixtures/multiple_choice_model.json --iterations 1000
mix oli.benchmark_mcq_schema path/to/exported_or_authored_mcq.json --iterations 1000
```

The benchmark starts no application background jobs and accesses no database.
It measures a deliberately cold schema build separately, then the public cached
API for valid input and invalid input with an appended malformed stem element.
Warm timings include schema selection, cache lookup, validation, and error
normalization on failures. JSON decoding is outside the timed region.

Local measurements on 2026-11-15, Elixir 1.19.2 / OTP 28, 1,000 iterations:

| Input | Encoded bytes | Flat dispatch, valid mean | Balanced dispatch, valid mean | Balanced dispatch, invalid mean |
| --- | ---: | ---: | ---: | ---: |
| Factory model with explanation | 1,742 | 258 microseconds | 75 microseconds | 165 microseconds |
| Synthetic model with all 34 Basic Page factory examples in every content slot | 57,152 | 21.8 milliseconds | 5.67 milliseconds | 5.63 milliseconds |

After adding strict MCQ field closure and reproducible dispatcher generation, a
1,000-iteration rerun measured 79 microseconds valid / 195 microseconds invalid
for the factory model, and 5.71 / 5.86 milliseconds for the synthetic model.
Generation remains outside the validation path; these additional field checks
preserve the measured benefit of cached shared-content validation.

Observed cold builds ranged from about 4.5 to 32 milliseconds across these runs.
Both inputs use the same schema graph, so cold-build variation is not a
model-size scaling claim. These are local exploratory measurements, not a
production throughput benchmark or a comparison with ExJsonSchema. They show
why build caching and efficient shared-content dispatch both matter.

To reproduce the synthetic input, replace stem, both choices, all three hints,
both response feedback arrays, and explanation content in the factory fixture
with the array of values from `test/support/fixtures/basic_page_elements.json`.
Do not interpret the repeated IDs in that synthetic input as valid domain
references; this benchmark measures structural validation only.

## Verification and remaining semantic work

`assets/test/multiple_choice/mc_schema_test.ts` checks the actual factory against
the schema and shared fixture, targeted feedback, and malformed explanation
content using AJV. `test/oli/utils/multiple_choice_schema_test.exs` checks the same
fixture through the generic server adapter, all 34 page examples in all five
content slots, malformed content recursively in modern and legacy representations,
legacy exports, strict unknown-field rejection, metadata, scoring, transformations,
triggers, and error locations.
The existing Basic Page tests run against the optimized shared dispatcher.

Standard JSON Schema cannot generally compare an arbitrary choice-ID list with
IDs elsewhere in the model, enforce uniqueness by an object's ID property, or
parse/evaluate Torus response rules and variable expressions. A production
correctness validator still needs domain checks for:

- Unique choice, response, hint, and part IDs in the relevant scopes.
- Targeted mappings, transformation paths, and trigger references pointing to
  existing choices, responses, parts, and hint ordinals.
- Valid rule grammar and variable expressions, a usable correct response and
  catch-all ordering, and consistency of scores/out-of values.
- Media/resource references, publish readiness, and compatibility of stored content.

Those checks should complement this shared structural layer, rather than duplicate
its recursive rich-content validation. Wider enforcement should follow a production
compatibility audit and an explicit rollout decision.
