defmodule OliWeb.Sections.EnrollmentsView do
  use OliWeb, :surface_view
  use OliWeb.Common.Modal

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext

  @limit 25
  @default_options %EnrollmentBrowseOptions{
    is_student: true,
    is_instructor: false,
    text_search: nil
  }

  data breadcrumbs, :any
  data title, :string, default: "Enrollments"
  data section, :any, default: nil

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any

  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Enrollments",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        context = SessionContext.init(session)

        %{total_count: total_count, table_model: table_model} =
          enrollment_assigns(section, context)

        {:ok,
         assign(socket,
           context: context,
           changeset: Sections.change_section(section),
           delivery_breadcrumb: true,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           total_count: total_count,
           table_model: table_model,
           options: @default_options,
           modal: nil
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

    options = %EnrollmentBrowseOptions{
      text_search: get_param(params, "text_search", ""),
      is_student: true,
      is_instructor: false
    }

    enrollments =
      Sections.browse_enrollments(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, enrollments)
    total_count = determine_total(enrollments)

    {:noreply,
     assign(socket,
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
         ),
       replace: true
     )}
  end

  def handle_event("unenroll", %{"id" => user_id}, socket) do
    %{section: section, context: context} = socket.assigns

    case Sections.unenroll_learner(user_id, section.id) do
      {:ok, _} ->
        %{total_count: total_count, table_model: table_model} =
          enrollment_assigns(section, context)

        {:noreply, assign(socket, total_count: total_count, table_model: table_model)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def enrollment_assigns(section, context) do
    enrollments =
      Sections.browse_enrollments(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )

    total_count = determine_total(enrollments)
    {:ok, table_model} = EnrollmentsTableModel.new(enrollments, section, context)

    %{total_count: total_count, table_model: table_model}
  end
end
