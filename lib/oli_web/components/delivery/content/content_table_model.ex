defmodule OliWeb.Components.Delivery.ContentTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.ColumnSpec
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents

  alias OliWeb.Router.Helpers, as: Routes

  def new(containers, container_column_name, section_slug, view, patch_url_type, navigation_data) do
    column_specs = [
      %ColumnSpec{
        name: :numbering_index,
        label: "ORDER",
        th_class: "pl-10",
        td_class: "pl-10"
      },
      %ColumnSpec{
        name: :container_name,
        label: container_column_name,
        render_fn: &__MODULE__.render_name_column/3
      },
      %ColumnSpec{
        name: :student_completion,
        th_class: "flex items-center gap-1 ",
        label: HTMLComponents.student_progress_label(%{title: "STUDENT PROGRESS"}),
        render_fn: &__MODULE__.render_student_completion/3
      },
      %ColumnSpec{
        name: :student_proficiency,
        label: "STUDENT PROFICIENCY",
        tooltip:
          "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it.",
        render_fn: &__MODULE__.render_student_proficiency/3
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
        "PAGES" -> %{page_id: container.id}
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
      <div class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @progress < 50, do: "bg-red-600", else: "bg-gray-500"}"}>
      </div>
      <%= if @patch_url_type == :instructor_dashboard do %>
        <.link
          class="ml-6 underline"
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
      class={if @progress < 50, do: "text-red-600 font-bold"}
      data-progress-check={if @progress >= 50, do: "true", else: "false"}
    >
      <%= @progress %>%
    </div>
    """
  end

  def render_student_proficiency(assigns, container, _) do
    assigns = Map.merge(assigns, %{container: container})

    ~H"""
    <div class={if @container.student_proficiency == "Low", do: "text-red-600 font-bold"}>
      <%= @container.student_proficiency %>
    </div>
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
