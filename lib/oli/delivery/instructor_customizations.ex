defmodule Oli.Delivery.InstructorCustomizations do
  @moduledoc """
  Delivery-owned instructor customization state for section page activities.

  Phase-one APIs expose raw page exclusions, a compact page exclusion view,
  and pure predicates. Write and target-validation APIs are added in later
  implementation phases.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Delivery.InstructorCustomizations.PageExclusions
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo

  @doc """
  Returns raw exclusions for trusted internal callers.

  UI and transport callers must perform section authorization before using this
  function. Phase-two write and UI-facing APIs centralize that authorization.
  """
  def get_page_exclusions(section_or_id, page_resource_id) when is_integer(page_resource_id) do
    section_id = section_id(section_or_id)

    from(exclusion in ActivityExclusion,
      where:
        exclusion.section_id == ^section_id and
          exclusion.page_resource_id == ^page_resource_id,
      order_by: exclusion.id
    )
    |> Repo.all()
  end

  @doc """
  Returns a compact page exclusion view for trusted internal callers.

  UI and transport callers must perform section authorization before using this
  function. Delivery lifecycle code can use it after resolving its trusted
  section context.
  """
  def get_page_exclusion_view(section_or_id, page_resource_id)
      when is_integer(page_resource_id) do
    section_id = section_id(section_or_id)

    from(exclusion in ActivityExclusion,
      where:
        exclusion.section_id == ^section_id and
          exclusion.page_resource_id == ^page_resource_id,
      select: struct(exclusion, [:kind, :selection_id, :excluded_resource_id])
    )
    |> Repo.all()
    |> then(&PageExclusions.new(section_id, page_resource_id, &1))
  end

  def activity_enabled?(%PageExclusions{} = exclusions, activity_resource_id) do
    !MapSet.member?(exclusions.excluded_activity_ids, activity_resource_id)
  end

  def bank_selection_enabled?(%PageExclusions{} = exclusions, selection_id) do
    !MapSet.member?(exclusions.excluded_selection_ids, selection_id)
  end

  def bank_candidate_enabled?(%PageExclusions{} = exclusions, selection_id, activity_resource_id) do
    case Map.fetch(exclusions.excluded_bank_candidate_ids_by_selection, selection_id) do
      {:ok, excluded_candidate_ids} ->
        !MapSet.member?(excluded_candidate_ids, activity_resource_id)

      :error ->
        true
    end
  end

  defp section_id(%Section{id: id}), do: id
  defp section_id(id) when is_integer(id), do: id
end
