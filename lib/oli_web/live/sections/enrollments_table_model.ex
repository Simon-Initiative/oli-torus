defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
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
        render_fn: &__MODULE__.stub_last_interacted/3,
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
        render_fn: &__MODULE__.stub_overall_mastery/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :engagement,
        label: "COURSE ENGAGEMENT",
        render_fn: &__MODULE__.stub_engagement/3,
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
    assigns = Map.merge(assigns, %{progress: parse_progress(progress)})
    # TODO link to "Student Details View" (not yet developed) instead of "Student Progress View"
    ~F"""
    <div class="flex items-center ml-8">
      <div class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @progress < 50, do: "bg-red-600", else: "bg-gray-500"}"}></div>
      <a
        class="ml-6 text-gray-600 underline hover:text-gray-700"
        href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, assigns.section_slug, id)}
      >
        {Utils.name(name, given_name, family_name)}
      </a>
    </div>
    """
  end

  def render_progress_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{progress: parse_progress(user.progress)})

    ~F"""
    <div class={if @progress < 50, do: "text-red-600 font-bold"} data-progress-check={if @progress >= 50, do: "true", else: "false"}>{@progress}%</div>
    """
  end

  def render_unenroll_column(assigns, user, _) do
    ~F"""
    <button class="btn btn-outline-danger" phx-click="unenroll" phx-value-id={user.id}>
      Unenroll
    </button>
    """
  end

  def stub_last_interacted(assigns, _user, _) do
    random_datetime = DateTime.utc_now() |> DateTime.add(-Enum.random(1..365), :day)
    assigns = Map.merge(assigns, %{last_interacted_stub: random_datetime})

    ~F"""
    {Timex.format!(@last_interacted_stub, "{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")}
    """
  end

  def stub_overall_mastery(assigns, _user, _) do
    assigns = Map.merge(assigns, %{overall_mastery: random_value()})

    ~F"""
      <div class={if @overall_mastery == "Low", do: "text-red-600 font-bold"}>{@overall_mastery}</div>
    """
  end

  def stub_engagement(assigns, _user, _) do
    assigns = Map.merge(assigns, %{engagement: random_value()})

    ~F"""
      <div class={if @engagement == "Low", do: "text-red-600 font-bold"}>{@engagement}</div>
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
