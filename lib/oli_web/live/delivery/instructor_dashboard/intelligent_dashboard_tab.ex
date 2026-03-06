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

  alias Oli.InstructorDashboard, as: InstructorDashboardStateContext
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.Snapshot.Assembler
  alias Oli.Dashboard.Snapshot.Projections
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
  @dashboard_container_levels [1, 2, 3]

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
        {:noreply, assign_dashboard_tab(socket, params)}

      _invalid_or_stale_scope ->
        {:noreply, Phoenix.LiveView.push_patch(socket, to: path(socket, scope_selector))}
    end
  end

  @doc """
  Handles dashboard request timeout messages and applies coordinator timeout actions.
  """
  @spec handle_dashboard_request_timeout(socket(), non_neg_integer()) :: {:noreply, socket()}
  def handle_dashboard_request_timeout(socket, request_token) do
    scope = parse_scope(Map.get(socket.assigns, :dashboard_scope, "course"))
    context = dashboard_context(socket, scope)

    case LiveDataCoordinator.handle_request_timeout(
           socket.assigns.dashboard_coordinator_state,
           request_token,
           coordinator_opts(context, dashboard_cache_opts(socket))
         ) do
      {:ok, coordinator_state, actions} ->
        {:noreply,
         socket
         |> assign(:dashboard_coordinator_state, coordinator_state)
         |> apply_dashboard_coordinator_actions(actions, context, dashboard_dependency_profile())}

      {:error, _reason, coordinator_state, _actions} ->
        {:noreply, assign(socket, :dashboard_coordinator_state, coordinator_state)}
    end
  end

  defp assign_dashboard_tab(socket, params) do
    socket = ensure_initialized(socket)
    {socket, scope_selector} = resolve_scope_context(socket, params)
    use_revisit? = not socket.assigns.dashboard_revisit_hydrated?

    socket
    |> assign(
      params: params,
      view: :insights,
      active_tab: :dashboard,
      dashboard_scope: scope_selector,
      instructor_enrollment: socket.assigns.instructor_enrollment,
      dashboard_navigator_items: navigator_items(socket.assigns.section)
    )
    |> load_dashboard(use_revisit?: use_revisit?)
    |> assign(:dashboard_revisit_hydrated?, true)
  end

  defp load_dashboard(socket, opts) do
    scope_selector = Map.get(socket.assigns, :dashboard_scope, "course")
    scope = parse_scope(scope_selector)
    context = dashboard_context(socket, scope)
    cache_opts = dashboard_cache_opts(socket)
    use_revisit? = Keyword.get(opts, :use_revisit?, true)

    revisit_hydration =
      if use_revisit? do
        hydrate_required_from_revisit_cache(
          socket.assigns.dashboard_revisit_cache,
          context,
          scope,
          cache_opts
        )
      else
        %{source: :skipped, revisit_hits: 0, revisit_misses: 0}
      end

    dependency_profile = dashboard_dependency_profile()

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
  end

  defp dashboard_context(socket, scope) do
    %{
      dashboard_context_type: :section,
      dashboard_context_id: socket.assigns.section.id,
      user_id: dashboard_user_id(socket),
      scope: scope
    }
  end

  defp dashboard_user_id(socket) do
    cond do
      is_map(socket.assigns[:current_user]) and is_integer(socket.assigns.current_user.id) ->
        socket.assigns.current_user.id

      is_map(socket.assigns[:ctx]) and is_integer(socket.assigns.ctx.user_id) ->
        socket.assigns.ctx.user_id

      true ->
        1
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
         context,
         dependency_profile
       ) do
    if active_dashboard_request?(socket, request_token) do
      maybe_assign_dashboard_bundle(socket, request_token, context, dependency_profile)
    else
      socket
    end
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :runtime_start, request_token: request_token, misses: misses},
         context,
         dependency_profile
       ) do
    Enum.reduce(misses, socket, fn oracle_key, acc ->
      oracle_result = dashboard_runtime_result(oracle_key, context)

      case LiveDataCoordinator.handle_oracle_result(
             acc.assigns.dashboard_coordinator_state,
             request_token,
             oracle_key,
             oracle_result,
             coordinator_opts(context, dashboard_cache_opts(acc))
           ) do
        {:ok, coordinator_state, actions} ->
          acc
          |> assign(:dashboard_coordinator_state, coordinator_state)
          |> apply_dashboard_coordinator_actions(actions, context, dependency_profile)

        {:error, _reason, coordinator_state, _actions} ->
          assign(acc, :dashboard_coordinator_state, coordinator_state)
      end
    end)
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{
           type: :oracle_result_received,
           token_state: :active,
           oracle_key: oracle_key,
           oracle_result: oracle_result,
           request_token: request_token
         },
         context,
         dependency_profile
       ) do
    socket
    |> update(:dashboard_oracle_results, &Map.put(&1, oracle_key, oracle_result))
    |> maybe_assign_dashboard_bundle(request_token, context, dependency_profile)
  end

  defp apply_dashboard_coordinator_action(
         socket,
         %{type: :request_completed, request_token: request_token},
         context,
         dependency_profile
       ) do
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
             dependency_profile
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
            :dashboard,
            build_dashboard_payload(bundle, socket.assigns.dashboard_revisit_hydration)
          )

        {:error, reason} ->
          assign(socket, :dashboard, dashboard_error_payload(reason))
      end
    else
      socket
    end
  end

  defp build_dashboard_bundle(context, request_token, oracle_results, dependency_profile) do
    expected_oracles = dependency_profile.required ++ dependency_profile.optional

    with {:ok, snapshot} <-
           Assembler.assemble(context, Integer.to_string(request_token), oracle_results,
             scope: context.scope,
             expected_oracles: expected_oracles,
             metadata: %{timezone: "Etc/UTC", source: :instructor_insights}
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
    oracle_context =
      case OracleContext.new(context) do
        {:ok, oracle_context} ->
          oracle_context

        {:error, reason} ->
          raise ArgumentError, "invalid dashboard oracle context: #{inspect(reason)}"
      end

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
  end

  defp cache_hit_result(oracle_key, payload, cache_source) do
    version =
      case OracleRegistry.oracle_module(oracle_key) do
        {:ok, module} -> oracle_version(module)
        _ -> 1
      end

    Result.ok(oracle_key, payload,
      version: version,
      metadata: %{source: cache_source, dashboard_product: :instructor_dashboard}
    )
  end

  defp dashboard_dependency_profile do
    {:ok, progress} = OracleRegistry.dependencies_for(:progress_summary)
    {:ok, support} = OracleRegistry.dependencies_for(:support_summary)

    %{
      required: Enum.uniq(progress.required ++ support.required),
      optional: Enum.uniq(progress.optional ++ support.optional)
    }
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

  # TODO(intelligent-dashboard): Prototype-only data-validation payload helpers.
  # Remove these helpers once the epic is fully implemented and tile groups/tiles
  # consume typed projection data directly instead of debug text payloads:
  # build_dashboard_payload/2, dashboard_cache_stats/3, count_oracle_sources/2,
  # ratio/2, percent/1, summarize_projection_statuses/1,
  # dashboard_oracle_sources/1, dashboard_error_payload/1.
  defp build_dashboard_payload(bundle, revisit_hydration) do
    progress_projection = Map.get(bundle.projections, :progress, %{})
    support_projection = Map.get(bundle.projections, :student_support, %{})
    oracle_sources = dashboard_oracle_sources(bundle.snapshot.oracle_statuses)
    cache_stats = dashboard_cache_stats(bundle, oracle_sources, revisit_hydration)
    projection_statuses = summarize_projection_statuses(bundle.projection_statuses)

    status_lines = [
      "INPROCESS CACHE",
      "  hits: #{cache_stats.snapshot_cache_hits}/#{cache_stats.snapshot_total} (#{percent(cache_stats.snapshot_cache_hit_rate)})",
      "  misses: #{cache_stats.snapshot_cache_misses}/#{cache_stats.snapshot_total} (#{percent(1.0 - cache_stats.snapshot_cache_hit_rate)})",
      "  runtime loaded from misses: #{cache_stats.runtime_fallbacks}",
      "  unresolved after runtime: #{cache_stats.unresolved_oracles}",
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
      student_support_text: inspect(support_projection, pretty: true, limit: :infinity)
    }
  end

  defp dashboard_cache_stats(bundle, oracle_sources, revisit_hydration) do
    expected_oracles =
      bundle.dependency_profile.required
      |> Kernel.++(bundle.dependency_profile.optional)
      |> Enum.uniq()
      |> length()

    cache_hits = count_oracle_sources(oracle_sources, :cache)
    runtime_fallbacks = count_oracle_sources(oracle_sources, :runtime)
    unresolved = max(expected_oracles - cache_hits - runtime_fallbacks, 0)

    revisit_hits = Map.get(revisit_hydration, :revisit_hits, 0)
    revisit_misses = Map.get(revisit_hydration, :revisit_misses, 0)

    %{
      snapshot_cache_hits: cache_hits,
      snapshot_cache_misses: expected_oracles - cache_hits,
      snapshot_cache_hit_rate: ratio(cache_hits, expected_oracles),
      runtime_fallbacks: runtime_fallbacks,
      unresolved_oracles: unresolved,
      revisit_hits: revisit_hits,
      revisit_misses: revisit_misses,
      revisit_total: revisit_hits + revisit_misses,
      revisit_hit_rate: ratio(revisit_hits, revisit_hits + revisit_misses),
      snapshot_total: expected_oracles
    }
  end

  defp count_oracle_sources(oracle_sources, source) when is_map(oracle_sources) do
    Enum.count(oracle_sources, fn {_oracle_key, value} -> value == source end)
  end

  defp count_oracle_sources(_, _), do: 0

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
      source =
        status
        |> Map.get(:metadata, %{})
        |> Map.get(:source, :unknown)

      {oracle_key, source}
    end)
  end

  defp dashboard_oracle_sources(_), do: %{}

  defp dashboard_error_payload(reason) do
    %{
      runtime_status_text: "snapshot load failed:\n#{inspect(reason, pretty: true)}",
      progress_text: "unavailable",
      student_support_text: "unavailable"
    }
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
