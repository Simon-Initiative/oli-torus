defmodule OliWeb.Users.UsersTableModel do
  use Phoenix.Component

  import OliWeb.Common.Utils

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(users, ctx) do
    SortableTableModel.new(
      rows: users,
      column_specs: [
        %ColumnSpec{name: :name, label: "Name", render_fn: &__MODULE__.render_name_column/3},
        %ColumnSpec{
          name: :email,
          label: "Email",
          render_fn: &OliWeb.Users.Common.render_email_column/3
        },
        %ColumnSpec{
          name: :independent_learner,
          label: "Account Type",
          render_fn: &__MODULE__.render_learner_column/3
        },
        %ColumnSpec{
          name: :author,
          label: "Linked Author",
          render_fn: &__MODULE__.render_author_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_author_column(assigns, %{author: author, author_id: author_id}, _) do
    case author_id do
      nil ->
        ~H"""
        <span class="text-secondary"><em>None</em></span>
        """

      author_id ->
        assigns = Map.merge(assigns, %{author: author, author_id: author_id})

        ~H"""
        <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, @author_id)}>
          <span class="badge badge-dark"><%= @author.email %></span>
        </a>
        """
    end
  end

  def render_name_column(
        assigns,
        %{id: id, name: name, given_name: given_name, family_name: family_name},
        _
      ) do
    assigns =
      Map.merge(assigns, %{id: id, name: name, given_name: given_name, family_name: family_name})

    ~H"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, @id)}>
      <%= name(@name, @given_name, @family_name) %>
    </a>
    """
  end

  def render_learner_column(
        assigns,
        %{independent_learner: independent_learner, can_create_sections: can_create_sections},
        _
      ) do
    primary_badge =
      if independent_learner do
        ~H"""
        <span class="badge badge-primary">Independent Learner</span>
        """
      else
        ~H"""
        <span class="badge badge-dark">LTI</span>
        """
      end

    secondary_badge =
      if can_create_sections do
        ~H"""
        <span class="badge badge-light">Can Create Sections</span>
        """
      else
        ~H"""
        """
      end

    assigns =
      Map.merge(assigns, %{primary_badge: primary_badge, secondary_badge: secondary_badge})

    ~H"""
    <div>
      <%= @primary_badge %>
      <%= @secondary_badge %>
    </div>
    """
  end
end
