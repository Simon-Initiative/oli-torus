# Basic Page domain validation

`Oli.Validation.validate_page_domain/2` validates decoded **page content** (the
`version`/`model` object), separately from JSON Schema validation. It is opt-in:
existing save, ingest, delivery, and MCP paths do not call it automatically.
Adaptive pages and the contents of referenced activity models are outside its scope.

```elixir
alias Oli.Utils.{JSONValidation, SchemaResolver}
alias Oli.Publishing.AuthoringResolver

# Authorize the caller for this project before creating the resolver.
resolve = fn ids -> {:ok, AuthoringResolver.resource_types(project_slug, ids)} end

with :ok <- JSONValidation.validate(
       SchemaResolver.resolve("page-content-basic.schema.json"), content),
     :ok <- Oli.Validation.validate_page_domain(content, resolve) do
  # Persist or otherwise use the validated content.
end
```

## Checks

- Every object `id` in the content document, including rich content, captions,
  popups, nested groups, triggers, and extension data, must be unique. Integer
  `1` and string `"1"` identify the same logical ID. Resource reference fields
  do not define logical IDs, and repeated references to the same resource are valid.
- Bank selection `count` must be a positive integer.
- Bank logic must parse with the delivery bank's existing
  `Oli.Activities.Realizer.Logic` parser. `conditions: null` is an unrestricted
  bank; an empty logic object is invalid. The parser defines supported fact/operator
  combinations and clause grammar. Tag/objective operands must be resolvable IDs.
  `type` operands must be positive integer **activity registration IDs**, not
  resource IDs; their existence is not checked by this resource resolver.
- References must resolve to the expected resource type:

| Source | Field | Expected type |
| --- | --- | --- |
| Activity placement / sequence | `activity_id` | `activity` |
| Bank logic expression | `tags` / `objectives` values | `tag` / `objective` |
| Report | `activityId` | `activity` |
| Alternatives placement | `alternatives_id` | `alternatives` |
| Learning objectives | `resource_id` | `objective` |
| Objective revisit/practice lists | page IDs | `page` |
| Page link | `idref` | `page` |
| Citation / root bibliography | `bibref` / `bibrefs` | `bibentry` |

Resource IDs are positive signed-64-bit integers or decimal strings of up to 19
characters. Numeric strings normalize before batching; original source paths are
retained. Export identifiers must be rewired to resource IDs before this check.
Local command targets, alternative option values, URLs, and activity registration
IDs are not resource references.

## Collection and resolution

The bounded tree scan collects logical IDs, local issues, and reference occurrences
before any resolution. Each occurrence stores its canonical ID, expected type, and
source path. IDs are deduplicated and sorted for a single resolver call, even when
local checks have already found errors. An empty reference set makes no call.
The returned map is then checked against every occurrence, so a missing resource
is reported at each use and the same ID can have different expected types at
separate uses. No resolver calls occur during traversal or error mapping.

The injected function's contract is:

```elixir
# All requested resource types, resolved within the caller's authorized scope.
fn [10, 20, 30] -> {:ok, %{10 => "activity", 20 => "tag", 30 => "objective"}} end
```

The result is `{:ok, %{positive_integer_id => type_name}}`, where type names are
strings from `Oli.Resources.ResourceType`. Omit missing, deleted, or inaccessible
resources. Return `{:error, reason}` for operational failures. Exceptions and
malformed results also fail closed with a root `resource_resolution_failed` issue;
internal exception messages are not returned. The core has no database dependency
and no cache of request-specific resolution results.

`AuthoringResolver.resource_types/2` is an optional production adapter. It performs
one query selecting only resource IDs and resource type IDs through the project's
working-publication mappings. It excludes deleted and non-project revisions,
ignores newer unmapped revisions, and never loads revision content. Authorization
belongs to the caller. Other adapters can resolve against publication or delivery
snapshots without changing validation.

## Results and boundaries

Returns `:ok` or `{:error, issues}` with the existing JSON-serializable
`Oli.Validation.ActivityDomain.Issue` format: `code`, JSON Pointer `path`, bounded
`message`, and `related_paths` (the original definition for duplicate IDs).
Codes are `duplicate_id`, `invalid_selection_count`, `invalid_selection_logic`,
`invalid_logic_value`, `invalid_resource_id`, `missing_resource`,
`resource_type_mismatch`, `resource_resolution_failed`, `unsupported_page_type`,
`invalid_input_shape`, `invalid_resolver`, and `input_limit_exceeded`.

Issues are deterministic and capped at 100. All references are collected and
resolved even when that cap is reached. Input uses the existing JSON budgets:
4 MiB aggregate string/key bytes, depth 128, and 100,000 nodes. Tree processing
retains one entry per distinct logical ID and per reference occurrence; it never
rescans the document per reference. Map keys and the distinct resource batch are
sorted for stable diagnostics and calls.

The check does not realize a bank, count matching candidates, evaluate student
answers, enforce scoring, validate local command targets, or mutate content. A
resource can change between validation and persistence; callers requiring a
stable snapshot must choose an appropriate transaction/resolver boundary.
