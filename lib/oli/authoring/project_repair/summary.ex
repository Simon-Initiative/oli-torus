defmodule Oli.Authoring.ProjectRepair.Summary do
  @moduledoc """
  Stores the bounded aggregate counts rendered by the project repair preview.

  Counts live in a dedicated struct so callers do not need to recalculate subtly
  different page and resource cardinalities from issue lists. In particular,
  repairable shared pages are counted separately from groups whose shared activity
  is missing and therefore must remain report-only.
  """

  @typedoc "Aggregate counts for one project repair analysis."
  @type t :: %__MODULE__{
          scanned_pages_count: non_neg_integer(),
          skipped_adaptive_pages_count: non_neg_integer(),
          missing_activity_reference_count: non_neg_integer(),
          missing_activity_affected_page_count: non_neg_integer(),
          repairable_shared_activity_resource_count: non_neg_integer(),
          repairable_shared_activity_affected_page_count: non_neg_integer(),
          non_repairable_shared_missing_activity_resource_count: non_neg_integer()
        }

  defstruct scanned_pages_count: 0,
            skipped_adaptive_pages_count: 0,
            missing_activity_reference_count: 0,
            missing_activity_affected_page_count: 0,
            repairable_shared_activity_resource_count: 0,
            repairable_shared_activity_affected_page_count: 0,
            non_repairable_shared_missing_activity_resource_count: 0
end
