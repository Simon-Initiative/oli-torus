defmodule OliWeb.Accounts.AccountsLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.{ColumnSpec, SortableTable, SortableTableModel}
  alias OliWeb.Common.Modal
  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Accounts
  alias OliWeb.Accounts.AccountsModel
  alias OliWeb.Pow.UserContext
  alias OliWeb.Pow.AuthorContext

  def mount(_, %{"current_author_id" => current_author_id}, socket) do
    current_author = Repo.get(Author, current_author_id)

    {:ok, authors_model} = load_authors_model(current_author)
    {:ok, users_model} = load_users_model()

    {:ok, model} =
      AccountsModel.new(
        users_model: users_model,
        authors_model: authors_model,
        author: current_author
      )

    {:ok,
     assign(socket,
       model: model,
       title: "Manage Accounts",
       active: :accounts,
       selected_author: nil,
       selected_user: nil
     )}
  end

  def load_authors_model(current_author) do
    SortableTableModel.new(
      rows: Accounts.list_authors(),
      column_specs: [
        %ColumnSpec{name: :given_name, label: "First Name"},
        %ColumnSpec{name: :family_name, label: "Last Name"},
        %ColumnSpec{
          name: :email,
          label: "Email",
          render_fn: &__MODULE__.render_email_column/3
        },
        %ColumnSpec{
          name: :system_role_id,
          label: "Role",
          render_fn: &__MODULE__.render_role_column/3
        },
        %ColumnSpec{
          name: :actions,
          label: "",
          render_fn: &__MODULE__.render_author_actions_column/3
        }
      ],
      event_suffix: "_authors",
      id_field: :email
    )
    |> then(fn {:ok, authors_model} -> authors_model end)
    |> Map.put(:author, current_author)
    |> then(fn authors_model -> {:ok, authors_model} end)
  end

  def load_users_model() do
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
  end

  def render_email_column(
        assigns,
        %{email: email, email_confirmed_at: email_confirmed_at, locked_at: locked_at},
        _
      ) do
    checkmark =
      if email_confirmed_at == nil do
        ~L"""
        <span data-toggle="tooltip" data-html="true" title="<b>Confirmation Pending</b> sent to <%= email %>">
          <i class="las la-paper-plane text-secondary"></i>
        </span>
        """
      else
        ~L"""
        <span data-toggle="tooltip" data-html="true" title="<b>Email Confirmed</b> on <%= Timex.format!(email_confirmed_at, "{YYYY}-{M}-{D}") %>">
          <i class="las la-check text-success"></i>
        </span>
        """
      end

    ~L"""
      <div class="d-flex flex-row">
       <%= email %> <div class="flex-grow-1"></div> <%= checkmark %>
      </div>
      <div>
        <%= if locked_at != nil do %>
          <span class="badge badge-warning"><i class="las la-user-lock"></i> Account Locked</span>
        <% end %>
      </div>
    """
  end

  def render_role_column(assigns, %{system_role_id: system_role_id} = row, _) do
    admin_role_id = SystemRole.role_id().admin

    case system_role_id do
      ^admin_role_id ->
        ~L"""
          <span class="badge badge-warning">Administrator</span>
        """

      _ ->
        ~L"""
          <span class="badge badge-light">Author</span>
        """
    end
  end

  def render_author_actions_column(
        assigns,
        %{
          id: id,
          email: email,
          email_confirmed_at: email_confirmed_at,
          system_role_id: system_role_id,
          locked_at: locked_at
        } = row,
        _
      ) do
    admin_role_id = SystemRole.role_id().admin

    resend_confirmation_link_path =
      Routes.pow_path(OliWeb.Endpoint, :resend_author_confirmation_link)

    if row != assigns.model.author and
         row.email != System.get_env("ADMIN_EMAIL", "admin@example.edu") do
      ~L"""
        <div class="dropdown">
          <button class="btn btn-xs btn-secondary dropdown-toggle" type="button" id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            <i class="las la-tools"></i> Manage
          </button>
          <div class="dropdown-menu" aria-labelledby="dropdownMenuButton">
            <%= if email_confirmed_at == nil do %>
              <form method="post" action="<%= resend_confirmation_link_path %>">
                <input type="hidden" name="id" value="<%= id %>" />
                <button type="submit" class="dropdown-item">Resend confirmation link</button>
              </form>
              <button class="dropdown-item">Confirm email</button>

              <div class="dropdown-divider"></div>
            <% end %>

            <button class="dropdown-item">Reset password</button>

            <div class="dropdown-divider"></div>

            <%= case system_role_id do %>
              <% ^admin_role_id -> %>
                <button class="dropdown-item text-danger" data-toggle="modal" data-target="#revoke_admin" phx-click="select_author" phx-value-id="<%= id %>">Revoke admin</button>

              <% _ -> %>
                <button class="dropdown-item text-warning" data-toggle="modal" data-target="#grant_admin" phx-click="select_author" phx-value-id="<%= id %>">Grant admin</button>
            <% end %>

            <div class="dropdown-divider"></div>


            <%= if locked_at != nil do %>
              <button class="dropdown-item text-warning" data-toggle="modal" data-target="#unlock_user" phx-click="select_author" phx-value-id="<%= id %>">Unlock Account</button>
            <% else %>
              <button class="dropdown-item text-warning" data-toggle="modal" data-target="#lock_user" phx-click="select_author" phx-value-id="<%= id %>">Lock Account</button>
            <% end %>

            <button class="dropdown-item text-danger" data-toggle="modal" data-target="#delete_user" phx-click="select_author" phx-value-id="<%= id %>">Delete</button>
          </div>
        </div>
      """
    else
      ~L"""
      <button class="btn btn-xs btn-secondary dropdown-toggle" type="button" disabled>
        <i class="las la-tools"></i> Manage
      </button>
      """
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

  def handle_event("select_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:noreply, assign(socket, selected_user: user)}
  end

  def handle_event("select_author", %{"id" => id}, socket) do
    author = Accounts.get_author!(id)
    {:noreply, assign(socket, selected_author: author)}
  end

  def handle_event("lock_user_users", _, socket) do
    UserContext.lock(socket.assigns.selected_user)

    {:ok, users_model} = load_users_model()
    model = Map.merge(socket.assigns.model, %{users_model: users_model})

    {:noreply, assign(socket, model: model, selected_user: nil)}
  end

  def handle_event("unlock_user_users", _, socket) do
    UserContext.unlock(socket.assigns.selected_user)

    {:ok, users_model} = load_users_model()
    model = Map.merge(socket.assigns.model, %{users_model: users_model})

    {:noreply, assign(socket, model: model, selected_user: nil)}
  end

  def handle_event("delete_user_users", _, socket) do
    IO.inspect("TODO: delete_user_users")

    {:noreply, assign(socket, selected_user: nil)}
  end

  def handle_event("lock_user_authors", _, socket) do
    AuthorContext.lock(socket.assigns.selected_author)

    {:ok, authors_model} = load_authors_model(socket.assigns.model.author)
    model = Map.merge(socket.assigns.model, %{authors_model: authors_model})

    {:noreply, assign(socket, model: model, selected_author: nil)}
  end

  def handle_event("unlock_user_authors", _, socket) do
    AuthorContext.unlock(socket.assigns.selected_author)

    {:ok, authors_model} = load_authors_model(socket.assigns.model.author)
    model = Map.merge(socket.assigns.model, %{authors_model: authors_model})

    {:noreply, assign(socket, model: model, selected_author: nil)}
  end

  def handle_event("delete_user_authors", _, socket) do
    IO.inspect("TODO: delete_user_authors")

    {:noreply, assign(socket, selected_author: nil)}
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
    author = Accounts.get_author!(socket.assigns.selection)

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
                class="nav-link <%= if @model.active_tab == :authors do "active" else "" end %>" href="#authors">Authors</a>
            </li>
            <li class="nav-item">
              <a phx-click="active_tab" phx-value-tab="users"
                class="nav-link <%= if @model.active_tab == :users do "active" else "" end %>" href="#users">Users</a>
            </li>
          </ul>
          <div class="mt-4 ml-1 mr-2">
            <%= live_component SortableTable, model: (if @model.active_tab == :users do @model.users_model else @model.authors_model end) %>
          </div>
        </div>
      </div>
      <%= live_component Modal, title: "Confirm", modal_id: "grant_admin", ok_action: "grant_admin", ok_label: "Grant", ok_style: "btn btn-warning" do %>
        <p class="mb-4">Are you sure you want to grant this author <b>administrator privileges</b>?</p>
      <% end %>
      <%= live_component Modal, title: "Confirm", modal_id: "revoke_admin", ok_action: "revoke_admin", ok_label: "Revoke", ok_style: "btn btn-danger" do %>
        <p class="mb-4">Are you sure you want to revoke <b>administrator privileges</b> from this author account?</p>
      <% end %>
      <%= live_component Modal, title: "Confirm", modal_id: "lock_user", ok_action: "lock_user_#{@model.active_tab}", ok_label: "Lock", ok_style: "btn btn-warning" do %>
        <p class="mb-4">Are you sure you want to <b>lock</b> access this account?</p>
      <% end %>
      <%= live_component Modal, title: "Confirm", modal_id: "unlock_user", ok_action: "unlock_user_#{@model.active_tab}", ok_label: "Unlock", ok_style: "btn btn-warning" do %>
        <p class="mb-4">Are you sure you want to <b>unlock</b> access this account?</p>
      <% end %>
      <%= live_component Modal, title: "Confirm", modal_id: "delete_user", ok_action: "delete_user_#{@model.active_tab}", ok_label: "Delete", ok_style: "btn btn-danger" do %>
        <p class="mb-4">Are you sure you want to <b>delete</b> this account?</p>
      <% end %>
    </div>
    <script>
      $("[data-toggle=tooltip").tooltip();
    </script>
    """
  end
end
