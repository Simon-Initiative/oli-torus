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
  effective-default calculation. Each imported row validates its values, locks its
  current mapping, and creates a successor revision only when those values differ.
- Export selects compact fields and part metadata in cursor batches of 100. Import
  consumes CSV rows incrementally and loads full revision content only one changed
  resource at a time to copy it faithfully into its successor.
- `lib/oli_web/live/workspaces/course_author/learning_model_parameters_live.ex` provides
  the upload UI; a controller streams the download over HTTP.
- `test/oli/learning_model/parameter_csv_test.exs` and
  `test/oli_web/learning_model_parameters_test.exs` cover transfer behavior and access.
