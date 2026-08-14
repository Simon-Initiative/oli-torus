defmodule Oli.Experiments.Queries do
  @moduledoc """
  Shared scoped queries for experiment authoring, delivery, and operational reporting.
  """

  import Ecto.Query

  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}
  alias Oli.Experiments.ExperimentError

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    PolicyState
  }

  alias Oli.Repo

  def scoped_experiment_query(scope, experiment_id) do
    query =
      from(experiment in ExperimentDefinition,
        as: :experiment,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_experiment_id(experiment_id)
    |> maybe_filter_experiment_section(scope.section_id)
  end

  def scoped_project_experiments_query(scope) do
    from(experiment in ExperimentDefinition,
      where: experiment.project_id == ^scope.project_id
    )
  end

  def ensure_analytics_experiment_scope(_scope, nil), do: :ok

  def ensure_analytics_experiment_scope(scope, experiment_id) do
    case Repo.exists?(scoped_experiment_query(scope, experiment_id)) do
      true ->
        :ok

      false ->
        invalid_scope("experiment is outside analytics scope", %{experiment_id: experiment_id})
    end
  end

  def scoped_assignment_query(scope, experiment_id) do
    query =
      from(assignment in Assignment,
        join: experiment in ExperimentDefinition,
        as: :experiment,
        on: experiment.id == assignment.experiment_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_assignment_section(scope.section_id)
    |> maybe_filter_assignment_institution(scope)
  end

  def reward_eligible_assignment_query(scope) do
    from(assignment in Assignment,
      join: experiment in ExperimentDefinition,
      as: :experiment,
      on: experiment.id == assignment.experiment_id,
      join: condition in Condition,
      on: condition.id == assignment.condition_id,
      where:
        experiment.project_id == ^scope.project_id and
          experiment.state == :active and
          exists(participating_section_query(scope.section_id)) and
          assignment.section_id == ^scope.section_id and
          assignment.enrollment_id == ^scope.enrollment_id and
          assignment.user_id == ^scope.user_id,
      select: %{
        assignment: assignment,
        experiment: experiment,
        condition: condition
      },
      distinct: assignment.id
    )
  end

  def maybe_filter_experiment_id(query, nil), do: query

  def maybe_filter_experiment_id(query, experiment_id) do
    where(query, [experiment], experiment.id == ^experiment_id)
  end

  def maybe_filter_joined_experiment_id(query, nil), do: query

  def maybe_filter_joined_experiment_id(query, experiment_id) do
    where(query, [_record, experiment], experiment.id == ^experiment_id)
  end

  def maybe_filter_experiment_section(query, nil), do: query

  def maybe_filter_experiment_section(query, section_id) do
    where(query, [experiment: _experiment], exists(participating_section_query(section_id)))
  end

  def maybe_filter_joined_experiment_section(query, nil), do: query

  def maybe_filter_joined_experiment_section(query, section_id) do
    where(query, [experiment: _experiment], exists(participating_section_query(section_id)))
  end

  def participating_section_query(section_id) do
    from(experiment_section in ExperimentSection,
      join: section in Section,
      on: section.id == experiment_section.section_id,
      join: spp in SectionsProjectsPublications,
      on:
        spp.section_id == section.id and
          spp.project_id == parent_as(:experiment).project_id,
      where:
        experiment_section.experiment_id == parent_as(:experiment).id and
          experiment_section.section_id == ^section_id and
          section.status == :active,
      select: 1
    )
  end

  def maybe_filter_assignment_section(query, nil), do: query

  def maybe_filter_assignment_section(query, section_id) do
    where(query, [assignment, _experiment], assignment.section_id == ^section_id)
  end

  def maybe_filter_assignment_institution(query, %{institution_id: nil}), do: query

  def maybe_filter_assignment_institution(query, %{section_id: section_id})
      when not is_nil(section_id), do: query

  def maybe_filter_assignment_institution(query, %{institution_id: institution_id}) do
    where(
      query,
      [assignment, _experiment],
      fragment(
        "EXISTS (SELECT 1 FROM sections s WHERE s.id = ? AND s.institution_id = ?)",
        assignment.section_id,
        ^institution_id
      )
    )
  end

  def maybe_filter_section_institution(query, nil), do: query

  def maybe_filter_section_institution(query, institution_id) do
    where(
      query,
      [section],
      is_nil(section.institution_id) or section.institution_id == ^institution_id
    )
  end

  def runtime_event_count(scope, experiment_id, event_group) do
    scope
    |> scoped_assignment_query(experiment_id)
    |> where(
      [assignment, _experiment],
      fragment("? \\? ?", assignment.runtime_event_state, ^event_group)
    )
    |> Repo.aggregate(:count, :id)
  end

  def scoped_policy_state_query(scope, experiment_id) do
    query =
      from(policy_state in PolicyState,
        join: experiment in ExperimentDefinition,
        as: :experiment,
        on: experiment.id == policy_state.experiment_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_joined_experiment_section(scope.section_id)
  end

  defp invalid_scope(message, details) do
    {:error, %ExperimentError{type: :invalid_scope, message: message, details: details}}
  end
end
