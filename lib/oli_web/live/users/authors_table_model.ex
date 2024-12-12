defmodule OliWeb.Users.AuthorsTableModel do
  use Phoenix.Component

  import OliWeb.Common.Utils

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(authors, ctx) do
    SortableTableModel.new(
      rows: authors,
      column_specs: [
        %ColumnSpec{
          name: :name,
          label: "Name",
          render_fn: &__MODULE__.render_name_column/3
        },
        %ColumnSpec{
          name: :email,
          label: "Email",
          render_fn: &OliWeb.Users.Common.render_email_column/3
        },
        %ColumnSpec{
          name: :collaborations_count,
          label: "Count of Projects"
        },
        %ColumnSpec{
          name: :system_role_id,
          label: "Role",
          render_fn: &__MODULE__.render_role_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_role_column(assigns, author, _) do
    has_admin_role? = Accounts.has_admin_role?(author, :account_admin)

    if has_admin_role? do
      ~H"""
      <span class="badge badge-warning">Administrator</span>
      """
    else
      ~H"""
      <span class="badge badge-dark">Author</span>
      """
    end
  end

  def render_name_column(
        assigns,
        %{name: name, family_name: family_name, given_name: given_name, id: id},
        _
      ) do
    assigns =
      Map.merge(assigns, %{id: id, name: name, family_name: family_name, given_name: given_name})

    ~H"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, @id)}>
      <%= name(@name, @given_name, @family_name) %>
    </a>
    """
  end
end
