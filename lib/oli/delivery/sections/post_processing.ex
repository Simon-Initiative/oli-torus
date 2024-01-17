defmodule Oli.Delivery.Sections.PostProcessing do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType

  @type options :: [option]
  @type option :: :all | :discussions | :explorations | :deliberate_practice

  @page_type_id ResourceType.get_id_by_type("page")

  @spec apply(Section.t(), options()) :: Section.t()
  def apply(section, actions \\ []) do
    all = [:discussions, :explorations, :deliberate_practice]
    actions = if actions == :all, do: all, else: actions

    result =
      Enum.reduce(Enum.uniq(actions), %{}, fn action, acc ->
        case action do
          :discussions ->
            Map.put(acc, :contains_discussions, maybe_update_contains_discusssions(section))

          :explorations ->
            Map.put(acc, :contains_explorations, maybe_update_contains_explorations(section))

          :deliberate_practice ->
            Map.put(acc, :deliberate_practice, contains_deliberate_practice(section))

          _ ->
            acc
        end
      end)

    Sections.update_section!(section, result)
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
end
