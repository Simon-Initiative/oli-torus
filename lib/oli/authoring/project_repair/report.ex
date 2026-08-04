defmodule Oli.Authoring.ProjectRepair.Report do
  @moduledoc """
  Defines the complete read model returned by project repair analysis.

  A report deliberately contains revision ids and slugs but never page JSON. The
  revision id later participates in stale-plan detection, while the slug lets the
  web layer build an editor URL without introducing an `OliWeb` dependency here.
  """

  alias Oli.Authoring.ProjectRepair.{
    MissingActivityReference,
    SharedActivityReference,
    Summary
  }

  @typedoc "A deterministic, content-free analysis report for one authoring project."
  @type t :: %__MODULE__{
          project_id: pos_integer(),
          project_slug: String.t(),
          scanned_pages_count: non_neg_integer(),
          skipped_adaptive_pages_count: non_neg_integer(),
          missing_activity_references: [MissingActivityReference.t()],
          shared_activity_references: [SharedActivityReference.t()],
          summary: Summary.t()
        }

  @enforce_keys [:project_id, :project_slug]
  defstruct project_id: nil,
            project_slug: nil,
            scanned_pages_count: 0,
            skipped_adaptive_pages_count: 0,
            missing_activity_references: [],
            shared_activity_references: [],
            summary: %Summary{}
end
