# Learning model parameter CSV (MER-5864)

Content administrators and system administrators can open **Learning Model Parameters**
from a project's overview Actions section. This is available regardless of the project's
learning-model algorithm.

## Workflow and format

1. Select **Generate and Download** to export the current working publication.
2. Train offline and edit the numeric parameter values.
3. Select the CSV and wait for the automatic file transfer to finish. Click **Upload**
   to apply the values; the page reports changed and unchanged counts.
4. Publish the project through the normal publishing workflow to make the revisions available to sections.

The exact header is `title,resource_id,children_ids,beta_lo,beta_difficulty`.
There is one row per non-deleted objective or activity, including unreferenced resources.
Objective children are a CSV-quoted JSON array, such as `[12,34]`. A child appears once
as its own row even if multiple objectives reference it. Activity children are blank.

Objectives have a numeric `beta_lo` and blank `beta_difficulty`. Activities have blank
`beta_lo` and a CSV-quoted JSON object mapping each part ID to a numeric difficulty,
such as `{"part-1":0.5,"part-2":-1.2}`. Activities without parts use `{}`.
Missing parameters export as their effective default, zero.

Keep resource IDs and activity part IDs intact. Titles and children are informational;
import ignores edits to those columns. CSVs may contain a subset of resources, but each
activity row must contain all of its current parts. The upload limit is 20 MB.
Invalid headers, duplicate or foreign resource IDs, invalid numbers, unknown/missing
parts, and actively edited resources reject the entire upload without partial writes.
An unchanged effective value creates no revision, including missing parameters exported
as zero. Changed resources get new revisions attributed to the importing administrator.
Published mappings remain unchanged.

## Implementation and verification

- `lib/oli/learning_model/parameter_csv.ex` owns authorization, streaming, validation,
  effective defaults, mapping locks, and atomic revision creation. CSV parsing produces
  the existing typed parameter structs; export and no-op detection share the same
  effective-default calculation. Import validates and applies batches of resources,
  creating successor revisions only when parameter values differ.
- `@batch_size 250` near the top of `ParameterCsv` controls import batches and export
  cursor batches. Both handle fewer than 250 rows and a partial final batch.
- Import executes five queries per changed batch: lock mappings in resource order,
  verify the publication is still unpublished, read compact parameter projections,
  `INSERT … SELECT … RETURNING` successor revisions, and bulk-update mappings.
  Unchanged batches skip both writes. All batches share one transaction.
- Revision copying stays inside PostgreSQL. The copied column list derives from
  persisted Ecto schema fields, including embeds. Identity, previous revision ID,
  importing author, parameters, and timestamps are replaced; other fields, including
  content and slug, are copied. Only new IDs return to Elixir for mapping updates.
- Tests cover batch boundaries, rollback across batches, full field preservation,
  and query counts for 2,000 resources (at most 45 queries, including overhead).
- `lib/oli_web/live/workspaces/course_author/learning_model_parameters_live.ex` provides
  the upload UI; a controller streams the download over HTTP.
- `test/oli/learning_model/parameter_csv_test.exs` and
  `test/oli_web/learning_model_parameters_test.exs` cover transfer behavior and access.
