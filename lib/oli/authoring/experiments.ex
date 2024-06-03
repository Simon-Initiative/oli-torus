defmodule Oli.Authoring.Experiments do
  @moduledoc """
  This module provides a context around experiments.
  """

  import Ecto.Query, warn: false
  import Oli.Publishing.AuthoringResolver, only: [project_working_publication: 1]

  alias Oli.Authoring.Schemas.Experiment
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType

  @alternatives_type_id ResourceType.id_for_alternatives()
  @experiment_id "upgrade_decision_point"

  @doc """
  Retrieve the revision associated with the experiment for a given project.

  Returns:

  .`%Revision{}` when the resource is retrieved
  . `nil` when the resource is not found
  . Raises if more than one resource.
  """
  @spec get_latest_experiment(String.t()) :: {:ok, %Revision{}} | nil | term()
  def get_latest_experiment(project_slug) do
    project_slug |> base_query() |> Repo.one()
  end

  @doc """
  Returns a boolean when a project has an the experiment.
  """
  @spec has_experiment(String.t()) :: boolean()
  def has_experiment(project_slug) do
    project_slug |> base_query() |> Repo.exists?()
  end

  def base_query(project_slug) do
    from(pr in PublishedResource,
      join: revision in Revision,
      on: revision.id == pr.revision_id,
      where: pr.publication_id in subquery(project_working_publication(project_slug)),
      where: fragment("?->>'strategy' = ?", revision.content, @experiment_id),
      where: revision.resource_type_id == @alternatives_type_id,
      select: revision
    )
  end

  def is_experiment_enabled(project_slug) do
    from(pr in PublishedResource,
      join: revision in Revision,
      on: revision.id == pr.revision_id,
      join: e in Experiment,
      on: e.revision_id == revision.id,
      where: pr.publication_id in subquery(project_working_publication(project_slug)),
      where: fragment("?->>'strategy' = ?", revision.content, @experiment_id),
      where: revision.resource_type_id == @alternatives_type_id,
      select: e.is_enabled
    )
    |> Repo.one!()
  end

  def create_experiment!(params) do
    params
    |> Experiment.new_changeset()
    |> Repo.insert!()
  end

  def update_experiment!(experiment, params) do
    changeset = Experiment.changeset(experiment, params)
    Repo.update!(changeset)
  end

  def get_experiment_state!(nil), do: false

  def get_experiment_state!(%Revision{} = revision) do
    get_experiment_state!(revision.id)
  end

  def get_experiment_state!(revision_id) do
    from(e in Experiment,
      where: e.revision_id == ^revision_id,
      select: e.is_enabled
    )
    |> Repo.one()
  end
end
