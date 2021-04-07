defmodule OliWeb.Accounts.AccountsLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.{ColumnSpec, SortableTable, SortableTableModel}
  alias OliWeb.Common.Modal
  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Accounts
  alias OliWeb.Accounts.AccountsModel

  alias Oli.Repo

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    {:ok, authors_model} =
      SortableTableModel.new(
        rows: Accounts.list_authors(),
        column_specs: [
          %ColumnSpec{name: :given_name, label: "First Name"},
          %ColumnSpec{name: :family_name, label: "Last Name"},
          %ColumnSpec{name: :email, label: "Email"},
          %ColumnSpec{
            name: :system_role_id,
            label: "Role",
            render_fn: &__MODULE__.render_role_column/3
          }
        ],
        event_suffix: "_authors",
        id_field: :email
      )

    authors_model = Map.put(authors_model, :author, author)

    {:ok, users_model} =
      SortableTableModel.new(
        rows: Accounts.list_users(),
        column_specs: [
          %ColumnSpec{name: :given_name, label: "First Name"},
          %ColumnSpec{name: :family_name, label: "Last Name"},
          %ColumnSpec{name: :email, label: "Email"},
          %ColumnSpec{
            name: :author_id,
            label: "Author?",
            render_fn: &__MODULE__.render_author_column/3
          }
        ],
        event_suffix: "_users",
        id_field: :email
      )

    {:ok, model} =
      AccountsModel.new(users_model: users_model, authors_model: authors_model, author: author)

    {:ok, assign(socket, model: model, title: "Account Management", active: :accounts)}
  end

  def render_role_column(assigns, %{system_role_id: system_role_id} = row, _) do
    admin_role_id = SystemRole.role_id().admin

    if row == assigns.model.selected and
         row.email != System.get_env("ADMIN_EMAIL", "admin@example.edu") and
         row != assigns.model.author do
      case system_role_id do
        ^admin_role_id ->
          ~L"""
            <span class="badge badge-primary">Administrator</span>
            <span class="ml-3 badge badge-danger" style="cursor: pointer;" data-toggle="modal" data-target="#revoke_admin">Revoke Admin</span>
          """

        _ ->
          ~L"""
            <span class="badge badge-light">Author</span>
            <span class="ml-3 badge badge-danger" style="cursor: pointer;" data-toggle="modal" data-target="#grant_admin">Grant Admin</span>
          """
      end
    else
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
  end

  def render_author_column(assigns, %{author_id: author_id}, _) do
    case author_id do
      nil ->
        ""

      _ ->
        ~L"""
          <span class="badge badge-light">Author</span>
        """
    end
  end

  defp get_patch_params(%AccountsModel{
         authors_model: authors_model,
         users_model: users_model,
         active_tab: active_tab
       }) do
    Map.merge(%{active_tab: active_tab}, SortableTableModel.to_params(authors_model))
    |> Map.merge(SortableTableModel.to_params(users_model))
  end

  def handle_event("sort_authors", %{"sort_by" => sort_by}, socket) do
    authors_model =
      SortableTableModel.update_sort_params(
        socket.assigns.model.authors_model,
        String.to_existing_atom(sort_by)
      )

    model = Map.put(socket.assigns.model, :authors_model, authors_model)

    {:noreply,
     push_patch(socket, to: Routes.live_path(socket, __MODULE__, get_patch_params(model)))}
  end

  def handle_event("sort_users", %{"sort_by" => sort_by}, socket) do
    users_model =
      SortableTableModel.update_sort_params(
        socket.assigns.model.users_model,
        String.to_existing_atom(sort_by)
      )

    model = Map.put(socket.assigns.model, :users_model, users_model)

    {:noreply,
     push_patch(socket, to: Routes.live_path(socket, __MODULE__, get_patch_params(model)))}
  end

  def handle_event("active_tab", %{"tab" => "users"}, socket) do
    model = AccountsModel.change_active_tab(socket.assigns.model, :users)

    {:noreply,
     push_patch(socket, to: Routes.live_path(socket, __MODULE__, get_patch_params(model)))}
  end

  def handle_event("active_tab", %{"tab" => "authors"}, socket) do
    model = AccountsModel.change_active_tab(socket.assigns.model, :authors)

    {:noreply,
     push_patch(socket, to: Routes.live_path(socket, __MODULE__, get_patch_params(model)))}
  end

  def handle_event("select_authors", %{"id" => email}, socket) do
    authors_model = SortableTableModel.update_selection(socket.assigns.model.authors_model, email)
    model = Map.put(socket.assigns.model, :authors_model, authors_model)

    {:noreply,
     push_patch(socket, to: Routes.live_path(socket, __MODULE__, get_patch_params(model)))}
  end

  def handle_event("select_users", %{"id" => email}, socket) do
    users_model = SortableTableModel.update_selection(socket.assigns.model.users_model, email)
    model = Map.put(socket.assigns.model, :users_model, users_model)

    {:noreply,
     push_patch(socket, to: Routes.live_path(socket, __MODULE__, get_patch_params(model)))}
  end

  def handle_event("grant_admin", _, socket) do
    admin_role_id = SystemRole.role_id().admin
    {:noreply, change_system_role(admin_role_id, socket)}
  end

  def handle_event("revoke_admin", _, socket) do
    author_role_id = SystemRole.role_id().author
    {:noreply, change_system_role(author_role_id, socket)}
  end

  defp change_system_role(role_id, socket) do
    author = Accounts.get_author_by_email(socket.assigns.model.authors_model.selected.email)

    case Accounts.update_author(author, %{system_role_id: role_id}) do
      {:ok, author} ->
        index =
          Enum.find_index(socket.assigns.model.authors_model.rows, fn a ->
            a.email == author.email
          end)

        rows = List.replace_at(socket.assigns.model.authors_model.rows, index, author)

        authors_model =
          Map.put(socket.assigns.model.authors_model, :rows, rows)
          |> Map.put(:selected, author)

        model = Map.put(socket.assigns.model, :authors_model, authors_model)
        assign(socket, model: model)

      {:error, _} ->
        put_flash(socket, :error, "Could not edit author")
    end
  end

  def handle_params(params, _, socket) do
    active_tab =
      case params["active_tab"] do
        tab when tab in ~w(authors users) -> String.to_existing_atom(tab)
        _ -> socket.assigns.model.active_tab
      end

    authors_model =
      SortableTableModel.update_from_params(socket.assigns.model.authors_model, params)

    users_model = SortableTableModel.update_from_params(socket.assigns.model.users_model, params)

    model =
      AccountsModel.change_active_tab(socket.assigns.model, active_tab)
      |> Map.put(:authors_model, authors_model)
      |> Map.put(:users_model, users_model)

    {:noreply, assign(socket, model: model)}
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~L"""
    <div class="container">
      <div class="row">
        <div class="col-12">
          <ul class="nav nav-tabs">
            <li class="nav-item">
              <a phx-click="active_tab" phx-value-tab="authors"
                class="nav-link <%= if @model.active_tab == :authors do "active" else "" end %>" href="#">Authors</a>
            </li>
            <li class="nav-item">
              <a phx-click="active_tab" phx-value-tab="users"
                class="nav-link <%= if @model.active_tab == :users do "active" else "" end %>" href="#">Users</a>
            </li>
          </ul>
          <div class="mt-4 ml-1 mr-2">
            <%= live_component @socket, SortableTable, model: (if @model.active_tab == :users do @model.users_model else @model.authors_model end) %>
          </div>
        </div>
      </div>
      <%= live_component @socket, Modal, title: "Confirm", modal_id: "grant_admin", ok_action: "grant_admin" do %>
        <p class="mb-4">Are you sure you want to do grant this user Administrator access?</p>
      <% end %>
      <%= live_component @socket, Modal, title: "Confirm", modal_id: "revoke_admin", ok_action: "revoke_admin" do %>
        <p class="mb-4">Are you sure you want to do revoke Administrator privileges from this author account?</p>
      <% end %>
    </div>
    """
  end
end
