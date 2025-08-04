defmodule OliWeb.Components.Delivery.ContentTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.ColumnSpec
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias OliWeb.Common.Chip

  alias OliWeb.Router.Helpers, as: Routes

  def new(containers, container_column_name, section_slug, view, patch_url_type, navigation_data) do
    column_specs = [
      %ColumnSpec{
        name: :numbering_index,
        label: "Order"
      },
      %ColumnSpec{
        name: :container_name,
        label: container_column_name,
        render_fn: &render_name_column/3
      },
      %ColumnSpec{
        name: :student_completion,
        label: HTMLComponents.student_progress_label(%{title: "Class Progress"}),
        render_fn: &render_student_completion/3
      },
      %ColumnSpec{
        name: :student_proficiency,
        label: "Class Proficiency",
        tooltip:
          "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it.",
        render_fn: &render_student_proficiency/3
      }
    ]

    SortableTableModel.new(
      rows: containers,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        section_slug: section_slug,
        view: view,
        patch_url_type: patch_url_type,
        navigation_data: navigation_data
      }
    )
  end

  def render_name_column(
        assigns,
        container,
        column_spec
      ) do
    url_params =
      case column_spec.label do
        "Pages" -> %{page_id: container.id}
        _ -> %{container_id: container.id}
      end

    navigation_data = Map.merge(assigns.navigation_data, %{current_container_id: container.id})

    url_params = Map.merge(url_params, %{navigation_data: Jason.encode!(navigation_data)})

    assigns =
      Map.merge(assigns, %{
        progress: parse_progress(container.progress),
        title: container.title,
        url_params: url_params
      })

    ~H"""
    <div class="flex items-center">
      <%= if @patch_url_type == :instructor_dashboard do %>
        <.link
          class="justify-start text-[#1B67B2] dark:text-[#4CA6FF] text-base font-medium leading-normal"
          patch={
            Routes.live_path(
              OliWeb.Endpoint,
              OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
              @section_slug,
              @view,
              :content,
              @url_params
            )
          }
        >
          <%= @title %>
        </.link>
      <% else %>
        <div class="ml-6 text-gray-600">
          <%= @title %>
        </div>
      <% end %>
    </div>
    """
  end

  def render_student_completion(assigns, container, _) do
    assigns = Map.merge(assigns, %{progress: parse_progress(container.progress)})

    ~H"""
    <div
      class={"font-bold #{if @progress < 50, do: "text-[#FF8787]", else: "text-[#353740] dark:text-[#EEEBF5]"}"}
      data-progress-check={if @progress >= 50, do: "true", else: "false"}
    >
      <%= @progress %>%
    </div>
    """
  end

  def render_student_proficiency(assigns, container, _) do
    {bg_color, text_color} =
      case container.student_proficiency do
        "High" -> {"bg-[#e6fcf2] dark:bg-[#3D4F47]", "text-[#175a3d] dark:text-[#39E581]"}
        "Medium" -> {"bg-[#ffecde] dark:bg-[#4C3F39]", "text-[#91450e] dark:text-[#FFB387]"}
        "Low" -> {"bg-[#feebed] dark:bg-[#33181A]", "text-[#ce2c31] dark:text-[#FF8787]"}
        _ -> {"bg-[#ced1d9] dark:bg-[#353740]", "text-[#000000] dark:text-[#FFFFFF]"}
      end

    assigns =
      Map.merge(assigns, %{
        label: container.student_proficiency,
        bg_color: bg_color,
        text_color: text_color
      })

    ~H"""
    <Chip.render {assigns} />
    """
  end

  defp parse_progress(progress) do
    {progress, _} =
      Float.round(progress * 100)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end
end
