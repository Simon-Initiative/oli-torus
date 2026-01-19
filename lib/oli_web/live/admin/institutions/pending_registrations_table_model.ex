defmodule OliWeb.Admin.Institutions.PendingRegistrationsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Common.Utils
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  def new(pending_registrations, ctx) do
    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"

    column_specs = [
      %ColumnSpec{
        name: :name,
        label: "Name",
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :institution_url,
        label: "URL",
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :institution_email,
        label: "Contact Email",
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "When",
        render_fn: &__MODULE__.render_date_column/3,
        sort_fn: &Common.sort_date/2,
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :actions,
        label: "Action",
        render_fn: &__MODULE__.render_actions_column/3,
        sortable: false,
        th_class: default_th_class,
        td_class: "text-nowrap " <> default_td_class
      }
    ]

    sort_by_spec = Enum.find(column_specs, fn spec -> spec.name == :inserted_at end)

    SortableTableModel.new(
      rows: pending_registrations,
      column_specs: column_specs,
      event_suffix: "_pending_registrations",
      id_field: [:id],
      sort_by_spec: sort_by_spec,
      sort_order: :desc,
      data: %{
        ctx: ctx
      }
    )
  end

  def render_date_column(assigns, pending_registration, _) do
    Utils.render_date(pending_registration, :inserted_at, assigns.ctx)
  end

  def render_actions_column(assigns, pending_registration, _) do
    assigns = Map.merge(assigns, %{pending_registration: pending_registration})

    ~H"""
    <button
      class="btn btn-sm btn-outline-primary ml-2"
      phx-click={
        JS.push("select_pending_registration",
          value: %{registration_id: @pending_registration.id, action: "review"}
        )
        |> Modal.show_modal("review-registration-modal")
      }
    >
      Review
    </button>
    <button
      class="btn btn-sm btn-outline-danger ml-2"
      phx-click={
        JS.push("select_pending_registration",
          value: %{registration_id: @pending_registration.id, action: "decline"}
        )
        |> Modal.show_modal("decline-registration-modal")
      }
    >
      Decline
    </button>
    """
  end
end
