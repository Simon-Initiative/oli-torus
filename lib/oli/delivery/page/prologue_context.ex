defmodule Oli.Delivery.Page.PrologueContext do
  @moduledoc """
  Defines the context required to render the prologue page in delivery mode.
  """

  defstruct [
    :page,
    :resource_attempts,
    :historical_attempts,
    :effective_settings
  ]

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections.Section

  @doc """
  Creates the page context required to render a page for visiting a current or new
  attempt.
  """
  def create_for_visit(
        %Section{slug: section_slug, id: section_id},
        page_slug,
        user
      ) do
    # resolve the page revision per section
    page_revision = DeliveryResolver.from_revision_slug(section_slug, page_slug)
    Core.track_access(page_revision.resource_id, section_id, user.id)

    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(page_revision, section_id, user.id)

    attempts =
      case Core.get_resource_attempt_history(
             page_revision.resource_id,
             section_slug,
             user.id
           ) do
        {_access, attempts} -> attempts
        nil -> []
      end

    graded_attempts = Enum.filter(attempts, fn a -> a.revision.graded == true end)

    %__MODULE__{
      page: page_revision,
      resource_attempts: graded_attempts,
      historical_attempts: retrieve_historical_attempts(graded_attempts),
      effective_settings: effective_settings
    }
  end

  # For the given resource attempt, retrieve all historical activity attempt records,
  # assembling them into a map of activity_id to a list of the activity attempts, including
  # the latest attempt

  defp retrieve_historical_attempts([]), do: %{}

  defp retrieve_historical_attempts(resource_attempts) do
    Core.get_all_activity_attempts(hd(resource_attempts).id)
    |> Enum.sort(fn a1, a2 -> a1.attempt_number < a2.attempt_number end)
    |> Enum.reduce(%{}, fn a, m ->
      appended = Map.get(m, a.resource_id, []) ++ [a]
      Map.put(m, a.resource_id, appended)
    end)
  end
end
