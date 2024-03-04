defmodule OliWeb.Insights do
  alias OliWeb.Common.MultiSelectOptions
  alias Oli.Delivery.Sections
  use OliWeb, :live_view
<<<<<<< HEAD
  alias OliWeb.Common.MultiSelect
  alias OliWeb.Common.MultiSelectOptions.SelectOption
  alias Oli.Publishing
=======

  alias Oli.{Accounts, Publishing}
>>>>>>> master
  alias OliWeb.Insights.{TableHeader, TableRow}
  alias Oli.Authoring.Course
  alias OliWeb.Components.Project.AsyncExporter
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.SessionContext

  def mount(_params, %{"project_slug" => project_slug} = session, socket) do
    ctx = SessionContext.init(socket, session)

    by_activity_rows =
      Oli.Analytics.ByActivity.query_against_project_slug(project_slug, [])

    project = Course.get_project_by_slug(project_slug)

    {sections, products} =
      Sections.get_sections_by_base_project(project)
      |> Enum.reduce({[], []}, fn section, {sections, products} ->
        if section.type == :blueprint do
          {sections,
           products ++
             [
               %SelectOption{
                 id: section.id,
                 label: section.title,
                 selected: false,
                 is_product: true
               }
             ]}
        else
          {sections ++
             [
               %SelectOption{
                 id: section.id,
                 label: section.title,
                 selected: false,
                 is_product: false
               }
             ], products}
        end
      end)

    parent_pages =
      Enum.map(by_activity_rows, fn r -> r.slice.resource_id end)
      |> parent_pages(project_slug)

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
       initial_section_options: sections,
       initial_product_options: products,
       ctx: ctx,
       is_admin?: Accounts.is_system_admin?(ctx.author),
       project: project,
       by_page_rows: nil,
       by_activity_rows: by_activity_rows,
       by_objective_rows: nil,
       parent_pages: parent_pages,
       selected: :by_activity,
       active_rows: apply_filter_sort(:by_activity, by_activity_rows, "", "title", :asc),
       query: "",
       sort_by: "title",
       sort_order: :asc,
       title: "Insights | " <> project.title,
       latest_publication: latest_publication,
       analytics_export_status: analytics_export_status,
       analytics_export_url: analytics_export_url,
       analytics_export_timestamp: analytics_export_timestamp,
       products: products,
       sections: sections,
       filtered_sections: sections,
       filtered_blueprint: products,
       is_product: false,
       form_sections:
         MultiSelectOptions.build_changeset(sections)
         |> to_form(),
       form_products:
         MultiSelectOptions.build_changeset(products)
         |> to_form(),
       section_ids: [],
       product_ids: [],
       form_uid: ""
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

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
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
        <button {is_disabled(@selected, :by_activity)} class="btn btn-primary" phx-click="by-activity">
          By Activity
        </button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button {is_disabled(@selected, :by_page)} class="btn btn-primary" phx-click="by-page">
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
          phx-click="by-objective"
        >
          <%= if is_loading?(assigns) and @selected == :by_objective do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
          By Objective
        </button>
      </li>

      <li class="nav-item my-2 mr-2 ">
        <div class="flex gap-10">
          <.form for={@form_sections} id="multiselect-form-section" phx-change="section-change">
            <.live_component
              id="multi_sections"
              module={MultiSelect}
              options={@sections}
              initial_values={@initial_section_options}
              form={@form_sections}
              label="Select a section..."
              uid={@form_uid}
            />
          </.form>

          <.form for={@form_products} id="multiselect-form" phx-change="product-change">
            <.live_component
              id="multi_products"
              module={MultiSelect}
              options={@products}
              initial_values={@initial_product_options}
              form={@form_products}
              label="Select a product..."
              uid={@form_uid}
            />
          </.form>
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
        <% end %>
      </div>
    </div>
    """
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

  # data splits
  def handle_event("by-activity", _event, socket) do
    active_rows =
      apply_filter_sort(
        :by_activity,
        socket.assigns.by_activity_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, selected: :by_activity, active_rows: active_rows)}
  end

  def handle_event("by-page", _event, socket) do
    active_rows =
      if is_nil(socket.assigns.by_page_rows) do
        send(self(), :init_by_page)
        nil
      else
        apply_filter_sort(
          :by_page,
          socket.assigns.by_page_rows,
          socket.assigns.query,
          socket.assigns.sort_by,
          socket.assigns.sort_order
        )
      end

    {:noreply, assign(socket, selected: :by_page, active_rows: active_rows)}
  end

  def handle_event("by-objective", _event, socket) do
    active_rows =
      if is_nil(socket.assigns.by_objective_rows) do
        send(self(), :init_by_objective)
        nil
      else
        apply_filter_sort(
          :by_objective,
          socket.assigns.by_objective_rows,
          socket.assigns.query,
          socket.assigns.sort_by,
          socket.assigns.sort_order
        )
      end

    {:noreply, assign(socket, selected: :by_objective, active_rows: active_rows)}
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

  def handle_event("section-change", params, socket) do
    target_value =
      hd(params["_target"])

    value =
      params[target_value]

    update_section_by_value(value, socket, target_value)
  end

  def handle_event("product-change", params, socket) do
    target_value = hd(params["_target"])

    value =
      params[target_value]

    update_product_by_value(value, socket, target_value)
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
      get_by_page_row(socket)

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
      Oli.Analytics.ByObjective.query_against_project_slug(
        socket.assigns.project.slug,
        socket.assigns.section_ids
      )
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
      get_by_page_row(socket)

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

  defp get_by_page_row(socket) do
    if socket.assigns.is_product do
      Oli.Analytics.ByActivity.query_against_project_slug(
        socket.assigns.project.slug,
        socket.assigns.product_ids
      )
    else
      Oli.Analytics.ByActivity.query_against_project_slug(
        socket.assigns.project.slug,
        socket.assigns.section_ids
      )
    end
  end

  defp update_section_by_value(value, socket, target_value) do
    case value do
      "true" ->
        section_ids_updated =
          update_section_ids(
            :add,
            socket.assigns.sections,
            target_value,
            socket.assigns.section_ids
          )

        treget =
          if socket.assigns.product_ids != [] do
            Integer.to_string(:rand.uniform(100))
          else
            socket.assigns.form_uid
          end

        socket =
          assign(socket,
            is_product: false,
            section_ids: section_ids_updated,
            form_uid: treget
          )

        filter_type(socket.assigns.selected)
        {:noreply, socket}

      "false" ->
        section_ids_updated =
          update_section_ids(
            :delete,
            socket.assigns.sections,
            target_value,
            socket.assigns.section_ids
          )

        treget =
          if socket.assigns.product_ids != [] do
            Integer.to_string(:rand.uniform(100))
          else
            socket.assigns.form_uid
          end

        socket =
          assign(socket,
            is_product: false,
            section_ids: section_ids_updated,
            form_uid: treget
          )

        filter_type(socket.assigns.selected)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp update_product_by_value(value, socket, target_value) do
    case value do
      "true" ->
        product_ids_updated =
          update_section_ids(
            :add,
            socket.assigns.products,
            target_value,
            socket.assigns.product_ids
          )

        treget =
          if socket.assigns.section_ids != [] do
            Integer.to_string(:rand.uniform(100))
          else
            socket.assigns.form_uid
          end

        socket =
          assign(socket,
            is_product: false,
            product_ids: product_ids_updated,
            form_uid: treget
          )

        filter_type(socket.assigns.selected)
        {:noreply, socket}

      "false" ->
        product_ids_updated =
          update_section_ids(
            :delete,
            socket.assigns.products,
            target_value,
            socket.assigns.product_ids
          )

        treget =
          if socket.assigns.section_ids != [] do
            Integer.to_string(:rand.uniform(100))
          else
            socket.assigns.form_uid
          end

        socket =
          assign(socket,
            is_product: false,
            product_ids: product_ids_updated,
            form_uid: treget
          )

        filter_type(socket.assigns.selected)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
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

  defp update_section_ids(action, sections, target, section_ids) do
    case action do
      :add ->
        [fliter_section_by_target_value(sections, target) | section_ids]

      :delete ->
        List.delete(section_ids, fliter_section_by_target_value(sections, target))
    end
  end

  defp fliter_section_by_target_value(sections, target) do
    hd(
      Enum.filter(sections, fn section ->
        section.label == target
      end)
    ).id
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
