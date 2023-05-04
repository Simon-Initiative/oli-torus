defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(users, section, context) do
    column_specs = [
      %ColumnSpec{
        name: :name,
        label: "STUDENT NAME",
        render_fn: &__MODULE__.render_name_column/3,
        th_class: "pl-10 instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :last_interaction,
        label: "LAST INTERACTED",
        render_fn: &__MODULE__.render_last_interaction_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :progress,
        label: "COURSE PROGRESS",
        render_fn: &__MODULE__.render_progress_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :overall_mastery,
        label: "OVERALL COURSE MASTERY",
        render_fn: &__MODULE__.render_overall_mastery_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :engagement,
        label: "COURSE ENGAGEMENT",
        render_fn: &__MODULE__.render_engagement_column/3,
        th_class: "instructor_dashboard_th"
      }
    ]

    SortableTableModel.new(
      rows: users,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context,
        section_slug: section.slug
      }
    )
  end

  def render_name_column(
        assigns,
        %{
          id: id,
          name: name,
          given_name: given_name,
          family_name: family_name,
          progress: progress
        },
        _
      ) do
    assigns =
      Map.merge(assigns, %{
        progress: parse_progress(progress),
        id: id,
        name: name,
        family_name: family_name,
        given_name: given_name
      })

    ~H"""
    <div class="flex items-center ml-8">
      <div class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @progress < 50, do: "bg-red-600", else: "bg-gray-500"}"}></div>
      <.link
        class="ml-6 text-gray-600 underline hover:text-gray-700"
        navigate={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.StudentDashboard.StudentDashboardLive, @section_slug, @id, :content)}
      >
        <%= Utils.name(@name, @given_name, @family_name) %>
      </.link>
    </div>
    """
  end

  def render_progress_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{progress: parse_progress(user.progress)})

    ~H"""
    <div class={if @progress < 50, do: "text-red-600 font-bold"} data-progress-check={if @progress >= 50, do: "true", else: "false"}><%= @progress %>%</div>
    """
  end

  def render_unenroll_column(assigns, _user, _) do
    ~H"""
    <button class="btn btn-outline-danger" phx-click="unenroll" phx-value-id={@user.id}>
      Unenroll
    </button>
    """
  end

  def render_last_interaction_column(assigns, user, _) do
    assigns =
      Map.merge(assigns, %{
        last_interaction: parse_last_interaction(Map.get(user, :last_interaction))
      })

    ~H"""
    <%= @last_interaction %>
    """
  end

  def render_overall_mastery_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{overall_mastery: Map.get(user, :overall_mastery)})

    ~H"""
      <div class={if @overall_mastery == "Low", do: "text-red-600 font-bold"}><%= @overall_mastery %></div>
    """
  end

  def render_engagement_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{engagement: Map.get(user, :engagement)})

    ~H"""
      <div class={if @engagement == "Low", do: "text-red-600 font-bold"}><%= @engagement %></div>
    """
  end

  defp parse_progress(progress) do
    {progress, _} =
      ((progress && Float.round(progress * 100)) || 0.0)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end

  defp parse_last_interaction(nil), do: "-"

  defp parse_last_interaction(datetime) do
    Timex.format!(datetime, "{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
  end
end
