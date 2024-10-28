defmodule OliWeb.Users.AuthorsDetailView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Utils

  alias Oli.Accounts
  alias Oli.Accounts.{Author, SystemRole}

  alias OliWeb.Accounts.Modals.{
    LockAccountModal,
    UnlockAccountModal,
    DeleteAccountModal,
    GrantAdminModal,
    RevokeAdminModal,
    ConfirmEmailModal
  }

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias OliWeb.Pow.AuthorContext
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.Actions
  alias OliWeb.Common.SessionContext

  defp set_breadcrumbs(author) do
    OliWeb.Admin.AdminView.breadcrumb()
    |> OliWeb.Users.AuthorsView.breadcrumb()
    |> breadcrumb(author)
  end

  def breadcrumb(previous, %Author{id: id} = author) do
    name = name(author.name, author.given_name, author.family_name)

    previous ++
      [
        Breadcrumb.new(%{
          full_title: name,
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, id)
        })
      ]
  end

  def mount(
        %{"user_id" => user_id},
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    author = Accounts.get_author(author_id)

    case Accounts.get_author(user_id) do
      nil ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      user ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(user),
           author: author,
           user: user,
           csrf_token: Phoenix.Controller.get_csrf_token(),
           changeset: author_changeset(user),
           disabled_edit: true,
           ctx: SessionContext.init(socket, session),
           authors: SystemRole.role_id(),
           password_reset_link: ""
         )}
    end
  end

  attr(:author, :any)
  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "Author Details")
  attr(:user, :map, default: nil)
  attr(:modal, :any, default: nil)
  attr(:csrf_token, :any)
  attr(:changeset, :map)
  attr(:disabled_edit, :boolean, default: true)
  attr(:authors, :map, default: %{})

  def render(assigns) do
    ~H"""
    <div>
      <%= render_modal(assigns) %>

      <Groups.render>
        <Group.render label="Details" description="User details">
          <.form
            id="edit_author"
            for={@changeset}
            phx-change="change"
            phx-submit="submit"
            autocomplete="off"
          >
            <ReadOnly.render label="Name" value={@user.name} />
            <div class="form-group">
              <label for="given_name">First Name</label>
              <.input
                value={fetch_field(@changeset, :given_name)}
                id="given_name"
                name="author[given_name]"
                class="form-control"
                disabled={@disabled_edit}
              />
            </div>
            <div class="form-group">
              <label for="family_name">Last Name</label>
              <.input
                value={fetch_field(@changeset, :family_name)}
                id="family_name"
                name="author[family_name]"
                class="form-control"
                disabled={@disabled_edit}
              />
            </div>
            <div class="form-group">
              <label for="email">Email</label>
              <.input
                value={fetch_field(@changeset, :email)}
                id="email"
                name="author[email]"
                class="form-control"
                disabled={@disabled_edit}
              />
            </div>
            <div class="form-group">
              <label for="role">Role</label>
              <select
                id="role"
                class="form-control"
                name="author[system_role_id]"
                disabled={@disabled_edit or not Accounts.is_system_admin?(@author)}
              >
                <%= for {_type, id} <- @authors do %>
                  <option value={id} selected={@user.system_role_id == id}><%= role(id) %></option>
                <% end %>
              </select>
            </div>
            <%= unless @disabled_edit do %>
              <button type="submit" class="float-right btn btn-md btn-primary mt-2">Save</button>
            <% end %>
          </.form>
          <%= if @disabled_edit do %>
            <button class="float-right btn btn-md btn-primary mt-2" phx-click="start_edit">
              Edit
            </button>
          <% end %>
        </Group.render>
        <Group.render
          label="Projects"
          description="Projects that the Author has either created or is a collaborator within"
        >
          <.live_component
            module={OliWeb.Users.AuthorProjects}
            id="author_projects"
            user={@user}
            ctx={@ctx}
          />
        </Group.render>
        <Group.render label="Actions" description="Actions that can be taken for this user">
          <%= if @user.id != @author.id and @user.email != System.get_env("ADMIN_EMAIL", "admin@example.edu") do %>
            <Actions.user_actions
              user={@user}
              csrf_token={@csrf_token}
              for_author={true}
              password_reset_link={@password_reset_link}
            />
          <% end %>
        </Group.render>
      </Groups.render>
    </div>
    """
  end

  def handle_event("show_confirm_email_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <ConfirmEmailModal.render id="confirm_email" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "confirm_email",
        _,
        socket
      ) do
    email_confirmed_at = DateTime.truncate(DateTime.utc_now(), :second)

    case Accounts.update_author(socket.assigns.user, %{email_confirmed_at: email_confirmed_at}) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user)
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Error confirming author's email")}
    end
  end

  def handle_event("show_unlock_account_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <UnlockAccountModal.render id="unlock_account" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("generate_reset_password_link", params, socket) do
    {:noreply,
     assign(socket,
       password_reset_link: OliWeb.PowController.create_password_reset_link(params, :author)
     )}
  end

  def handle_event(
        "unlock_account",
        %{"id" => id},
        socket
      ) do
    author = Accounts.get_author!(id)
    AuthorContext.unlock(author)

    {:noreply,
     socket
     |> assign(user: Accounts.get_author!(id))
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("show_delete_account_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <DeleteAccountModal.render id="delete_account" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "delete_account",
        %{"id" => id},
        socket
      ) do
    author = Accounts.get_author!(id)

    case Accounts.delete_author(author) do
      {:ok, _} ->
        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)
         |> put_flash(:info, "Author successfully deleted.")
         |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Author couldn't be deleted.")}
    end
  end

  def handle_event("show_lock_account_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <LockAccountModal.render id="lock_account" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "lock_account",
        %{"id" => id},
        socket
      ) do
    author = Accounts.get_author!(id)
    AuthorContext.lock(author)

    {:noreply,
     socket
     |> assign(user: Accounts.get_author!(id))
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("show_grant_admin_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <GrantAdminModal.render id="grant_admin" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("grant_admin", %{"id" => id}, socket) do
    admin_role_id = SystemRole.role_id().system_admin
    author = Accounts.get_author!(id)

    {:noreply,
     socket
     |> change_system_role(author, admin_role_id)
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("show_revoke_admin_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <RevokeAdminModal.render id="revoke_admin" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("revoke_admin", %{"id" => id}, socket) do
    author_role_id = SystemRole.role_id().author
    author = Accounts.get_author!(id)

    {:noreply,
     socket
     |> change_system_role(author, author_role_id)
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("change", %{"author" => params}, socket) do
    {:noreply, assign(socket, changeset: author_changeset(socket.assigns.user, params))}
  end

  def handle_event("submit", %{"author" => params}, socket) do
    case Accounts.update_author(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Author successfully updated.")
         |> assign(user: user, changeset: author_changeset(user, params), disabled_edit: true)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Author couldn't be updated.")}
    end
  end

  def handle_event("start_edit", _, socket) do
    {:noreply, socket |> assign(disabled_edit: false)}
  end

  defp author_changeset(author, attrs \\ %{}) do
    Author.noauth_changeset(author, attrs)
    |> Map.put(:action, :update)
  end

  defp change_system_role(socket, author, role_id) do
    case Accounts.update_author(author, %{system_role_id: role_id}) do
      {:ok, author} ->
        assign(socket, user: author)

      {:error, _} ->
        put_flash(socket, :error, "Could not edit author")
    end
  end

  defp role(system_role_id) do
    admin_role_id = SystemRole.role_id().system_admin
    account_role_id = SystemRole.role_id().account_admin
    content_role_id = SystemRole.role_id().content_admin

    case system_role_id do
      ^admin_role_id ->
        "System Admin"

      ^account_role_id ->
        "Account Admin"

      ^content_role_id ->
        "Content Admin"

      _ ->
        "Author"
    end
  end
end
