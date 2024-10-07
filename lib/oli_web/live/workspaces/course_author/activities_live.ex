defmodule OliWeb.Workspaces.CourseAuthor.ActivitiesLive do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.{Activities, Publishing}
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources.{ActivityBrowse, ActivityBrowseOptions}
  alias OliWeb.Common.{FilterBox, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Resources.ActivitiesTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Workspaces.CourseAuthor.Activities.ActivitiesTableModel

  @limit 25
  @default_options %ActivityBrowseOptions{
    activity_type_id: nil,
    deleted: false,
    text_search: nil
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, current_author: author, ctx: ctx} = socket.assigns

    activities =
      ActivityBrowse.browse_activities(
        project,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        @default_options
      )

    publication_id = Publishing.get_unpublished_publication_id!(project.id)

    parent_pages = Publishing.determine_parent_pages(publication_id)

    registered_activities = Activities.list_activity_registrations()

    tags_by_id =
      Enum.reduce(registered_activities, %{}, fn a, m -> Map.put(m, a.id, a.authoring_element) end)

    activities_by_id =
      Enum.reduce(registered_activities, %{}, fn a, m -> Map.put(m, a.id, a) end)

    total_count = determine_total(activities)

    {:ok, table_model} =
      ActivitiesTableModel.new(activities, project, ctx, activities_by_id, parent_pages)

    {:ok,
     assign(socket,
       author: author,
       ctx: ctx,
       options: @default_options,
       parent_pages: parent_pages,
       project: project,
       publication_id: publication_id,
       resource_slug: project.slug,
       resource_title: project.title,
       table_model: table_model,
       tags_by_id: tags_by_id,
       total_count: total_count
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    selected = get_param(params, "selected", nil)
    offset = get_int_param(params, "offset", 0)
    table_model = Map.put(table_model, :selected, selected)

    options = %ActivityBrowseOptions{
      text_search: get_param(params, "text_search", ""),
      deleted: false,
      activity_type_id: get_int_param(params, "activity_type_id", nil)
    }

    if only_selection_changed(socket.assigns, table_model, options, offset) do
      table_model = Map.put(socket.assigns.table_model, :selected, selected)

      socket =
        push_sync_event(socket, table_model)
        |> assign(table_model: table_model)

      {:noreply, socket}
    else
      activities =
        ActivityBrowse.browse_activities(
          socket.assigns.project,
          %Paging{offset: offset, limit: @limit},
          %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
          options
        )

      selected =
        case selected do
          "-2" ->
            Enum.at(activities, 0).id |> Integer.to_string()

          "-1" ->
            Enum.at(activities, Enum.count(activities) - 1).id |> Integer.to_string()

          _ ->
            case Enum.find(activities, fn r -> Integer.to_string(r.id) == selected end) do
              nil -> nil
              _ -> selected
            end
        end

      table_model =
        Map.put(table_model, :rows, activities)
        |> Map.put(:selected, selected)

      total_count = determine_total(activities)

      {:noreply,
       push_sync_event(socket, table_model)
       |> assign(
         offset: offset,
         table_model: table_model,
         total_count: total_count,
         options: options
       )}
    end
  end

  attr(:project, :any)
  attr(:limit, :integer, default: @limit)
  attr(:offset, :integer, default: 0)
  attr(:total_count, :integer, default: 0)
  attr(:table_model, :any)
  attr(:options, :map)

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div id="activity_review" phx-hook="ReviewActivity">
      <FilterBox.render
        card_header_text="Browse All Activities"
        card_body_text=""
        table_model={@table_model}
        show_sort={false}
        show_more_opts={false}
      >
        <TextSearch.render id="text-search" text={@options.text_search} />
      </FilterBox.render>

      <div class="mb-3" />

      <PagedTable.render
        allow_selection={true}
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
      />

      <.link navigate={~p"/workspaces/course_author/#{@project.slug}/activities/activity_review"}>
        Open Sync View
      </.link>
    </div>
    """
  end

  # If there is a selected item in the table, push down an event to the client-side ReviewActivity hook
  # giving it the information that it needs to broadcast a client-side sync event to other tabs
  defp push_sync_event(socket, table_model) do
    if !is_nil(table_model.selected) do
      revision =
        Enum.find(table_model.rows, fn r -> Integer.to_string(r.id) == table_model.selected end)

      rendered =
        render_authoring(revision, socket.assigns.tags_by_id, socket.assigns.project.slug)

      legacy_svn_root = socket.assigns.project.legacy_svn_root || ""
      legacy_path = (revision.legacy && revision.legacy.path) || ""

      Phoenix.LiveView.push_event(socket, "activity_selected", %{
        rendered: rendered,
        title: revision.title,
        slug: revision.slug,
        svn_path: legacy_svn_root <> legacy_path,
        svn_relative_path: legacy_path,
        history:
          Routes.live_url(
            OliWeb.Endpoint,
            OliWeb.RevisionHistory,
            socket.assigns.project.slug,
            revision.slug
          ),
        reference:
          case Map.get(socket.assigns.parent_pages, revision.resource_id, nil) do
            nil ->
              nil

            %{slug: slug} ->
              Routes.resource_url(OliWeb.Endpoint, :edit, socket.assigns.project.slug, slug)
          end
      })
    else
      socket
    end
  end

  defp render_authoring(nil, _, _) do
    []
  end

  defp render_authoring(revision, tags_by_id, project_slug) do
    tag = Map.get(tags_by_id, revision.activity_type_id)

    [
      "<",
      tag,
      " model=\"",
      encode_model(revision.content),
      "\" editMode=\"false\" projectSlug=\"",
      project_slug,
      "\"/>"
    ]
    |> IO.iodata_to_binary()
  end

  defp encode_model(model) do
    {:safe, encoded} = Jason.encode!(model) |> Phoenix.HTML.html_escape()
    IO.iodata_to_binary(encoded)
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.project.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               selected: socket.assigns.table_model.selected,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search,
               activity_type_id: socket.assigns.options.activity_type_id,
               sidebar_expanded: socket.assigns.sidebar_expanded
             },
             changes
           )
         ),
       replace: true
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("keyboard-navigation", %{"direction" => direction}, socket) do
    selected = socket.assigns.table_model.selected

    index =
      Enum.find_index(socket.assigns.table_model.rows, fn r ->
        Integer.to_string(r.id) == selected
      end)

    new_index = direction + index

    # The logic for allowing keyboard arrow navigation to change the selection *and* to
    # switch pages (when the current item is the first or last item)
    changes =
      cond do
        new_index < 0 ->
          if socket.assigns.offset != 0 do
            %{offset: socket.assigns.offset - @limit, selected: Integer.to_string(-1)}
          else
            %{selected: Enum.at(socket.assigns.table_model.rows, index).id |> Integer.to_string()}
          end

        new_index + socket.assigns.offset >= socket.assigns.total_count ->
          %{selected: Enum.at(socket.assigns.table_model.rows, index).id |> Integer.to_string()}

        new_index >= @limit ->
          %{offset: socket.assigns.offset + @limit, selected: Integer.to_string(-2)}

        true ->
          %{
            selected:
              Enum.at(socket.assigns.table_model.rows, new_index).id |> Integer.to_string()
          }
      end

    patch_with(socket, changes)
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  # Determines if the change after parsing the URL params is strictly a selection change,
  # relative to the current assigns
  defp only_selection_changed(assigns, model_after, options_after, offset_after) do
    assigns.table_model.selected != model_after.selected and
      assigns.table_model.sort_by_spec == model_after.sort_by_spec and
      assigns.table_model.sort_order == model_after.sort_order and
      assigns.options.text_search == options_after.text_search and
      assigns.options.deleted == options_after.deleted and
      assigns.options.activity_type_id == options_after.activity_type_id and
      assigns.offset == offset_after
  end
end
