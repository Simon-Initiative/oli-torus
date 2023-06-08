defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  alias OliWeb.Common.FormatDateTime

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(users, section, ctx) do
    column_specs =
      [
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
          name: :overall_proficiency,
          label: "OVERALL COURSE PROFICIENCY",
          render_fn: &__MODULE__.render_overall_proficiency_column/3,
          th_class: "instructor_dashboard_th"
        }
      ] ++
        if section.requires_payment do
          [
            %ColumnSpec{
              name: :payment_status,
              label: "PAYMENT STATUS",
              render_fn: &__MODULE__.render_payment_status/3,
              th_class: "instructor_dashboard_th"
            }
          ]
        else
          []
        end

    SortableTableModel.new(
      rows: users,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx,
        section: section
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
        navigate={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.StudentDashboard.StudentDashboardLive, @section.slug, @id, :content)}
      >
        <%= Utils.name(@name, @given_name, @family_name) %>
      </.link>
    </div>
    """
  end

  def render_payment_status(
        assigns,
        %{payment_status: payment_status, payment_date: payment_date},
        _
      ) do
    assigns = assign(assigns, payment_status: payment_status, payment_date: payment_date)

    ~H"""
      <div class={if @payment_status == :not_paid, do: "text-red-600 font-bold"}><%= render_label(@payment_status, @payment_date, @section) %></div>
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
        last_interaction: Map.get(user, :last_interaction)
      })

    ~H"""
    <%= parse_last_interaction(@last_interaction, @ctx) %>
    """
  end

  def render_overall_proficiency_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{overall_proficiency: Map.get(user, :overall_proficiency)})

    ~H"""
      <div class={if @overall_proficiency == "Low", do: "text-red-600 font-bold"}><%= @overall_proficiency %></div>
    """
  end

  defp parse_progress(progress) do
    {progress, _} =
      ((progress && Float.round(progress * 100)) || 0.0)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end

  defp parse_last_interaction(nil, _ctx), do: "-"

  defp parse_last_interaction(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
  end

  defp render_label(:not_paid, _, _), do: "Not Paid"

  defp render_label(:within_grace_period, _, section) do
    grace_period_days = section.grace_period_days
    start_date = section.start_date

    days_remaining =
      Timex.diff(Timex.shift(start_date, days: grace_period_days), Timex.now(), :days)

    "Grace Period: #{days_remaining}d remaining"
  end

  defp render_label(:paid, date, _), do: "Paid on #{Timex.format!(date, "{0M}/{0D}/{YYYY}")}"
  defp render_label(_, _, _), do: "-"
end
