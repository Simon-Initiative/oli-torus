defmodule OliWeb.Certificates.CertificatesIssuedTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.ColumnSpec
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Common.Utils

  def new(%SessionContext{} = ctx, granted_certificates, product_slug) do
    column_specs = [
      %ColumnSpec{
        name: :recipient,
        label: "Student",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :issued_at,
        label: "Issue Date",
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      },
      %ColumnSpec{
        name: :issuer,
        label: "Issued By",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :guid,
        label: "ID",
        render_fn: &__MODULE__.custom_render/3,
        sortable: false,
        th_class: "py-5"
      }
    ]

    {:ok, table_model} =
      SortableTableModel.new(
        rows: granted_certificates,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:guid],
        data: %{ctx: ctx, product_slug: product_slug}
      )

    table_model
  end

  def custom_render(assigns, granted_certificate, %ColumnSpec{name: :recipient}) do
    assigns = Map.merge(assigns, %{gc: granted_certificate})

    ~H"""
    <.link
      navigate={~p"/sections/#{@product_slug}/student_dashboard/#{@gc.recipient.id}/content"}
      class="mr-3"
    >
      {Utils.name(@gc.recipient.name, @gc.recipient.family_name, @gc.recipient.given_name)}
    </.link>

    {@gc.recipient.email}
    """
  end

  def custom_render(assigns, granted_certificate, %ColumnSpec{name: :issuer}) do
    assigns = Map.merge(assigns, %{gc: granted_certificate})

    ~H"""
    {Utils.name(@gc.issuer.name, @gc.issuer.family_name, @gc.issuer.given_name)}
    """
  end

  def custom_render(assigns, granted_certificate, %ColumnSpec{name: :guid}) do
    assigns = Map.merge(assigns, %{gc: granted_certificate})

    ~H"""
    {@gc.guid}
    """
  end
end
