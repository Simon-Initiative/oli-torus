defmodule Oli.Resources.Alternatives.DecisionPointStrategy do
  import Ecto.Query, warn: false

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    RecordExposureRequest,
    Scope
  }

  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.PageContent
  alias Oli.Resources.Alternatives.Selection
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Repo

  require Logger

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Resolves delivery-time experiment decisions and records page exposure evidence
  before page rendering begins.
  """
  def prepare_delivery_decisions(
        %AlternativesStrategyContext{
          mode: :delivery,
          alternative_groups_by_id: by_id
        } = context,
        %{"model" => _model} = content
      )
      when is_map(by_id) do
    placements = PageContent.alternatives_placements(content)
    prepare_decisions(context, placements)
  end

  def prepare_delivery_decisions(%AlternativesStrategyContext{}, _content), do: {%{}, []}

  @doc """
  Resolves delivery decisions from placements already classified by page content traversal.

  This avoids repeating classification when the caller also needs the complete placement set
  to resolve Alternatives metadata.
  """
  def prepare_classified_delivery_decisions(
        %AlternativesStrategyContext{
          mode: :delivery,
          alternative_groups_by_id: by_id
        } = context,
        placements
      )
      when is_map(by_id) and is_list(placements) do
    prepare_decisions(context, placements)
  end

  def prepare_classified_delivery_decisions(%AlternativesStrategyContext{}, _placements),
    do: {%{}, []}

  @doc "Builds placement-keyed inert decisions without experiment persistence access."
  def fallback_delivery_decisions(%{"model" => model}) when is_list(model) do
    placements = PageContent.alternatives_placements(%{"model" => model})
    {fallback_decisions(placements, %{}), []}
  end

  def fallback_delivery_decisions(_content), do: {%{}, []}

  @doc "Builds placement-keyed inert decisions from an already classified placement list."
  def fallback_classified_delivery_decisions(placements) when is_list(placements) do
    {fallback_decisions(placements, %{}), []}
  end

  def fallback_classified_delivery_decisions(_placements), do: {%{}, []}

  @doc """
  Uses A/B testing assignment for a delivery decision point and falls back to the
  first option when no active experiment applies.
  """
  def select(
        %AlternativesStrategyContext{
          mode: :delivery,
          alternative_groups_by_id: by_id
        } = context,
        %{
          "children" => children,
          "alternatives_id" => alternatives_id
        } = alternatives_element
      ) do
    decision_point = Map.get(by_id, alternatives_id)

    with nil <- prepared_decision(context, alternatives_element),
         {%Scope{} = scope, decision_point} <- scoped_decision_point(context, decision_point),
         {:ok, %AssignmentDecision{status: :assigned} = decision} <-
           assign_condition(scope, decision_point, context, alternatives_element),
         selections when selections != [] <-
           select_matching_assignment(children, decision_point, decision),
         :ok =
           maybe_record_exposure(
             decision,
             scope,
             decision_point
           ) do
      selections
    else
      {:ok, %AssignmentDecision{status: :no_experiment}} ->
        display_first(children)

      %{status: :assigned, option_id: option_id} when is_binary(option_id) ->
        case select_matching_value(children, option_id) do
          [] -> display_first(children)
          selections -> selections
        end

      %{status: :assigned, condition_code: condition_code} ->
        case select_matching_condition(children, decision_point, condition_code) do
          [] -> display_first(children)
          selections -> selections
        end

      %{status: _status} ->
        display_first(children)

      {:error, error} ->
        Logger.warning("A/B testing assignment fell back to first option: #{inspect(error)}")

        display_first(children)

      [] ->
        display_first(children)

      _ ->
        display_first(children)
    end
  end

  def select(
        %AlternativesStrategyContext{
          mode: :review,
          alternative_groups_by_id: by_id,
          activity_resource_ids: activity_resource_ids
        } = context,
        %{
          "children" => children,
          "alternatives_id" => alternatives_id
        }
      ) do
    decision_point = Map.get(by_id, alternatives_id)

    with [] <- select_attempted_activity_branch(children, activity_resource_ids),
         {%Scope{} = scope, decision_point} <-
           scoped_decision_point(context, decision_point, false),
         {:ok, %AssignmentDecision{status: :assigned} = decision} <-
           assigned_condition(scope, decision_point, context, %{}),
         selections when selections != [] <-
           select_matching_assignment(children, decision_point, decision) do
      selections
    else
      selections when is_list(selections) and selections != [] ->
        selections

      {:ok, %AssignmentDecision{status: :no_experiment}} ->
        []

      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        Logger.warning(
          "A/B testing review assignment could not be resolved: #{error.type}: #{error.message}"
        )

        []

      {:error, error} ->
        Logger.warning(
          "A/B testing review assignment could not be resolved: #{inspect_error(error)}"
        )

        []

      [] ->
        []

      _ ->
        []
    end
  end

  def select(
        %AlternativesStrategyContext{mode: mode},
        %{"children" => children}
      )
      when mode in [:author_preview, :instructor_preview] do
    Enum.map(children, &%Selection{alternative: &1})
  end

  def select(_, %{"children" => children}), do: display_first(children)

  defp assign_condition(%Scope{} = scope, decision_point, context, element) do
    Oli.Experiments.assign_condition(%AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: decision_point.id,
      alternatives_revision_id: decision_point.revision_id,
      decision_point_key: decision_point_key(decision_point.id),
      page_resource_id: context.page_resource_id,
      page_revision_id: context.page_revision_id,
      content_element_id: Map.get(element, "id"),
      available_condition_codes: Enum.map(decision_point.options, &option_condition_code/1)
    })
  end

  defp assigned_condition(%Scope{} = scope, decision_point, context, element) do
    Oli.Experiments.assigned_condition(%AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: decision_point.id,
      alternatives_revision_id: decision_point.revision_id,
      decision_point_key: decision_point_key(decision_point.id),
      page_resource_id: context.page_resource_id,
      page_revision_id: context.page_revision_id,
      content_element_id: Map.get(element, "id"),
      available_condition_codes: Enum.map(decision_point.options, &option_condition_code/1)
    })
  end

  defp maybe_record_exposure(
         %AssignmentDecision{assignment_id: assignment_id},
         %Scope{} = scope,
         decision_point
       ) do
    request = %RecordExposureRequest{
      key:
        "alternatives:#{decision_point.id}:#{decision_point.revision_id}:assignment:#{assignment_id}",
      scope: scope,
      assignment_id: assignment_id,
      content_revision_id: decision_point.revision_id
    }

    case Oli.Experiments.record_exposure(request) do
      {:ok, _receipt} ->
        :ok

      {:error, error} ->
        Logger.warning("A/B testing exposure recording failed: #{inspect(error)}")
        :ok
    end
  end

  defp prepare_decisions(
         %AlternativesStrategyContext{page_resource_id: page_resource_id},
         _elements
       )
       when not is_integer(page_resource_id),
       do: {%{}, []}

  defp prepare_decisions(
         %AlternativesStrategyContext{alternative_groups_by_id: by_id} = context,
         elements
       ) do
    placements =
      Enum.filter(elements, fn
        %{"type" => "alternatives", "id" => _id, "alternatives_id" => alternatives_id} ->
          group = Map.get(by_id, alternatives_id)
          experiment_group?(group)

        _ ->
          false
      end)

    case placements do
      [] ->
        {%{}, []}

      [first | _] ->
        first_group = Map.get(by_id, first["alternatives_id"])

        with {%Scope{} = scope, _group} <- scoped_decision_point(context, first_group),
             requests <- Enum.map(placements, &batch_request(&1, context, scope, by_id)),
             {:ok, assigned} <- Oli.Experiments.assign_page_conditions(requests),
             exposure_requests <- batch_exposure_requests(placements, assigned, scope, by_id),
             {:ok, attributions} <- Oli.Experiments.record_page_exposures(exposure_requests) do
          decisions =
            Enum.reduce(placements, %{}, fn element, decisions ->
              decision = Map.fetch!(assigned, element["id"])
              group = Map.fetch!(by_id, element["alternatives_id"])
              prepared = prepared_assignment(decision, group)
              Map.put(decisions, element["id"], prepared)
            end)

          {decisions, attributions}
        else
          _ -> {%{}, []}
        end
    end
  end

  defp experiment_group?(%{strategy: strategy}),
    do: strategy in ["experiment_controlled", "upgrade_decision_point"]

  defp experiment_group?(_group), do: false

  defp batch_request(element, context, scope, by_id) do
    group = Map.fetch!(by_id, element["alternatives_id"])

    %AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: group.id,
      alternatives_revision_id: group.revision_id,
      decision_point_key: decision_point_key(group.id),
      page_resource_id: context.page_resource_id,
      page_revision_id: context.page_revision_id,
      content_element_id: element["id"],
      available_condition_codes: Enum.map(group.options, &option_condition_code/1)
    }
  end

  defp prepared_assignment(%AssignmentDecision{status: :assigned} = decision, group) do
    %{
      status: :assigned,
      condition_code: decision.condition_code,
      option_id: decision.option_id,
      decision_point_key: decision_point_key(group.id)
    }
  end

  defp prepared_assignment(_decision, _group), do: %{status: :no_experiment}

  defp batch_exposure_requests(placements, assigned, scope, by_id) do
    Enum.flat_map(placements, fn element ->
      group = Map.fetch!(by_id, element["alternatives_id"])

      case Map.fetch!(assigned, element["id"]) do
        %AssignmentDecision{status: :assigned, assignment_id: assignment_id} ->
          [
            %RecordExposureRequest{
              key: "alternatives:#{group.id}:#{group.revision_id}:assignment:#{assignment_id}",
              scope: scope,
              assignment_id: assignment_id,
              content_revision_id: group.revision_id
            }
          ]

        _decision ->
          []
      end
    end)
  end

  defp prepared_decision(
         %AlternativesStrategyContext{experiment_decisions: decisions},
         element
       )
       when is_map(decisions) do
    placement_id = Map.get(element, "id") || Map.get(element, "alternatives_id")
    Map.get(decisions, placement_id)
  end

  defp prepared_decision(%AlternativesStrategyContext{}, _element), do: nil

  defp fallback_decisions(elements, decisions) when is_list(elements) do
    Enum.reduce(elements, decisions, fn
      %{"type" => "alternatives"} = element, acc ->
        id = Map.get(element, "id") || Map.get(element, "alternatives_id")
        Map.put(acc, id, %{status: :no_experiment})

      _element, acc ->
        acc
    end)
  end

  defp scoped_decision_point(context, decision_point, include_publication? \\ true)

  defp scoped_decision_point(_context, nil, _include_publication?),
    do: {:error, :missing_decision_point}

  defp scoped_decision_point(
         %AlternativesStrategyContext{} = context,
         decision_point,
         include_publication?
       ) do
    section = maybe_section(context)
    section_id = context.section_id || (section && section.id)
    project_id = context.project_id || (section && section.base_project_id)

    {
      %Scope{
        institution_id: context.institution_id || (section && section.institution_id),
        project_id: project_id,
        project_slug: context.project_slug,
        publication_id:
          context.publication_id ||
            scoped_publication_id(section_id, decision_point.id, include_publication?),
        section_id: section_id,
        section_slug: context.section_slug,
        user_id: context.user && context.user.id,
        enrollment_id: context.enrollment_id
      },
      decision_point
    }
  end

  defp maybe_section(%AlternativesStrategyContext{
         institution_id: institution_id,
         project_id: project_id,
         section_id: section_id
       })
       when not is_nil(institution_id) and not is_nil(project_id) and not is_nil(section_id),
       do: nil

  defp maybe_section(%AlternativesStrategyContext{
         section_id: section_id,
         section_slug: section_slug
       }),
       do: section(section_id, section_slug)

  defp section(section_id, _section_slug) when not is_nil(section_id),
    do: Repo.get(Section, section_id)

  defp section(_section_id, nil), do: nil

  defp section(_section_id, section_slug),
    do: Oli.Delivery.Sections.get_section_by(slug: section_slug)

  defp publication_id(nil, _alternatives_resource_id), do: nil

  defp publication_id(section_id, alternatives_resource_id) do
    Repo.one(
      from spp in SectionsProjectsPublications,
        join: pr in ProjectResource,
        on: pr.project_id == spp.project_id,
        where:
          spp.section_id == ^section_id and
            pr.resource_id == ^alternatives_resource_id,
        select: spp.publication_id,
        limit: 1
    )
  end

  defp decision_point_key(alternatives_resource_id),
    do: "alternatives:#{alternatives_resource_id}"

  defp scoped_publication_id(section_id, alternatives_resource_id, true),
    do: publication_id(section_id, alternatives_resource_id)

  defp scoped_publication_id(_section_id, _alternatives_resource_id, false), do: nil

  defp select_attempted_activity_branch(_children, []), do: []

  defp select_attempted_activity_branch(children, activity_resource_ids) do
    attempted = MapSet.new(activity_resource_ids)

    case Enum.find(children, fn alternative ->
           alternative
           |> activity_ids()
           |> Enum.any?(&MapSet.member?(attempted, &1))
         end) do
      nil ->
        []

      %{"value" => value} ->
        select_matching_value(children, value)
    end
  end

  defp activity_ids(%{"type" => "activity", "activity_id" => activity_id}), do: [activity_id]

  defp activity_ids(%{"children" => children}) when is_list(children) do
    Enum.flat_map(children, &activity_ids/1)
  end

  defp activity_ids(_element), do: []

  defp select_matching_condition(children, decision_point, condition) do
    case Enum.find(decision_point.options, fn option ->
           option_matches_condition?(option, condition)
         end) do
      nil ->
        []

      %{"id" => option_id} ->
        select_matching_value(children, option_id)
    end
  end

  defp select_matching_assignment(children, _decision_point, %{option_id: option_id})
       when is_binary(option_id),
       do: select_matching_value(children, option_id)

  defp select_matching_assignment(children, decision_point, decision),
    do: select_matching_condition(children, decision_point, decision.condition_code)

  defp select_matching_value(children, value) do
    selections =
      Enum.map(children, fn alt ->
        if alt["value"] == value do
          %Selection{alternative: alt}
        else
          %Selection{alternative: alt, hidden: true}
        end
      end)

    if Enum.any?(selections, &(&1.hidden == false)) do
      selections
    else
      []
    end
  end

  defp option_condition_code(option), do: Map.get(option, "id") || Map.get(option, "name")

  defp option_matches_condition?(option, condition) do
    condition in [Map.get(option, "id"), Map.get(option, "name")]
  end

  defp inspect_error(error) when is_atom(error), do: Atom.to_string(error)
  defp inspect_error(_error), do: "unexpected_error"

  defp display_first(children) do
    case children do
      [] ->
        Logger.error("Alternatives element does not have any alternatives specified")
        []

      [first | rest] ->
        [
          %Selection{alternative: first}
          | Enum.map(rest, fn alt -> %Selection{alternative: alt, hidden: true} end)
        ]
    end
  end
end
