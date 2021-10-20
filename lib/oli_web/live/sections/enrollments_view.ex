defmodule OliWeb.Sections.EnrollmentsView do
  use Surface.LiveView
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  @limit 25
  @default_options %EnrollmentBrowseOptions{
    is_student: true,
    is_instructor: false,
    text_search: nil
  }

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "Enrollments"
  data section, :any, default: nil

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any
  data is_admin, :boolean

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "All Course Sections",
          link: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    case Sections.get_section_by(slug: section_slug) do
      nil ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      section ->
        enrollments =
          Sections.browse_enrollments(
            section,
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :asc, field: :name},
            @default_options
          )

        total_count = determine_total(enrollments)

        {:ok, table_model} = EnrollmentsTableModel.new(enrollments, section)

        {:ok,
         assign(socket,
           changeset: Sections.change_section(section),
           is_admin: Oli.Accounts.is_admin?(author),
           breadcrumbs: set_breadcrumbs(),
           author: author,
           section: section,
           total_count: total_count,
           table_model: table_model,
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
