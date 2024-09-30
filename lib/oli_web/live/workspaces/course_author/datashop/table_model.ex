defmodule OliWeb.Workspaces.CourseAuthor.Datashop.SectionsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  def new(%SessionContext{} = ctx, sections, selected_sections, max_checked \\ 5) do
    SortableTableModel.new(
      rows: sections,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &custom_render/3
        },
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &custom_render/3
        },
        %ColumnSpec{
          name: :enrollments_count,
          label: "# Enrolled"
        },
        %ColumnSpec{
          name: :requires_payment,
          label: "Cost",
          render_fn: &custom_render/3
        },
        %ColumnSpec{
          name: :start_date,
          label: "Start",
          render_fn: &Common.render_date/3,
          sort_fn: &Common.sort_date/2
        },
        %ColumnSpec{
          name: :end_date,
          label: "End",
          render_fn: &Common.render_date/3,
          sort_fn: &Common.sort_date/2
        },
        %ColumnSpec{
          name: :status,
          label: "Status",
          render_fn: &custom_render/3
        },
        %ColumnSpec{
          name: :instructor,
          label: "Instructors",
          render_fn: &custom_render/3
        },
        %ColumnSpec{
          name: :institution,
          label: "Institution",
          render_fn: &custom_render/3
        },
        %ColumnSpec{
          name: :blueprint,
          label: "Product",
          render_fn: &custom_render/3,
          sortable: false
        },
        %ColumnSpec{
          name: :select,
          label: "Select",
          td_class: "hover:cursor-auto",
          render_fn: &custom_render/3,
          sortable: false
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx,
        fade_data: true,
        selected_sections: selected_sections,
        max_checked: max_checked
      }
    )
  end

  def custom_render(assigns, section, %ColumnSpec{name: :select}) do
    assigns =
      Map.merge(assigns, %{
        section: section,
        checked: MapSet.member?(assigns.selected_sections, section.id)
      })

    ~H"""
    <div class="form-check flex justify-center items-center">
      <input
        id={"select-section-#{@section.id}"}
        type="checkbox"
        class="form-check-input hover:cursor-pointer"
        checked={@checked}
        phx-click={JS.push("toggle_section", value: %{section_id: @section.id})}
        disabled={!@checked and MapSet.size(@selected_sections) >= @max_checked}
      />
    </div>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :title}) do
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <a href={
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
        @section.slug,
        :manage
      )
    }>
      <%= @section.title %>
    </a>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :type}),
    do: if(section.open_and_free, do: "Open", else: "LMS")

  def custom_render(assigns, section, %ColumnSpec{name: :blueprint}) do
    product = if section.blueprint, do: section.blueprint.title, else: ""
    assigns = Map.merge(assigns, %{product: product})

    ~H"""
    <div class="flex space-x-2 items-center">
      <div>
        <%= @product %>
      </div>
    </div>
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
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <div class="flex space-x-2 items-center">
      <div>
        <%= @section.institution && @section.institution.name %>
      </div>
    </div>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :status}),
    do: Phoenix.Naming.humanize(section.status)

  def custom_render(_assigns, section, %ColumnSpec{name: :instructor}),
    do: Map.get(section, :instructor_name, "")

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
