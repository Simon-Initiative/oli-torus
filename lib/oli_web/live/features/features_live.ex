defmodule OliWeb.Features.FeaturesLive do
  @moduledoc """
  LiveView implementation of a feature flag editor.
  """

  use OliWeb, :live_view

  import Ecto.Query
  import OliWeb.DelegatedEvents

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery
  alias Oli.Delivery.Sections.Section
  alias Oli.Features
  alias Oli.RuntimeLogOverrides
  alias OliWeb.Common.{Breadcrumb, PagedTable, Params}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Features.EnabledScopedFeaturesTableModel

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @default_params %{
    offset: 0,
    limit: 25,
    sort_order: :desc,
    sort_by: :inserted_at
  }

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{full_title: "Feature Flags"})
      ]
  end

  def mount(_params, _, socket) do
    research_consent_form_setting =
      Delivery.get_system_research_consent_form_setting()

    {:ok,
     socket
     |> assign(
       title: "Feature Flags",
       module_log_form: module_log_form(),
       active: :features,
       features: Features.list_features_and_states(),
       breadcrumbs: set_breadcrumbs(),
       research_consent_form_setting: research_consent_form_setting,
       params: @default_params,
       total_count: 0,
       table_model: nil
     )
     |> assign_runtime_log_cluster_state(RuntimeLogOverrides.cluster_state())}
  end

  def handle_params(params, _url, socket) do
    offset = Params.get_int_param(params, "offset", @default_params.offset)
    limit = Params.get_int_param(params, "limit", @default_params.limit)

    sort_by =
      Params.get_atom_param(
        params,
        "sort_by",
        [:feature_name, :resource_type, :inserted_at],
        @default_params.sort_by
      )

    sort_order =
      Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order)

    updated_params = %{
      offset: offset,
      limit: limit,
      sort_order: sort_order,
      sort_by: sort_by
    }

    {enabled_features, total_count} = get_enabled_scoped_features_paged(updated_params)
    {:ok, table_model} = EnabledScopedFeaturesTableModel.new(enabled_features)
    table_model = SortableTableModel.update_from_params(table_model, params)

    {:noreply,
     assign(socket,
       params: updated_params,
       total_count: total_count,
       table_model: table_model
     )}
  end

  defp current(:enabled), do: "Enabled"
  defp current(:disabled), do: "Disabled"

  defp action(:enabled), do: "Disable"
  defp action(:disabled), do: "Enable"

  defp to_state("Enable"), do: :enabled
  defp to_state("Disable"), do: :disabled

  defp module_log_form(params \\ %{"module_name" => "", "level" => "debug"}) do
    to_form(params, as: :module_override)
  end

  defp module_override_dom_id(target_label) do
    "module-log-override-" <> String.replace(target_label, ~r/[^a-zA-Z0-9_-]/, "-")
  end

  defp get_enabled_scoped_features_paged(%{
         offset: offset,
         limit: limit,
         sort_by: sort_by,
         sort_order: sort_order
       }) do
    total_count = Oli.Repo.aggregate(Oli.ScopedFeatureFlags.ScopedFeatureFlagState, :count, :id)

    query =
      from(sfs in Oli.ScopedFeatureFlags.ScopedFeatureFlagState,
        left_join: p in Project,
        on: sfs.project_id == p.id,
        left_join: s in Section,
        on: sfs.section_id == s.id,
        select: %{
          id: sfs.id,
          feature_name: sfs.feature_name,
          project_id: sfs.project_id,
          project_title: p.title,
          project_slug: p.slug,
          section_id: sfs.section_id,
          section_title: s.title,
          section_slug: s.slug,
          resource_type:
            fragment("CASE WHEN ? IS NOT NULL THEN 'project' ELSE 'section' END", sfs.project_id),
          inserted_at: sfs.inserted_at
        }
      )

    query =
      case {sort_by, sort_order} do
        {:feature_name, :asc} ->
          order_by(query, [sfs], asc: sfs.feature_name)

        {:feature_name, :desc} ->
          order_by(query, [sfs], desc: sfs.feature_name)

        {:resource_type, :asc} ->
          order_by(query, [sfs],
            asc:
              fragment(
                "CASE WHEN ? IS NOT NULL THEN 'project' ELSE 'section' END",
                sfs.project_id
              )
          )

        {:resource_type, :desc} ->
          order_by(query, [sfs],
            desc:
              fragment(
                "CASE WHEN ? IS NOT NULL THEN 'project' ELSE 'section' END",
                sfs.project_id
              )
          )

        {:inserted_at, :asc} ->
          order_by(query, [sfs], asc: sfs.inserted_at)

        {:inserted_at, :desc} ->
          order_by(query, [sfs], desc: sfs.inserted_at)

        _ ->
          order_by(query, [sfs], desc: sfs.inserted_at)
      end

    query =
      query
      |> offset(^offset)
      |> limit(^limit)

    features = Oli.Repo.all(query)
    {features, total_count}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <div class="grid grid-cols-12 mb-8">
        <div class="col-span-12">
          <h2 class="mb-4">
            Cluster Runtime Log Overrides
          </h2>
          <p class="mb-2 text-gray-700">
            Actions on this page target all currently connected Torus nodes visible to this admin session.
          </p>
          <p class="mb-4 text-gray-600">
            Overrides are runtime-only, do not persist across restarts or deploys, and do not automatically apply to nodes that join later.
          </p>

          <%= if @runtime_log_cluster_state.read_errors != [] do %>
            <div id="cluster-log-read-errors" class="alert alert-warning mb-4">
              Cluster state could not be read from: {format_node_list(
                @runtime_log_cluster_state.read_errors
              )}.
            </div>
          <% end %>

          <div id="cluster-system-log-state" class="mb-4 rounded border border-gray-200 p-4">
            <div class="font-semibold">
              {system_level_heading(@runtime_log_cluster_state.system_level)}
            </div>
            <div class="text-sm text-gray-600">
              {system_level_detail(@runtime_log_cluster_state.system_level)}
            </div>

            <%= if @runtime_log_cluster_state.system_level.status == :mixed do %>
              <div class="mt-2 text-sm text-gray-600">
                Nodes: {format_exception_nodes(@runtime_log_cluster_state.system_level.exceptions)}
              </div>
            <% end %>
          </div>

          <div class="flex flex-wrap gap-2">
            <button type="button" class="btn btn-danger" phx-click="logging" phx-value-level="debug">
              Debug (most verbose)
            </button>
            <button type="button" class="btn btn-secondary" phx-click="logging" phx-value-level="info">
              Info
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="notice"
            >
              Notice
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="warning"
            >
              Warning
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="error"
            >
              Error
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="critical"
            >
              Critical
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="alert"
            >
              Alert
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="emergency"
            >
              Emergency (least verbose)
            </button>
            <button
              id="clear-system-log-level"
              type="button"
              class="btn btn-outline-danger"
              phx-click="clear_system_log_level"
            >
              Clear Cluster Override
            </button>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-12 mb-8">
        <div class="col-span-12">
          <h2 class="mb-4">
            Cluster Module-Level Log Overrides
          </h2>
          <p class="mb-4 text-gray-600">
            Apply a temporary cluster-wide log-level override to a loaded Elixir module. This does not change the cluster system log level.
          </p>

          <.form
            id="module-log-override-form"
            for={@module_log_form}
            phx-submit="set_module_log_level"
            class="grid gap-4 md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_auto]"
          >
            <.input
              field={@module_log_form[:module_name]}
              type="text"
              label="Module"
              placeholder="Elixir.Oli.Some.Module"
            />
            <.input
              field={@module_log_form[:level]}
              type="select"
              label="Override Level"
              options={Enum.map(Logger.levels(), &{Atom.to_string(&1), &1})}
            />
            <div class="flex items-end">
              <button id="apply-module-log-override" type="submit" class="btn btn-primary w-full">
                Apply Cluster Override
              </button>
            </div>
          </.form>

          <div class="mt-5">
            <h3 class="mb-3 text-lg font-semibold">Active Cluster Module Overrides</h3>

            <%= case @runtime_log_cluster_state.module_levels do %>
              <% [] -> %>
                <p id="no-module-log-overrides" class="text-gray-600">
                  No active module overrides across the connected cluster.
                </p>
              <% overrides -> %>
                <div class="space-y-3" id="active-module-log-overrides">
                  <%= for override <- overrides do %>
                    <div
                      id={module_override_dom_id(override.module_label)}
                      class="flex flex-col gap-3 rounded border border-gray-200 p-4"
                    >
                      <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                        <div>
                          <div class="font-medium">{override.module_label}</div>
                          <div class="text-sm text-gray-600">
                            {module_override_detail(override)}
                          </div>
                        </div>
                        <button
                          type="button"
                          class="btn btn-outline-danger"
                          phx-click="clear_module_log_level"
                          phx-value-module={override.module_label}
                        >
                          Clear Cluster Override
                        </button>
                      </div>

                      <%= if override.status == :mixed do %>
                        <div class="text-sm text-gray-600">
                          Nodes: {format_exception_nodes(override.exceptions)}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-12 mt-5">
        <div class="col-span-12">
          <h2 class="mb-5">
            Change the status of system-wide feature flags
          </h2>
        </div>
      </div>
      <div class="grid grid-cols-12">
        <div class="col-span-12">
          <table class="table table-striped table-bordered">
            <thead>
              <tr>
                <th>Feature</th>
                <th>Description</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <%= for {feature, status} <- @features do %>
                <tr>
                  <td>{feature.label}</td>
                  <td>{feature.description}</td>
                  <td>{current(status)}</td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="toggle"
                      phx-value-label={feature.label}
                      phx-value-action={action(status)}
                    >
                      {action(status)}
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="grid grid-cols-12 mt-8">
        <div class="col-span-12">
          <h2 class="mb-5">
            All Enabled Scoped Feature Flags
          </h2>
          <p class="mb-4 text-gray-600">
            Complete list of all enabled scoped feature flags across projects and sections.
          </p>

          <%= if @table_model do %>
            <PagedTable.render
              page_change="paged_table_page_change"
              sort="paged_table_sort"
              total_count={@total_count}
              limit={@params.limit}
              offset={@params.offset}
              table_model={@table_model}
              no_records_message="No enabled scoped feature flags found. Enable feature flags on projects or sections to see them here."
              show_limit_change={true}
            />
          <% end %>
        </div>
      </div>

      <div class="mt-5">
        <h2 class="mb-5">
          Research Consent
        </h2>
      </div>
      <div class="flex flex-row">
        <.form :let={f} for={%{}} phx-change="change_research_consent_form">
          <label for="countries" class="block mb-2 text-sm font-medium text-gray-900 dark:text-white">
            Direct Delivery Research Consent Form
          </label>

          <.input
            field={f[:research_consent_form]}
            type="select"
            value={@research_consent_form_setting}
            options={[{"OLI Form", :oli_form}, {"No Form", :no_form}]}
            class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
          >
          </.input>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("toggle", %{"label" => label, "action" => action}, socket) do
    Features.change_state(label, to_state(action))
    {:noreply, assign(socket, features: Features.list_features_and_states())}
  end

  def handle_event("logging", %{"level" => level}, socket) do
    socket =
      case RuntimeLogOverrides.cluster_apply_system_level(level) do
        {:ok, result} ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> put_flash(
            :info,
            success_message("Applied cluster system log level #{level}", result)
          )

        {:error, %{status: status} = result} when status in [:partial, :failure] ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> put_flash(:error, failure_message("apply cluster system log level #{level}", result))

        {:error, :invalid_level} ->
          put_flash(socket, :error, "Logging level could not be changed to #{level}")
      end

    {:noreply, socket}
  end

  def handle_event("clear_system_log_level", _params, socket) do
    socket =
      case RuntimeLogOverrides.cluster_clear_system_level() do
        {:ok, result} ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> put_flash(:info, success_message("Cleared cluster system log override", result))

        {:error, result} ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> put_flash(:error, failure_message("clear cluster system log override", result))
      end

    {:noreply, socket}
  end

  def handle_event("set_module_log_level", %{"module_override" => params}, socket) do
    socket =
      case RuntimeLogOverrides.cluster_apply_module_level(params["module_name"], params["level"]) do
        {:ok, result} ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> assign(module_log_form: module_log_form())
          |> put_flash(
            :info,
            success_message(
              "Applied cluster module override for #{params["module_name"]} at #{params["level"]}",
              result
            )
          )

        {:error, %{status: status} = result} when status in [:partial, :failure] ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> assign(module_log_form: module_log_form(params))
          |> put_flash(
            :error,
            failure_message(
              "apply cluster module override for #{params["module_name"]}",
              result
            )
          )

        {:error, :invalid_module} ->
          socket
          |> put_flash(:error, "Module log override failed: invalid module")
          |> assign(module_log_form: module_log_form(params))

        {:error, :invalid_level} ->
          socket
          |> put_flash(:error, "Module log override failed: invalid log level")
          |> assign(module_log_form: module_log_form(params))
      end

    {:noreply, socket}
  end

  def handle_event("clear_module_log_level", %{"module" => module_name}, socket) do
    socket =
      case RuntimeLogOverrides.cluster_clear_module_level(module_name) do
        {:ok, result} ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> put_flash(
            :info,
            success_message("Cleared cluster module override for #{module_name}", result)
          )

        {:error, %{status: status} = result} when status in [:partial, :failure] ->
          socket
          |> assign_runtime_log_cluster_state(result.cluster_state)
          |> put_flash(
            :error,
            failure_message("clear cluster module override for #{module_name}", result)
          )

        {:error, :invalid_module} ->
          put_flash(socket, :error, "Module log override clear failed: invalid module")
      end

    {:noreply, socket}
  end

  def handle_event(
        "change_research_consent_form",
        %{"research_consent_form" => research_consent_form},
        socket
      ) do
    research_consent_form_selection = String.to_existing_atom(research_consent_form)

    Delivery.update_system_research_consent_form_setting(research_consent_form_selection)

    {:noreply, assign(socket, research_consent_form_setting: research_consent_form_selection)}
  end

  def handle_event(event, params, socket) do
    delegate_to({event, params, socket, &patch_with/2}, [
      &PagedTable.handle_delegated/4
    ])
  end

  defp patch_with(socket, changes) do
    current_params = socket.assigns.params
    new_params = Map.merge(current_params, changes)

    path = ~p"/admin/features?#{new_params}"
    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  defp assign_runtime_log_cluster_state(socket, cluster_state) do
    assign(socket,
      runtime_log_cluster_state: cluster_state,
      log_level: cluster_state.system_level.level
    )
  end

  defp success_message(action, result) do
    "#{action} across #{length(result.target_nodes)} connected nodes."
  end

  defp failure_message(action, result) do
    prefix =
      case result.status do
        :partial ->
          "Partial success while trying to #{action}."

        :failure ->
          "Failed to #{action}."
      end

    "#{prefix} Failed or unreachable nodes: #{format_node_list(result.failed_nodes)}."
  end

  defp system_level_heading(%{status: :uniform, level: level}) when not is_nil(level) do
    "Current cluster system log level: #{level}"
  end

  defp system_level_heading(%{status: :mixed}), do: "Current cluster system log level is mixed"
  defp system_level_heading(_), do: "Current cluster system log level is unavailable"

  defp system_level_detail(%{status: :uniform}) do
    "Connected nodes currently agree on the active runtime system log level."
  end

  defp system_level_detail(%{status: :mixed}) do
    "Connected nodes disagree on the active runtime system log level."
  end

  defp system_level_detail(_),
    do: "Cluster runtime state could not be read from any connected node."

  defp module_override_detail(%{status: :uniform, level: level}) do
    "Cluster override level: #{level}"
  end

  defp module_override_detail(%{status: :mixed}) do
    "Mixed override state across connected nodes."
  end

  defp format_exception_nodes(exceptions) do
    exceptions
    |> Enum.map(fn
      %{node: node, level: level} -> "#{node}: #{level || "none"}"
      %{node: node} -> to_string(node)
    end)
    |> Enum.join(", ")
  end

  defp format_node_list(entries) do
    entries
    |> Enum.map(fn
      %{node: node} -> to_string(node)
      node when is_atom(node) -> to_string(node)
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end
end
