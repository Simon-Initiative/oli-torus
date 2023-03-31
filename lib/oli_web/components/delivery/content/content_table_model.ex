defmodule OliWeb.Components.Delivery.ContentTableModel do
  use Phoenix.Component
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(containers, container_column_name, section_slug) do
    column_specs = [
      %ColumnSpec{
        name: :container_name,
        label: container_column_name,
        render_fn: &__MODULE__.render_name_column/3,
        th_class: "pl-10 instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :student_completion,
        label: "STUDENT COMPLETION",
        render_fn: &__MODULE__.render_student_completion/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :student_mastery,
        label: "STUDENT MASTERY",
        render_fn: &__MODULE__.stub_student_mastery/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :student_engagement,
        label: "STUDENT ENGAGEMENT",
        render_fn: &__MODULE__.stub_student_engagement/3,
        th_class: "instructor_dashboard_th"
      }
    ]

    SortableTableModel.new(
      rows: containers,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{section_slug: section_slug}
    )
  end

  def render_name_column(
        assigns,
        container,
        _column_spec
      ) do
    assigns =
      Map.merge(assigns, %{
        progress: parse_progress(container.progress),
        title: container.title,
        container_id: container.id,
        section_slug: assigns.model.data.section_slug
      })

    ~H"""
    <div class="flex items-center ml-8">
      <div class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @progress < 50, do: "bg-red-600", else: "bg-gray-500"}"}></div>
      <.link
        class="ml-6 text-gray-600 underline hover:text-gray-700"
        patch={Routes.live_path(OliWeb.Endpoint,
        OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
        @section_slug,
        :students, %{container_id: @container_id})}
      >
        <%= @title %>
      </.link>
    </div>
    """
  end

  def render_student_completion(assigns, container, _) do
    assigns = Map.merge(assigns, %{progress: parse_progress(container.progress)})

    ~H"""
    <div class={if @progress < 50, do: "text-red-600 font-bold"} data-progress-check={if @progress >= 50, do: "true", else: "false"}><%= @progress %>%</div>
    """
  end

  def stub_student_mastery(assigns, _user, _) do
    assigns = Map.merge(assigns, %{overall_mastery: random_value()})

    ~H"""
      <div class={if @overall_mastery == "Low", do: "text-red-600 font-bold"}><%= @overall_mastery%></div>
    """
  end

  def stub_student_engagement(assigns, _user, _) do
    assigns = Map.merge(assigns, %{engagement: random_value()})

    ~H"""
      <div class={if @engagement == "Low", do: "text-red-600 font-bold"}><%= @engagement %></div>
    """
  end

  defp random_value(), do: Enum.random(["Low", "Medium", "High", "Not enough data"])

  defp parse_progress(progress) do
    {progress, _} =
      ((progress && Float.round(progress * 100)) || 0.0)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end
end
