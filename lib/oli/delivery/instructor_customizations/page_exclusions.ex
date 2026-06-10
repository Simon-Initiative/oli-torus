defmodule Oli.Delivery.InstructorCustomizations.PageExclusions do
  @moduledoc """
  Compact lookup view of all instructor exclusions for one section and page.
  """

  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion

  @enforce_keys [
    :section_id,
    :page_resource_id,
    :excluded_activity_ids,
    :excluded_selection_ids,
    :excluded_bank_candidate_ids_by_selection
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          section_id: integer(),
          page_resource_id: integer(),
          excluded_activity_ids: MapSet.t(integer()),
          excluded_selection_ids: MapSet.t(String.t()),
          excluded_bank_candidate_ids_by_selection: %{String.t() => MapSet.t(integer())}
        }

  def new(section_id, page_resource_id, exclusions \\ [])
      when is_integer(section_id) and is_integer(page_resource_id) and is_list(exclusions) do
    Enum.reduce(exclusions, empty(section_id, page_resource_id), &add_exclusion/2)
  end

  def empty(section_id, page_resource_id) do
    %__MODULE__{
      section_id: section_id,
      page_resource_id: page_resource_id,
      excluded_activity_ids: MapSet.new(),
      excluded_selection_ids: MapSet.new(),
      excluded_bank_candidate_ids_by_selection: %{}
    }
  end

  defp add_exclusion(
         %ActivityExclusion{kind: :embedded_activity, excluded_resource_id: activity_id},
         exclusions
       ) do
    %{
      exclusions
      | excluded_activity_ids: MapSet.put(exclusions.excluded_activity_ids, activity_id)
    }
  end

  defp add_exclusion(
         %ActivityExclusion{kind: :bank_selection, selection_id: selection_id},
         exclusions
       ) do
    %{
      exclusions
      | excluded_selection_ids: MapSet.put(exclusions.excluded_selection_ids, selection_id)
    }
  end

  defp add_exclusion(
         %ActivityExclusion{
           kind: :bank_candidate,
           selection_id: selection_id,
           excluded_resource_id: activity_id
         },
         exclusions
       ) do
    candidates =
      case Map.fetch(exclusions.excluded_bank_candidate_ids_by_selection, selection_id) do
        {:ok, excluded_candidate_ids} ->
          Map.put(
            exclusions.excluded_bank_candidate_ids_by_selection,
            selection_id,
            MapSet.put(excluded_candidate_ids, activity_id)
          )

        :error ->
          Map.put(
            exclusions.excluded_bank_candidate_ids_by_selection,
            selection_id,
            MapSet.new([activity_id])
          )
      end

    %{exclusions | excluded_bank_candidate_ids_by_selection: candidates}
  end
end
