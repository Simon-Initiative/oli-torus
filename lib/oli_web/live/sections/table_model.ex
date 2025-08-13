defmodule OliWeb.Sections.SectionsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(%SessionContext{} = ctx, sections, render_institution_action \\ false) do
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
          name: :base,
          label: "Base Project/Product",
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
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx,
        fade_data: true,
        render_institution_action: render_institution_action
      }
    )
  end

  def custom_render(assigns, section, %ColumnSpec{name: :title}) do
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <a
      href={~p"/sections/#{@section.slug}/manage"}
      target="_blank"
      class="text-[#1B67B2] dark:text-[#99CCFF]"
    >
      <%= @section.title %>
    </a>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :type}),
    do: if(section.open_and_free, do: "Open", else: "LMS")

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
        :active -> "text-[#245D45] dark:text-[#39E581]"
        :deleted -> "text-[#A42327] dark:text-[#FF8787]"
        _ -> "text-[#1B67B2] dark:text-[#99CCFF]"
      end

    assigns = Map.merge(assigns, %{section: section, class: class})

    ~H"""
    <span class={@class}>
      <%= Phoenix.Naming.humanize(@section.status) %>
    </span>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :base}) do
    if section.blueprint_id do
      route_path =
        Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section.blueprint.slug)

      SortableTableModel.render_link_column(
        assigns,
        section.blueprint.title,
        route_path,
        "text-[#1B67B2] dark:text-[#99CCFF]"
      )
    else
      route_path = ~p"/workspaces/course_author/#{section.base_project.slug}/overview"

      SortableTableModel.render_link_column(
        assigns,
        section.base_project.title,
        route_path,
        "text-[#1B67B2] dark:text-[#99CCFF]"
      )
    end
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :instructor}),
    do: Map.get(section, :instructor_name, "")

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
