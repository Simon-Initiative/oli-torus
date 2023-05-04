defmodule OliWeb.Users.UserEnrolledTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end

  def new(sections, user, context) do
    SortableTableModel.new(
      rows: sections,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &__MODULE__.render_title_column/3,
          th_class: "whitespace-nowrap"
        },
        %ColumnSpec{
          name: :enrollment_status,
          label: "Enrollment Status",
          th_class: "whitespace-nowrap"
        },
        %ColumnSpec{
          name: :enrollment_role,
          label: "Enrollment Role",
          th_class: "whitespace-nowrap"
        },
        %ColumnSpec{
          name: :start_date,
          label: "Start Date",
          render_fn: &__MODULE__.custom_render_date/3,
          th_class: "whitespace-nowrap"
        },
        %ColumnSpec{
          name: :end_date,
          label: "End Date",
          render_fn: &__MODULE__.custom_render_date/3,
          th_class: "whitespace-nowrap"
        },
        %ColumnSpec{
          name: :payment_status,
          label: "Payment Status",
          render_fn: &__MODULE__.render_payment_status/3,
          th_class: "whitespace-nowrap"
        },
        %ColumnSpec{
          name: :last_accessed,
          label: "Last Accessed",
          render_fn: &__MODULE__.render_last_accessed/3,
          th_class: "whitespace-nowrap"
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context,
        user: user
      }
    )
  end

  def render_last_accessed(assigns, row, col_spec) do
    case row.last_accessed do
      nil ->
        ~F"""
          <span>Not accessed yet</span>
        """

      _ ->
        ~F"""
          <span>{Utils.render_relative_date(row, col_spec.name, Map.get(assigns, :context))}</span>
        """
    end
  end

  def custom_render_date(assigns, row, col_spec) do
    Utils.render_relative_date(row, col_spec.name, Map.get(assigns, :context))
  end

  def render_title_column(assigns, row, _col_spec) do
    route_path =
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
        row.slug,
        assigns.user.id,
        :content
      )

    SortableTableModel.render_link_column(
      assigns,
      row.title,
      route_path,
      "instructor_dashboard_table_link"
    )
  end

  def render_payment_status(assigns, row, _col_spec) do
    case row.payment_status do
      :not_paywalled ->
        ~F"""
          <span>N/A</span>
        """

      :paid ->
        ~F"""
          <span>Paid</span>
        """

      :not_paid ->
        ~F"""
          <span>Not Paid</span>
        """

      :within_grace_period ->
        ~F"""
          <span>Within Grace Period</span>
        """

      :instructor ->
        ~F"""
          <span>Instructor</span>
        """

      _ ->
        ~F"""
          <span>Unknown</span>
        """
    end
  end
end
