defmodule Oli.Authoring.Audited.Support do
  @moduledoc false
  # Event recording and before/after reads shared by the private modules of
  # `Oli.Authoring.Audited`.

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing
  alias Oli.Auditing.Changes
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Publishing.{AuthoringResolver, PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @container_type_id ResourceType.id_for_container()

  # Page settings recorded by authoring_settings_changed; objectives have their own event, and
  # children, parent objectives, and deletion do not belong to page settings.
  @page_settings Map.drop(Fields.authoring_configuration(), [
                   :objectives,
                   :children,
                   :parent_objective_id,
                   :selection_rules,
                   :deleted
                 ])

  @doc "Builds the event from `proposal` and inserts it in the current transaction."
  def record(context, proposal) do
    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end

  @doc """
  Builds an event from each of `proposals` and inserts them all in one statement in the
  current transaction.
  """
  def record_many(context, proposals) do
    proposals
    |> Enum.reduce_while({:ok, []}, fn proposal, {:ok, changesets} ->
      case Auditing.build(context, proposal) do
        {:ok, changeset} -> {:cont, {:ok, [changeset | changesets]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, changesets} -> changesets |> Enum.reverse() |> Auditing.insert_all()
      error -> error
    end
  end

  @doc "Records each of `items` with `record_one`, stopping at the first error."
  def record_all(items, record_one) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case record_one.(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc "The page and container settings policy of `authoring_settings_changed`."
  def page_settings, do: @page_settings

  @doc """
  Locks the working mappings of `resource_ids`, reads them, runs `write`, and calls
  `record_one.(before, after)` for each resource, all in one transaction. `write` returns
  `{:ok, result}` or `{:error, reason}`; `:created` returns the IDs of resources the write
  created from its result, which are recorded with a `nil` before-state.
  """
  def changing(project, resource_ids, write, record_one, opts \\ []) do
    created = Keyword.get(opts, :created, fn _result -> [] end)

    Repo.transaction(fn ->
      lock_working_mappings(project, resource_ids)
      before = latest_revisions(project, resource_ids)

      case write.() do
        {:ok, result} ->
          resource_ids = Enum.uniq(resource_ids ++ created.(result))
          after_state = latest_revisions(project, resource_ids)

          case record_all(resource_ids, &record_one.(before[&1], after_state[&1])) do
            :ok -> result
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, reason} ->
          Repo.rollback(reason)

        other ->
          Repo.rollback(other)
      end
    end)
  end

  @doc """
  Records `changes` of an authored resource (`revision`) as `event_type`, or nothing when there
  are no changes. Containers are recorded as `:container` entities, other resources as
  `:resource`.
  """
  def record_resource_change(_context, _project, _revision, _event_type, changes)
      when map_size(changes) == 0,
      do: :ok

  def record_resource_change(context, project, revision, event_type, changes) do
    record(context, %{
      event_type: event_type,
      entity:
        {entity_type(revision), revision.resource_id,
         %{title: revision.title, slug: revision.slug}},
      scope: %{project_id: project.id, resource_id: revision.resource_id},
      event_key: "resource:#{revision.resource_id}:#{event_type}",
      changes: changes
    })
  end

  @doc """
  Records `authoring_content_replaced` for a resource whose content `previous` was replaced by
  `resulting`, with `reason` and the settings that changed; an in-place edit (same revision)
  references only that revision. Content itself is never recorded.
  """
  def record_replacement(context, project, previous, resulting, reason),
    do: record(context, replacement(project, previous, resulting, reason))

  @doc "The `authoring_content_replaced` proposal that `record_replacement/5` records."
  def replacement(project, previous, resulting, reason) do
    %{
      event_type: :authoring_content_replaced,
      entity: {:resource, previous.resource_id, %{title: previous.title, slug: previous.slug}},
      scope: %{project_id: project.id, resource_id: previous.resource_id},
      refs: replacement_refs(previous, resulting),
      changes:
        Changes.diff(previous, resulting, Map.delete(Fields.authoring_content(), :revision_id)),
      details: %{reason: reason},
      event_key: "resource:#{previous.resource_id}:replaced"
    }
  end

  @doc """
  Locks the working-publication mappings of `resource_ids`, so that their revisions read next
  are the before-state of the write that follows in the same transaction.
  """
  def lock_working_mappings(_project, []), do: :ok

  def lock_working_mappings(project, resource_ids) do
    from(mapping in PublishedResource,
      join: publication in Publication,
      on: publication.id == mapping.publication_id,
      where:
        publication.project_id == ^project.id and is_nil(publication.published) and
          mapping.resource_id in ^resource_ids,
      order_by: mapping.resource_id,
      lock: "FOR UPDATE OF p0"
    )
    |> Repo.all()

    :ok
  end

  @doc "Returns the working revisions of `resource_ids` that exist, by resource ID."
  def latest_revisions(_project, []), do: %{}

  def latest_revisions(project, resource_ids) do
    project.slug
    |> AuthoringResolver.from_resource_id(resource_ids)
    |> Enum.reject(&is_nil/1)
    |> Map.new(&{&1.resource_id, &1})
  end

  @doc "Parses client resource IDs (integers or strings); anything else is left to the write."
  def resource_ids(ids) do
    Enum.flat_map(ids, fn
      id when is_integer(id) ->
        [id]

      id when is_binary(id) ->
        case Integer.parse(id) do
          {id, ""} -> [id]
          _ -> []
        end

      _ ->
        []
    end)
  end

  defp replacement_refs(%{id: id} = revision, %{id: id}),
    do: [%{role: :resulting, type: :revision, id: id, label: revision.title}]

  defp replacement_refs(previous, resulting) do
    [
      %{role: :previous, type: :revision, id: previous.id, label: previous.title},
      %{role: :resulting, type: :revision, id: resulting.id, label: resulting.title}
    ]
  end

  defp entity_type(%{resource_type_id: @container_type_id}), do: :container
  defp entity_type(_revision), do: :resource
end
