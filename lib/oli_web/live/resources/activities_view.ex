defmodule OliWeb.Resources.ActivitiesView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  import Oli.Authoring.Editing.Utils
  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb, FilterBox}
  alias Oli.Resources.ActivityBrowse
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Resources.ActivityBrowseOptions
  alias OliWeb.Common.SessionContext
  alias OliWeb.Resources.ActivitiesTableModel
  alias Oli.Repo.{Paging, Sorting}

  data title, :string, default: "All Activities"
  data project, :any
  data breadcrumbs, :list
  data author, :any
  data activities, :list

  @limit 25

  defp limit, do: @limit

  @default_options %ActivityBrowseOptions{
    activity_type_id: nil,
    deleted: false,
    text_search: nil
  }

  def breadcrumb(project) do
    [
      Breadcrumb.new(%{
        full_title: "Project Overview",
        link: Routes.project_path(OliWeb.Endpoint, :overview, project.slug)
      }),
      Breadcrumb.new(%{full_title: "All Activities"})
    ]
  end

  def mount(
        %{"project_id" => project_slug},
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    socket =
      with {:ok, author} <- Accounts.get_author(author_id) |> trap_nil(),
           {:ok, project} <- Oli.Authoring.Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project) do
        context = SessionContext.init(session)

        activities =
          ActivityBrowse.browse_activities(
            project,
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :asc, field: :title},
            @default_options
          )

        registered_activities = Oli.Activities.list_activity_registrations()

        activities_by_id =
          Enum.reduce(registered_activities, %{}, fn a, m -> Map.put(m, a.id, a) end)

        total_count = determine_total(activities)

        {:ok, table_model} =
          ActivitiesTableModel.new(activities, project, context, activities_by_id)

        assign(socket,
          context: context,
          breadcrumbs: breadcrumb(project),
          project: project,
          author: author,
          total_count: total_count,
          table_model: table_model,
          options: @default_options,
          tags_by_id:
            Enum.reduce(registered_activities, %{}, fn a, m ->
              Map.put(m, a.id, a.authoring_element)
            end)
        )
      else
        _ ->
          socket
          |> put_flash(:info, "You do not have permission to access this course project")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))
      end

    {:ok, socket}
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    selected = get_param(params, "selected", nil)
    table_model = Map.put(table_model, :selected, selected)

    offset = get_int_param(params, "offset", 0)

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
          "-2" -> Enum.at(activities, 0).id |> Integer.to_string()
          "-1" -> Enum.at(activities, Enum.count(activities) - 1).id |> Integer.to_string()
          _ -> selected
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

  defp push_sync_event(socket, table_model) do
    if !is_nil(table_model.selected) do
      revision =
        Enum.find(table_model.rows, fn r -> Integer.to_string(r.id) == table_model.selected end)

      rendered =
        render_authoring(revision, socket.assigns.tags_by_id, socket.assigns.project.slug)

      references =
        Oli.Publishing.determine_parent_pages(
          [revision.resource_id],
          Oli.Publishing.get_unpublished_publication_id!(socket.assigns.project.id)
        )

      Phoenix.LiveView.push_event(socket, "activity_selected", %{
        rendered: rendered,
        title: revision.title,
        slug: revision.slug,
        history:
          Routes.live_url(
            OliWeb.Endpoint,
            OliWeb.RevisionHistory,
            socket.assigns.project.slug,
            revision.slug
          ),
        reference:
          case Map.get(references, revision.resource_id, nil) do
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

  def render(assigns) do
    ~F"""
    <div id="activity_review" phx-hook="ReviewActivity">
      <FilterBox
        card_header_text="Browse All Activities"
        card_body_text=""
        table_model={@table_model}
        show_sort={false}
        show_more_opts={false}>
        <TextSearch id="text-search" text={@options.text_search}/>
      </FilterBox>

      <div class="mb-3"/>

      <PagedTable
        allow_selection={true}
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={limit()}/>
    </div>
    """
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
               activity_type_id: socket.assigns.options.activity_type_id
             },
             changes
           )
         ),
       replace: true
     )}
  end

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
