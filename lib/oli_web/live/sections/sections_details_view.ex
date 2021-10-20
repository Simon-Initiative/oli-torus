defmodule OliWeb.Sections.SectionsDetailsView do
  use Surface.LiveView
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias OliWeb.Common.Properties.{Groups, Group, WideGroup}
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  alias OliWeb.Sections.{Instructors, MainDetails, OpenFreeSettings, LtiSettings, PaywallSettings}
  alias Surface.Components.{Form}
  alias Oli.Branding
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
  data title, :string, default: "Section Details"
  data section, :any, default: nil
  data instructors, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any
  data changeset, :any
  data is_admin, :boolean
  data brands, :list

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

        available_brands =
          Branding.list_brands()
          |> Enum.map(fn brand -> {brand.name, brand.id} end)

        total_count = determine_total(enrollments)

        {:ok, table_model} = EnrollmentsTableModel.new(enrollments)

        {:ok,
         assign(socket,
           brands: available_brands,
           changeset: Sections.change_section(section),
           is_admin: Oli.Accounts.is_admin?(author),
           breadcrumbs: set_breadcrumbs(),
           instructors: fetch_instructors(section),
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

  defp fetch_instructors(section) do
    Sections.browse_enrollments(
      section,
      %Paging{offset: 0, limit: 50},
      %Sorting{direction: :asc, field: :name},
      %EnrollmentBrowseOptions{
        is_student: false,
        is_instructor: true,
        text_search: nil
      }
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
    <Form as={:section} for={@changeset} change="validate" submit="save" opts={autocomplete: "off"}>
      <Groups>
        <Group label="Settings" description="Manage the course section settings">
          <MainDetails changeset={@changeset} disabled={false}  is_admin={@is_admin} brands={@brands} />
        </Group>
        {#if @section.open_and_free}
          <OpenFreeSettings is_admin={@is_admin} changeset={@changeset} disabled={false}/>
        {#else}
          <LtiSettings section={@section}/>
        {/if}
        <PaywallSettings is_admin={@is_admin} changeset={@changeset} disabled={!can_change_payment?(@section)}/>
        <Group label="Instructors" description="Manage the users with instructor level access">
          <Instructors users={@instructors}/>
        </Group>
        <WideGroup label="Enrollments" description="Access and manage the enrolled students">

          <TextSearch id="text-search"/>

          <div class="mb-3"/>

          <PagedTable
            filter={@options.text_search}
            table_model={@table_model}
            total_count={@total_count}
            offset={@offset}
            limit={@limit}/>

        </WideGroup>

      </Groups>
    </Form>
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

  def handle_event("validate", %{"section" => params}, socket) do
    params = convert_dates(params)

    changeset =
      socket.assigns.section
      |> Sections.change_section(params)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"section" => params}, socket) do
    params = convert_dates(params)

    case Sections.update_section(socket.assigns.section, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Section changes saved")

        {:noreply, assign(socket, section: section, changeset: Sections.change_section(section))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def parse_and_convert_start_end_dates_to_utc(start_date, end_date, from_timezone) do
    section_timezone = Timex.Timezone.get(from_timezone)
    utc_timezone = Timex.Timezone.get(:utc, Timex.now())

    utc_start_date =
      case start_date do
        start_date when start_date == nil or start_date == "" or not is_binary(start_date) ->
          start_date

        start_date ->
          start_date
          |> Timex.parse!("%Y-%m-%d", :strftime)
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    utc_end_date =
      case end_date do
        end_date when end_date == nil or end_date == "" or not is_binary(end_date) ->
          end_date

        end_date ->
          end_date
          |> Timex.parse!("%Y-%m-%d", :strftime)
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    {utc_start_date, utc_end_date}
  end

  defp convert_dates(params) do
    {utc_start_date, utc_end_date} =
      parse_and_convert_start_end_dates_to_utc(
        params["start_date"],
        params["end_date"],
        params["timezone"]
      )

    params
    |> Map.put("start_date", utc_start_date)
    |> Map.put("end_date", utc_end_date)
  end

  defp can_change_payment?(section) do
    is_nil(section.blueprint_id)
  end
end
