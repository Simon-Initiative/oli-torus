defmodule OliWeb.Users.UsersTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(users) do
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
      id_field: [:id]
    )
  end

  def render_author_column(assigns, %{author: author}, _) do
    case author do
      nil ->
        ~F"""
          <span class="text-secondary"><em>None</em></span>
        """

      author ->
        ~F"""
          <span class="badge badge-dark">{author.email}</span>
        """
    end
  end

  defp has_value(v) do
    !is_nil(v) and v != ""
  end

  defp normalize(name, given_name, family_name) do
    case {has_value(name), has_value(given_name), has_value(family_name)} do
      {_, true, true} -> "#{family_name}, #{given_name}"
      {false, false, true} -> family_name
      {true, _, _} -> name
      _ -> "Unknown"
    end
  end

  def render_name_column(
        assigns,
        %{id: id, name: name, given_name: given_name, family_name: family_name},
        _
      ) do
    ~F"""
      <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, id)}>{normalize(name, given_name, family_name)}</a>
    """
  end

  def render_learner_column(assigns, %{independent_learner: independent_learner}, _) do
    if independent_learner do
      ~F"""
        <span class="badge badge-primary">Independent Learner</span>
      """
    else
      ~F"""
        <span class="badge badge-dark">LTI</span>
      """
    end
  end
end
