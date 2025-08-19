defmodule Oli.Auditing do
  @moduledoc """
  The Auditing context provides functionality for logging and querying audit events.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Auditing.{LogEvent, BrowseOptions}
  alias Oli.Accounts.{User, Author}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo.{Paging, Sorting}

  @doc """
  Captures an audit log event.

  ## Parameters
    - actor: The user or author performing the action (or nil for system actions)
    - event_type: The type of event (atom)
    - resource: The resource being acted upon (optional)
    - details: Additional details about the event (map)

  ## Examples

      iex> capture(%User{id: 1}, :project_published, %Project{id: 10}, %{version: "1.0"})
      {:ok, %LogEvent{}}

      iex> capture(%Author{id: 2}, :user_deleted, nil, %{email: "user@example.com"})
      {:ok, %LogEvent{}}
  """
  def capture(actor, event_type, resource \\ nil, details \\ %{}) do
    attrs = build_attrs(actor, event_type, resource, details)

    %LogEvent{}
    |> LogEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Captures an audit log event, raising an exception on failure.
  """
  def capture!(actor, event_type, resource \\ nil, details \\ %{}) do
    case capture(actor, event_type, resource, details) do
      {:ok, event} -> event
      {:error, changeset} -> raise "Failed to capture audit event: #{inspect(changeset)}"
    end
  end

  defp build_attrs(actor, event_type, resource, details) do
    attrs = %{
      event_type: event_type,
      details: details
    }

    attrs
    |> add_actor_attrs(actor)
    |> add_resource_attrs(resource)
  end

  defp add_actor_attrs(attrs, %User{id: id}), do: Map.put(attrs, :user_id, id)
  defp add_actor_attrs(attrs, %Author{id: id}), do: Map.put(attrs, :author_id, id)
  defp add_actor_attrs(attrs, nil), do: attrs
  defp add_actor_attrs(attrs, _), do: attrs

  defp add_resource_attrs(attrs, %Project{id: id}), do: Map.put(attrs, :project_id, id)
  defp add_resource_attrs(attrs, %Section{id: id}), do: Map.put(attrs, :section_id, id)

  defp add_resource_attrs(attrs, %{id: id, __struct__: struct_name}) do
    # For other resources with an id, store in resource_id
    Map.put(attrs, :resource_id, id)
    |> Map.update(:details, %{}, fn details ->
      Map.put(details, "resource_type", to_string(struct_name))
    end)
  end

  defp add_resource_attrs(attrs, nil), do: attrs
  defp add_resource_attrs(attrs, _), do: attrs

  @doc """
  Lists audit events with optional filters.

  ## Options
    - :user_id - Filter by user ID
    - :author_id - Filter by author ID
    - :event_type - Filter by event type
    - :section_id - Filter by section ID
    - :project_id - Filter by project ID
    - :limit - Maximum number of results (default: 100)
    - :order_by - Order results (default: [desc: :inserted_at])

  ## Examples

      iex> list_events(user_id: 1, event_type: :project_published)
      [%LogEvent{}, ...]
  """
  def list_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    order_by = Keyword.get(opts, :order_by, [desc: :inserted_at])

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
      {:section_id, id}, query -> where(query, [e], e.section_id == ^id)
      {:project_id, id}, query -> where(query, [e], e.project_id == ^id)
      {:date_from, date}, query -> where(query, [e], e.inserted_at >= ^date)
      {:date_to, date}, query -> where(query, [e], e.inserted_at <= ^date)
      _, query -> query
    end)
  end

  @doc """
  Gets a single audit event.

  Raises `Ecto.NoResultsError` if the event does not exist.

  ## Examples

      iex> get_event!(123)
      %LogEvent{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)
  """
  def get_event!(id) do
    LogEvent
    |> Repo.get!(id)
    |> preload_associations()
  end

  @doc """
  Convenience function to log a user action.
  """
  def log_user_action(%User{} = user, event_type, details \\ %{}) do
    capture(user, event_type, nil, details)
  end

  @doc """
  Convenience function to log an author action.
  """
  def log_author_action(%Author{} = author, event_type, details \\ %{}) do
    capture(author, event_type, nil, details)
  end

  @doc """
  Convenience function to log an admin-only action.
  Admin actions are typically performed by users with admin privileges.
  """
  def log_admin_action(admin, event_type, resource \\ nil, details \\ %{}) do
    details_with_admin = Map.put(details, "admin_action", true)
    capture(admin, event_type, resource, details_with_admin)
  end

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
        projects[event.project_id] || sections[event.section_id]
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
          )
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

    # Date range filters
    filter_by_date_from =
      if options.date_from,
        do: dynamic([e], e.inserted_at >= ^options.date_from),
        else: true

    filter_by_date_to =
      if options.date_to,
        do: dynamic([e], e.inserted_at <= ^options.date_to),
        else: true

    # Resource filters
    filter_by_project =
      if options.project_id,
        do: dynamic([e], e.project_id == ^options.project_id),
        else: true

    filter_by_section =
      if options.section_id,
        do: dynamic([e], e.section_id == ^options.section_id),
        else: true

    query =
      LogEvent
      |> join(:left, [e], u in User, on: e.user_id == u.id)
      |> join(:left, [e], a in Author, on: e.author_id == a.id)
      |> join(:left, [e], p in Project, on: e.project_id == p.id)
      |> join(:left, [e], s in Section, on: e.section_id == s.id)
      |> where(^filter_by_text)
      |> where(^filter_by_event_type)
      |> where(^filter_by_actor_type)
      |> where(^filter_by_date_from)
      |> where(^filter_by_date_to)
      |> where(^filter_by_project)
      |> where(^filter_by_section)
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
          order_by(query, [e, _, _, p, s], {^direction, fragment("coalesce(?, ?)", p.title, s.title)})

        :inserted_at ->
          order_by(query, [e], {^direction, e.inserted_at})

        _ ->
          order_by(query, [e], {^direction, field(e, ^field)})
      end

    # Ensure stable sort order based on id
    order_by(query, [e], e.id)
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