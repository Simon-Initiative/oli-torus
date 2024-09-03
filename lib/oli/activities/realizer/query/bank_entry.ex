defmodule Oli.Activities.Realizer.Query.BankEntry do
  @moduledoc """
  Meta data for each activity bank entry.
  """

  defstruct [
    :resource_id,
    :tags,
    :objectives,
    :activity_type_id
  ]

  @type t() :: %__MODULE__{
          resource_id: integer(),
          tags: list(),
          objectives: list(),
          activity_type_id: integer()
        }

  def from_map(m) do
    objectives =
      Map.values(m.objectives)
      |> List.flatten()
      |> MapSet.new()

    %Oli.Activities.Realizer.Query.BankEntry{
      resource_id: m.resource_id,
      tags: MapSet.new(m.tags),
      objectives: objectives,
      activity_type_id: m.activity_type_id
    }
  end
end
