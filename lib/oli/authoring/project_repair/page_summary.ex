defmodule Oli.Authoring.ProjectRepair.PageSummary do
  @moduledoc """
  Identifies one current authoring page without retaining its full content.

  Repair reports cross the domain-to-web boundary and can remain assigned in a
  LiveView process. Keeping only stable identifiers and display metadata here is
  therefore an important part of the repair tool's bounded-memory contract.
  """

  @typedoc "A compact reference to the current unpublished revision of a page."
  @type t :: %__MODULE__{
          resource_id: pos_integer(),
          revision_id: pos_integer(),
          revision_slug: String.t(),
          title: String.t()
        }

  @enforce_keys [:resource_id, :revision_id, :revision_slug, :title]
  defstruct [:resource_id, :revision_id, :revision_slug, :title]
end
