defmodule Oli.Authoring.LearningObjectives.ProjectClassifier do
  @moduledoc """
  Classifies whether a project follows the supported learning-objective attachment structure.

  A well-formed project attaches only top-level objectives to pages and only sub-objectives
  to activities. Existing classifications are sticky; only projects whose classification is
  `nil` are inspected and updated.
  """

  import Ecto.Query, warn: false

  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @objective_type_id ResourceType.id_for_objective()
  @page_type_id ResourceType.id_for_page()
  @activity_type_id ResourceType.id_for_activity()
  @classified_resource_type_ids [@objective_type_id, @page_type_id, @activity_type_id]

  @doc """
  Returns a project's existing classification, or computes and persists it when currently nil.

  The publication must belong to the project being classified.
  """
  def ensure_classified(
        %Project{id: project_id, lo_well_formed: value},
        %Publication{project_id: project_id}
      )
      when is_boolean(value),
      do: {:ok, value}

  def ensure_classified(
        %Project{id: project_id},
        %Publication{id: publication_id, project_id: project_id}
      ) do
    value = publication_id |> classification_data() |> well_formed?()

    case persist_if_unclassified(project_id, value) do
      :updated -> {:ok, value}
      :already_classified -> current_classification(project_id)
    end
  end

  def ensure_classified(%Project{}, %Publication{}), do: {:error, :not_found}

  @doc """
  Determines whether classification data follows the learning-objective attachment rules.

  References to objectives absent from the current publication make the project malformed,
  because they cannot be verified as valid for either attachment type.
  """
  def well_formed?(rows) do
    objective_rows = Enum.filter(rows, &(&1.resource_type_id == @objective_type_id))

    objective_ids = objective_rows |> Enum.map(& &1.resource_id) |> MapSet.new()

    sub_objective_ids =
      objective_rows
      |> Enum.flat_map(&(&1.children || []))
      |> MapSet.new()
      |> MapSet.intersection(objective_ids)

    top_level_objective_ids = MapSet.difference(objective_ids, sub_objective_ids)

    Enum.all?(rows, fn row ->
      attached_ids = row.objectives |> flatten_objective_ids() |> MapSet.new()

      case row.resource_type_id do
        @page_type_id -> MapSet.subset?(attached_ids, top_level_objective_ids)
        @activity_type_id -> MapSet.subset?(attached_ids, sub_objective_ids)
        _ -> true
      end
    end)
  end

  defp classification_data(publication_id) do
    Repo.all(
      from published_resource in PublishedResource,
        join: revision in Revision,
        on: published_resource.revision_id == revision.id,
        where:
          published_resource.publication_id == ^publication_id and
            revision.deleted == false and
            revision.resource_type_id in ^@classified_resource_type_ids,
        select: map(revision, [:resource_id, :resource_type_id, :children, :objectives])
    )
  end

  defp persist_if_unclassified(project_id, value) do
    {updated_count, _} =
      from(project in Project,
        where: project.id == ^project_id and is_nil(project.lo_well_formed)
      )
      |> Repo.update_all(set: [lo_well_formed: value])

    case updated_count do
      1 -> :updated
      0 -> :already_classified
    end
  end

  defp current_classification(project_id) do
    case Repo.get(Project, project_id) do
      %Project{lo_well_formed: value} when is_boolean(value) -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  defp flatten_objective_ids(nil), do: []

  defp flatten_objective_ids(objectives) when is_map(objectives) do
    objectives |> Map.values() |> Enum.flat_map(&flatten_objective_ids/1)
  end

  defp flatten_objective_ids(objectives) when is_list(objectives) do
    Enum.flat_map(objectives, &flatten_objective_ids/1)
  end

  defp flatten_objective_ids(objective_id) when is_integer(objective_id), do: [objective_id]
  defp flatten_objective_ids(_), do: []
end
