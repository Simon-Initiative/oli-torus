defmodule OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab do
  @moduledoc """
  Intelligent Dashboard tab orchestration helpers for `Insights > Dashboard`.

  This module groups the tab-specific behavior outside `InstructorDashboardLive`,
  including:

  - scope restoration/normalization and canonical URL helpers
  - tab-scoped assign initialization for coordinator/cache state
  - dashboard container navigation item shaping

  It is intentionally focused on the Intelligent Dashboard surface and should not
  absorb generic helpers for other Instructor Dashboard tabs.
  """

  require Logger

  alias Oli.InstructorDashboard, as: InstructorDashboardStateContext
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.Snapshot.Assembler
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.InstructorDashboard.DataSnapshot.Projections, as: InstructorProjections
  alias Oli.InstructorDashboard.OracleRegistry
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  import Phoenix.Component, only: [assign: 2, assign: 3, assign_new: 3, update: 3]

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
  @type student_support_tile_state :: %{
          selected_bucket_id: String.t() | nil,
          selected_activity_filter: :all | :active | :inactive,
          search_term: String.t(),
          page: pos_integer(),
          visible_count: pos_integer()
        }
  @type assessments_tile_state :: %{
          expanded_assessment_id: pos_integer() | nil
        }
  @dashboard_container_levels [1, 2, 3]
  @support_page_size 20

  @doc """
  Lazily initializes dashboard-tab-specific assigns for the current LiveView session.
  """
  @spec ensure_initialized(socket()) :: socket()
  def ensure_initialized(socket) do
    socket
    |> assign_new(:dashboard_store, fn -> start_inprocess_store() end)
    |> assign_new(:dashboard_revisit_cache, fn -> RevisitCache end)
    |> assign_new(:dashboard_revisit_hydrated?, fn -> false end)
    |> assign_new(:dashboard_coordinator_state, fn ->
      Oli.Dashboard.LiveDataCoordinator.new_session()
    end)
    |> assign_new(:dashboard_bundle_state, fn -> nil end)
    |> assign_new(:dashboard_oracle_results, fn -> %{} end)
    |> assign_new(:dashboard_timeout_refs, fn -> %{} end)
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
  @spec path(socket(), scope_selector(), map()) :: String.t()
  def path(socket, scope_selector, extra_params \\ %{}) do
    params =
      socket
      |> dashboard_base_params(scope_selector)
      |> merge_dashboard_params(extra_params)

    path_for_section(socket.assigns.section.slug, scope_selector, params)
  end

  @doc """
  Builds the canonical dashboard path for a given section slug and scope selector.
  """
  @spec path_for_section(String.t(), scope_selector(), map()) :: String.t()
  def path_for_section(section_slug, scope_selector, params \\ %{}) do
    encoded_params =
      params
      |> normalize_dashboard_path_params(scope_selector)
      |> Plug.Conn.Query.encode()

    "/sections/#{section_slug}/instructor_dashboard/insights/dashboard?#{encoded_params}"
  end

  @doc """
  Parses a scope selector into the dashboard scope request shape.
  """
  @spec parse_scope(scope_selector() | nil) :: scope()
  def parse_scope("course"), do: %{container_type: :course, container_id: nil}

  def parse_scope("container:" <> id) do
    case Integer.parse(id) do
      {parsed, ""} when parsed > 0 -> %{container_type: :container, container_id: parsed}
      _ -> %{container_type: :course, container_id: nil}
    end
  end

  def parse_scope(_), do: %{container_type: :course, container_id: nil}

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

  @doc """
  Handles `insights/dashboard` params by canonicalizing scope and loading dashboard state.
  """
  @spec handle_dashboard_params(socket(), map()) :: {:noreply, socket()}
  def handle_dashboard_params(socket, params) do
    {socket, scope_selector} = resolve_scope_context(socket, params)

    case params["dashboard_scope"] do
      nil ->
        {:noreply, Phoenix.LiveView.push_patch(socket, to: path(socket, scope_selector))}

      ^scope_selector ->
        persist_scope(socket.assigns[:instructor_enrollment], scope_selector)
        {:noreply, assign_dashboard_tab(socket, params, scope_selector)}

      _invalid_or_stale_scope ->
        {:noreply, Phoenix.LiveView.push_patch(socket, to: path(socket, scope_selector))}
    end
  end

  @doc """
  Applies a section expand/collapse toggle, persists the resulting layout, and rolls back
  the assigns if persistence fails.
  """
  @spec handle_section_toggled(socket(), String.t(), boolean()) ::
          {:ok, socket()}
          | {:error, :save_failed, socket()}
          | {:error, :unknown_section, socket()}
  def handle_section_toggled(socket, section_id, expanded?) do
    if section_id in dashboard_section_ids(socket) do
      previous_sections = socket.assigns.dashboard_visible_sections
      previous_collapsed_section_ids = socket.assigns.dashboard_collapsed_section_ids

      collapsed_section_ids =
        socket.assigns.dashboard_collapsed_section_ids
        |> update_collapsed_sections(section_id, expanded?)

      socket =
        assign(socket,
          dashboard_collapsed_section_ids: collapsed_section_ids,
          dashboard_visible_sections:
            update_dashboard_section_expansion(previous_sections, section_id, expanded?)
        )

      case persist_dashboard_layout(socket) do
        {:ok, socket} ->
          {:ok, socket}

        {:error, socket} ->
          {:error, :save_failed,
           socket
           |> assign(:dashboard_collapsed_section_ids, previous_collapsed_section_ids)
           |> assign(:dashboard_visible_sections, previous_sections)}
      end
    else
      {:error, :unknown_section, socket}
    end
  end

  @doc """
  Applies a dashboard section reorder, persists the resulting layout, and rolls back
  the assigns if persistence fails.
  """
  @spec handle_sections_reordered(socket(), [String.t()]) ::
          {:ok, socket()} | {:error, :invalid_order, socket()} | {:error, :save_failed, socket()}
  def handle_sections_reordered(socket, section_ids) when is_list(section_ids) do
    if valid_dashboard_section_order?(socket, section_ids) do
      previous_sections = socket.assigns.dashboard_visible_sections
      previous_order = socket.assigns.dashboard_section_order

      socket =
        assign(socket,
          dashboard_section_order: section_ids,
          dashboard_visible_sections: reorder_dashboard_sections(previous_sections, section_ids)
        )

      case persist_dashboard_layout(socket) do
        {:ok, socket} ->
          {:ok, socket}

        {:error, socket} ->
          {:error, :save_failed,
           socket
           |> assign(:dashboard_section_order, previous_order)
           |> assign(:dashboard_visible_sections, previous_sections)}
      end
    else
      {:error, :invalid_order, socket}
    end
  end

  @doc """
  Handles dashboard request timeout messages and applies coordinator timeout actions.
  """
  @spec handle_dashboard_request_timeout(socket(), non_neg_integer()) :: {:noreply, socket()}
  def handle_dashboard_request_timeout(socket, request_token) do
    scope = parse_scope(Map.get(socket.assigns, :dashboard_scope, "course"))

    with {:ok, context} <- dashboard_context(socket, scope),
         {:ok, dependency_profile} <- dashboard_dependency_profile() do
      case LiveDataCoordinator.handle_request_timeout(
             socket.assigns.dashboard_coordinator_state,
             request_token,
             coordinator_opts(context, dashboard_cache_opts(socket))
           ) do
        {:ok, coordinator_state, actions} ->
          {:noreply,
           socket
           |> assign(:dashboard_coordinator_state, coordinator_state)
           |> apply_dashboard_coordinator_actions(actions, context, dependency_profile)}

        {:error, _reason, coordinator_state, _actions} ->
          {:noreply, assign(socket, :dashboard_coordinator_state, coordinator_state)}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, :dashboard, dashboard_error_payload(reason))}
    end
  end

  @doc """
  Handles async runtime oracle results and applies coordinator actions.
  """
  @spec handle_dashboard_runtime_oracle_result(
          socket(),
          non_neg_integer(),
          map(),
          atom(),
          map()
        ) :: {:noreply, socket()}
  def handle_dashboard_runtime_oracle_result(
        socket,
        request_token,
        context,
        oracle_key,
        oracle_result
      ) do
    with {:ok, dependency_profile} <- dashboard_dependency_profile() do
      case LiveDataCoordinator.handle_oracle_result(
             socket.assigns.dashboard_coordinator_state,
             request_token,
             oracle_key,
             oracle_result,
             coordinator_opts(context, dashboard_cache_opts(socket))
           ) do
        {:ok, coordinator_state, actions} ->
          {:noreply,
           socket
           |> assign(:dashboard_coordinator_state, coordinator_state)
           |> apply_dashboard_coordinator_actions(actions, context, dependency_profile)}

        {:error, reason, coordinator_state, _actions} ->
          {:noreply,
           socket
           |> assign(:dashboard_coordinator_state, coordinator_state)
           |> assign(:dashboard, dashboard_error_payload(reason))}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, :dashboard, dashboard_error_payload(reason))}
    end
  end

  defp assign_dashboard_tab(socket, params, scope_selector) do
    socket = ensure_initialized(socket)
    use_revisit? = not socket.assigns.dashboard_revisit_hydrated?
    {socket, dashboard_navigator_items} = ensure_dashboard_navigator_items(socket)
    layout_state = current_layout_state(socket)
    student_support_tile_state = parse_student_support_tile_state(params)
    assessments_tile_state = parse_assessments_tile_state(params)
    previous_scope = Map.get(socket.assigns, :dashboard_scope)
    current_projection = get_in(socket.assigns, [:dashboard, :student_support_projection])

    previous_expanded_assessment_id =
      socket.assigns
      |> Map.get(:assessments_tile_state, %{})
      |> Map.get(:expanded_assessment_id)

    socket =
      socket
      |> assign(
        params: dashboard_navigation_params(params, scope_selector),
        view: :insights,
        active_tab: :dashboard,
        dashboard_scope: scope_selector,
        instructor_enrollment: socket.assigns.instructor_enrollment,
        dashboard_navigator_items: dashboard_navigator_items,
        student_support_tile_state: student_support_tile_state,
        assessments_tile_state: assessments_tile_state
      )
      |> assign_dashboard_sections(layout_state)
      |> maybe_push_assessment_scroll(
        previous_expanded_assessment_id,
        assessments_tile_state.expanded_assessment_id
      )

    if reload_dashboard?(previous_scope, current_projection, scope_selector) do
      socket
      |> assign(:dashboard, dashboard_loading_payload())
      |> load_dashboard(use_revisit?: use_revisit?)
      |> assign(:dashboard_revisit_hydrated?, true)
    else
      Logger.debug(
        "intelligent_dashboard support tile patch reused current projection scope=#{inspect(scope_selector)}"
      )

      socket
    end
  end

  defp ensure_dashboard_navigator_items(socket) do
    section_id = socket.assigns.section.id

    # Cache navigator items by section id to avoid re-fetching and flattening
    # containers on every dashboard scope change or param patch.
    case {socket.assigns[:dashboard_navigator_section_id],
          socket.assigns[:dashboard_navigator_items]} do
      {^section_id, {_count, items} = navigator_items} when is_list(items) ->
        {socket, navigator_items}

      _ ->
        dashboard_navigator_items = navigator_items(socket.assigns.section)

        {socket
         |> assign(:dashboard_navigator_section_id, section_id)
         |> assign(:dashboard_navigator_items, dashboard_navigator_items),
         dashboard_navigator_items}
    end
  end

  defp load_dashboard(socket, opts) do
    scope_selector = Map.get(socket.assigns, :dashboard_scope, "course")
    scope = parse_scope(scope_selector)
    cache_opts = dashboard_cache_opts(socket)
    use_revisit? = Keyword.get(opts, :use_revisit?, true)

    with {:ok, context} <- dashboard_context(socket, scope),
         {:ok, dependency_profile} <- dashboard_dependency_profile() do
      revisit_hydration =
        case use_revisit? do
          true ->
            hydrate_required_from_revisit_cache(
              socket.assigns.dashboard_revisit_cache,
              context,
              scope,
              cache_opts
            )

          false ->
            %{source: :skipped, revisit_hits: 0, revisit_misses: 0}
        end

      case LiveDataCoordinator.request_scope_change(
             socket.assigns.dashboard_coordinator_state,
             scope,
             dependency_profile,
             coordinator_opts(context, cache_opts)
           ) do
        {:ok, coordinator_state, actions} ->
          socket
          |> assign(:dashboard_revisit_hydration, revisit_hydration)
          |> assign(:dashboard_coordinator_state, coordinator_state)
          |> assign(:dashboard_oracle_results, %{})
          |> apply_dashboard_coordinator_actions(actions, context, dependency_profile)

        {:error, reason, coordinator_state, _actions} ->
          socket
          |> assign(:dashboard_coordinator_state, coordinator_state)
          |> assign(:dashboard, dashboard_error_payload(reason))
      end
    else
      {:error, reason} ->
        assign(socket, :dashboard, dashboard_error_payload(reason))
    end
  end

  defp dashboard_context(socket, scope) do
    case dashboard_user_id(socket) do
      user_id when is_integer(user_id) ->
        {:ok,
         %{
           dashboard_context_type: :section,
           dashboard_context_id: socket.assigns.section.id,
           user_id: user_id,
           scope: scope
         }}

      _ ->
        {:error, :missing_user_id}
    end
  end

  defp dashboard_user_id(socket) do
    cond do
      is_map(socket.assigns[:current_user]) and is_integer(socket.assigns.current_user.id) ->
        socket.assigns.current_user.id

      is_map(socket.assigns[:ctx]) and is_integer(socket.assigns.ctx.user_id) ->
        socket.assigns.ctx.user_id

      true ->
        nil
    end
  end

  defp dashboard_cache_opts(socket) do
    [inprocess_store: socket.assigns.dashboard_store]
  end

  defp hydrate_required_from_revisit_cache(revisit_cache, context, scope, cache_opts) do
    with {:ok, required_keys} <- dashboard_required_oracle_keys(),
         {:ok, lookup} <-
           Cache.lookup_revisit(context.user_id, context, scope, required_keys,
             revisit_cache: revisit_cache,
             revisit_eligible: true
           ) do
      Enum.each(lookup.hits, fn {oracle_key, payload} ->
        _ =
          Cache.write_oracle(
            context,
            scope,
            oracle_key,
            payload,
            dashboard_cache_meta(oracle_key),
            cache_opts
          )
      end)

      %{
        source: lookup.source,
        revisit_hits: map_size(lookup.hits),
        revisit_misses: length(lookup.misses)
      }
    else
      _ ->
        %{source: :none, revisit_hits: 0, revisit_misses: 0}
    end
  end

  defp dashboard_required_oracle_keys do
    with {:ok, progress} <- OracleRegistry.dependencies_for(:progress_summary),
         {:ok, support} <- OracleRegistry.dependencies_for(:support_summary) do
      {:ok, Enum.uniq(progress.required ++ support.required)}
    end
  end

  @doc """
  Parses the namespaced URL-backed state for the Student Support tile.
  """
  @spec parse_student_support_tile_state(map()) :: student_support_tile_state()
  def parse_student_support_tile_state(params) when is_map(params) do
    tile_params =
      case Map.get(params, "tile_support", %{}) do
        value when is_map(value) -> value
        _ -> %{}
      end

    page = normalize_positive_integer(Map.get(tile_params, "page"), 1)

    %{
      selected_bucket_id: normalize_selected_bucket_id(Map.get(tile_params, "bucket")),
      selected_activity_filter: normalize_activity_filter(Map.get(tile_params, "filter")),
      search_term: normalize_search_term(Map.get(tile_params, "q")),
      page: page,
      visible_count: page * @support_page_size
    }
  end

  def parse_student_support_tile_state(_), do: parse_student_support_tile_state(%{})

  @doc """
  Parses the namespaced URL-backed state for the Assessments tile.
  """
  @spec parse_assessments_tile_state(map()) :: assessments_tile_state()
  def parse_assessments_tile_state(params) when is_map(params) do
    tile_params =
      case Map.get(params, "tile_assessments", %{}) do
        value when is_map(value) -> value
        _ -> %{}
      end

    %{
      expanded_assessment_id: normalize_assessment_id(Map.get(tile_params, "expanded"))
    }
  end

  def parse_assessments_tile_state(_), do: parse_assessments_tile_state(%{})

  @doc """
  Builds a dashboard path with merged Student Support tile params.
  """
  @spec student_support_path(socket(), map()) :: String.t()
  def student_support_path(socket, updates) when is_map(updates) do
    scope_selector = Map.get(socket.assigns, :dashboard_scope, "course")
    params = dashboard_base_params(socket, scope_selector)
    current = Map.get(params, "tile_support", %{})

    merged_tile_params =
      current
      |> Map.merge(stringify_keys(updates))
      |> normalize_student_support_path_params()

    params = put_student_support_params(params, merged_tile_params)

    path_for_section(socket.assigns.section.slug, scope_selector, params)
  end

  @doc """
  Builds a dashboard path with merged Assessments tile params.
  """
  @spec assessments_path(socket(), map()) :: String.t()
  def assessments_path(socket, updates) when is_map(updates) do
    scope_selector = Map.get(socket.assigns, :dashboard_scope, "course")
    params = dashboard_base_params(socket, scope_selector)
    current = Map.get(params, "tile_assessments", %{})

    merged_tile_params =
      current
      |> Map.merge(stringify_keys(updates))
      |> normalize_assessments_path_params()

    params = put_assessments_params(params, merged_tile_params)

    path_for_section(socket.assigns.section.slug, scope_selector, params)
  end

  defp persist_revisit_cache(nil, _context, _scope, _oracles), do: :ok

  defp persist_revisit_cache(revisit_cache, context, scope, oracles) when is_map(oracles) do
    Enum.each(oracles, fn {oracle_key, payload} ->
      meta = dashboard_cache_meta(oracle_key)

      with {:ok, revisit_key} <- Key.revisit(context.user_id, context, scope, oracle_key, meta) do
        _ =
          try do
            RevisitCache.write(revisit_cache, revisit_key, payload)
          catch
            :exit, _ -> :ok
          end
      end
    end)
  end

  defp persist_revisit_cache(_revisit_cache, _context, _scope, _oracles), do: :ok

  defp apply_dashboard_coordinator_actions(socket, actions, context, dependency_profile) do
    Enum.reduce(actions, socket, fn action, acc ->
      apply_dashboard_coordinator_action(acc, action, context, dependency_profile)
    end)
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :request_started, request_token: request_token},
         _context,
         _dependency_profile
       ) do
    cancel_dashboard_timeout(socket, request_token)
    |> assign(:dashboard_request_token, request_token)
    |> assign(:dashboard_bundle_state, nil)
    |> assign(:dashboard_oracle_results, %{})
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :request_promoted, request_token: request_token},
         _context,
         _dependency_profile
       ) do
    cancel_dashboard_timeout(socket, request_token)
    |> assign(:dashboard_request_token, request_token)
    |> assign(:dashboard_bundle_state, nil)
    |> assign(:dashboard_oracle_results, %{})
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :timeout_scheduled, request_token: request_token, timeout_ms: timeout_ms},
         _context,
         _dependency_profile
       ) do
    ref = Process.send_after(self(), {:dashboard_request_timeout, request_token}, timeout_ms)
    update(socket, :dashboard_timeout_refs, &Map.put(&1, request_token, ref))
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :timeout_cancelled, request_token: request_token},
         _context,
         _dependency_profile
       ) do
    cancel_dashboard_timeout(socket, request_token)
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{
           type: :emit_required_ready,
           request_token: request_token,
           hits: hits,
           cache_source: source
         },
         context,
         dependency_profile
       ) do
    if active_dashboard_request?(socket, request_token) do
      # Required-ready is a stable milestone: enough data exists to build a useful
      # partial dashboard. We intentionally rebuild here to hydrate tiles early.
      oracle_results =
        Enum.reduce(hits, socket.assigns.dashboard_oracle_results, fn {oracle_key, payload},
                                                                      acc ->
          Map.put(acc, oracle_key, cache_hit_result(oracle_key, payload, source))
        end)

      socket
      |> assign(:dashboard_oracle_results, oracle_results)
      |> maybe_assign_dashboard_bundle(request_token, context, dependency_profile)
    else
      socket
    end
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :emit_loading, request_token: request_token},
         _context,
         _dependency_profile
       ) do
    if active_dashboard_request?(socket, request_token) do
      # Loading can fire frequently while oracles trickle in. Rebuilding the entire
      # snapshot/projection graph here adds churn with little UX value, so we no-op.
      socket
    else
      socket
    end
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :runtime_start, request_token: request_token, misses: misses},
         context,
         _dependency_profile
       ) do
    start_dashboard_runtime_loads(request_token, misses, context)
    socket
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{
           type: :oracle_result_received,
           token_state: :active,
           oracle_key: oracle_key,
           oracle_result: oracle_result
         },
         context,
         dependency_profile
       ) do
    # Oracle results may arrive one-by-one; storing them avoids lost work while
    # deferring unrelated projection work until the affected capability changes.
    socket
    |> update(:dashboard_oracle_results, &Map.put(&1, oracle_key, oracle_result))
    |> maybe_assign_incremental_dashboard_bundle(context, dependency_profile, oracle_key)
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :request_completed, request_token: request_token},
         context,
         dependency_profile
       ) do
    # Completion is the final milestone for the active request; rebuild once to
    # publish the fully resolved dashboard payload.
    socket
    |> cancel_dashboard_timeout(request_token)
    |> maybe_assign_dashboard_bundle(request_token, context, dependency_profile)
    |> assign(:dashboard_revisit_hydrated?, true)
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :emit_timeout_fallback, request_token: request_token},
         _context,
         _dependency_profile
       ) do
    if active_dashboard_request?(socket, request_token) do
      assign(socket, :dashboard, dashboard_error_payload(:timeout))
    else
      socket
    end
  end

  defp apply_dashboard_coordinator_action(socket, _action, _context, _dependency_profile),
    do: socket

  defp maybe_assign_dashboard_bundle(socket, request_token, context, dependency_profile) do
    if active_dashboard_request?(socket, request_token) do
      case build_dashboard_bundle(
             context,
             request_token,
             socket.assigns.dashboard_oracle_results,
             dependency_profile,
             dashboard_timezone(socket)
           ) do
        {:ok, bundle} ->
          persist_revisit_cache(
            socket.assigns.dashboard_revisit_cache,
            context,
            context.scope,
            bundle.snapshot.oracles
          )

          assign(
            socket,
            dashboard_bundle_state: bundle,
            dashboard: build_dashboard_payload(bundle, socket.assigns.dashboard_revisit_hydration)
          )

        {:error, reason} ->
          assign(socket, :dashboard, dashboard_error_payload(reason))
      end
    else
      socket
    end
  end

  defp maybe_assign_incremental_dashboard_bundle(socket, context, dependency_profile, oracle_key) do
    affected_capabilities = InstructorProjections.affected_capabilities(oracle_key)

    if affected_capabilities == [] do
      socket
    else
      request_token = Map.get(socket.assigns, :dashboard_request_token)

      case build_dashboard_snapshot(
             context,
             request_token,
             socket.assigns.dashboard_oracle_results,
             dependency_profile,
             dashboard_timezone(socket)
           ) do
        {:ok, snapshot} ->
          bundle =
            merge_incremental_bundle(
              socket,
              snapshot,
              context,
              dependency_profile,
              affected_capabilities
            )

          socket
          |> assign(:dashboard_bundle_state, bundle)
          |> update_dashboard_payload(bundle)

        {:error, _reason} ->
          socket
      end
    end
  end

  defp merge_incremental_bundle(
         socket,
         snapshot,
         context,
         dependency_profile,
         affected_capabilities
       ) do
    # Preserve already-derived projections and only re-run the capabilities touched
    # by the newly resolved oracle. This keeps independent tiles from waiting on or
    # recomputing unrelated dashboard capabilities.
    existing_bundle = Map.get(socket.assigns, :dashboard_bundle_state) || %{}
    existing_projections = Map.get(existing_bundle, :projections, %{})
    existing_statuses = Map.get(existing_bundle, :projection_statuses, %{})

    {projections, projection_statuses} =
      Enum.reduce(
        affected_capabilities,
        {existing_projections, existing_statuses},
        fn capability_key, {projection_acc, status_acc} ->
          case Projections.derive(capability_key, snapshot) do
            {:ok, projection, status} ->
              next_projections =
                if projection == %{} do
                  Map.delete(projection_acc, capability_key)
                else
                  Map.put(projection_acc, capability_key, projection)
                end

              {next_projections, Map.put(status_acc, capability_key, status)}

            {:error, _reason} ->
              {projection_acc, status_acc}
          end
        end
      )

    %{
      snapshot: %{snapshot | projections: projections, projection_statuses: projection_statuses},
      projections: projections,
      projection_statuses: projection_statuses,
      context: context,
      scope: context.scope,
      request_token: snapshot.request_token,
      dependency_profile: dependency_profile
    }
  end

  defp update_dashboard_payload(socket, bundle) do
    payload = build_dashboard_payload(bundle, socket.assigns.dashboard_revisit_hydration)
    projections = Map.get(bundle, :projections, %{})

    update(socket, :dashboard, fn current ->
      current = current || %{}

      # Only publish fields backed by projections that are currently present. This
      # keeps LiveView diffs tighter when one tile becomes ready before another.
      current
      |> Map.put(:runtime_status_text, Map.get(payload, :runtime_status_text))
      |> maybe_put_dashboard_field(
        :progress_text,
        Map.get(payload, :progress_text),
        :progress in Map.keys(projections)
      )
      |> maybe_put_dashboard_field(
        :student_support_text,
        Map.get(payload, :student_support_text),
        :student_support in Map.keys(projections)
      )
      |> maybe_put_dashboard_field(
        :student_support_projection,
        Map.get(payload, :student_support_projection),
        :student_support in Map.keys(projections)
      )
      |> maybe_put_dashboard_field(
        :assessments_text,
        Map.get(payload, :assessments_text),
        :assessments in Map.keys(projections)
      )
      |> maybe_put_dashboard_field(
        :assessments_projection,
        Map.get(payload, :assessments_projection),
        :assessments in Map.keys(projections)
      )
    end)
  end

  defp build_dashboard_snapshot(
         context,
         request_token,
         oracle_results,
         dependency_profile,
         timezone
       ) do
    expected_oracles = dependency_profile.required ++ dependency_profile.optional

    Assembler.assemble(context, Integer.to_string(request_token), oracle_results,
      scope: context.scope,
      expected_oracles: expected_oracles,
      metadata: %{timezone: timezone, source: :instructor_insights}
    )
  end

  defp build_dashboard_bundle(
         context,
         request_token,
         oracle_results,
         dependency_profile,
         timezone
       ) do
    with {:ok, snapshot} <-
           build_dashboard_snapshot(
             context,
             request_token,
             oracle_results,
             dependency_profile,
             timezone
           ),
         {:ok, %{projections: projection_map, statuses: projection_statuses}} <-
           Projections.derive_all(snapshot) do
      {:ok,
       %{
         snapshot: %{
           snapshot
           | projections: projection_map,
             projection_statuses: projection_statuses
         },
         projections: projection_map,
         projection_statuses: projection_statuses,
         context: context,
         scope: context.scope,
         request_token: Integer.to_string(request_token),
         dependency_profile: dependency_profile
       }}
    end
  end

  defp dashboard_runtime_result(oracle_key, context) do
    case OracleRegistry.oracle_module(oracle_key) do
      {:ok, module} ->
        load_oracle_result(module, oracle_key, context)

      {:error, reason} ->
        Result.error(oracle_key, reason)
    end
  end

  defp load_oracle_result(module, oracle_key, context) do
    case OracleContext.new(context) do
      {:ok, oracle_context} ->
        case module.load(oracle_context, []) do
          {:ok, payload} ->
            Result.ok(oracle_key, payload,
              version: oracle_version(module),
              metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
            )

          {:error, reason} ->
            Result.error(oracle_key, reason,
              version: oracle_version(module),
              metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
            )
        end

      {:error, reason} ->
        Result.error(oracle_key, {:invalid_oracle_context, reason},
          version: oracle_version(module),
          metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
        )
    end
  end

  defp cache_hit_result(oracle_key, payload, cache_source) do
    version =
      case OracleRegistry.oracle_module(oracle_key) do
        {:ok, module} -> oracle_version(module)
        _ -> 1
      end

    Result.ok(oracle_key, payload,
      version: version,
      metadata: %{
        source: :cache,
        cache_source: normalize_cache_source(cache_source),
        dashboard_product: :instructor_dashboard
      }
    )
  end

  defp start_dashboard_runtime_loads(request_token, misses, context) do
    live_view_pid = self()

    Task.start(fn ->
      misses
      |> Task.async_stream(
        fn oracle_key -> {oracle_key, dashboard_runtime_result(oracle_key, context)} end,
        max_concurrency: dashboard_runtime_max_concurrency(),
        ordered: false,
        timeout: :infinity
      )
      |> Enum.each(fn
        {:ok, {oracle_key, oracle_result}} ->
          send(
            live_view_pid,
            {:dashboard_runtime_oracle_result, request_token, context, oracle_key, oracle_result}
          )

        {:exit, _reason} ->
          :ok
      end)
    end)
  end

  defp dashboard_runtime_max_concurrency, do: 4

  defp dashboard_dependency_profile do
    case OracleRegistry.dependencies_for(:progress_summary) do
      {:ok, progress} ->
        case OracleRegistry.dependencies_for(:support_summary) do
          {:ok, support} ->
            case OracleRegistry.dependencies_for(:assessments_summary) do
              {:ok, assessments} ->
                {:ok,
                 %{
                   required:
                     Enum.uniq(progress.required ++ support.required ++ assessments.required),
                   optional:
                     Enum.uniq(
                       progress.optional ++
                         support.optional ++ assessments.optional
                     )
                 }}

              {:error, reason} ->
                {:error, {:dependency_profile_unavailable, :assessments_summary, reason}}

              other ->
                {:error, {:dependency_profile_unavailable, :assessments_summary, other}}
            end

          {:error, reason} ->
            {:error, {:dependency_profile_unavailable, :support_summary, reason}}

          other ->
            {:error, {:dependency_profile_unavailable, :support_summary, other}}
        end

      {:error, reason} ->
        {:error, {:dependency_profile_unavailable, :progress_summary, reason}}

      other ->
        {:error, {:dependency_profile_unavailable, :progress_summary, other}}
    end
  end

  defp coordinator_opts(context, cache_opts) do
    [
      context: context,
      cache_module: Cache,
      cache_opts: cache_opts,
      dashboard_product: :instructor_dashboard
    ]
  end

  defp active_dashboard_request?(socket, request_token) do
    Map.get(socket.assigns, :dashboard_request_token) == request_token
  end

  defp cancel_dashboard_timeout(socket, request_token) do
    case get_in(socket.assigns, [:dashboard_timeout_refs, request_token]) do
      nil ->
        socket

      ref ->
        Process.cancel_timer(ref)
        update(socket, :dashboard_timeout_refs, &Map.delete(&1, request_token))
    end
  end

  defp oracle_version(module) do
    if function_exported?(module, :version, 0), do: module.version(), else: 1
  end

  defp dashboard_cache_meta(oracle_key) do
    oracle_version =
      case OracleRegistry.oracle_module(oracle_key) do
        {:ok, module} -> oracle_version(module)
        _ -> 1
      end

    %{oracle_version: oracle_version, data_version: 1}
  end

  defp dashboard_timezone(socket) do
    case Map.get(socket.assigns, :browser_timezone) do
      timezone when is_binary(timezone) and timezone != "" -> timezone
      _ -> "Etc/UTC"
    end
  end

  # TODO(intelligent-dashboard): Prototype-only data-validation payload helpers.
  # Remove these helpers once the epic is fully implemented and tile groups/tiles
  # consume typed projection data directly instead of debug text payloads:
  # build_dashboard_payload/2, dashboard_cache_stats/3, count_oracle_sources/2,
  # ratio/2, percent/1, summarize_projection_statuses/1,
  # dashboard_oracle_sources/1, dashboard_error_payload/1.
  defp build_dashboard_payload(bundle, revisit_hydration) do
    progress_projection = Map.get(bundle.projections, :progress, %{})
    support_projection = Map.get(bundle.projections, :student_support, %{})
    assessments_projection = Map.get(bundle.projections, :assessments, %{})
    oracle_sources = dashboard_oracle_sources(bundle.snapshot.oracle_statuses)

    cache_stats =
      dashboard_cache_stats(bundle, bundle.snapshot.oracle_statuses, revisit_hydration)

    projection_statuses = summarize_projection_statuses(bundle.projection_statuses)

    status_lines = [
      "ORACLE RESOLUTION",
      "  cache-backed: #{cache_stats.cache_backed_hits}/#{cache_stats.snapshot_total} (#{percent(cache_stats.cache_backed_hit_rate)})",
      "  runtime fallback: #{cache_stats.runtime_fallbacks}/#{cache_stats.snapshot_total} (#{percent(cache_stats.runtime_fallback_rate)})",
      "  unresolved after runtime: #{cache_stats.unresolved_oracles}/#{cache_stats.snapshot_total} (#{percent(cache_stats.unresolved_rate)})",
      "  cache source mix: #{inspect(cache_stats.cache_source_mix)}",
      "",
      "REVISIT CACHE (PRE-HYDRATION)",
      "  source: #{revisit_hydration.source}",
      "  hits: #{cache_stats.revisit_hits}/#{cache_stats.revisit_total} (#{percent(cache_stats.revisit_hit_rate)})",
      "  misses: #{cache_stats.revisit_misses}/#{cache_stats.revisit_total} (#{percent(1.0 - cache_stats.revisit_hit_rate)})",
      "",
      "REQUEST",
      "  token: #{bundle.request_token}",
      "  scope: #{inspect(bundle.scope)}",
      "",
      "PROJECTIONS",
      "  statuses: #{inspect(projection_statuses)}",
      "",
      "ORACLES",
      "  sources: #{inspect(oracle_sources)}"
    ]

    %{
      runtime_status_text: Enum.join(status_lines, "\n"),
      progress_text: inspect(progress_projection, pretty: true, limit: :infinity),
      student_support_text: inspect(support_projection, pretty: true, limit: :infinity),
      student_support_projection: Map.get(support_projection, :support, %{}),
      assessments_text: inspect(assessments_projection, pretty: true, limit: :infinity),
      assessments_projection: Map.get(assessments_projection, :assessments, %{}),
      objectives_text: "Waiting for scoped data"
    }
  end

  defp dashboard_cache_stats(bundle, oracle_statuses, revisit_hydration) do
    expected_oracles =
      bundle.dependency_profile.required
      |> Kernel.++(bundle.dependency_profile.optional)
      |> Enum.uniq()
      |> length()

    source_counts = count_oracle_sources(oracle_statuses)
    cache_hits = source_counts.cache
    runtime_fallbacks = source_counts.runtime
    unresolved = max(expected_oracles - cache_hits - runtime_fallbacks, 0)

    revisit_hits = Map.get(revisit_hydration, :revisit_hits, 0)
    revisit_misses = Map.get(revisit_hydration, :revisit_misses, 0)

    %{
      cache_backed_hits: cache_hits,
      cache_backed_hit_rate: ratio(cache_hits, expected_oracles),
      runtime_fallbacks: runtime_fallbacks,
      runtime_fallback_rate: ratio(runtime_fallbacks, expected_oracles),
      unresolved_oracles: unresolved,
      unresolved_rate: ratio(unresolved, expected_oracles),
      cache_source_mix: source_counts.cache_source_mix,
      revisit_hits: revisit_hits,
      revisit_misses: revisit_misses,
      revisit_total: revisit_hits + revisit_misses,
      revisit_hit_rate: ratio(revisit_hits, revisit_hits + revisit_misses),
      snapshot_total: expected_oracles
    }
  end

  defp count_oracle_sources(oracle_statuses) when is_map(oracle_statuses) do
    Enum.reduce(oracle_statuses, %{cache: 0, runtime: 0, cache_source_mix: %{}}, fn
      {_oracle_key, %{metadata: %{source: :cache} = metadata}}, acc ->
        cache_source = Map.get(metadata, :cache_source, :unknown)

        %{
          acc
          | cache: acc.cache + 1,
            cache_source_mix: Map.update(acc.cache_source_mix, cache_source, 1, &(&1 + 1))
        }

      {_oracle_key, %{metadata: %{source: :runtime}}}, acc ->
        %{acc | runtime: acc.runtime + 1}

      {_oracle_key, _status}, acc ->
        acc
    end)
  end

  defp count_oracle_sources(_), do: %{cache: 0, runtime: 0, cache_source_mix: %{}}

  defp ratio(_num, 0), do: 0.0
  defp ratio(num, den), do: Float.round(num / den, 4)

  defp percent(rate) when is_number(rate) do
    "#{Float.round(rate * 100.0, 1)}%"
  end

  defp summarize_projection_statuses(projection_statuses) when is_map(projection_statuses) do
    Enum.into(projection_statuses, %{}, fn {projection_key, status} ->
      {projection_key, Map.get(status, :status, :unknown)}
    end)
  end

  defp summarize_projection_statuses(_), do: %{}

  defp dashboard_oracle_sources(oracle_statuses) when is_map(oracle_statuses) do
    Enum.into(oracle_statuses, %{}, fn {oracle_key, status} ->
      metadata = Map.get(status, :metadata, %{})

      source =
        case {Map.get(metadata, :source, :unknown), Map.get(metadata, :cache_source)} do
          {:cache, cache_source} when cache_source in [:inprocess, :revisit, :mixed] ->
            "cache/#{cache_source}"

          {source, _cache_source} ->
            source
        end

      {oracle_key, source}
    end)
  end

  defp dashboard_oracle_sources(_), do: %{}

  defp normalize_cache_source(value) when value in [:inprocess, :revisit, :mixed, :none],
    do: value

  defp normalize_cache_source(_), do: :unknown

  defp maybe_put_dashboard_field(map, _key, _value, false), do: map
  defp maybe_put_dashboard_field(map, key, value, true), do: Map.put(map, key, value)

  defp dashboard_loading_payload do
    %{
      runtime_status_text: "Loading...",
      progress_text: "Loading...",
      student_support_text: "Loading...",
      student_support_projection: %{},
      objectives_text: "Loading...",
      assessments_text: "Loading...",
      assessments_projection: %{}
    }
  end

  defp dashboard_error_payload(reason) do
    %{
      runtime_status_text: "snapshot load failed:\n#{inspect(reason, pretty: true)}",
      progress_text: "unavailable",
      student_support_text: "unavailable",
      student_support_projection: %{},
      objectives_text: "unavailable",
      assessments_text: "unavailable",
      assessments_projection: %{}
    }
  end

  defp reload_dashboard?(previous_scope, current_projection, scope_selector) do
    previous_scope != scope_selector or not is_map(current_projection) or
      current_projection == %{}
  end

  defp dashboard_navigation_params(params, scope_selector) do
    params
    |> stringify_keys()
    |> Enum.filter(fn {key, _value} ->
      key == "dashboard_scope" or String.starts_with?(key, "tile_")
    end)
    |> Map.new()
    |> normalize_dashboard_path_params(scope_selector)
  end

  defp normalize_dashboard_path_params(params, scope_selector) do
    params
    |> stringify_keys()
    |> Map.put("dashboard_scope", scope_selector)
    |> then(fn params ->
      case normalize_student_support_path_params(Map.get(params, "tile_support")) do
        tile_support when map_size(tile_support) == 0 -> Map.delete(params, "tile_support")
        tile_support -> Map.put(params, "tile_support", tile_support)
      end
    end)
    |> then(fn params ->
      case normalize_assessments_path_params(Map.get(params, "tile_assessments")) do
        tile_assessments when map_size(tile_assessments) == 0 ->
          Map.delete(params, "tile_assessments")

        tile_assessments ->
          Map.put(params, "tile_assessments", tile_assessments)
      end
    end)
  end

  defp dashboard_base_params(socket, scope_selector) do
    socket.assigns
    |> Map.get(:params, %{})
    |> dashboard_navigation_params(scope_selector)
  end

  defp merge_dashboard_params(current_params, extra_params) do
    current_params = stringify_keys(current_params)
    extra_params = stringify_keys(extra_params)

    Map.merge(current_params, extra_params, fn
      "tile_support", left, right when is_map(left) and is_map(right) ->
        Map.merge(left, right)

      "tile_assessments", left, right when is_map(left) and is_map(right) ->
        Map.merge(left, right)

      _key, _left, right ->
        right
    end)
  end

  defp put_student_support_params(params, tile_support) when is_map(tile_support) do
    if map_size(tile_support) == 0 do
      Map.delete(params, "tile_support")
    else
      Map.put(params, "tile_support", tile_support)
    end
  end

  defp put_assessments_params(params, tile_assessments) when is_map(tile_assessments) do
    if map_size(tile_assessments) == 0 do
      Map.delete(params, "tile_assessments")
    else
      Map.put(params, "tile_assessments", tile_assessments)
    end
  end

  defp normalize_student_support_path_params(nil), do: %{}

  defp normalize_student_support_path_params(tile_params) when is_map(tile_params) do
    tile_params
    |> stringify_keys()
    |> Enum.reduce(%{}, fn
      {"bucket", value}, acc ->
        case normalize_selected_bucket_id(value) do
          nil -> acc
          bucket_id -> Map.put(acc, "bucket", bucket_id)
        end

      {"filter", value}, acc ->
        case normalize_activity_filter(value) do
          :all -> acc
          filter -> Map.put(acc, "filter", Atom.to_string(filter))
        end

      {"page", value}, acc ->
        case normalize_positive_integer(value, 1) do
          1 -> acc
          page -> Map.put(acc, "page", Integer.to_string(page))
        end

      {"q", value}, acc ->
        case normalize_search_term(value) do
          "" -> acc
          term -> Map.put(acc, "q", term)
        end

      {_key, _value}, acc ->
        acc
    end)
  end

  defp normalize_student_support_path_params(_), do: %{}

  defp normalize_assessments_path_params(nil), do: %{}

  defp normalize_assessments_path_params(tile_params) when is_map(tile_params) do
    tile_params
    |> stringify_keys()
    |> Enum.reduce(%{}, fn
      {"expanded", value}, acc ->
        case normalize_assessment_id(value) do
          nil -> acc
          assessment_id -> Map.put(acc, "expanded", Integer.to_string(assessment_id))
        end

      {_key, _value}, acc ->
        acc
    end)
  end

  defp normalize_assessments_path_params(_), do: %{}

  defp normalize_selected_bucket_id(bucket_id)
       when bucket_id in ["struggling", "on_track", "excelling", "not_enough_information"],
       do: bucket_id

  defp normalize_selected_bucket_id(_), do: nil

  defp normalize_activity_filter(filter) when filter in ["all", :all, nil], do: :all
  defp normalize_activity_filter("active"), do: :active
  defp normalize_activity_filter("inactive"), do: :inactive
  defp normalize_activity_filter(:active), do: :active
  defp normalize_activity_filter(:inactive), do: :inactive
  defp normalize_activity_filter(_), do: :all

  defp normalize_search_term(term) when is_binary(term), do: String.trim(term)
  defp normalize_search_term(_), do: ""

  defp normalize_positive_integer(value, _fallback) when is_integer(value) and value > 0,
    do: value

  defp normalize_positive_integer(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> fallback
    end
  end

  defp normalize_positive_integer(_, fallback), do: fallback

  defp normalize_assessment_id(value), do: normalize_positive_integer(value, nil)

  defp maybe_push_assessment_scroll(
         socket,
         previous_expanded_assessment_id,
         expanded_assessment_id
       )
       when is_integer(expanded_assessment_id) and
              previous_expanded_assessment_id != expanded_assessment_id do
    Phoenix.LiveView.push_event(socket, "scroll-y-to-target", %{
      id: "learning-dashboard-assessment-card-#{expanded_assessment_id}",
      offset: 6,
      scroll_mode: "contain",
      scroll_delay: 120,
      offset_target_id: "instructor-dashboard-header"
    })
  end

  defp maybe_push_assessment_scroll(
         socket,
         _previous_expanded_assessment_id,
         _expanded_assessment_id
       ),
       do: socket

  defp stringify_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      key =
        case key do
          atom when is_atom(atom) -> Atom.to_string(atom)
          other -> other
        end

      value = if is_map(value), do: stringify_keys(value), else: value
      {key, value}
    end)
  end

  defp stringify_keys(other), do: other

  defp assign_dashboard_sections(socket, layout_state) do
    visible_sections = build_dashboard_visible_sections(socket, layout_state)

    socket
    |> assign(:dashboard_visible_sections, visible_sections)
    |> assign(:dashboard_section_order, Enum.map(visible_sections, & &1.id))
    |> assign(
      :dashboard_collapsed_section_ids,
      visible_sections
      |> Enum.reject(& &1.expanded)
      |> Enum.map(& &1.id)
    )
  end

  defp current_layout_state(socket) do
    case socket.assigns[:instructor_enrollment] do
      %{id: enrollment_id} ->
        InstructorDashboardStateContext.get_state_by_enrollment_id(enrollment_id)

      _ ->
        nil
    end
  end

  defp build_dashboard_visible_sections(socket, layout_state) do
    scope = parse_scope(Map.get(socket.assigns, :dashboard_scope, "course"))
    default_sections = default_dashboard_sections(socket.assigns.section, scope)
    default_section_ids = Enum.map(default_sections, & &1.id)

    %{section_order: ordered_ids, collapsed_section_ids: collapsed_ids} =
      InstructorDashboardStateContext.resolve_section_layout(layout_state, default_section_ids)

    sections_by_id = Map.new(default_sections, &{&1.id, &1})

    Enum.map(ordered_ids, fn section_id ->
      sections_by_id
      |> Map.fetch!(section_id)
      |> Map.put(:expanded, section_id not in collapsed_ids)
    end)
  end

  defp default_dashboard_sections(section, scope) do
    [
      %{
        id: "engagement",
        title: "Engagement",
        tiles: [%{id: "progress"}, %{id: "student_support"}]
      },
      %{
        id: "content",
        title: "Content",
        tiles:
          [
            if(has_objectives_tile?(section, scope), do: %{id: "objectives"}),
            if(has_assessments_tile?(section, scope), do: %{id: "assessments"})
          ]
          |> Enum.reject(&is_nil/1)
      }
    ]
    |> Enum.reject(&(Map.get(&1, :tiles, []) == []))
  end

  defp has_objectives_tile?(section, %{container_type: :course}) do
    Sections.get_section_contained_objectives(section.id, nil) != []
  end

  defp has_objectives_tile?(section, %{container_type: :container, container_id: container_id}) do
    Sections.get_section_contained_objectives(section.id, container_id) != []
  end

  defp has_assessments_tile?(section, %{container_type: :course}) do
    Sections.section_container_has_graded_pages?(section.id)
  end

  defp has_assessments_tile?(section, %{container_type: :container, container_id: container_id}) do
    Sections.section_container_has_graded_pages?(section.id, container_id)
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

  defp persist_dashboard_layout(socket) do
    case socket.assigns[:instructor_enrollment] do
      %{id: enrollment_id} ->
        case InstructorDashboardStateContext.upsert_state(enrollment_id, %{
               section_order: socket.assigns.dashboard_section_order,
               collapsed_section_ids: socket.assigns.dashboard_collapsed_section_ids
             }) do
          {:ok, _state} -> {:ok, socket}
          {:error, _changeset} -> {:error, socket}
        end

      _ ->
        {:ok, socket}
    end
  end

  defp dashboard_section_ids(socket) do
    Enum.map(socket.assigns.dashboard_visible_sections, & &1.id)
  end

  defp valid_dashboard_section_order?(socket, section_ids) do
    existing_ids = dashboard_section_ids(socket)
    Enum.sort(existing_ids) == Enum.sort(section_ids) and Enum.uniq(section_ids) == section_ids
  end

  defp reorder_dashboard_sections(sections, ordered_ids) do
    sections_by_id = Map.new(sections, &{&1.id, &1})
    Enum.map(ordered_ids, &Map.fetch!(sections_by_id, &1))
  end

  defp update_dashboard_section_expansion(sections, section_id, expanded?) do
    Enum.map(sections, fn section ->
      if section.id == section_id, do: %{section | expanded: expanded?}, else: section
    end)
  end

  defp update_collapsed_sections(collapsed_section_ids, section_id, true) do
    Enum.reject(collapsed_section_ids, &(&1 == section_id))
  end

  defp update_collapsed_sections(collapsed_section_ids, section_id, false) do
    Enum.uniq(collapsed_section_ids ++ [section_id])
  end

  defp start_inprocess_store do
    {:ok, pid} = InProcessStore.start_link([])
    pid
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
