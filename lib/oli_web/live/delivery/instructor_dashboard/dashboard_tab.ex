defmodule OliWeb.Delivery.InstructorDashboard.DashboardTab do
  @moduledoc """
  Dashboard-tab-specific LiveView helpers for scope restoration and canonical URLs.

  This module keeps the `Insights / Dashboard` tab behavior grouped outside the main
  `InstructorDashboardLive` so future dashboard-only state and routing logic has a
  dedicated home without bloating the shared instructor dashboard helpers.
  """

  alias Oli.InstructorDashboard, as: InstructorDashboardStateContext
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  import Phoenix.Component, only: [assign_new: 3]

  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.RevisitCache

  @type socket :: Phoenix.LiveView.Socket.t()
  @type scope_selector :: String.t()
  @type scope ::
          %{container_type: :course}
          | %{container_type: :container, container_id: pos_integer()}
  @type navigator_item :: %{
          required(:id) => pos_integer() | String.t(),
          required(:resource_id) => pos_integer() | String.t(),
          required(:title) => String.t(),
          required(:resource_type_id) => pos_integer(),
          required(:numbering_level) => integer(),
          required(:numbering_index) => integer()
        }
  @dashboard_container_levels [1, 2, 3]

  @doc """
  Lazily initializes dashboard-tab-specific assigns for the current LiveView session.
  """
  @spec ensure_initialized(socket()) :: socket()
  def ensure_initialized(socket) do
    socket
    |> assign_new(:dashboard_store, fn -> start_inprocess_store() end)
    |> assign_new(:dashboard_revisit_cache, fn -> ensure_revisit_cache() end)
    |> assign_new(:dashboard_revisit_hydrated?, fn -> false end)
  end

  @doc """
  Ensures the instructor enrollment assign exists and resolves the effective dashboard scope.

  The resolved selector is validated against the section's current dashboard containers so
  stale or tampered container selectors fall back to `"course"`.
  """
  @spec resolve_scope_context(socket(), map()) :: {socket(), scope_selector()}
  def resolve_scope_context(socket, params) do
    socket = ensure_instructor_enrollment(socket)
    # Reuse assigned dashboard containers when the tab is already loaded.
    # Entry/canonicalization paths may not have `:containers` yet, so validation
    # falls back to fetching the current section containers.
    containers = socket.assigns[:dashboard_navigator_items]

    scope_selector =
      resolve_scope(
        socket.assigns.section,
        containers,
        params,
        socket.assigns.instructor_enrollment
      )

    {socket, scope_selector}
  end

  @doc """
  Builds the canonical dashboard path for a given scope selector.
  """
  @spec path(socket(), scope_selector()) :: String.t()
  def path(socket, scope_selector) do
    path_for_section(socket.assigns.section.slug, scope_selector)
  end

  @doc """
  Builds the canonical dashboard path for a given section slug and scope selector.
  """
  @spec path_for_section(String.t(), scope_selector()) :: String.t()
  def path_for_section(section_slug, scope_selector) do
    "/sections/#{section_slug}/instructor_dashboard/insights/dashboard?dashboard_scope=#{URI.encode_www_form(scope_selector)}"
  end

  @doc """
  Parses a scope selector into the dashboard scope request shape.
  """
  @spec parse_scope(scope_selector() | nil) :: scope()
  def parse_scope("course"), do: %{container_type: :course}

  def parse_scope("container:" <> id) do
    case Integer.parse(id) do
      {parsed, ""} when parsed > 0 -> %{container_type: :container, container_id: parsed}
      _ -> %{container_type: :course}
    end
  end

  def parse_scope(_), do: %{container_type: :course}

  @doc """
  Persists the selected dashboard scope for the instructor enrollment.

  Callers are expected to validate untrusted selectors against the section before persisting.
  """
  @spec persist_scope(map() | nil, scope_selector()) ::
          :ok
          | {:ok, InstructorDashboardState.t()}
          | {:error, Ecto.Changeset.t()}
  def persist_scope(nil, _scope_selector), do: :ok

  def persist_scope(%{id: enrollment_id}, scope_selector) do
    InstructorDashboardStateContext.upsert_state(enrollment_id, %{
      last_viewed_scope: scope_selector
    })
  end

  @doc """
  Returns the canonical selector string for the provided scope map.
  """
  @spec scope_selector(scope()) :: scope_selector()
  def scope_selector(%{container_type: :container, container_id: container_id}),
    do: "container:#{container_id}"

  def scope_selector(_), do: "course"

  @doc """
  Builds the ordered navigator items for the dashboard scope control.

  The synthetic `"Entire Course"` item is always first, followed by container items
  in curriculum order through section level.
  """
  @spec navigator_items(map()) :: {non_neg_integer(), [navigator_item()]}
  def navigator_items(section) do
    course_item = entire_course_item()

    items =
      section
      |> fetch_dashboard_containers()
      |> flatten_dashboard_containers()

    {length(items), [course_item | items]}
  end

  @doc """
  Normalizes a scope selector against the section's current containers.

  Invalid, unauthorized, or no-longer-present container selectors fall back to `"course"`.
  """
  @spec normalize_scope_selector(map(), scope_selector() | nil) :: scope_selector()
  def normalize_scope_selector(section, scope_selector) do
    normalize_scope_selector(section, nil, scope_selector)
  end

  @spec normalize_scope_selector(map(), {non_neg_integer(), list()} | nil, scope_selector() | nil) ::
          scope_selector()
  def normalize_scope_selector(section, containers, scope_selector) do
    case validate_scope_selector(section, containers, scope_selector) do
      {:ok, normalized_scope_selector} -> normalized_scope_selector
      :error -> "course"
    end
  end

  @doc """
  Validates a scope selector against the section's current containers and returns
  the canonical selector when valid.

  This rejects both unauthorized container ids and persisted selectors for containers that
  no longer exist in the remixed section.
  """
  @spec validate_scope_selector(map(), scope_selector() | nil) ::
          {:ok, scope_selector()} | :error
  def validate_scope_selector(section, scope_selector) do
    validate_scope_selector(section, nil, scope_selector)
  end

  @spec validate_scope_selector(map(), {non_neg_integer(), list()} | nil, scope_selector() | nil) ::
          {:ok, scope_selector()} | :error
  def validate_scope_selector(section, containers, scope_selector) do
    case parse_scope(scope_selector) do
      %{container_type: :course} ->
        {:ok, "course"}

      %{container_type: :container, container_id: container_id} ->
        if valid_container_id?(section, containers, container_id) do
          {:ok, scope_selector(%{container_type: :container, container_id: container_id})}
        else
          :error
        end
    end
  end

  defp ensure_instructor_enrollment(socket) do
    assign_new(socket, :instructor_enrollment, fn ->
      Helpers.get_instructor_enrollment(socket.assigns.section, socket.assigns.current_user)
    end)
  end

  defp resolve_scope(section, containers, params, enrollment) do
    case params["dashboard_scope"] do
      nil -> normalize_scope_selector(section, containers, last_viewed_scope(enrollment))
      scope_selector -> normalize_scope_selector(section, containers, scope_selector)
    end
  end

  defp last_viewed_scope(nil), do: nil

  defp last_viewed_scope(%{id: enrollment_id}) do
    case InstructorDashboardStateContext.get_state_by_enrollment_id(enrollment_id) do
      nil -> nil
      state -> state.last_viewed_scope
    end
  end

  defp start_inprocess_store do
    {:ok, pid} = InProcessStore.start_link([])
    pid
  end

  defp ensure_revisit_cache do
    case Process.whereis(RevisitCache) do
      nil ->
        case RevisitCache.start_link(name: RevisitCache) do
          {:ok, _pid} -> RevisitCache
          {:error, {:already_started, _pid}} -> RevisitCache
          _ -> nil
        end

      _pid ->
        RevisitCache
    end
  end

  defp valid_container_id?(_section, {_, containers}, container_id) when is_list(containers) do
    Enum.any?(containers, fn container ->
      Map.get(container, :id) == container_id or Map.get(container, :resource_id) == container_id
    end)
  end

  defp valid_container_id?(%{id: section_id}, _containers, container_id)
       when is_integer(section_id) do
    navigator_items(%{id: section_id})
    |> elem(1)
    |> Enum.any?(&(Map.get(&1, :resource_id) == container_id))
  end

  defp valid_container_id?(_, _, _), do: false

  defp entire_course_item do
    %{
      id: "course",
      resource_id: "course",
      title: "Entire Course",
      resource_type_id: Oli.Resources.ResourceType.id_for_container(),
      numbering_level: 0,
      numbering_index: -1
    }
  end

  defp fetch_dashboard_containers(%{id: section_id}) when is_integer(section_id) do
    SectionResourceDepot.containers(section_id,
      numbering_level: {:in, @dashboard_container_levels}
    )
  end

  defp fetch_dashboard_containers(_), do: []

  defp flatten_dashboard_containers(containers) do
    containers_by_id = Map.new(containers, &{&1.id, &1})

    child_container_ids =
      containers
      |> Enum.flat_map(&Map.get(&1, :children, []))
      |> MapSet.new()

    containers
    |> Enum.reject(&MapSet.member?(child_container_ids, &1.id))
    |> Enum.sort_by(& &1.numbering_index)
    |> Enum.flat_map(&flatten_dashboard_container(&1, containers_by_id))
  end

  defp flatten_dashboard_container(container, containers_by_id) do
    children =
      container
      |> Map.get(:children, [])
      |> Enum.map(&Map.get(containers_by_id, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&flatten_dashboard_container(&1, containers_by_id))

    [navigator_item(container) | children]
  end

  defp navigator_item(container) do
    %{
      id: container.resource_id,
      resource_id: container.resource_id,
      title: container.title,
      resource_type_id: container.resource_type_id,
      numbering_level: container.numbering_level,
      numbering_index: container.numbering_index
    }
  end
end
