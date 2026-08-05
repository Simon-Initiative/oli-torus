defmodule Oli.Delivery.Experiments.PageDecisions do
  @moduledoc """
  Prepares native experiment-backed alternatives decisions for delivery page views.
  """

  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.PageContent
  alias Oli.Repo

  @empty %{
    alternative_groups_by_id: %{},
    experiment_decisions: %{},
    experiment_attributions: []
  }

  def prepare(section, page_context) do
    content = attempt_content(page_context)
    alternatives_resource_ids = alternatives_resource_ids(content)

    with true <- alternatives_resource_ids != [],
         groups <- alternatives_groups(section.slug, alternatives_resource_ids) do
      by_id = Map.new(groups, fn group -> {group.id, group} end)
      enrollment = Sections.get_enrollment(section.slug, page_context.user.id)

      context = %AlternativesStrategyContext{
        enrollment_id: enrollment && enrollment.id,
        user: page_context.user,
        institution_id: section.institution_id,
        project_id: section.base_project_id,
        section_id: section.id,
        section_slug: section.slug,
        mode: :delivery,
        project_slug: Repo.get(Oli.Authoring.Course.Project, section.base_project_id).slug,
        activity_resource_ids: activity_resource_ids(page_context.activities),
        alternative_groups_by_id: by_id
      }

      {decisions, attributions} =
        Oli.Resources.Alternatives.prepare_delivery_decisions(context, content)

      %{
        alternative_groups_by_id: by_id,
        experiment_decisions: decisions,
        experiment_attributions: attributions
      }
    else
      _ -> @empty
    end
  end

  defp activity_resource_ids(activity_map) when is_map(activity_map), do: Map.keys(activity_map)
  defp activity_resource_ids(_activity_map), do: []

  defp alternatives_resource_ids(%{"model" => _model} = content) do
    content
    |> PageContent.flat_filter(&(Map.get(&1, "type") == "alternatives"))
    |> Enum.map(&Map.get(&1, "alternatives_id"))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp alternatives_resource_ids(_content), do: []

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
