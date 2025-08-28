defmodule OliWeb.Projects.PublicationDetails do
  use OliWeb, :live_component

  alias OliWeb.Common.Utils
  alias OliWeb.Common.{PagedTable, Utils}
  alias OliWeb.Projects.PublishChangesTableModel
  alias Phoenix.LiveView.JS

  @custom_params %{
    "limit" => 10,
    "offset" => 0,
    "sort_by" => "title",
    "sort_order" => :asc
  }

  def update(
        %{publication_changes: publication_changes} = assigns,
        socket
      ) do
    params = @custom_params

    {total_count, rows} = apply_filters(publication_changes, params)

    {:ok, table_model} = PublishChangesTableModel.new(publication_changes)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params["sort_order"],
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec ->
            col_spec.name == params["sort_by"]
          end)
      })

    {:ok,
     assign(socket,
       active_publication_changes: assigns.active_publication_changes,
       ctx: assigns.ctx,
       has_changes: assigns.has_changes,
       latest_published_publication: assigns.latest_published_publication,
       params: params,
       parent_pages: assigns.parent_pages,
       project: assigns.project,
       publication_changes: publication_changes,
       table_model: table_model,
       total_count: total_count
     )}
  end

  attr(:active_publication_changes, :any, required: true)
  attr(:ctx, :map, required: true)
  attr(:has_changes, :boolean, required: true)
  attr(:latest_published_publication, :any, required: true)
  attr(:parent_pages, :map, required: true)
  attr(:project, :map, required: true)
  attr(:limit, :integer, default: 10)
  attr(:offset, :integer, default: 0)

  def render(assigns) do
    ~H"""
    <div>
      <h5 class="mb-0">Publication Details</h5>
      <div class="flex flex-row items-center">
        <div class="flex-1">
          Publish your project to give instructors access to the latest changes.
        </div>
        <div>
          <button
            class="btn btn-outline-primary whitespace-nowrap"
            phx-click="display_lti_connect_modal"
          >
            <i class="fa-solid fa-plug-circle-bolt"></i> Connect with LTI 1.3
          </button>
        </div>
      </div>
      <%= case @latest_published_publication do %>
        <% %{edition: current_edition, major: current_major, minor: current_minor} -> %>
          <div class="badge badge-secondary">
            Latest Publication: {Utils.render_version(
              current_edition,
              current_major,
              current_minor
            )}
          </div>
        <% _ -> %>
      <% end %>

      <%= case {@has_changes, @active_publication_changes} do %>
        <% {true, nil} -> %>
          <h6 class="my-3"><strong>This project has not been published yet</strong></h6>
        <% {false, _} -> %>
          <h6 class="my-3">
            Published <strong> <%= Utils.render_date(@latest_published_publication, :published, @ctx) %></strong>.
            There are <strong>no changes</strong> since the latest publication.
          </h6>
        <% {true, changes} -> %>
          <div class="my-3">
            Last published <strong> <%= Utils.render_date(@latest_published_publication, :published, @ctx) %></strong>.
            There {if change_count(changes) == 1, do: "is", else: "are"}
            <strong>{change_count(changes)}</strong>
            pending {if change_count(changes) == 1, do: "change", else: "changes"} since last publish:
          </div>
      <% end %>
      <div id="publish-changes-table">
        <PagedTable.render
          additional_table_class="publish_changes_table"
          allow_selection={false}
          limit={@params["limit"]}
          offset={@params["offset"]}
          page_change={JS.push("paged_table_page_change", target: @myself)}
          render_top_info={false}
          show_bottom_paging={false}
          sort={JS.push("paged_table_sort", target: @myself)}
          table_model={@table_model}
          total_count={@total_count}
        />
      </div>
    </div>
    """
  end

  defp do_update(socket, params) do
    {_total_count, rows} = apply_filters(socket.assigns.publication_changes, params)

    {:ok, table_model} = PublishChangesTableModel.new(socket.assigns.publication_changes)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params["sort_order"],
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec ->
            col_spec.name == params["sort_by"]
          end)
      })

    {:noreply,
     assign(socket,
       table_model: table_model,
       params: params
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    do_update(socket, update_params(socket.assigns.params, %{"sort_by" => sort_by}))
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    do_update(
      socket,
      update_params(socket.assigns.params, %{
        "limit" => String.to_integer(limit),
        "offset" => String.to_integer(offset)
      })
    )
  end

  defp apply_filters(changes, params) do
    changes =
      changes
      |> sort_by(params["sort_by"], params["sort_order"])

    {length(changes),
     changes
     |> Enum.drop(params["offset"])
     |> Enum.take(params["limit"])}
  end

  defp sort_by(changes, sort_by, sort_order) do
    case sort_by do
      "title" ->
        Enum.sort_by(changes, fn change -> change.title end, sort_order)

      "type" ->
        Enum.sort_by(changes, fn change -> change.type end, sort_order)

      "is_structural" ->
        Enum.sort_by(changes, fn change -> change.is_structural end, sort_order)
    end
  end

  defp update_params(
         %{"sort_by" => current_sort_by, "sort_order" => current_sort_order} = params,
         %{
           "sort_by" => new_sort_by
         }
       )
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc

    update_params(params, %{"sort_order" => toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
  end

  defp change_count(changes),
    do:
      changes
      |> Map.values()
      |> Enum.count()
end
