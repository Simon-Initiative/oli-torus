defmodule OliWeb.Products.UsageTableModel do
  use Phoenix.Component

  alias Oli.Accounts
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.Publications.Publication
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Common.Utils
  alias OliWeb.Sections.SectionsTableModel

  @default_opts [
    render_date: :full,
    sort_by_spec: :start_date,
    sort_order: :desc,
    search_term: "",
    is_admin: false,
    current_author: nil
  ]

  def new(%SessionContext{} = ctx, sections, opts \\ []) do
    opts = Keyword.validate!(opts, @default_opts)

    date_render =
      if opts[:render_date] == :relative, do: &Common.render_date/3, else: &custom_render/3

    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"

    search_term = Keyword.get(opts, :search_term, "")
    is_admin = Keyword.get(opts, :is_admin, false)
    current_author = Keyword.get(opts, :current_author)

    base_columns = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        th_class: "!sticky left-0 z-[60] " <> default_th_class,
        td_class: "!sticky left-0 z-[1] bg-inherit " <> default_td_class,
        render_fn: &custom_render/3
      }
    ]

    tags_column = %ColumnSpec{
      name: :tags,
      label: "Tags",
      sortable: false,
      td_class: "w-[200px] min-w-[200px] max-w-[200px] !p-0 " <> default_td_class,
      th_class: "w-[200px] min-w-[200px] max-w-[200px] " <> default_th_class,
      render_fn: &SectionsTableModel.custom_render/3
    }

    remaining_columns = [
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
        render_fn: &SectionsTableModel.custom_render/3
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
        name: :project_version,
        label: "Project Version",
        sortable: false,
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
        render_fn: &SectionsTableModel.custom_render/3
      },
      %ColumnSpec{
        name: :status,
        label: "Status",
        render_fn: &SectionsTableModel.custom_render/3
      }
    ]

    column_specs =
      if is_admin do
        base_columns ++ [tags_column] ++ remaining_columns
      else
        base_columns ++ remaining_columns
      end

    sort_by = Keyword.get(opts, :sort_by_spec, :start_date)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    sort_by_spec =
      Enum.find(column_specs, fn spec -> spec.name == sort_by end)

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
        render_institution_action: false,
        search_term: search_term,
        current_author: current_author
      }
    )
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :project_version}) do
    version =
      section
      |> project_publication()
      |> render_version()

    assigns = %{version: version}

    ~H"""
    <span class="text-Text-text-high text-base font-medium leading-normal">
      {@version}
    </span>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :instructor}) do
    assigns = %{instructor_name: Map.get(section, :instructor_name, "")}

    ~H"""
    <span class="text-Text-text-high text-base font-medium leading-normal">
      {@instructor_name}
    </span>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :start_date}),
    do: Common.render_date(assigns, section, %ColumnSpec{name: :start_date})

  def custom_render(assigns, section, %ColumnSpec{name: :end_date}),
    do: Common.render_date(assigns, section, %ColumnSpec{name: :end_date})

  def custom_render(assigns, section, %ColumnSpec{name: :title}) do
    search_term = Map.get(assigns, :search_term, "")
    current_author = Map.get(assigns, :current_author)

    assigns = %{
      section: section,
      search_term: search_term,
      can_link?: Accounts.is_admin?(current_author)
    }

    ~H"""
    <div class="flex flex-col">
      <%= if @can_link? do %>
        <a
          href={"/sections/#{@section.slug}/manage"}
          class="text-Text-text-link text-base font-medium leading-normal"
        >
          {highlight_search_term(@section.title, @search_term)}
        </a>
      <% else %>
        <span class="text-Text-text-high text-base font-medium leading-normal">
          {highlight_search_term(@section.title, @search_term)}
        </span>
      <% end %>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {highlight_search_term(@section.slug, @search_term)}
      </span>
    </div>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :institution}) do
    search_term = Map.get(assigns, :search_term, "")
    current_author = Map.get(assigns, :current_author)

    assigns =
      %{section: section, search_term: search_term, can_link?: Accounts.is_admin?(current_author)}

    ~H"""
    <div class="flex space-x-2 items-center">
      <span class="text-Text-text-high text-base font-medium">
        <%= if @section.institution do %>
          <%= if @can_link? do %>
            <a
              href={"/admin/institutions/#{@section.institution.id}"}
              class="text-Text-text-link text-base font-medium leading-normal"
            >
              {highlight_search_term(@section.institution.name, @search_term)}
            </a>
          <% else %>
            {highlight_search_term(@section.institution.name, @search_term)}
          <% end %>
        <% end %>
      </span>
    </div>
    """
  end

  defp project_publication(section) do
    section
    |> Map.get(:section_project_publications, [])
    |> pick_project_publication(section.base_project_id)
  end

  defp pick_project_publication(section_project_publications, base_project_id)
       when is_list(section_project_publications) do
    Enum.find(section_project_publications, fn
      %SectionsProjectsPublications{project_id: project_id} -> project_id == base_project_id
      _ -> false
    end)
  end

  defp pick_project_publication(_, _), do: nil

  defp render_version(%SectionsProjectsPublications{publication: %Publication{} = publication}),
    do: Utils.render_version(publication.edition, publication.major, publication.minor)

  defp render_version(_), do: "N/A"

  defp highlight_search_term(text, search_term),
    do:
      Phoenix.HTML.raw(
        Utils.multi_highlight_search_term(
          text || "",
          search_term,
          "span class=\"search-highlight\"",
          "span"
        )
      )
end
