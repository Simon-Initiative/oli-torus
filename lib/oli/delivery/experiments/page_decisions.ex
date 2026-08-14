defmodule Oli.Delivery.Experiments.PageDecisions do
  @moduledoc """
  Prepares native experiment-backed alternatives decisions for delivery page views.
  """

  alias Oli.Delivery.Sections
  alias Oli.Experiments
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.PageContent
  alias Oli.Resources.Alternatives.AlternativesStrategyContext

  @empty %{
    alternative_groups_by_id: %{},
    experiment_decisions: %{},
    experiment_attributions: []
  }

  def prepare(_section, %{resource_attempts: []}), do: @empty

  def prepare(_section, %{
        alternative_groups_by_id: by_id,
        experiment_decisions: decisions,
        experiment_attributions: attributions
      })
      when is_map(by_id) and is_map(decisions) and is_list(attributions) do
    %{
      alternative_groups_by_id: by_id,
      experiment_decisions: decisions,
      experiment_attributions: attributions
    }
  end

  def prepare(section, page_context) do
    content = attempt_content(page_context)
    prepare_content(section, page_context.page, page_context.user, content)
  end

  @doc """
  Prepares delivery decisions from server-resolved page content before a new attempt
  hierarchy is created.

  This entry point lets activity realization use the same persisted experiment choice
  as rendering and completion.
  """
  def prepare_content(section, page, user, content) do
    placements = PageContent.alternatives_placements(content)
    prepare_placements(section, page, user, placements)
  end

  @doc """
  Prepares delivery decisions from Alternatives placements already extracted from page content.
  """
  def prepare_placements(
        %Sections.Section{id: section_id, base_project_id: nil} = _section,
        page,
        user,
        placements
      )
      when is_integer(section_id) do
    section_id
    |> then(&Sections.get_section_by(id: &1))
    |> prepare_placements(page, user, placements)
  end

  def prepare_placements(section, page, user, placements) when is_list(placements) do
    alternatives_resource_ids = alternatives_resource_ids(placements)

    case alternatives_resource_ids do
      [] ->
        @empty

      _ids ->
        case Experiments.relevant_active_experiment?(section.id, section.base_project_id) do
          true ->
            prepare_active(section, page, user, placements, alternatives_resource_ids)

          false ->
            inert_decisions(section.slug, placements, alternatives_resource_ids)
        end
    end
  end

  defp prepare_active(section, page, user, placements, alternatives_resource_ids) do
    groups = alternatives_groups(section.slug, alternatives_resource_ids)
    by_id = Map.new(groups, fn group -> {group.id, group} end)

    {project_slug, enrollment} =
      Sections.get_alternatives_render_context(section.id, user.id)

    context = %AlternativesStrategyContext{
      enrollment_id: enrollment && enrollment.id,
      user: user,
      institution_id: section.institution_id,
      project_id: section.base_project_id,
      section_id: section.id,
      section_slug: section.slug,
      mode: :delivery,
      project_slug: project_slug,
      page_resource_id: page.resource_id,
      page_revision_id: page.id,
      alternative_groups_by_id: by_id
    }

    {decisions, attributions} =
      Oli.Resources.Alternatives.prepare_classified_delivery_decisions(context, placements)

    %{
      alternative_groups_by_id: by_id,
      experiment_decisions: decisions,
      experiment_attributions: attributions
    }
  end

  defp inert_decisions(section_slug, all_placements, alternatives_resource_ids) do
    groups = alternatives_groups(section_slug, alternatives_resource_ids)
    by_id = Map.new(groups, fn group -> {group.id, group} end)

    {decisions, []} =
      Oli.Resources.Alternatives.fallback_classified_delivery_decisions(all_placements)

    %{@empty | alternative_groups_by_id: by_id, experiment_decisions: decisions}
  end

  defp alternatives_resource_ids(placements) do
    placements
    |> Enum.map(&Map.get(&1, "alternatives_id"))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp alternatives_groups(section_slug, resource_ids) do
    section_slug
    |> DeliveryResolver.from_resource_id(resource_ids)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn revision ->
      %{
        id: revision.resource_id,
        revision_id: revision.id,
        title: revision.title,
        options: Map.get(revision.content || %{}, "options", []),
        strategy: Map.get(revision.content || %{}, "strategy", "user_section_preference")
      }
    end)
  end

  defp attempt_content(%{resource_attempts: [this_attempt | _]} = page_context) do
    if Enum.any?(this_attempt.errors, fn e ->
         e == "Selection failed to fulfill: no values provided for expression"
       end) and page_context.is_student do
      %{"model" => []}
    else
      this_attempt.content
    end
  end

  defp attempt_content(_page_context), do: %{"model" => []}
end
