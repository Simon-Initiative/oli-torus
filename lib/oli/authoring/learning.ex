defmodule Oli.Authoring.Learning do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Oli.Repo

  alias Oli.Authoring.Learning.{Objective, ObjectiveFamily, ObjectiveRevision}
  alias Oli.Publishing
  alias Oli.Publishing.ObjectiveMapping

  def get_objective!(id), do: Repo.get!(Objective, id)

  def create_objective(attrs \\ %{}) do
    Multi.new
    |> Multi.insert(:objective_family, new_objective_family())
    |> Multi.merge(fn %{objective_family: objective_family} ->
      Multi.new
      |> Multi.insert(:objective, change_objective(attrs, objective_family)) end)
    |> Multi.merge(fn %{objective: objective} ->
      Multi.new
      |> Multi.insert(:objective_revision, change_objective_revision(attrs, objective)) end)
    |> Multi.merge(fn %{objective: objective, objective_revision: objective_revision} ->
      Multi.new
      |> Multi.insert(:objective_mapping, change_objective_mapping(Publishing.get_unpublished_publication(Map.get(attrs, "project_id")), objective, objective_revision))end)
    |> Repo.transaction
  end

  defp change_objective_mapping(publication_id, objective, objective_revision) do
    %ObjectiveMapping{}
    |> ObjectiveMapping.changeset(%{
      publication_id: publication_id,
      objective_id: objective.id,
      revision_id: objective_revision.id
    })
  end

  def change_objective(attrs, objective_family) do
    project_id = Map.get(attrs, "project_id")
    %Objective{}
    |> Objective.changeset(%{
      family_id: objective_family.id,
      project_id: project_id
    })
  end

  defp change_objective_revision(attrs, objective) do
    title = Map.get(attrs, "title")
    %ObjectiveRevision{}
    |> ObjectiveRevision.changeset(%{
      title: title,
      children: [],
      deleted: false,
      objective_id: objective.id
    })
  end

  def update_objective(%Objective{} = objective, attrs) do
    objective
    |> Objective.changeset(attrs)
    |> Repo.update()
  end

  def delete_objective(%Objective{} = objective) do
    Repo.delete(objective)
  end

  def change_objective(%Objective{} = objective) do
    Objective.changeset(objective, %{})
  end

  def create_objective_revision(attrs \\ %{}) do
    %ObjectiveRevision{}
    |> ObjectiveRevision.changeset(attrs)
    |> Repo.insert()
  end

  defp new_objective_family() do
    %ObjectiveFamily{}
    |> ObjectiveFamily.changeset()
  end
end
