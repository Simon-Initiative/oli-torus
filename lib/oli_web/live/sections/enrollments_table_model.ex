defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  use OliWeb, :verified_routes
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  alias OliWeb.Components.Delivery.Students.Certificates.{
    PendingApprovalComponent,
    StateApprovalComponent
  }

  alias OliWeb.Common.Utils
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Chip
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias Phoenix.LiveView.JS

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
        target,
        selected_students \\ []
      ) do
    column_specs =
      [
        %ColumnSpec{
          name: :selection,
          label: render_select_all_header(users, selected_students, target),
          render_fn: &__MODULE__.render_selection_column/3,
          sortable: false,
          th_class: "w-4"
        },
        %ColumnSpec{
          name: :name,
          label: "Student Name",
          render_fn: &render_name_column/3,
          sort_fn: &sort_name_column/2
        },
        %ColumnSpec{
          name: :email,
          label: "Email",
          render_fn: &render_email_column/3
        },
        %ColumnSpec{
          name: :last_interaction,
          label: "Last Interacted",
          render_fn: &render_last_interaction_column/3
        },
        %ColumnSpec{
          name: :progress,
          th_class: "flex items-center gap-1 !border-b-0",
          label: HTMLComponents.student_progress_label(%{title: "Student Progress"}),
          render_fn: &render_progress_column/3
        },
        %ColumnSpec{
          name: :overall_proficiency,
          label: "Student Proficiency",
          render_fn: &render_proficiency_column/3,
          tooltip:
            "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it."
        }
      ] ++
        if section.requires_payment do
          [
            %ColumnSpec{
              name: :payment_status,
              label: "Payment Status",
              render_fn: &render_payment_status/3
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
              th_class: "flex items-center gap-2 border-b-0"
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

  def render_select_all_header(users, selected_students, target) do
    all_user_ids = Enum.map(users, & &1.id)

    all_selected =
      length(selected_students) > 0 && Enum.all?(all_user_ids, &(&1 in selected_students))

    assigns = %{
      all_selected: all_selected,
      target: target,
      has_users: length(users) > 0
    }

    ~H"""
    <div class="flex items-center justify-center">
      <input
        :if={@has_users}
        type="checkbox"
        checked={@all_selected}
        class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        phx-click="select_all_students"
        phx-target={@target}
      />
    </div>
    """
  end

  def render_selection_column(assigns, user, _) do
    selected_students = Map.get(assigns, :selected_students, [])
    is_selected = user.id in selected_students

    assigns = Map.merge(assigns, %{is_selected: is_selected, user_id: user.id})

    ~H"""
    <div class="flex items-center justify-center">
      <input
        type="checkbox"
        checked={@is_selected}
        class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        phx-click={JS.push("paged_table_selection_change", value: %{id: @user_id})}
        phx-target={@target}
      />
    </div>
    """
  end

  def render_name_column(
        assigns,
        %{
          id: id,
          name: name,
          given_name: given_name,
          family_name: family_name
        },
        _
      ) do
    assigns =
      Map.merge(assigns, %{
        name: name,
        family_name: family_name,
        given_name: given_name,
        link: ~p"/sections/#{assigns.section.slug}/student_dashboard/#{id}/content"
      })

    ~H"""
    <.link
      navigate={@link}
      class="text-Text-text-link text-base font-medium leading-normal"
    >
      {if @name, do: Utils.name(@name, @given_name, @family_name), else: "N/A"}
    </.link>
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
      {render_label(@payment_status, @payment_date, @section, @ctx)}
    </div>
    """
  end

  def render_progress_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{progress: parse_progress(user.progress)})

    ~H"""
    <span
      class={"text-Text-text-high text-base font-bold leading-normal #{if @progress < 50, do: " text-Text-text-danger"}"}
      data-progress-check={if @progress >= 50, do: "true", else: "false"}
    >
      {@progress}%
    </span>
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
    <span class="text-Text-text-high text-base font-medium leading-normal">
      {parse_last_interaction(@last_interaction, @ctx)}
    </span>
    """
  end

  def render_proficiency_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{overall_proficiency: Map.get(user, :overall_proficiency)})

    {bg_color, text_color} =
      case assigns.overall_proficiency do
        "High" -> {"bg-Fill-Chip-Green", "text-Text-Chip-Green"}
        "Medium" -> {"bg-Fill-Accent-fill-accent-orange", "text-Text-Chip-Orange"}
        "Low" -> {"bg-Fill-fill-danger", "text-Text-text-danger"}
        _ -> {"bg-Fill-Chip-Gray", "text-Text-Chip-Gray"}
      end

    assigns =
      Map.merge(assigns, %{
        label: assigns.overall_proficiency,
        bg_color: bg_color,
        text_color: text_color
      })

    ~H"""
    <Chip.render {assigns} />
    """
  end

  def render_email_column(assigns, user, _) do
    assigns = Map.merge(assigns, %{email: Map.get(user, :email)})

    ~H"""
    <span class="text-Text-text-high text-base font-medium leading-normal">
      {@email}
    </span>
    """
  end

  defp render_certificate_status_label(pending_approvals)
       when pending_approvals in [nil, 0],
       do: "Certificate Status"

  defp render_certificate_status_label(pending_approvals) do
    assigns = %{pending_approvals: pending_approvals}

    ~H"""
    <div class="flex items-center gap-2">
      <.live_component
        id="certificate_pending_approval_count_badge"
        module={PendingApprovalComponent}
        pending_approvals={@pending_approvals}
      /> Certificate Status
    </div>
    """
  end

  def render_certificate_status_column(assigns, user, _) do
    assigns =
      Map.merge(assigns, %{
        certificate_status: Map.get(user, :certificate) && user.certificate.state,
        student: user,
        granted_certificate_id: Map.get(user, :certificate) && user.certificate.id
      })

    ~H"""
    <.live_component
      id={"certificate-state-component-#{@student.id}"}
      module={StateApprovalComponent}
      certificate_status={@certificate_status}
      requires_instructor_approval={@certificate.requires_instructor_approval}
      granted_certificate_id={@granted_certificate_id}
      certificate_id={@certificate.id}
      student={@student}
      platform_name={Oli.Branding.brand_name(@section)}
      course_name={@section.title}
      instructor_email={issued_by_email(@ctx)}
      issued_by_type={issued_by_type(@ctx)}
      issued_by_id={issued_by_id(@ctx)}
    />
    """
  end

  defp issued_by_email(%{author: author} = _ctx) when not is_nil(author), do: author.email
  defp issued_by_email(ctx), do: ctx.user.email

  defp issued_by_type(%{author: author} = _ctx) when not is_nil(author), do: :author
  defp issued_by_type(_ctx), do: :user

  defp issued_by_id(%{author: author} = _ctx) when not is_nil(author), do: author.id
  defp issued_by_id(ctx), do: ctx.user.id

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
