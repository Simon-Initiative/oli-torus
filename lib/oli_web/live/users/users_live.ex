defmodule OliWeb.Users.UsersLive do

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.{ColumnSpec, SortableTable, SortableTableModel}
  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Accounts

  alias Oli.Repo

  def mount(_, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)

    {:ok, authors_model} = SortableTableModel.new(
      rows: Accounts.list_authors(),
      column_specs: [
        %ColumnSpec{name: :first_name, label: "First Name"},
        %ColumnSpec{name: :last_name, label: "Last Name"},
        %ColumnSpec{name: :email, label: "Email"},
        %ColumnSpec{name: :system_role_id, label: "Role",
          render_fn: &__MODULE__.render_role_column/3}],
      event_suffix: "_authors")

    {:ok, assign(socket, authors_model: authors_model, author: author, title: "Account Management")}
  end

  def render_role_column(assigns, %{system_role_id: system_role_id}, _) do
    admin_role_id = SystemRole.role_id().admin
    case system_role_id do
      ^admin_role_id ->
        ~L"""
          <span class="badge badge-primary">Administrator</span>
        """
      _ ->
        ~L"""
          <span class="badge badge-light">Author</span>
        """
    end
  end

  def handle_event("sort_authors", %{"sort_by" => sort_by}, socket) do

    authors_model = SortableTableModel.update_sort_params(socket.assigns.authors_model, String.to_existing_atom(sort_by))

    {:noreply, push_patch(socket, to: Routes.live_path(socket, OliWeb.Users.UsersLive,
      %{authors_sort_by: authors_model.sort_by_spec.name, authors_sort_order: authors_model.sort_order}))}
  end

  def handle_params(params, _, socket) do

    authors_sort_by =
      case params["authors_sort_by"] do
        sort_by when sort_by in ~w(last_name first_name email system_role_id) -> Enum.find(socket.assigns.authors_model.column_specs, fn s -> s.name == String.to_existing_atom(sort_by) end)
        _ -> socket.assigns.authors_model.sort_by_spec
      end

    authors_sort_order =
      case params["authors_sort_order"] do
        sort_order when sort_order in ~w(asc desc) -> String.to_existing_atom(sort_order)
        _ -> socket.assigns.authors_model.sort_order
      end

    authors_model = Map.put(socket.assigns.authors_model, :sort_by_spec, authors_sort_by)
    |> Map.put(:sort_order, authors_sort_order)
    |> SortableTableModel.sort

    {:noreply, assign(socket, authors_model: authors_model)}
  end

  def render(assigns) do
    ~L"""
    <div class="container">
      <div class="row">
        <div class="col-12">
          <%= live_component @socket, SortableTable, model: @authors_model %>
        </div>
      </div>
    """
  end

end
