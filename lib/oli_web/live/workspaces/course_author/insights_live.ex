defmodule OliWeb.Workspaces.CourseAuthor.InsightsLive do
  use OliWeb, :live_view

  alias Oli.{Accounts, Publishing}
  alias Oli.Analytics.{ByActivity, ByObjective, ByPage}
  alias Oli.Authoring.{Broadcaster, Course}
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Common.MultiSelectInput
  alias OliWeb.Common.MultiSelect.Option
  alias OliWeb.Components.Project.AsyncExporter
  alias OliWeb.Workspaces.CourseAuthor.{TableHeader, TableRow}

  on_mount {OliWeb.LiveSessionPlugs.AuthorizeProject, :default}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, ctx: ctx} = socket.assigns

    by_activity_rows = ByActivity.query_against_project_slug(project.slug, [])

    {sections, products} =
      Sections.get_sections_containing_resources_of_given_project(project.id)
      |> Enum.reduce({[], []}, fn section, {sections, products} ->
        if section.type == :blueprint,
          do: {sections, [%Option{id: section.id, name: section.title} | products]},
          else: {[%Option{id: section.id, name: section.title} | sections], products}
      end)

    parent_pages =
      Enum.map(by_activity_rows, fn r -> r.slice.resource_id end)
      |> parent_pages(project.slug)

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
       active: :insights,
       active_rows: apply_filter_sort(:by_activity, by_activity_rows, "", "title", :asc),
       active_view: :insights,
       active_workspace: :course_author,
       analytics_export_status: analytics_export_status,
       analytics_export_timestamp: analytics_export_timestamp,
       analytics_export_url: analytics_export_url,
       by_activity_rows: by_activity_rows,
       by_page_rows: nil,
       by_objective_rows: nil,
       ctx: ctx,
       form_uuid_for_product: "",
       form_uuid_for_section: "",
       is_admin?: Accounts.is_system_admin?(ctx.author),
       is_product: false,
       latest_publication: latest_publication,
       parent_pages: parent_pages,
       product_ids: [],
       products: products,
       project: project,
       query: "",
       resource_slug: project.slug,
       resource_title: project.title,
       section_ids: [],
       sections: sections,
       selected: :by_activity,
       sort_by: "title",
       sort_order: :asc
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-8">
      <div class="mb-3">
        <p>
          Insights can help you improve your course by providing a statistical analysis of
          the skills covered by each question to find areas where students are struggling.
        </p>
        <%= if @is_admin? do %>
          <div class="flex items-center my-3">
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
      <ul class="nav nav-pills mb-4">
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
          <button
            {is_disabled(@selected, :by_page)}
            class="btn btn-primary"
            phx-click="filter_by_page"
          >
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
        <div class="card-header mb-2">
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
          <h5 class="card-title my-4">
            Viewing analytics by <%= case @selected do
              :by_page -> "page"
              :by_activity -> "activity"
              :by_objective -> "objective"
              _ -> "activity"
            end %>
          </h5>

          <%= if !is_loading?(assigns) do %>
            <table class="table table-sm">
              <TableHeader.render selected={@selected} sort_by={@sort_by} sort_order={@sort_order} />
              <tbody>
                <%= for row <- @active_rows do %>
                  <TableRow.render
                    row={row}
                    parent_pages={@parent_pages}
                    project={@project}
                    selected={@selected}
                  />
                <% end %>
              </tbody>
            </table>
          <% else %>
            <div class="w-full h-40 flex items-center justify-center">
              <span
                class="spinner-border spinner-border-sm w-16 h-16"
                role="status"
                aria-hidden="true"
              >
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("filter_" <> filter_criteria, _event, socket) do
    selected = String.to_existing_atom(filter_criteria)

    # do the query and assign the results in an async way
    filter_type(selected)

    {:noreply, assign(socket, selected: selected, active_rows: nil)}
  end

  # search
  def handle_event("search", %{"query" => query}, socket) do
    active_rows =
      apply_filter_sort(
        socket.assigns.selected,
        get_active_original(socket.assigns),
        query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, query: query, active_rows: active_rows)}
  end

  # sorting

  # CLick same column -> reverse sort order
  def handle_event(
        "sort",
        %{"sort-by" => column} = event,
        %{assigns: %{sort_by: sort_by, sort_order: :asc}} = socket
      )
      when column == sort_by do
    {:noreply,
     if click_or_enter_key?(event) do
       active_rows =
         apply_filter_sort(
           socket.assigns.selected,
           get_active_original(socket.assigns),
           socket.assigns.query,
           socket.assigns.sort_by,
           :desc
         )

       assign(socket, sort_by: sort_by, sort_order: :desc, active_rows: active_rows)
     else
       socket
     end}
  end

  def handle_event(
        "sort",
        %{"sort-by" => column} = event,
        %{assigns: %{sort_by: sort_by, sort_order: :desc}} = socket
      )
      when column == sort_by do
    {:noreply,
     if click_or_enter_key?(event) do
       active_rows =
         apply_filter_sort(
           socket.assigns.selected,
           get_active_original(socket.assigns),
           socket.assigns.query,
           socket.assigns.sort_by,
           :asc
         )

       assign(socket, sort_by: sort_by, sort_order: :asc, active_rows: active_rows)
     else
       socket
     end}
  end

  # Click new column
  def handle_event("sort", %{"sort-by" => column} = event, socket) do
    {:noreply,
     if click_or_enter_key?(event) do
       active_rows =
         apply_filter_sort(
           socket.assigns.selected,
           get_active_original(socket.assigns),
           socket.assigns.query,
           column,
           socket.assigns.sort_order
         )

       assign(socket, sort_by: column, active_rows: active_rows)
     else
       socket
     end}
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

  @impl Phoenix.LiveView
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

  def handle_info(:init_by_page, socket) do
    by_page_rows =
      get_rows_by(socket, :by_page)

    active_rows =
      apply_filter_sort(
        :by_page,
        by_page_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, by_page_rows: by_page_rows, active_rows: active_rows)}
  end

  def handle_info(:init_by_objective, socket) do
    by_objective_rows =
      get_rows_by(socket, :by_objective)
      |> arrange_rows_into_objective_hierarchy()

    active_rows =
      apply_filter_sort(
        :by_objective,
        by_objective_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, by_objective_rows: by_objective_rows, active_rows: active_rows)}
  end

  def handle_info(:init_by_activity, socket) do
    by_activity_rows =
      get_rows_by(socket, :by_activity)

    active_rows =
      apply_filter_sort(
        :by_activity,
        by_activity_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, by_activity_rows: by_activity_rows, active_rows: active_rows)}
  end

  defp parent_pages(resource_ids, project_slug) do
    publication = Publishing.project_working_publication(project_slug)
    Publishing.determine_parent_pages(resource_ids, publication.id)
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

  defp is_loading?(assigns) do
    is_nil(assigns.active_rows)
  end

  defp apply_filter_sort(:by_objective, rows, query, sort_by, sort_order) do
    filter(rows, query)
    |> sort(sort_by, sort_order)
    |> Enum.reduce([], fn p, all ->
      p.child_rows ++ [p] ++ all
    end)
    |> Enum.reverse()
  end

  defp apply_filter_sort(_, rows, query, sort_by, sort_order) do
    filter(rows, query)
    |> sort(sort_by, sort_order)
  end

  defp filter(rows, query) do
    rows |> Enum.filter(&String.match?(&1.slice.title, ~r/#{String.trim(query)}/i))
  end

  defp get_rows_by(socket, :by_activity) do
    if socket.assigns.is_product do
      section_by_product_ids =
        DeliveryResolver.get_sections_for_products(socket.assigns.product_ids)

      ByActivity.query_against_project_slug(
        socket.assigns.project.slug,
        section_by_product_ids
      )
    else
      ByActivity.query_against_project_slug(
        socket.assigns.project.slug,
        socket.assigns.section_ids
      )
    end
  end

  defp get_rows_by(socket, :by_objective) do
    if socket.assigns.is_product do
      section_by_product_ids =
        DeliveryResolver.get_sections_for_products(socket.assigns.product_ids)

      ByObjective.query_against_project_slug(
        socket.assigns.project.slug,
        section_by_product_ids
      )
    else
      ByObjective.query_against_project_slug(
        socket.assigns.project.slug,
        socket.assigns.section_ids
      )
    end
  end

  defp get_rows_by(socket, :by_page) do
    if socket.assigns.is_product do
      section_by_product_ids =
        DeliveryResolver.get_sections_for_products(socket.assigns.product_ids)

      ByPage.query_against_project_slug(
        socket.assigns.project.slug,
        section_by_product_ids
      )
    else
      ByPage.query_against_project_slug(
        socket.assigns.project.slug,
        socket.assigns.section_ids
      )
    end
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

  defp sort(rows, "title", :asc), do: rows |> Enum.sort(&(&1.slice.title > &2.slice.title))
  defp sort(rows, "title", :desc), do: rows |> Enum.sort(&(&1.slice.title <= &2.slice.title))

  defp sort(rows, sort_by, :asc) do
    sort_by_as_atom = String.to_existing_atom(sort_by)
    Enum.sort(rows, &(&1[sort_by_as_atom] > &2[sort_by_as_atom]))
  end

  defp sort(rows, sort_by, :desc) do
    sort_by_as_atom = String.to_existing_atom(sort_by)
    Enum.sort(rows, &(&1[sort_by_as_atom] <= &2[sort_by_as_atom]))
  end

  defp is_disabled(selected, title) do
    if selected == title,
      do: [disabled: true],
      else: []
  end

  def truncate(float_or_nil) when is_nil(float_or_nil), do: nil
  def truncate(float_or_nil) when is_float(float_or_nil), do: Float.round(float_or_nil, 2)

  def format_percent(float_or_nil) when is_nil(float_or_nil), do: nil

  def format_percent(float_or_nil) when is_float(float_or_nil),
    do: "#{round(100 * float_or_nil)}%"
end
