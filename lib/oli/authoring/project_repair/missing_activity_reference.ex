defmodule Oli.Authoring.ProjectRepair.MissingActivityReference do
  @moduledoc """
  Describes a Basic page reference whose activity does not resolve in the project.

  Missing references are intentionally report-only. This struct carries enough
  information for an administrator to locate the page while containing no field
  that could be mistaken for a repair instruction.
  """

  alias Oli.Authoring.ProjectRepair.PageSummary

  @typedoc "A missing activity resource id paired with the affected Basic page."
  @type t :: %__MODULE__{
          activity_resource_id: pos_integer(),
          page: PageSummary.t()
        }

  @enforce_keys [:activity_resource_id, :page]
  defstruct [:activity_resource_id, :page]
end
