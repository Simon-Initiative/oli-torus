defmodule OliWeb.Insights do
  alias ElixirLS.LanguageServer.Providers.Completion.Reducers.Struct
  alias Oli.Analytics.Summary.BrowseInsights
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Delivery.Sections
  alias OliWeb.Common.MultiSelectInput
  alias OliWeb.Common.MultiSelect.Option
  alias Oli.{Accounts, Publishing}
  alias OliWeb.Insights.{TableHeader, TableRow}
  alias OliWeb.Common.{Breadcrumb, Check, FilterBox, PagedTable, TextSearch, SessionContext}
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Authoring.Course
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Components.Project.AsyncExporter
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.SessionContext
  alias Oli.Analytics.Summary.BrowseInsights
  alias Oli.Analytics.Summary.BrowseInsightsOptions
  alias OliWeb.Insights.SectionsTableModel
  alias OliWeb.Insights.ActivityTableModel

  @limit 25

  def mount(%{"project_id" => project_slug}, session, socket) do
    ctx = SessionContext.init(socket, session)

    project = Course.get_project_by_slug(project_slug)

    {sections, products} =
      Sections.get_sections_containing_resources_of_given_project(project.id)
      |> Enum.reduce({[], []}, fn section, {sections, products} ->
        if section.type == :blueprint do
          {sections, [%Option{id: section.id, name: section.title} | products]}
        else
          {[%Option{id: section.id, name: section.title} | sections], products}
        end
      end)

    activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")
    options = %BrowseInsightsOptions{project_id: project.id, resource_type_id: activity_type_id, section_ids: []}

    insights =
      BrowseInsights.browse_insights(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :first_attempt_correct},
        options
      )

    activity_types_map = Oli.Activities.list_activity_registrations()
    |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.id, a) end)

    total_count = determine_total(insights)
    {:ok, table_model} = ActivityTableModel.new(insights, activity_types_map,ctx)

   # parent_pages =
   #   Enum.map(by_activity_rows, fn r -> r.slice.resource_id end)
   #   |> parent_pages(project_slug)

    latest_publication = Publishing.get_latest_published_publication_by_slug(project.slug)

    {analytics_export_status, analytics_export_url, analytics_export_timestamp} =
      case Course.analytics_export_status(project) do
        {:available, url, timestamp} -> {:available, url, timestamp}
        {:expired, _, _} -> {:expired, nil, nil}
        {status} -> {status, nil, nil}
      end

    # Subscribe to any raw analytics snapshot progress updates for this project
    Subscriber.subscribe_to_analytics_export_status(project.slug)

    {:ok,
     assign(socket,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Insights"})],
       active: :insights,
       ctx: ctx,
       is_admin?: Accounts.is_system_admin?(ctx.author),
       project: project,
       parent_pages: nil,
       selected: :by_activity,
       latest_publication: latest_publication,
       analytics_export_status: analytics_export_status,
       analytics_export_url: analytics_export_url,
       analytics_export_timestamp: analytics_export_timestamp,
       products: products,
       sections: sections,
       is_product: false,
       section_ids: [],
       product_ids: [],
       form_uuid_for_product: "",
       form_uuid_for_section: "",
       table_model: table_model,
       options: options,
       offset: 0,
       total_count: total_count,
       active_rows: insights,
       query: "",
       limit: @limit
     )}
  end

  defp determine_total(items) do
    case items do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end


  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = get_int_param(params, "offset", 0)

    options = socket.assigns.options

    insights =
      BrowseInsights.browse_insights(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, insights)
    total_count = determine_total(insights)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end


  defp parent_pages(resource_ids, project_slug) do
    publication = Oli.Publishing.project_working_publication(project_slug)
    Oli.Publishing.determine_parent_pages(resource_ids, publication.id)
  end

  defp arrange_rows_into_objective_hierarchy(rows) do
    by_id = Enum.reduce(rows, %{}, fn r, m -> Map.put(m, r.slice.resource_id, r) end)

    parents =
      Enum.reduce(rows, %{}, fn r, m ->
        Enum.reduce(r.slice.children, m, fn id, m -> Map.put(m, id, r.slice.resource_id) end)
      end)

    Enum.filter(rows, fn r -> !Map.has_key?(parents, r.slice.resource_id) end)
    |> Enum.map(fn parent ->
      child_rows =
        Enum.map(parent.slice.children, fn c -> Map.get(by_id, c) |> Map.put(:is_child, true) end)

      Map.put(parent, :child_rows, child_rows)
    end)
  end

  defp get_active_original(assigns) do
    case assigns.selected do
      :by_page -> assigns.by_page_rows
      :by_activity -> assigns.by_activity_rows
      _ -> assigns.by_objective_rows
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <p>
        Insights can help you improve your course by providing a statistical analysis of
        the skills covered by each question to find areas where students are struggling.
      </p>
      <%= if @is_admin? do %>
        <div class="d-flex align-items-center my-3">
          <AsyncExporter.raw_analytics
            ctx={@ctx}
            latest_publication={@latest_publication}
            analytics_export_status={@analytics_export_status}
            analytics_export_url={@analytics_export_url}
            analytics_export_timestamp={@analytics_export_timestamp}
          />
        </div>
      <% end %>
    </div>
    <ul class="nav nav-pills">
      <li class="nav-item my-2 mr-2">
        <button
          {is_disabled(@selected, :by_activity)}
          class="btn btn-primary"
          phx-click="filter_by_activity"
        >
          <%= if is_loading?(assigns) and @selected == :by_activity do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
          By Activity
        </button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button {is_disabled(@selected, :by_page)} class="btn btn-primary" phx-click="filter_by_page">
          <%= if is_loading?(assigns) and @selected == :by_page do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
          By Page
        </button>
      </li>

      <li class="nav-item my-2 mr-2">
        <button
          {is_disabled(@selected, :by_objective)}
          class="btn btn-primary"
          phx-click="filter_by_objective"
        >
          <%= if is_loading?(assigns) and @selected == :by_objective do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
          By Objective
        </button>
      </li>

      <li class="nav-item my-2 mr-2 ">
        <div class="flex gap-10">
          <.live_component
            id="sections"
            module={MultiSelectInput}
            options={@sections}
            disabled={@sections == []}
            on_select_message="section_selected"
            placeholder="Select a section"
            uuid={@form_uuid_for_section}
          />
          <.live_component
            id="products"
            module={MultiSelectInput}
            options={@products}
            disabled={@products == []}
            on_select_message="product_selected"
            placeholder="Select a product"
            uuid={@form_uuid_for_product}
          />
        </div>
      </li>
    </ul>

    <div class="card">
      <div class="card-header">
        <form phx-change="search">
          <input
            type="text"
            class="form-control"
            name="query"
            value={@query}
            placeholder="Search by title..."
          />
        </form>
      </div>
      <div class="card-body">
        <h5 class="card-title">
          Viewing analytics by <%= case @selected do
            :by_page -> "page"
            :by_activity -> "activity"
            :by_objective -> "objective"
            _ -> "activity"
          end %>
        </h5>

        <PagedTable.render
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
        />
      </div>
    </div>
    """
  end

  defp is_loading?(assigns) do
    is_nil(assigns.active_rows)
  end


  def handle_event("generate_analytics_snapshot", _params, socket) do
    project = socket.assigns.project

    case Course.generate_analytics_snapshot(project) do
      {:ok, _job} ->
        Broadcaster.broadcast_analytics_export_status(project.slug, {:in_progress})

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Raw analytics snapshot could not be generated.")

        {:noreply, socket}
    end
  end


  def handle_event(event, params, socket),
  do:
    delegate_to(
      {event, params, socket, &__MODULE__.patch_with/2},
      [&TextSearch.handle_delegated/4, &PagedTable.handle_delegated/4]
    )

  def patch_with(socket, changes) do
    # Prepare the changes by converting to URL-friendly params
    params =
      socket.assigns
      |> Map.take([:sort_by, :sort_order, :offset, :query])
      |> Map.merge(changes)
      |> Enum.reject(fn {_k, v} -> v == nil end) # Remove nil values
      |> Enum.into(%{}, fn {k, v} -> {k, to_string(v)} end) # Convert values to strings

    # Push the patch with the sanitized params
    {:noreply,
    push_patch(socket,
      to: Routes.live_path(socket, __MODULE__, params),
      replace: true
    )}
  end

  def handle_info({:option_selected, "section_selected", selected_ids}, socket) do
    socket =
      assign(socket,
        section_ids: selected_ids,
        form_uuid_for_product: generate_uuid(),
        product_ids: [],
        is_product: false
      )

    filter_type(socket.assigns.selected)
    {:noreply, socket}
  end

  def handle_info({:option_selected, "product_selected", selected_ids}, socket) do
    socket =
      assign(socket,
        product_ids: selected_ids,
        form_uuid_for_section: generate_uuid(),
        section_ids: [],
        is_product: true
      )

    filter_type(socket.assigns.selected)
    {:noreply, socket}
  end

  def handle_info(
        {:analytics_export_status,
         {:available, analytics_export_url, analytics_export_timestamp}},
        socket
      ) do
    {:noreply,
     assign(socket,
       analytics_export_status: :available,
       analytics_export_url: analytics_export_url,
       analytics_export_timestamp: analytics_export_timestamp
     )}
  end

  def handle_info(
        {:analytics_export_status, {:error, _e}},
        socket
      ) do
    {:noreply,
     assign(socket,
       analytics_export_status: :error
     )}
  end

  def handle_info({:analytics_export_status, {status}}, socket) do
    {:noreply, assign(socket, analytics_export_status: status)}
  end

  defp generate_uuid do
    UUID.uuid4()
  end

  defp filter_type(selected) do
    case selected do
      :by_page ->
        send(self(), :init_by_page)

      :by_activity ->
        send(self(), :init_by_activity)

      :by_objective ->
        send(self(), :init_by_objective)
    end
  end

  defp click_or_enter_key?(event) do
    event["key"] == nil or event["key"] == "Enter"
  end

  defp is_disabled(selected, title) do
    if selected == title do
      [disabled: true]
    else
      []
    end
  end

  def truncate(float_or_nil) when is_nil(float_or_nil), do: nil
  def truncate(float_or_nil) when is_float(float_or_nil), do: Float.round(float_or_nil, 2)

  def format_percent(float_or_nil) when is_nil(float_or_nil), do: nil

  def format_percent(float_or_nil) when is_float(float_or_nil),
    do: "#{round(100 * float_or_nil)}%"

end
