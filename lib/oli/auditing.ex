defmodule Oli.Auditing do
  @moduledoc """
  Writes and reads audit events.

  Application code records events through `build/2` and then `append/3` (inside an
  `Ecto.Multi`) or `insert/1`. Every row is validated against the envelope rules and its
  contract in `Oli.Auditing.EventCatalog`, and failures are reported as `Oli.Auditing.Error`
  values that never contain the rejected data.

  `capture/4` keeps the call shape of the producers written before the catalog; it maps them
  to version 2 rows through `Oli.Auditing.LegacyAdapter`.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Ecto.{Changeset, Multi}
  alias Oli.Repo

  alias Oli.Auditing.{
    BrowseOptions,
    Context,
    Error,
    LegacyAdapter,
    LogEvent,
    Partitions,
    Snapshot
  }

  alias Oli.Accounts.{User, Author}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo.{Paging, Sorting}

  @scope_columns [:project_id, :section_id, :resource_id, :institution_id]

  @type proposal_attrs :: %{
          required(:event_type) => atom(),
          required(:entity) => {atom(), term(), map() | struct()},
          required(:event_key) => String.t(),
          optional(:outcome) => atom(),
          optional(:affected) => {:user | :author, pos_integer()},
          optional(:scope) => %{
            optional(:project_id | :section_id | :resource_id | :institution_id) => pos_integer()
          },
          optional(:refs) => [
            %{required(:role) => atom(), required(:type) => atom(), optional(atom()) => term()}
          ],
          optional(:changes) => map(),
          optional(:details) => map(),
          optional(:occurred_at) => DateTime.t()
        }

  @doc """
  Builds a version 2 changeset from who acted (`context`) and what happened (`proposal`).

  `inserted_at` is now; `occurred_at` defaults to it. The entity snapshot keeps only the
  allowlisted identity fields of the given struct or map, and `search_text` is derived from the
  actor and entity snapshots and the reference labels.

  Only the scope columns are taken from `scope`, so a proposal cannot replace the actor or any
  other envelope field.

  Returns `{:error, :no_changes}` for an event with a `:skip` contract and no changes, and
  `{:error, changeset}` when the row does not satisfy its contract.
  """
  @spec build(Context.t(), proposal_attrs()) ::
          {:ok, Changeset.t()} | {:error, :no_changes | Changeset.t()}
  def build(%Context{} = context, %{} = proposal) do
    now = DateTime.utc_now()
    {entity_type, entity_id, entity_snapshot} = entity(Map.fetch!(proposal, :entity))
    refs = proposal |> Map.get(:refs, []) |> Enum.map(&ref/1)

    attrs =
      %{
        inserted_at: now,
        occurred_at: Map.get(proposal, :occurred_at, now),
        event_type: Map.fetch!(proposal, :event_type),
        outcome: Map.get(proposal, :outcome, :succeeded),
        actor_type: context.actor_type,
        actor_key: context.system_key && Atom.to_string(context.system_key),
        user_id: context.user_id,
        author_id: context.author_id,
        actor_snapshot: context.actor_snapshot,
        entity_type: entity_type,
        entity_id: entity_id,
        entity_snapshot: entity_snapshot,
        refs: refs,
        changes: Map.get(proposal, :changes, %{}),
        details:
          proposal |> Map.get(:details, %{}) |> Map.new(fn {k, v} -> {to_string(k), v} end),
        source: context.source,
        operation_id: context.operation_id,
        parent_operation_id: context.parent_operation_id,
        event_key: Map.fetch!(proposal, :event_key),
        search_text:
          Snapshot.search_text([
            context.actor_snapshot,
            entity_snapshot | Enum.map(refs, &Map.take(&1, ["label"]))
          ])
      }
      |> Map.merge(proposal |> Map.get(:scope, %{}) |> Map.take(@scope_columns))
      |> Map.merge(affected(Map.get(proposal, :affected)))

    changeset = LogEvent.v2_changeset(%LogEvent{}, attrs)

    case changeset do
      %Changeset{valid?: true} -> {:ok, changeset}
      changeset -> build_error(changeset)
    end
  end

  defp build_error(changeset) do
    case Enum.any?(changeset.errors, fn {_field, {_message, meta}} ->
           meta[:validation] == :no_changes
         end) do
      true -> {:error, :no_changes}
      false -> {:error, changeset}
    end
  end

  defp entity({type, id, snapshot}), do: {type, to_string(id), Snapshot.of(snapshot)}

  defp ref(%{role: role, type: type, id: id} = ref) do
    %{"role" => Atom.to_string(role), "type" => Atom.to_string(type), "id" => id}
    |> put_label(Map.get(ref, :label))
  end

  defp put_label(ref, nil), do: ref
  defp put_label(ref, label), do: Map.put(ref, "label", label)

  defp affected(nil), do: %{}
  defp affected({:user, id}), do: %{affected_user_id: id}
  defp affected({:author, id}), do: %{affected_author_id: id}

  @doc """
  Adds a step to `multi` that writes the event returned by `builder`.

  `builder` receives the results of the previous steps and returns `{:ok, changeset}` (usually
  from `build/2`), `:skip` or `{:error, :no_changes}` to write nothing, or `{:error, term}`.
  Any error rolls back the whole `Ecto.Multi`; changesets and unexpected builder results are
  reported as `Oli.Auditing.Error` values.
  """
  @spec append(
          Multi.t(),
          Multi.name(),
          (map() -> {:ok, Changeset.t()} | {:error, term()} | :skip)
        ) :: Multi.t()
  def append(%Multi{} = multi, name, builder) when is_function(builder, 1) do
    Multi.run(multi, name, fn _repo, changes ->
      case builder.(changes) do
        {:ok, %Changeset{} = changeset} -> insert(changeset)
        :skip -> {:ok, nil}
        {:error, :no_changes} -> {:ok, nil}
        {:error, %Changeset{} = changeset} -> {:error, report(invalid_error(changeset))}
        {:error, reason} -> {:error, reason}
        _unexpected -> {:error, report(Error.new(:invalid_event))}
      end
    end)
  end

  @doc """
  Inserts a changeset built by `build/2` outside an `Ecto.Multi`.

  A row whose `inserted_at` has no partition returns `:partition_missing`. Every failure is
  logged once, without values, with the error's correlation ID, and emits the telemetry event
  `[:oli, :auditing, :append, :error]`.

  A database failure aborts the surrounding transaction, if any, so a caller inside
  `Repo.transaction/1` must roll back on `{:error, _}` instead of issuing more queries.
  """
  @spec insert(Changeset.t()) :: {:ok, LogEvent.t()} | {:error, Error.t()}
  def insert(%Changeset{valid?: true} = changeset) do
    do_insert(changeset, Changeset.get_field(changeset, :event_type))
  end

  def insert(%Changeset{} = changeset), do: {:error, report(invalid_error(changeset))}

  defp do_insert(changeset, event_type) do
    case Repo.insert(changeset) do
      {:ok, event} -> {:ok, event}
      {:error, changeset} -> {:error, report(invalid_error(changeset))}
    end
  rescue
    error in Postgrex.Error ->
      code = database_error_code(error)
      {:error, report(Error.new(code, event_type), interval(code, changeset))}

    DBConnection.ConnectionError ->
      {:error, report(Error.new(:insert_failed, event_type))}
  end

  defp database_error_code(%Postgrex.Error{postgres: %{code: :check_violation, message: message}}) do
    case String.contains?(message, "no partition of relation") do
      true -> :partition_missing
      false -> :invalid_event
    end
  end

  defp database_error_code(_error), do: :insert_failed

  defp interval(:partition_missing, changeset) do
    case Changeset.get_field(changeset, :inserted_at) do
      %DateTime{} = inserted_at -> Partitions.name_for(DateTime.to_date(inserted_at))
      _ -> nil
    end
  end

  defp interval(_code, _changeset), do: nil

  defp invalid_error(changeset),
    do: Error.new(:invalid_event, Changeset.get_field(changeset, :event_type))

  defp report(%Error{} = error, interval \\ nil) do
    Logger.error(
      "Audit event write failed code=#{error.code} event_type=#{error.event_type} " <>
        "correlation_id=#{error.correlation_id}" <>
        case interval do
          nil -> ""
          interval -> " partition=#{interval}"
        end
    )

    :telemetry.execute([:oli, :auditing, :append, :error], %{count: 1}, Map.from_struct(error))
    error
  end

  @doc """
  Records an event with the call shape used before the event catalog.

  `actor` must be a `User` or an `Author`; a `nil` actor returns
  `{:error, %Oli.Auditing.Error{code: :invalid_event}}` (no system actor is invented). A row
  that does not satisfy its contract returns `{:error, changeset}`, built from the mapped
  values, so existing callers that match on a changeset keep working.

  ## Examples

      iex> capture(author, :project_published, project, %{"project_title" => "Biology"})
      {:ok, %LogEvent{}}
  """
  @spec capture(%User{} | %Author{} | nil, atom(), struct() | nil, map()) ::
          {:ok, LogEvent.t()} | {:error, Error.t() | Changeset.t()}
  def capture(actor, event_type, resource \\ nil, details \\ %{}) do
    with {:ok, context, proposal} <-
           LegacyAdapter.to_proposal(actor, event_type, resource, details),
         {:ok, changeset} <- build(context, proposal) do
      insert(changeset)
    else
      {:error, :invalid_event} -> {:error, report(Error.new(:invalid_event, event_type))}
      {:error, :no_changes} -> {:error, Error.new(:no_changes, event_type)}
      {:error, %Changeset{} = changeset} -> report_changeset(changeset)
    end
  end

  defp report_changeset(changeset) do
    report(invalid_error(changeset))
    {:error, changeset}
  end

  @doc """
  Like `capture/4`, but raises on failure.
  """
  @spec capture!(%User{} | %Author{} | nil, atom(), struct() | nil, map()) :: LogEvent.t()
  def capture!(actor, event_type, resource \\ nil, details \\ %{}) do
    case capture(actor, event_type, resource, details) do
      {:ok, event} -> event
      {:error, %Error{code: code}} -> raise "Failed to capture audit event: #{code}"
      {:error, %Changeset{}} -> raise "Failed to capture audit event: invalid_event"
    end
  end

  @doc """
  Lists audit events with optional filters, newest first.

  ## Options
    - :user_id - Filter by user ID
    - :author_id - Filter by author ID
    - :event_type - Filter by event type
    - :limit - Maximum number of results (default: 100)
    - :order_by - Order results (default: newest first by `inserted_at`, then `id`)

  ## Examples

      iex> list_events(user_id: 1, event_type: :project_published)
      [%LogEvent{}, ...]
  """
  @spec list_events(keyword()) :: [LogEvent.t()]
  def list_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    order_by = Keyword.get(opts, :order_by, desc: :inserted_at, desc: :id)

    LogEvent
    |> apply_filters(opts)
    |> order_by(^order_by)
    |> limit(^limit)
    |> Repo.all()
    |> preload_associations()
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:user_id, id}, query -> where(query, [e], e.user_id == ^id)
      {:author_id, id}, query -> where(query, [e], e.author_id == ^id)
      {:event_type, type}, query -> where(query, [e], e.event_type == ^type)
      _, query -> query
    end)
  end

  @doc """
  Gets a single audit event by its full primary key, reading only the partition that holds it.

  Raises `Ecto.NoResultsError` if the event does not exist.
  """
  @spec get_event!(pos_integer(), DateTime.t()) :: LogEvent.t()
  def get_event!(id, %DateTime{} = inserted_at) do
    LogEvent
    |> where([e], e.id == ^id and e.inserted_at == ^inserted_at)
    |> Repo.one!()
    |> preload_associations()
  end

  @doc """
  Records an action performed by an administrator. Same as `capture/4`.
  """
  @spec log_admin_action(%User{} | %Author{} | nil, atom(), struct() | nil, map()) ::
          {:ok, LogEvent.t()} | {:error, Error.t() | Changeset.t()}
  def log_admin_action(admin, event_type, resource \\ nil, details \\ %{}),
    do: capture(admin, event_type, resource, details)

  # Preload associations for display purposes
  defp preload_associations(events) when is_list(events) do
    user_ids = events |> Enum.map(& &1.user_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    author_ids = events |> Enum.map(& &1.author_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    project_ids = events |> Enum.map(& &1.project_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    section_ids = events |> Enum.map(& &1.section_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    users =
      if Enum.empty?(user_ids),
        do: %{},
        else: User |> where([u], u.id in ^user_ids) |> Repo.all() |> Map.new(&{&1.id, &1})

    authors =
      if Enum.empty?(author_ids),
        do: %{},
        else: Author |> where([a], a.id in ^author_ids) |> Repo.all() |> Map.new(&{&1.id, &1})

    projects =
      if Enum.empty?(project_ids),
        do: %{},
        else: Project |> where([p], p.id in ^project_ids) |> Repo.all() |> Map.new(&{&1.id, &1})

    sections =
      if Enum.empty?(section_ids),
        do: %{},
        else: Section |> where([s], s.id in ^section_ids) |> Repo.all() |> Map.new(&{&1.id, &1})

    Enum.map(events, fn event ->
      event
      |> Map.put(:actor, users[event.user_id] || authors[event.author_id])
      |> Map.put(
        :resource,
        sections[event.section_id] || projects[event.project_id]
      )
    end)
  end

  defp preload_associations(%LogEvent{} = event) do
    [event] |> preload_associations() |> List.first()
  end

  @chars_to_replace_on_search [" ", "&", ":", ";", "(", ")", "|", "!", "'", "<", ">"]

  @doc """
  Paged, sorted, filterable queries for audit log events.
  """
  @spec browse_events_query(Paging.t(), Sorting.t(), BrowseOptions.t()) :: Ecto.Query.t()
  def browse_events_query(
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        %BrowseOptions{} = options
      ) do
    # Text search across user name, author name, project slug, section slug
    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        # Allow to search by prefix
        search_term =
          options.text_search
          |> String.split(@chars_to_replace_on_search, trim: true)
          |> Enum.map(fn x -> x <> ":*" end)
          |> Enum.join(" & ")

        # Current account and record names, plus the identities stored with the event.
        dynamic(
          [e, u, a, p, s],
          fragment(
            "to_tsvector('simple', coalesce(?, '') || ' ' || coalesce(?, '') || ' ' || coalesce(?, '') || ' ' || coalesce(?, '') || ' ' || coalesce(?, '') || ' ' || coalesce(?, '')) @@ to_tsquery('simple', ?)",
            u.name,
            u.email,
            a.name,
            a.email,
            p.slug,
            s.slug,
            ^search_term
          ) or
            fragment("? @@ to_tsquery('simple', ?)", e.search_vector, ^search_term)
        )
      end

    # Event type filter
    filter_by_event_type =
      if options.event_type,
        do: dynamic([e], e.event_type == ^options.event_type),
        else: true

    # Actor type filter
    filter_by_actor_type =
      case options.actor_type do
        :user -> dynamic([e], not is_nil(e.user_id))
        :author -> dynamic([e], not is_nil(e.author_id))
        _ -> true
      end

    query =
      LogEvent
      |> join(:left, [e], u in User, on: e.user_id == u.id)
      |> join(:left, [e], a in Author, on: e.author_id == a.id)
      |> join(:left, [e], p in Project, on: e.project_id == p.id)
      |> join(:left, [e], s in Section, on: e.section_id == s.id)
      |> where(^filter_by_text)
      |> where(^filter_by_event_type)
      |> where(^filter_by_actor_type)
      |> limit(^limit)
      |> offset(^offset)
      |> select_merge([e], %{
        total_count: fragment("count(*) OVER()")
      })

    # Sorting
    query =
      case field do
        :event_type ->
          order_by(query, [e], {^direction, e.event_type})

        :actor ->
          order_by(query, [e, u, a], {^direction, fragment("coalesce(?, ?)", u.name, a.name)})

        :resource ->
          order_by(
            query,
            [e, _, _, p, s],
            {^direction, fragment("coalesce(?, ?)", p.title, s.title)}
          )

        :inserted_at ->
          order_by(query, [e], {^direction, e.inserted_at})

        _ ->
          order_by(query, [e], {^direction, field(e, ^field)})
      end

    # Stable order for rows that tie on the sorted field, in the same direction so an index on
    # (inserted_at, id) can serve it.
    order_by(query, [e], [{^direction, e.inserted_at}, {^direction, e.id}])
  end

  @doc """
  Browse audit events with paging, sorting, and filtering.

  ## Examples

      iex> browse_events(%Paging{}, %Sorting{}, %BrowseOptions{})
      [%LogEvent{}, ...]
  """
  def browse_events(
        %Paging{} = paging,
        %Sorting{} = sorting,
        %BrowseOptions{} = options
      ) do
    browse_events_query(paging, sorting, options)
    |> Repo.all()
    |> preload_associations()
  end
end
