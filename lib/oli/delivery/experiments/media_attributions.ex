defmodule Oli.Delivery.Experiments.MediaAttributions do
  @moduledoc """
  Builds experiment attribution payloads for media xAPI host statements.
  """

  import Ecto.Query, warn: false

  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    Scope
  }

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    ExperimentDefinition
  }

  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.PageContent

  @doc """
  Builds media attributions when the caller already has the page content, as it does for
  attempt-based media events.

  The content is inspected first so events outside alternatives do not query experiment
  assignments. When matching branches exist, assignment filtering is performed in PostgreSQL.
  """
  def for_media_event(%Context{} = context, page_content, content_element_id)
      when is_binary(content_element_id) do
    matching_branches = matching_alternatives_branches(page_content, content_element_id)

    case matching_branches do
      [] ->
        []

      _ ->
        assignments = context |> assignment_query(matching_branches) |> Repo.all()

        media_attributions(assignments, context)
    end
  end

  def for_media_event(_context, _page_content, _content_element_id), do: []

  @doc """
  Builds media attributions for resource-only events using the deployed page revision.

  These events do not carry attempt content. The revision lookup is guarded by the existence of a
  learner assignment so page content is not returned for learners who cannot have experiment
  attribution. Assignment rows are loaded only after the content element is matched to an
  alternatives branch.
  """
  def for_media_event_from_revision(%Context{} = context, revision_id, content_element_id)
      when is_integer(revision_id) and is_binary(content_element_id) do
    page_content = page_content_for_assigned_learner(context, revision_id)
    matching_branches = matching_alternatives_branches(page_content, content_element_id)

    case matching_branches do
      [] ->
        []

      matching_branches ->
        context
        |> assignment_query(matching_branches)
        |> Repo.all()
        |> media_attributions(context)
    end
  end

  def for_media_event_from_revision(_context, _revision_id, _content_element_id), do: []

  # Combines the assignment-existence check and revision lookup into one query. PostgreSQL returns
  # no revision row when the learner has no assignments, avoiding transfer and decoding of page
  # content that cannot produce attribution.
  defp page_content_for_assigned_learner(%Context{} = context, revision_id) do
    assignments_exist =
      from(assignment in Assignment,
        join: experiment in ExperimentDefinition,
        on: experiment.id == assignment.experiment_id,
        where:
          experiment.project_id == ^context.project_id and
            assignment.section_id == ^context.section_id and
            assignment.user_id == ^context.user_id,
        select: 1
      )

    from(revision in Oli.Resources.Revision,
      where: revision.id == ^revision_id,
      where: exists(subquery(assignments_exist)),
      select: revision.content
    )
    |> Repo.one()
  end

  # Restricts assignment loading to the alternatives-resource/option pairs containing the media
  # element. The dynamic predicate remains parameterized by Ecto and supports legacy data where the
  # branch value matches the condition code instead of option_id.
  defp assignment_query(%Context{} = context, matching_branches) do
    branch_filter =
      Enum.reduce(matching_branches, dynamic(false), fn branch, branch_filter ->
        alternatives_resource_id = branch.alternatives_resource_id
        option_id = branch.option_id

        dynamic(
          [experiment: experiment, condition: condition],
          ^branch_filter or
            (experiment.alternatives_resource_id == ^alternatives_resource_id and
               (condition.option_id == ^option_id or condition.condition_code == ^option_id))
        )
      end)

    from(assignment in Assignment,
      as: :assignment,
      join: experiment in ExperimentDefinition,
      as: :experiment,
      on: experiment.id == assignment.experiment_id,
      join: condition in Condition,
      as: :condition,
      on: condition.id == assignment.condition_id,
      join: section in Oli.Delivery.Sections.Section,
      as: :section,
      on: section.id == assignment.section_id,
      where:
        experiment.project_id == ^context.project_id and
          assignment.section_id == ^context.section_id and
          assignment.user_id == ^context.user_id,
      where: ^branch_filter,
      preload: [experiment: experiment],
      select: %{
        assignment: assignment,
        experiment: experiment,
        condition: condition,
        section_slug: section.slug
      },
      distinct: assignment.id
    )
  end

  defp media_attributions([], _context), do: []

  defp media_attributions(assignments, context) do
    section_slug = assignments |> hd() |> Map.fetch!(:section_slug)

    resource_ids =
      assignments
      |> Enum.map(& &1.experiment.alternatives_resource_id)
      |> Enum.uniq()

    revisions_by_resource =
      section_slug
      |> DeliveryResolver.from_resource_id(resource_ids)
      |> Enum.reject(&is_nil/1)
      |> Map.new(&{&1.resource_id, &1})

    Enum.flat_map(assignments, &media_attribution(&1, context, revisions_by_resource))
  end

  defp media_attribution(
         %{
           assignment: %Assignment{} = assignment,
           experiment: %ExperimentDefinition{} = experiment,
           condition: %Condition{} = condition
         },
         %Context{} = context,
         revisions_by_resource
       ) do
    revision = Map.get(revisions_by_resource, experiment.alternatives_resource_id)

    decision = %AssignmentDecision{
      status: :assigned,
      experiment_id: assignment.experiment_id,
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      assignment_id: assignment.id,
      reused?: true
    }

    request = %AssignConditionRequest{
      scope: scope(context, assignment),
      alternatives_resource_id: experiment.alternatives_resource_id,
      alternatives_revision_id: revision && revision.id,
      available_condition_codes: [condition.condition_code]
    }

    decision
    |> Attributions.assignment_attribution(request, assignment: assignment)
    |> List.wrap()
    |> Attributions.attributions_for_media_event()
  end

  defp matching_alternatives_branches(%{"model" => _model} = page_content, content_element_id) do
    page_content
    |> PageContent.flat_filter(&(Map.get(&1, "type") == "alternatives"))
    |> Enum.flat_map(fn alternatives ->
      alternatives
      |> Map.get("children", [])
      |> Enum.filter(&branch_contains_content_element?(&1, content_element_id))
      |> Enum.map(fn branch ->
        %{
          alternatives_resource_id: Map.get(alternatives, "alternatives_id"),
          option_id: Map.get(branch, "value")
        }
      end)
    end)
    |> Enum.reject(fn branch ->
      is_nil(branch.alternatives_resource_id) or is_nil(branch.option_id)
    end)
  end

  defp matching_alternatives_branches(_page_content, _content_element_id), do: []

  defp branch_contains_content_element?(%{"children" => children}, content_element_id) do
    %{"model" => children}
    |> PageContent.flat_filter(&content_element?(&1, content_element_id))
    |> Enum.any?()
  end

  defp branch_contains_content_element?(_branch, _content_element_id), do: false

  defp content_element?(%{} = element, content_element_id) do
    Enum.any?(["id", "guid", "content_element_id"], fn key ->
      Map.get(element, key) == content_element_id
    end)
  end

  defp content_element?(_element, _content_element_id), do: false

  defp scope(%Context{} = context, %Assignment{} = assignment) do
    %Scope{
      project_id: context.project_id,
      publication_id: context.publication_id,
      section_id: context.section_id,
      user_id: context.user_id,
      enrollment_id: assignment.enrollment_id
    }
  end
end
