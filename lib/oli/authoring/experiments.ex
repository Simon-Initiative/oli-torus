defmodule Oli.Authoring.Experiments do
  @moduledoc """
  This module provides a context around experiments.
  """

  import Ecto.Query, warn: false
  import Oli.Publishing.AuthoringResolver, only: [project_working_publication: 1]

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
end
