defmodule OliWeb.Sections.SectionsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes

  @default_opts [
    render_institution_action: false,
    render_date: :relative,
    exclude_columns: [],
    sort_by_spec: :start_date,
    sort_order: :desc
  ]

  def new(%SessionContext{} = ctx, sections, opts \\ []) do
    opts = Keyword.validate!(opts, @default_opts)

    date_render =
      if opts[:render_date] == :relative, do: &Common.render_date/3, else: &custom_render/3

    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"

    search_term = Keyword.get(opts, :search_term, "")

    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        th_class: "!sticky left-0 z-[60] " <> default_th_class,
        td_class: "!sticky left-0 z-[1] bg-inherit " <> default_td_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :tags,
        label: "Tags",
        sortable: false,
        td_class: "w-[200px] min-w-[200px] max-w-[200px] !p-0 " <> default_td_class,
        th_class: "w-[200px] min-w-[200px] max-w-[200px] " <> default_th_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :enrollments_count,
        label: "# Enrolled",
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :requires_payment,
        label: "Cost",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :start_date,
        label: "Start",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: date_render,
        sort_fn: &Common.sort_date/2
      },
      %ColumnSpec{
        name: :end_date,
        label: "End",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: date_render,
        sort_fn: &Common.sort_date/2
      },
      %ColumnSpec{
        name: :base,
        label: "Base Project/Product",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :instructor,
        label: "Instructors",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :institution,
        label: "Institution",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :type,
        label: "Delivery",
        td_class: default_td_class,
        th_class: default_th_class,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :status,
        label: "Status",
        render_fn: &custom_render/3
      }
    ]

    sort_by = Keyword.get(opts, :sort_by_spec, :start_date)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    sort_by_spec =
      Enum.find(column_specs, fn spec -> spec.name == sort_by end)

    column_specs =
      Enum.reject(column_specs, fn column -> column.name in opts[:exclude_columns] end)

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      sort_by_spec: sort_by_spec,
      sort_order: sort_order,
      data: %{
        ctx: ctx,
        fade_data: true,
        render_institution_action: opts[:render_institution_action],
        search_term: search_term
      }
    )
  end

  def custom_render(assigns, section, %ColumnSpec{name: :title}) do
    search_term = Map.get(assigns, :search_term, "")
    assigns = Map.merge(assigns, %{section: section, search_term: search_term})

    ~H"""
    <div class="flex flex-col">
      <a
        href={~p"/sections/#{@section.slug}/manage"}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {Phoenix.HTML.raw(Utils.highlight_search_term(@section.title || "", @search_term))}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {Phoenix.HTML.raw(Utils.highlight_search_term(@section.slug || "", @search_term))}
      </span>
    </div>
    """
  end

  # Tags
  def custom_render(assigns, section, %ColumnSpec{name: :tags}) do
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <div>
      <.live_component
        module={OliWeb.Live.Components.Tags.TagsComponent}
        id={"tags-#{@section.id}"}
        entity_type={:section}
        entity_id={@section.id}
        current_tags={Map.get(@section, :tags, [])}
      />
    </div>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :type}) do
    {text, bg_color, text_color} =
      if section.open_and_free do
        {"DD", "bg-Fill-Accent-fill-accent-purple", "text-Text-text-accent-purple"}
      else
        {"LTI", "bg-Fill-Accent-fill-accent-teal", "text-Text-text-accent-teal"}
      end

    assigns = %{text: text, bg_color: bg_color, text_color: text_color}

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg_color} #{@text_color} shadow-sm"}>
      {@text}
    </span>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :requires_payment}) do
    if section.requires_payment do
      case Money.to_string(section.amount) do
        {:ok, m} -> m
        _ -> "Yes"
      end
    else
      "None"
    end
  end

  def custom_render(assigns, section, %ColumnSpec{name: :institution}) do
    search_term = Map.get(assigns, :search_term, "")
    assigns = Map.merge(assigns, %{section: section, search_term: search_term})

    ~H"""
    <div class="flex space-x-2 items-center">
      <span class="text-Text-text-high text-base font-medium">
        <%= if @section.institution do %>
          <a
            href={~p"/admin/institutions/#{@section.institution.id}"}
            class="text-Text-text-link text-base font-medium leading-normal"
          >
            {Phoenix.HTML.raw(
              Utils.highlight_search_term(@section.institution.name || "", @search_term)
            )}
          </a>
        <% end %>
      </span>
      <%= if @render_institution_action do %>
        <button class="btn btn-primary my-6" phx-click="edit_section" value={@section.id}>
          Edit
        </button>
      <% end %>
    </div>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :status}) do
    class =
      case section.status do
        :active -> "text-Table-text-accent-green"
        _ -> "text-Table-text-danger"
      end

    assigns = Map.merge(assigns, %{section: section, class: class})

    ~H"""
    <span class={@class}>
      {Phoenix.Naming.humanize(@section.status)}
    </span>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :base}) do
    {route_path, title, slug} =
      if section.blueprint_id do
        {Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section.blueprint.slug),
         section.blueprint.title, section.blueprint.slug}
      else
        {~p"/workspaces/course_author/#{section.base_project.slug}/overview",
         section.base_project.title, section.base_project.slug}
      end

    search_term = Map.get(assigns, :search_term, "")

    assigns =
      Map.merge(assigns, %{
        route_path: route_path,
        title: title,
        slug: slug,
        search_term: search_term
      })

    ~H"""
    <div class="flex flex-col">
      <a
        href={@route_path}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {Phoenix.HTML.raw(Utils.highlight_search_term(@title || "", @search_term))}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {Phoenix.HTML.raw(Utils.highlight_search_term(@slug || "", @search_term))}
      </span>
    </div>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :instructor}) do
    instructors =
      section.id
      |> Oli.Delivery.Sections.get_instructors_for_section()
      |> Enum.map(fn instructor ->
        author = Oli.Accounts.linked_author_account(instructor)
        author_id = if author, do: author.id
        {instructor.name, instructor.id, author_id}
      end)

    search_term = Map.get(assigns, :search_term, "")
    assigns = %{instructors: instructors, search_term: search_term}

    ~H"""
    <div class="flex flex-wrap gap-1">
      <%= for {{name, instructor_id, author_id}, index} <- Enum.with_index(@instructors) do %>
        <%= if author_id do %>
          <.link
            href={~p"/admin/authors/#{author_id}"}
            class="text-Text-text-link text-base font-medium leading-normal"
          >
            {Phoenix.HTML.raw(Utils.highlight_search_term(name || "", @search_term))}
          </.link>
        <% else %>
          <.link
            href={~p"/admin/users/#{instructor_id}"}
            class="text-Text-text-link text-base font-medium leading-normal"
          >
            {Phoenix.HTML.raw(Utils.highlight_search_term(name || "", @search_term))}
            <%= if index < length(@instructors) - 1 do %>
              ,
            <% end %>
          </.link>
        <% end %>
      <% end %>
    </div>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :start_date}) do
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <span class="text-Text-text-high text-base font-medium">
      {format_date(assigns, @section, @section.start_date)}
    </span>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :end_date}) do
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <span class="text-Text-text-high text-base font-medium">
      {format_date(assigns, @section, @section.end_date)}
    </span>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  defp format_date(_assigns, _section, nil), do: ""

  defp format_date(assigns, section, date) do
    tz =
      FormatDateTime.tz_preference_or_default(
        assigns.ctx.author,
        assigns.ctx.user,
        section,
        assigns.ctx.browser_timezone
      )

    datetime = FormatDateTime.convert_datetime(date, tz)
    Calendar.strftime(datetime, "%B %d, %Y %I:%M %p")
  end
end
