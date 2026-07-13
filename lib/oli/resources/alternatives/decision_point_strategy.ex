defmodule Oli.Resources.Alternatives.DecisionPointStrategy do
  import Ecto.Query, warn: false

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    RecordExposureRequest,
    Scope
  }

  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.Selection
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Repo

  require Logger

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

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
        }
      ) do
    decision_point = Map.get(by_id, alternatives_id)

    with {%Scope{} = scope, decision_point} <- scoped_decision_point(context, decision_point),
         {:ok, %AssignmentDecision{status: :assigned} = decision} <-
           assign_condition(scope, decision_point),
         selections when selections != [] <-
           select_matching_condition(children, decision_point, decision.condition_code),
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
           assigned_condition(scope, decision_point),
         selections when selections != [] <-
           select_matching_condition(children, decision_point, decision.condition_code) do
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

  def select(_, %{"children" => children}), do: display_first(children)

  defp assign_condition(%Scope{} = scope, decision_point) do
    Oli.Experiments.assign_condition(%AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: decision_point.id,
      alternatives_revision_id: decision_point.revision_id,
      decision_point_key: decision_point_key(decision_point.id),
      available_condition_codes: Enum.map(decision_point.options, &option_condition_code/1)
    })
  end

  defp assigned_condition(%Scope{} = scope, decision_point) do
    Oli.Experiments.assigned_condition(%AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: decision_point.id,
      alternatives_revision_id: decision_point.revision_id,
      decision_point_key: decision_point_key(decision_point.id),
      available_condition_codes: Enum.map(decision_point.options, &option_condition_code/1)
    })
  end

  defp maybe_record_exposure(
         %AssignmentDecision{assignment_id: assignment_id},
         %Scope{} = scope,
         decision_point
       ) do
    case Oli.Experiments.record_exposure(%RecordExposureRequest{
           scope: scope,
           assignment_id: assignment_id,
           content_revision_id: decision_point.revision_id,
           idempotency_key:
             "alternatives:#{decision_point.id}:#{decision_point.revision_id}:assignment:#{assignment_id}"
         }) do
      {:ok, _receipt} ->
        :ok

      {:error, error} ->
        Logger.warning("A/B testing exposure recording failed: #{inspect(error)}")
        :ok
    end
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
