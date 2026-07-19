defmodule Oli.Authoring.ProjectRepair.SharedActivityReference do
  @moduledoc """
  Groups Basic pages that reference the same activity resource.

  `repairable?` is false when the resource cannot be resolved from the selected
  project's authoring publication. Keeping that distinction in the domain result
  prevents the LiveView from having to repeat safety-sensitive resolver logic.
  """

  alias Oli.Authoring.ProjectRepair.PageSummary

  @typedoc "A shared activity id and the Basic pages that reference it."
  @type t :: %__MODULE__{
          activity_resource_id: pos_integer(),
          pages: [PageSummary.t()],
          page_count: non_neg_integer(),
          repairable?: boolean()
        }

  @enforce_keys [:activity_resource_id, :pages, :repairable?]
  defstruct [:activity_resource_id, :pages, :repairable?, page_count: 0]
end
