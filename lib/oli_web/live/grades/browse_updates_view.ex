defmodule OliWeb.Grades.BrowseUpdatesView do
  use OliWeb, :live_view

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Attempts.Core.GradeUpdateBrowseOptions
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  alias OliWeb.Sections.Mount
  alias OliWeb.Grades.UpdatesTableModel

  @limit 25

  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "LMS Grade Updates",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  defp default_options(section) do
    %GradeUpdateBrowseOptions{
      user_id: nil,
      section_id: section.id,
      text_search: nil
    }
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        ctx = socket.assigns.ctx

        options = default_options(section)

        updates =
          Core.browse_lms_grade_updates(
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :asc, field: :inserted_at},
            options
          )

        total_count = determine_total(updates)

        {:ok, table_model} = UpdatesTableModel.new(updates, ctx)

        {:ok,
         assign(socket,
           ctx: ctx,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           total_count: total_count,
           table_model: table_model,
           offset: 0,
           limit: @limit,
           options: options
         )}
    end
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

    offset = get_int_param(params, "offset", 0)

    options = %{socket.assigns.options | text_search: get_param(params, "text_search", "")}

    updates =
      Core.browse_lms_grade_updates(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, updates)
    total_count = determine_total(updates)

    {:noreply,
     assign(
       socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <TextSearch.render id="text-search" />

      <div class="mb-3" />

      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
      />
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
           socket.assigns.section.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
