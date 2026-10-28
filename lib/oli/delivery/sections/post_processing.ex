defmodule Oli.Delivery.Sections.PostProcessing do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType

  @type options :: [option]
  @type option :: :all | :discussions | :explorations | :deliberate_practice | :related_activities

  @page_type_id ResourceType.id_for_page()
  @all_actions [:discussions, :explorations, :deliberate_practice, :related_activities]

  @spec apply(Section.t(), options() | option()) :: Section.t()
  def apply(section, actions \\ []) do
    case apply_result(section, actions) do
      {:ok, section} -> section
      {:error, reason} -> raise "Section post-processing failed: #{inspect(reason)}"
    end
  end

  @doc "Runs post-processing with an explicit error contract for lifecycle orchestration."
  @spec apply_result(Section.t(), options() | option()) :: {:ok, Section.t()} | {:error, term()}
  def apply_result(section, actions \\ []) do
    actions =
      case actions do
        :all -> @all_actions
        action when action in @all_actions -> List.wrap(action)
        actions -> actions
      end

    {changes, project_related_activities?} =
      Enum.reduce(Enum.uniq(actions), {%{}, false}, fn action, {acc, project?} ->
        case action do
          :discussions ->
            {Map.put(acc, :contains_discussions, maybe_update_contains_discusssions(section)),
             project?}

          :explorations ->
            {Map.put(acc, :contains_explorations, maybe_update_contains_explorations(section)),
             project?}

          :deliberate_practice ->
            {Map.put(acc, :contains_deliberate_practice, contains_deliberate_practice(section)),
             project?}

          :related_activities ->
            {acc, true}

          _ ->
            {acc, project?}
        end
      end)

    with {:ok, section} <- maybe_project_related_activities(section, project_related_activities?) do
      {:ok, Sections.update_section!(section, changes)}
    end
  end

  # Updates contains_discussions flag if an active discussion is present.
  @spec maybe_update_contains_discusssions(Section.t()) :: boolean()
  defp maybe_update_contains_discusssions(section) do
    from(s in Section,
      join: sr in assoc(s, :section_resources),
      where: s.id == ^section.id,
      where: fragment("?->>'status' = ?", sr.collab_space_config, "enabled"),
      limit: 1,
      select: sr.id
    )
    |> Repo.exists?()
  end

  @spec maybe_update_contains_explorations(Section.t()) :: boolean()
  defp maybe_update_contains_explorations(section) do
    from([rev: rev] in base_query(section), where: rev.purpose == :application)
    |> Repo.exists?()
  end

  @spec contains_deliberate_practice(Section.t()) :: boolean()
  defp contains_deliberate_practice(section) do
    from([rev: rev] in base_query(section), where: rev.purpose == :deliberate_practice)
    |> Repo.exists?()
  end

  defp base_query(section) do
    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section.slug),
      where: rev.deleted == false,
      where: rev.resource_type_id == ^@page_type_id,
      limit: 1,
      select: rev.id
    )
  end

  defp maybe_project_related_activities(section, true),
    do: SectionResourceMigration.project_current(section)

  defp maybe_project_related_activities(section, false), do: {:ok, section}
end
