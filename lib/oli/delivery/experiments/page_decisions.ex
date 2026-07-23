defmodule Oli.Delivery.Experiments.PageDecisions do
  @moduledoc """
  Prepares native experiment-backed alternatives decisions for delivery page views.
  """

  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver, as: Resolver
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

    with true <- has_alternatives?(content),
         {:ok, groups} <- Oli.Resources.alternatives_groups(section.slug, Resolver) do
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

  defp has_alternatives?(%{"model" => _model} = content) do
    content
    |> PageContent.flat_filter(&(Map.get(&1, "type") == "alternatives"))
    |> Enum.any?()
  end

  defp has_alternatives?(_content), do: false

  defp attempt_content(page_context) do
    this_attempt = page_context.resource_attempts |> hd

    if Enum.any?(this_attempt.errors, fn e ->
         e == "Selection failed to fulfill: no values provided for expression"
       end) and page_context.is_student do
      %{"model" => []}
    else
      this_attempt.content
    end
  end
end
