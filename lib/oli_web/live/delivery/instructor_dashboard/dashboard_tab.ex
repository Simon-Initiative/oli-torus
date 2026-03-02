defmodule OliWeb.Delivery.InstructorDashboard.DashboardTab do
  @moduledoc """
  Dashboard-tab-specific LiveView helpers for scope restoration and canonical URLs.

  This module keeps the `Insights / Dashboard` tab behavior grouped outside the main
  `InstructorDashboardLive` so future dashboard-only state and routing logic has a
  dedicated home without bloating the shared instructor dashboard helpers.
  """

  alias Oli.InstructorDashboard, as: InstructorDashboardStateContext
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  import Phoenix.Component, only: [assign_new: 3]

  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.RevisitCache

  @type socket :: Phoenix.LiveView.Socket.t()
  @type scope_selector :: String.t()
  @type scope ::
          %{container_type: :course}
          | %{container_type: :container, container_id: pos_integer()}

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
  """
  @spec resolve_scope_context(socket(), map()) :: {socket(), scope_selector()}
  def resolve_scope_context(socket, params) do
    socket = ensure_instructor_enrollment(socket)
    scope_selector = resolve_scope(params, socket.assigns.instructor_enrollment)

    {socket, scope_selector}
  end

  @doc """
  Builds the canonical dashboard path for a given scope selector.
  """
  @spec path(socket(), scope_selector()) :: String.t()
  def path(socket, scope_selector) do
    "/sections/#{socket.assigns.section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=#{URI.encode_www_form(scope_selector)}"
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
  """
  @spec persist_scope(map() | nil, scope_selector()) :: :ok | {:error, Ecto.Changeset.t()}
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

  defp ensure_instructor_enrollment(socket) do
    assign_new(socket, :instructor_enrollment, fn ->
      Helpers.get_instructor_enrollment(socket.assigns.section, socket.assigns.current_user)
    end)
  end

  defp resolve_scope(params, enrollment) do
    case params["dashboard_scope"] do
      nil -> enrollment |> last_viewed_scope() |> normalize_scope_selector()
      scope_selector -> normalize_scope_selector(scope_selector)
    end
  end

  defp normalize_scope_selector(nil), do: "course"

  defp normalize_scope_selector(scope_selector) do
    scope_selector
    |> parse_scope()
    |> scope_selector()
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
end
