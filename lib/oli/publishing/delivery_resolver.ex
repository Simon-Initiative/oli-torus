defmodule Oli.Publishing.DeliveryResolver do

  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Resolver
  alias Oli.Delivery.Sections.Section
  import Oli.Timing
  import Ecto.Query, warn: false
  alias Oli.Repo

  @behaviour Resolver

  @impl Resolver
  def from_resource_id(context_id, resource_ids) when is_list(resource_ids) do

    fn ->
      revisions = Repo.all(from s in Section,
        join: m in PublishedResource, on: m.publication_id == s.publication_id,
        join: rev in Revision, on: rev.id == m.revision_id,
        where: s.context_id == ^context_id and m.resource_id in ^resource_ids,
        select: rev)

      # order them according to the resource_ids
      map = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, e.resource_id, e) end)
      Enum.map(resource_ids, fn resource_id -> Map.get(map, resource_id) end)
    end
    |> run() |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def from_resource_id(context_id, resource_id) do

    fn ->
      Repo.one(from s in Section,
        join: m in PublishedResource, on: m.publication_id == s.publication_id,
        join: rev in Revision, on: rev.id == m.revision_id,
        where: s.context_id == ^context_id and m.resource_id == ^resource_id,
        select: rev)
      end
    |> run() |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def from_revision_slug(context_id, revision_slug) do

    fn ->
      Repo.one(from rev in Revision,
        join: r in Resource, on: r.id == rev.resource_id,
        join: m in PublishedResource, on: m.resource_id == r.id,
        join: rev2 in Revision, on: m.revision_id == rev2.id,
        join: s in Section, on: s.publication_id == m.publication_id,
        where: rev.slug == ^revision_slug and s.context_id == ^context_id,
        limit: 1,
        select: rev2)
    end
    |> run() |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def publication(context_id) do
    fn ->
      Repo.one(from p in Publication,
        join: s in Section, on: p.id == s.publication_id,
        where: s.context_id == ^context_id,
        select: p)
      end
    |> run() |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def root_resource(context_id) do
    fn ->
      Repo.one(from s in Section,
        join: p in Publication, on: p.id == s.publication_id,
        join: m in PublishedResource, on: m.publication_id == p.id,
        join: rev in Revision, on: rev.id == m.revision_id,
        where: m.resource_id == p.root_resource_id and s.context_id == ^context_id,
        select: rev)
    end
    |> run() |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def hierarchy(context_id) do

    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    fn ->
      Repo.all(from s in Section,
        join: p in Publication, on: p.id == s.publication_id,
        join: m in PublishedResource, on: m.publication_id == p.id,
        join: rev in Revision, on: rev.id == m.revision_id,
        where: (rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id) and s.context_id == ^context_id,
        select: rev)
    end
    |> run() |> emit([:oli, :resolvers, :delivery], :duration)

  end

  @impl Resolver
  def find_parent_objectives(_, []), do: []
  def find_parent_objectives(context_id, resource_ids) do

    ids = Enum.join(resource_ids, ",")

    fn ->

      sql =
        """
        select rev.*
        from published_resources as m
        join sections as c on m.publication_id = c.publication_id
        join revisions as rev on rev.id = m.revision_id
        where c.context_id = '#{context_id}'
          and rev.deleted is false
          and rev.children && ARRAY[#{ids}]
        """

      {:ok, result} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

      Enum.map(result.rows, &Repo.load(Revision, {result.columns, &1}))

    end
    |> run() |> emit([:oli, :resolvers, :authoring], :duration)

  end

end
