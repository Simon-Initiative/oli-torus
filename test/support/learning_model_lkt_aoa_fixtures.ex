defmodule Oli.LearningModel.LktAoaFixtures do
  @moduledoc false

  import Oli.Factory

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.LearningModel.Parameters
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Resources.ResourceType

  @base_time ~U[2026-08-24 12:00:00Z]

  def lkt_fixture(opts \\ %{}) do
    opts = Map.new(opts)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section_attrs =
      Keyword.merge(
        [base_project: project, learning_model_version: :lkt_aoa],
        Map.get(opts, :section_attrs, [])
      )

    section = insert(:section, section_attrs)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    user = insert(:user)
    page_resource = insert(:resource)

    insert(:section_resource,
      section: section,
      project: project,
      resource_id: page_resource.id
    )

    resource_access =
      insert(:resource_access, section: section, user: user, resource: page_resource)

    part_specs = Map.get(opts, :part_attempts, [%{}])

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        lifecycle_state: :evaluated,
        score: total_score(part_specs),
        out_of: total_out_of(part_specs),
        date_evaluated: latest_date_evaluated(part_specs)
      )

    objective_specs = Map.get(opts, :objectives, [%{}])

    objectives =
      Enum.map(objective_specs, fn spec ->
        resource = insert(:resource)

        revision =
          insert(:revision,
            resource: resource,
            resource_type_id: ResourceType.id_for_objective(),
            learning_model_parameters: learning_objective_parameters(Map.get(spec, :beta_lo, 0.0))
          )

        case Map.get(opts, :publish_objectives?, true) do
          true ->
            insert(:published_resource,
              publication: publication,
              resource: resource,
              revision: revision
            )

          false ->
            :ok
        end

        resource
      end)

    activity_resource = insert(:resource)

    objectives_by_part =
      Map.new(part_specs, fn spec ->
        part_id = Map.get(spec, :part_id, "part-1")

        objective_ids =
          spec
          |> Map.get(:objective_indexes, [0])
          |> Enum.map(fn index -> Enum.at(objectives, index).id end)

        {part_id, objective_ids}
      end)

    part_betas =
      Map.new(part_specs, fn spec ->
        {Map.get(spec, :part_id, "part-1"), Map.get(spec, :beta_part, 0.0)}
      end)

    activity_type =
      Oli.Activities.get_registration_by_slug("oli_short_answer") ||
        insert(:activity_registration, slug: "oli_short_answer")

    activity_revision =
      insert(:revision,
        resource: activity_resource,
        resource_type_id: ResourceType.id_for_activity(),
        activity_type_id: activity_type.id,
        content: activity_content(Map.keys(part_betas)),
        objectives: objectives_by_part,
        learning_model_parameters: activity_parameters(part_betas)
      )

    activity_attempt =
      insert(:activity_attempt,
        resource: activity_resource,
        revision: activity_revision,
        resource_attempt: resource_attempt,
        lifecycle_state: :evaluated,
        score: total_score(part_specs),
        out_of: total_out_of(part_specs),
        date_evaluated: latest_date_evaluated(part_specs)
      )

    part_attempts =
      part_specs
      |> Enum.with_index()
      |> Enum.map(fn {spec, index} ->
        insert(:part_attempt,
          activity_attempt: activity_attempt,
          lifecycle_state: Map.get(spec, :lifecycle_state, :evaluated),
          attempt_guid:
            Map.get(spec, :attempt_guid, "attempt-#{System.unique_integer([:positive])}"),
          part_id: Map.get(spec, :part_id, "part-#{index + 1}"),
          date_evaluated:
            Map.get(spec, :date_evaluated, DateTime.add(@base_time, index, :second)),
          score: Map.get(spec, :score, 1.0),
          out_of: Map.get(spec, :out_of, 1.0),
          response: Map.get(spec, :response)
        )
        |> Map.put(:activity_revision, activity_revision)
      end)

    group = %AttemptGroup{
      context: %Context{
        host_name: "localhost",
        user_id: user.id,
        section_id: section.id,
        project_id: project.id,
        publication_id: publication.id
      },
      resource_attempt: Map.put(resource_attempt, :resource_id, page_resource.id),
      activity_attempts: [activity_attempt],
      part_attempts: part_attempts
    }

    %{section: section, group: group, user: user, objectives: objectives}
  end

  def add_attempt(group, opts) do
    activity_revision = hd(group.part_attempts).activity_revision
    activity_attempt = hd(group.part_attempts).activity_attempt

    part_attempt =
      insert(:part_attempt,
        activity_attempt: activity_attempt,
        lifecycle_state: :evaluated,
        attempt_guid: "attempt-#{System.unique_integer([:positive])}",
        part_id: Keyword.fetch!(opts, :part_id),
        date_evaluated: Keyword.fetch!(opts, :date_evaluated),
        score: Keyword.fetch!(opts, :score),
        out_of: Keyword.get(opts, :out_of, 1.0)
      )
      |> Map.put(:activity_revision, activity_revision)

    %{group | part_attempts: [part_attempt]}
  end

  defp learning_objective_parameters(beta_lo) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :learning_objective,
      payload: %LearningObjectiveParameters{beta_lo: beta_lo}
    }
  end

  defp activity_parameters(part_betas) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :activity,
      payload: %ActivityParameters{
        parts:
          Map.new(part_betas, fn {part_id, beta_part} ->
            {part_id, %PartParameters{beta_difficulty: beta_part}}
          end)
      }
    }
  end

  defp activity_content(part_ids) do
    %{
      "authoring" => %{"parts" => Enum.map(part_ids, &%{"id" => &1})},
      "input" => %{"partId" => hd(part_ids)}
    }
  end

  defp total_score(part_specs) do
    Enum.reduce(part_specs, 0.0, fn spec, total -> total + Map.get(spec, :score, 1.0) end)
  end

  defp total_out_of(part_specs) do
    Enum.reduce(part_specs, 0.0, fn spec, total -> total + Map.get(spec, :out_of, 1.0) end)
  end

  defp latest_date_evaluated(part_specs) do
    part_specs
    |> Enum.with_index()
    |> Enum.map(fn {spec, index} ->
      Map.get(spec, :date_evaluated, DateTime.add(@base_time, index, :second))
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> @base_time
      dates -> Enum.max(dates, DateTime)
    end
  end
end
