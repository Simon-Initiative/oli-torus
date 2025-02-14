defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  alias OliWeb.Components.Delivery.Students.Certificates.{
    PendingApprovalComponent,
    StateApprovalComponent
  }

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias Lti_1p3.Tool.ContextRoles

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(
        users,
        section,
        ctx,
        certificate,
        certificate_pending_approval_count,
        target
      ) do
    column_specs =
      [
        %ColumnSpec{
          name: :name,
          label: "STUDENT NAME",
          render_fn: &__MODULE__.render_name_column/3,
          sort_fn: &__MODULE__.sort_name_column/2,
          th_class: "pl-10"
        },
        %ColumnSpec{
          name: :email,
          label: "EMAIL",
          render_fn: &__MODULE__.render_email_column/3
        },
        %ColumnSpec{
          name: :last_interaction,
          label: "LAST INTERACTED",
          render_fn: &__MODULE__.render_last_interaction_column/3
        },
        %ColumnSpec{
          name: :progress,
          th_class: "flex items-center gap-1 ",
          label: HTMLComponents.student_progress_label(%{title: "COURSE PROGRESS"}),
          render_fn: &__MODULE__.render_progress_column/3
        },
        %ColumnSpec{
          name: :overall_proficiency,
          label: "OVERALL COURSE PROFICIENCY",
          render_fn: &__MODULE__.render_overall_proficiency_column/3,
          tooltip:
            "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it."
        },
        %ColumnSpec{
          name: :type,
          label: "TYPE",
          render_fn: &__MODULE__.render_type_column/3,
          sortable: false
        }
      ] ++
        if section.requires_payment do
          [
            %ColumnSpec{
              name: :payment_status,
              label: "PAYMENT STATUS",
              render_fn: &__MODULE__.render_payment_status/3
            }
          ]
        else
          []
        end ++
        if certificate do
          [
            %ColumnSpec{
              name: :certificate_status,
              label: render_certificate_status_label(certificate_pending_approval_count),
              render_fn: &render_certificate_status_column/3,
              th_class: "flex items-center gap-2"
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
        section: section,
        target: target,
        certificate: certificate
      }
    )
  end

  def sort_name_column(_sort_order, _sort_spec) do
    {
      fn item -> item end,
      fn row1, row2 ->
        Utils.name(row1.name, row1.given_name, row1.family_name) <=
          Utils.name(row2.name, row2.given_name, row2.family_name)
      end
    }
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
        name: name,
        family_name: family_name,
        given_name: given_name,
        link:
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
            assigns.section.slug,
            id,
            :content
          )
      })

    ~H"""
    <div class="flex items-center ml-8">
      <div class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @progress < 50, do: "bg-red-600", else: "bg-gray-500"}"}>
      </div>
      <.link class="ml-6 underline" navigate={@link}>
        <%= if @name, do: Utils.name(@name, @given_name, @family_name), else: "N/A" %>
      </.link>
    </div>
    """
  end

  def render_payment_status(
        assigns,
        %{payment_status: payment_status, payment_date: payment_date},
        _
      ) do
    assigns = Map.merge(assigns, %{payment_status: payment_status, payment_date: payment_date})

    ~H"""
    <div class={if @payment_status == :not_paid, do: "text-red-600 font-bold"}>
      <%= render_label(@payment_status, @payment_date, @section, @ctx) %>
    </div>
    """
  end

  def render_progress_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{progress: parse_progress(user.progress)})

    ~H"""
    <div
      class={if @progress < 50, do: "text-red-600 font-bold"}
      data-progress-check={if @progress >= 50, do: "true", else: "false"}
    >
      <%= @progress %>%
    </div>
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
    <div class={if @overall_proficiency == "Low", do: "text-red-600 font-bold"}>
      <%= @overall_proficiency %>
    </div>
    """
  end

  def render_email_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{email: Map.get(user, :email)})

    ~H"""
    <div><%= @email %></div>
    """
  end

  def render_type_column(assigns, user, _) do
    assigns =
      Map.merge(assigns, %{
        type:
          if(
            user.user_role_id == ContextRoles.get_role(:context_instructor).id,
            do: "Instructor",
            else: "Student"
          )
      })

    ~H"""
    <div><%= @type %></div>
    """
  end

  defp render_certificate_status_label(pending_approvals)
       when pending_approvals in [nil, 0],
       do: "CERTIFICATE STATUS"

  defp render_certificate_status_label(pending_approvals) do
    assigns = %{pending_approvals: pending_approvals}

    ~H"""
    <div class="flex items-center gap-2">
      <.live_component
        id="certificate_pending_approval_count_badge"
        module={PendingApprovalComponent}
        pending_approvals={@pending_approvals}
      /> CERTIFICATE STATUS
    </div>
    """
  end

  def render_certificate_status_column(assigns, user, _) do
    assigns =
      Map.merge(assigns, %{
        certificate_status: Map.get(user, :certificate) && user.certificate.state,
        user_id: user.id,
        granted_certificate_id: Map.get(user, :certificate) && user.certificate.id
      })

    ~H"""
    <.live_component
      id={"certificate-state-component-#{@user_id}"}
      module={StateApprovalComponent}
      certificate_status={@certificate_status}
      requires_instructor_approval={@certificate.requires_instructor_approval}
      granted_certificate_id={@granted_certificate_id}
    />
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

  defp render_label(:not_paid, _, _, _), do: "Not Paid"

  defp render_label(:within_grace_period, _, section, _) do
    grace_period_days = section.grace_period_days
    start_date = section.start_date

    days_remaining =
      Timex.diff(Timex.shift(start_date, days: grace_period_days), Timex.now(), :days)

    "Grace Period: #{days_remaining}d remaining"
  end

  defp render_label(:paid, date, _, ctx), do: "Paid on #{FormatDateTime.date(date, ctx)}"
  defp render_label(_, _, _, _), do: "-"
end
