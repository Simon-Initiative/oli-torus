defmodule OliWeb.Users.AuthorsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Oli.Accounts.SystemRole
  alias OliWeb.Router.Helpers, as: Routes

  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(authors) do
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
      id_field: [:id]
    )
  end

  def render_role_column(assigns, %{system_role_id: system_role_id}, _) do
    admin_role_id = SystemRole.role_id().admin

    case system_role_id do
      ^admin_role_id ->
        ~F"""
          <span class="badge badge-warning">Administrator</span>
        """

      _ ->
        ~F"""
          <span class="badge badge-dark">Author</span>
        """
    end
  end

  def render_name_column(assigns, %{name: name, id: id}, _) do
    ~F"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, id)}>{name}</a>
    """
  end
end
