defmodule OliWeb.Grades.GradebookView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  alias OliWeb.Sections.Mount
  alias OliWeb.Grades.GradebookTableModel

  @limit 25
  @default_options %EnrollmentBrowseOptions{
    is_student: true,
    is_instructor: false,
    text_search: nil
  }

  data breadcrumbs, :any
  data title, :string, default: "Gradebook"
  data section, :any, default: nil
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Gradebook",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        enrollments =
          Sections.browse_enrollments(
            section,
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :asc, field: :name},
            @default_options
          )

        total_count = determine_total(enrollments)

        hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

        graded_pages =
          hierarchy
          |> Oli.Delivery.Hierarchy.flatten()
          |> Enum.filter(fn node -> node.revision.graded end)
          |> Enum.map(fn node -> node.revision end)

        resource_accesses = fetch_resource_accesses(enrollments, section)

        {:ok, table_model} =
          GradebookTableModel.new(enrollments, graded_pages, resource_accesses, section.slug)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           total_count: total_count,
           table_model: table_model,
           graded_pages: graded_pages,
           options: @default_options
         )}
    end
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  defp fetch_resource_accesses(enrollments, section) do
    # retrieve all graded resource accesses, but only for this slice of students
    student_ids = Enum.map(enrollments, fn user -> user.id end)

    Oli.Delivery.Attempts.Core.get_graded_resource_access_for_context(
      section.slug,
      student_ids
    )
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %EnrollmentBrowseOptions{
      text_search: get_str_param(params, "text_search", ""),
      is_student: true,
      is_instructor: false
    }

    enrollments =
      Sections.browse_enrollments(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        # We cannot support sorting by columns other than the user name, so ignore any
        # attempt to do that
        %Sorting{direction: table_model.sort_order, field: :name},
        options
      )

    resource_accesses = fetch_resource_accesses(enrollments, socket.assigns.section)

    {:ok, table_model} =
      GradebookTableModel.new(
        enrollments,
        socket.assigns.graded_pages,
        resource_accesses,
        socket.assigns.section.slug
      )

    total_count = determine_total(enrollments)

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
    ~F"""
    <div>

      <TextSearch id="text-search"/>

      <div class="mb-3"/>

      <PagedTable
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>
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
         )
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
