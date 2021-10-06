defmodule OliWeb.Accounts.AccountsLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Repo
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.{ColumnSpec, SortableTable, SortableTableModel}
  alias Oli.Accounts.{Author, User, SystemRole}
  alias Oli.Accounts
  alias OliWeb.Accounts.AccountsModel
  alias OliWeb.Pow.UserContext
  alias OliWeb.Pow.AuthorContext

  alias OliWeb.Accounts.Modals.{
    ConfirmEmailModal,
    GrantAdminModal,
    RevokeAdminModal,
    LockAccountModal,
    UnlockAccountModal,
    DeleteAccountModal
  }

  def mount(
        _params,
        %{"current_author_id" => current_author_id, "csrf_token" => csrf_token},
        socket
      ) do
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
       csrf_token: csrf_token,
       model: model,
       title: "Manage Accounts",
       active: :accounts,
       modal: nil
     )}
  end

  def load_authors_model(current_author) do
    SortableTableModel.new(
      rows: Accounts.list_authors(),
      column_specs: [
        %ColumnSpec{name: :name, label: "Name"},
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
          render_fn: &__MODULE__.render_author_actions_column/3
        }
      ],
      event_suffix: "_authors",
      id_field: ["author", :id]
    )
    |> then(fn {:ok, authors_model} -> authors_model end)
    |> Map.put(:author, current_author)
    |> then(fn authors_model -> {:ok, authors_model} end)
  end

  def load_users_model() do
    SortableTableModel.new(
      rows: Accounts.list_users(),
      column_specs: [
        %ColumnSpec{name: :name, label: "Name"},
        %ColumnSpec{
          name: :email,
          label: "Email",
          render_fn: &__MODULE__.render_email_column/3
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
        },
        %ColumnSpec{
          name: :actions,
          render_fn: &__MODULE__.render_user_actions_column/3
        }
      ],
      event_suffix: "_users",
      id_field: ["user", :id]
    )
  end

  def render_email_column(
        assigns,
        %{email: email, email_confirmed_at: email_confirmed_at, locked_at: locked_at} = row,
        _
      ) do
    checkmark =
      case row do
        %{independent_learner: false} ->
          nil

        _ ->
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

  def render_role_column(assigns, %{system_role_id: system_role_id}, _) do
    admin_role_id = SystemRole.role_id().admin

    case system_role_id do
      ^admin_role_id ->
        ~L"""
          <span class="badge badge-warning">Administrator</span>
        """

      _ ->
        ~L"""
          <span class="badge badge-dark">Author</span>
        """
    end
  end

  def render_user_actions_column(
        %{csrf_token: csrf_token} = assigns,
        %{
          id: id,
          email_confirmed_at: email_confirmed_at,
          locked_at: locked_at,
          independent_learner: independent_learner
        },
        _
      ) do
    resend_confirmation_link_path =
      Routes.pow_path(OliWeb.Endpoint, :resend_user_confirmation_link)

    reset_password_link_path = Routes.pow_path(OliWeb.Endpoint, :send_user_password_reset_link)

    if independent_learner do
      ~L"""
        <form id="resend-confirmation-<%= id %>" method="post" action="<%= resend_confirmation_link_path %>">
          <input type="hidden" name="_csrf_token" value="<%= csrf_token %>" />
          <input type="hidden" name="id" value="<%= id %>" />
        </form>
        <form id="reset-password-<%= id %>" method="post" action="<%= reset_password_link_path %>">
        <input type="hidden" name="_csrf_token" value="<%= csrf_token %>" />
          <input type="hidden" name="id" value="<%= id %>" />
        </form>
        <div class="dropdown">
          <button class="btn btn-xs btn-secondary dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            <i class="las la-tools"></i> Manage
          </button>
          <div class="dropdown-menu dropdown-menu-right" aria-labelledby="dropdownMenuButton">
            <%= if email_confirmed_at == nil do %>
              <button type="submit" class="dropdown-item" form="resend-confirmation-<%= id %>">Resend confirmation link</button>
              <button class="dropdown-item" phx-click="show_confirm_email_modal" phx-value-id="<%= id %>">Confirm email</button>

              <div class="dropdown-divider"></div>
            <% end %>

            <button type="submit" class="dropdown-item" form="reset-password-<%= id %>">Send password reset link</button>

            <div class="dropdown-divider"></div>

            <%= if locked_at != nil do %>
              <button class="dropdown-item text-warning" phx-click="show_unlock_account_modal" phx-value-id="<%= id %>">Unlock Account</button>
            <% else %>
              <button class="dropdown-item text-warning" phx-click="show_lock_account_modal" phx-value-id="<%= id %>">Lock Account</button>
            <% end %>

            <button class="dropdown-item text-danger" phx-click="show_delete_account_modal" phx-value-id="<%= id %>">Delete</button>

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

  def render_author_actions_column(
        %{csrf_token: csrf_token} = assigns,
        %{
          id: id,
          email_confirmed_at: email_confirmed_at,
          system_role_id: system_role_id,
          locked_at: locked_at
        } = row,
        _
      ) do
    admin_role_id = SystemRole.role_id().admin

    resend_confirmation_link_path =
      Routes.pow_path(OliWeb.Endpoint, :resend_author_confirmation_link)

    reset_password_link_path = Routes.pow_path(OliWeb.Endpoint, :send_author_password_reset_link)

    if row != assigns.model.author and
         row.email != System.get_env("ADMIN_EMAIL", "admin@example.edu") do
      ~L"""
        <form id="resend-confirmation-<%= id %>" method="post" action="<%= resend_confirmation_link_path %>">
        <input type="hidden" name="_csrf_token" value="<%= csrf_token %>" />
          <input type="hidden" name="id" value="<%= id %>" />
        </form>
        <form id="reset-password-<%= id %>" method="post" action="<%= reset_password_link_path %>">
        <input type="hidden" name="_csrf_token" value="<%= csrf_token %>" />
          <input type="hidden" name="id" value="<%= id %>" />
        </form>
        <div class="dropdown">
          <button class="btn btn-xs btn-secondary dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            <i class="las la-tools"></i> Manage
          </button>
          <div class="dropdown-menu dropdown-menu-right" aria-labelledby="dropdownMenuButton">
            <%= if email_confirmed_at == nil do %>
              <button type="submit" class="dropdown-item" form="resend-confirmation-<%= id %>">Resend confirmation link</button>
              <button class="dropdown-item" phx-click="show_confirm_email_modal" phx-value-id="<%= id %>">Confirm email</button>

              <div class="dropdown-divider"></div>
            <% end %>

            <button type="submit" class="dropdown-item" form="reset-password-<%= id %>">Send password reset link</button>

            <div class="dropdown-divider"></div>

            <%= case system_role_id do %>
              <% ^admin_role_id -> %>
                <button class="dropdown-item text-warning" phx-click="show_revoke_admin_modal" phx-value-id="<%= id %>">Revoke admin</button>

              <% _ -> %>
                <button class="dropdown-item text-warning" phx-click="show_grant_admin_modal" phx-value-id="<%= id %>">Grant admin</button>
            <% end %>

            <div class="dropdown-divider"></div>


            <%= if locked_at != nil do %>
              <button class="dropdown-item text-warning" phx-click="show_unlock_account_modal" phx-value-id="<%= id %>">Unlock Account</button>
            <% else %>
              <button class="dropdown-item text-warning" phx-click="show_lock_account_modal" phx-value-id="<%= id %>">Lock Account</button>
            <% end %>

            <button class="dropdown-item text-danger" phx-click="show_delete_account_modal" phx-value-id="<%= id %>">Delete</button>

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

  def render_author_column(assigns, %{author: author}, _) do
    case author do
      nil ->
        ~L"""
          <span class="text-secondary"><em>None</em></span>
        """

      author ->
        ~L"""
          <span class="badge badge-dark"><%= author.email %></span>
        """
    end
  end

  def render_learner_column(assigns, %{independent_learner: independent_learner}, _) do
    if independent_learner do
      ~L"""
        <span class="badge badge-primary">Independent Learner</span>
      """
    else
      ~L"""
        <span class="badge badge-dark">LTI</span>
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

  def handle_event("show_confirm_email_modal", %{"id" => id}, socket) do
    %{model: %{active_tab: active_tab}} = socket.assigns

    modal = %{
      component: ConfirmEmailModal,
      assigns: %{
        id: "confirm_email",
        user: get_selected_user(id, active_tab)
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "confirm_email",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :users}}} = socket
      ) do
    email_confirmed_at = DateTime.truncate(DateTime.utc_now(), :second)

    get_selected_user(id, :users)
    |> User.noauth_changeset(%{email_confirmed_at: email_confirmed_at})
    |> Repo.update!()

    {:ok, users_model} = load_users_model()
    model = Map.merge(socket.assigns.model, %{users_model: users_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event(
        "confirm_email",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :authors}}} = socket
      ) do
    email_confirmed_at = DateTime.truncate(DateTime.utc_now(), :second)

    get_selected_user(id, :authors)
    |> Author.noauth_changeset(%{email_confirmed_at: email_confirmed_at})
    |> Repo.update!()

    {:ok, authors_model} = load_authors_model(socket.assigns.model.author)
    model = Map.merge(socket.assigns.model, %{authors_model: authors_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event("show_grant_admin_modal", %{"id" => id}, socket) do
    %{model: %{active_tab: active_tab}} = socket.assigns

    modal = %{
      component: GrantAdminModal,
      assigns: %{
        id: "grant_admin",
        user: get_selected_user(id, active_tab)
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event("grant_admin", %{"id" => id}, socket) do
    admin_role_id = SystemRole.role_id().admin
    author = Accounts.get_author!(id)

    {:noreply,
     socket
     |> change_system_role(author, admin_role_id)
     |> hide_modal()}
  end

  def handle_event("show_revoke_admin_modal", %{"id" => id}, socket) do
    %{model: %{active_tab: active_tab}} = socket.assigns

    modal = %{
      component: RevokeAdminModal,
      assigns: %{
        id: "revoke_admin",
        user: get_selected_user(id, active_tab)
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event("revoke_admin", %{"id" => id}, socket) do
    author_role_id = SystemRole.role_id().author
    author = Accounts.get_author!(id)

    {:noreply,
     socket
     |> change_system_role(author, author_role_id)
     |> hide_modal()}
  end

  def handle_event("show_lock_account_modal", %{"id" => id}, socket) do
    %{model: %{active_tab: active_tab}} = socket.assigns

    modal = %{
      component: LockAccountModal,
      assigns: %{
        id: "lock_account",
        user: get_selected_user(id, active_tab)
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "lock_account",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :users}}} = socket
      ) do
    user = Accounts.get_user!(id)
    UserContext.lock(user)

    {:ok, users_model} = load_users_model()
    model = Map.merge(socket.assigns.model, %{users_model: users_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event(
        "lock_account",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :authors}}} = socket
      ) do
    author = Accounts.get_author!(id)
    AuthorContext.lock(author)

    {:ok, authors_model} = load_authors_model(socket.assigns.model.author)
    model = Map.merge(socket.assigns.model, %{authors_model: authors_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event("show_unlock_account_modal", %{"id" => id}, socket) do
    %{model: %{active_tab: active_tab}} = socket.assigns

    modal = %{
      component: UnlockAccountModal,
      assigns: %{
        id: "unlock_account",
        user: get_selected_user(id, active_tab)
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "unlock_account",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :users}}} = socket
      ) do
    user = Accounts.get_user!(id)
    UserContext.unlock(user)

    {:ok, users_model} = load_users_model()
    model = Map.merge(socket.assigns.model, %{users_model: users_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event(
        "unlock_account",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :authors}}} = socket
      ) do
    author = Accounts.get_author!(id)
    AuthorContext.unlock(author)

    {:ok, authors_model} = load_authors_model(socket.assigns.model.author)
    model = Map.merge(socket.assigns.model, %{authors_model: authors_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event("show_delete_account_modal", %{"id" => id}, socket) do
    %{model: %{active_tab: active_tab}} = socket.assigns

    modal = %{
      component: DeleteAccountModal,
      assigns: %{
        id: "delete_account",
        user: get_selected_user(id, active_tab)
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "delete_account",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :users}}} = socket
      ) do
    user = Accounts.get_user!(id)
    {:ok, _user} = Accounts.delete_user(user)

    {:ok, users_model} = load_users_model()
    model = Map.merge(socket.assigns.model, %{users_model: users_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  def handle_event(
        "delete_account",
        %{"id" => id},
        %{assigns: %{model: %{active_tab: :authors}}} = socket
      ) do
    author = Accounts.get_author!(id)
    {:ok, _author} = Accounts.delete_author(author)

    {:ok, authors_model} = load_authors_model(socket.assigns.model.author)
    model = Map.merge(socket.assigns.model, %{authors_model: authors_model})

    {:noreply,
     socket
     |> assign(model: model)
     |> hide_modal()}
  end

  defp get_selected_user(id, active_tab) do
    case active_tab do
      :authors ->
        Accounts.get_author!(id)

      :users ->
        Accounts.get_user!(id)
    end
  end

  defp change_system_role(socket, author, role_id) do
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
  def render(%{csrf_token: csrf_token} = assigns) do
    ~L"""
    <%= render_modal(assigns) %>
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
            <%= live_component SortableTable, model: (if @model.active_tab == :users do @model.users_model else @model.authors_model end), csrf_token: csrf_token %>
          </div>
        </div>
      </div>
    </div>
    <script>
      $("[data-toggle=tooltip").tooltip();
    </script>
    """
  end
end
