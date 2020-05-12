defmodule Oli.Publishing.AuthoringResolver do

  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.Resolver
  import Oli.Timing
  import Ecto.Query, warn: false
  alias Oli.Repo

  @behaviour Resolver




  @impl Resolver
  def from_resource_id(project_slug, resource_ids) when is_list(resource_ids) do

    fn ->
      revisions = Repo.all(from m in PublishedResource,
        join: rev in Revision, on: rev.id == m.revision_id,
        join: p in Publication, on: p.id == m.publication_id,
        join: c in Project, on: p.project_id == c.id,
        where: p.published == false and m.resource_id in ^resource_ids and c.slug == ^project_slug,
        select: rev)

      # order them according to the resource_ids
      map = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, e.resource_id, e) end)
      Enum.map(resource_ids, fn resource_id -> Map.get(map, resource_id) end)
    end
    |> run() |> emit([:oli, :resolvers, :authoring], :duration)

  end

  @impl Resolver
  def from_resource_id(project_slug, resource_id) do

    fn ->
      Repo.one(from m in PublishedResource,
        join: rev in Revision, on: rev.id == m.revision_id,
        join: p in Publication, on: p.id == m.publication_id,
        join: c in Project, on: p.project_id == c.id,
        where: p.published == false and m.resource_id == ^resource_id and c.slug == ^project_slug,
        select: rev)
    end
    |> run() |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def from_revision_slug(project_slug, revision_slug) do

    fn ->
      Repo.one(from rev in Revision,
        join: r in Resource, on: r.id == rev.resource_id,
        join: m in PublishedResource, on: m.resource_id == r.id,
        join: rev2 in Revision, on: m.revision_id == rev2.id,
        join: p in Publication, on: p.id == m.publication_id,
        join: c in Project, on: p.project_id == c.id,
        where: p.published == false and rev.slug == ^revision_slug and c.slug == ^project_slug,
        limit: 1,
        select: rev2)
    end
    |> run() |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def publication(project_slug) do
    fn ->
      Repo.one(from p in Publication,
        join: c in Project, on: p.project_id == c.id,
        where: p.published == false and c.slug == ^project_slug,
        select: p)
    end
    |> run() |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def root_resource(project_slug) do

    fn ->
      Repo.one(from m in PublishedResource,
        join: rev in Revision, on: rev.id == m.revision_id,
        join: p in Publication, on: p.id == m.publication_id,
        join: c in Project, on: p.project_id == c.id,
        where: p.published == false and m.resource_id == p.root_resource_id and c.slug == ^project_slug,
        select: rev)
    end
    |> run() |> emit([:oli, :resolvers, :authoring], :duration)
  end

end
