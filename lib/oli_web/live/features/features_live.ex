defmodule OliWeb.Features.FeaturesLive do
  @moduledoc """
  LiveView implementation of a feature flag editor.
  """

  use OliWeb, :live_view

  import Ecto.Query
  import OliWeb.DelegatedEvents

  alias OliWeb.Common.{Breadcrumb, PagedTable, Params}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Features.EnabledScopedFeaturesTableModel
  alias Oli.Features
  alias Oli.Delivery
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{full_title: "Feature Flags"})
      ]
  end

  @default_params %{
    offset: 0,
    limit: 25,
    sort_order: :desc,
    sort_by: :inserted_at
  }

  def mount(_params, _, socket) do
    research_consent_form_setting =
      Delivery.get_system_research_consent_form_setting()

    {:ok,
     assign(socket,
       title: "Feature Flags",
       log_level: Logger.level(),
       active: :features,
       features: Features.list_features_and_states(),
       breadcrumbs: set_breadcrumbs(),
       research_consent_form_setting: research_consent_form_setting,
       params: @default_params,
       total_count: 0,
       table_model: nil
     )}
  end

  def handle_params(params, _url, socket) do
    # Parse pagination and sorting params
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

    # Get enabled scoped features with pagination and sorting
    {enabled_features, total_count} = get_enabled_scoped_features_paged(updated_params)

    # Create table model
    {:ok, table_model} = EnabledScopedFeaturesTableModel.new(enabled_features)

    # Update table model with current sort
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

  defp get_enabled_scoped_features_paged(%{
         offset: offset,
         limit: limit,
         sort_by: sort_by,
         sort_order: sort_order
       }) do
    # Get total count first
    total_count = Oli.Repo.aggregate(Oli.ScopedFeatureFlags.ScopedFeatureFlagState, :count, :id)

    # Build base query
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

    # Add sorting
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

    # Add pagination
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
      <div class="grid grid-cols-12 mb-5">
        <div class="col-span-12">
          <h2 class="mb-5">
            Change the logging level of the system.
          </h2>
          <p class="mb-5">
            Current log level is: <strong><mark><%= @log_level %></mark></strong>.
          </p>
          <p>
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
          </p>
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
      case Logger.configure(level: String.to_atom(level)) do
        :ok ->
          socket
          |> put_flash(:info, "Logging level changed to #{level}")
          |> assign(log_level: Logger.level())

        _ ->
          socket
          |> put_flash(:error, "Logging level could not be changed to #{level}")
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

  # Handle PagedTable events using delegation pattern
  def handle_event(event, params, socket) do
    delegate_to({event, params, socket, &patch_with/2}, [
      &PagedTable.handle_delegated/4
    ])
  end

  # Live navigation patch function for PagedTable
  defp patch_with(socket, changes) do
    current_params = socket.assigns.params
    new_params = Map.merge(current_params, changes)

    path = ~p"/admin/features?#{new_params}"
    {:noreply, push_patch(socket, to: path, replace: true)}
  end
end
