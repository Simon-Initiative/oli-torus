defmodule OliWeb.Users.AuthorsDetailView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
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

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "Author Details"
  data user, :struct, default: nil
  data modal, :any, default: nil
  data csrf_token, :any

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
        %{"csrf_token" => csrf_token, "current_author_id" => author_id},
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
           csrf_token: csrf_token
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div>
      {render_modal(assigns)}
      <Groups>
        <Group label="Details" description="User details">
          <ReadOnly label="Name" value={@user.name}/>
          <ReadOnly label="First Name" value={@user.given_name}/>
          <ReadOnly label="Last Name" value={@user.family_name}/>
          <ReadOnly label="Email" value={@user.email}/>
          <ReadOnly label="Role" value={role(@user.system_role_id)}/>
        </Group>
        <Group label="Actions" description="Actions that can be taken for this user">
          {#if @user.id != @author.id and @user.email != System.get_env("ADMIN_EMAIL", "admin@example.edu")}
            <Actions user={@user} csrf_token={@csrf_token} for_author={true}/>
          {/if}
        </Group>
      </Groups>
    </div>
    """
  end

  def handle_event("show_confirm_email_modal", _, socket) do
    modal = %{
      component: ConfirmEmailModal,
      assigns: %{
        id: "confirm_email",
        user: socket.assigns.user
      }
    }

    {:noreply, assign(socket, modal: modal)}
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
         |> hide_modal()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Error confirming author's email")}
    end
  end

  def handle_event("show_unlock_account_modal", _, socket) do
    modal = %{
      component: UnlockAccountModal,
      assigns: %{
        id: "unlock_account",
        user: socket.assigns.user
      }
    }

    {:noreply, assign(socket, modal: modal)}
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
     |> hide_modal()}
  end

  def handle_event("show_delete_account_modal", _, socket) do
    modal = %{
      component: DeleteAccountModal,
      assigns: %{
        id: "delete_account",
        user: socket.assigns.user
      }
    }

    {:noreply, assign(socket, modal: modal)}
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
         |> put_flash(:info, "Author successfully deleted.")
         |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Author couldn't be deleted.")}
    end
  end

  def handle_event("show_lock_account_modal", _, socket) do
    modal = %{
      component: LockAccountModal,
      assigns: %{
        id: "lock_account",
        user: socket.assigns.user
      }
    }

    {:noreply, assign(socket, modal: modal)}
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
     |> hide_modal()}
  end

  def handle_event("show_grant_admin_modal", _, socket) do
    modal = %{
      component: GrantAdminModal,
      assigns: %{
        id: "grant_admin",
        user: socket.assigns.user
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

  def handle_event("show_revoke_admin_modal", _, socket) do
    modal = %{
      component: RevokeAdminModal,
      assigns: %{
        id: "revoke_admin",
        user: socket.assigns.user
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

  defp change_system_role(socket, author, role_id) do
    case Accounts.update_author(author, %{system_role_id: role_id}) do
      {:ok, author} ->
        assign(socket, user: author)

      {:error, _} ->
        put_flash(socket, :error, "Could not edit author")
    end
  end

  defp role(system_role_id) do
    admin_role_id = SystemRole.role_id().admin

    case system_role_id do
      ^admin_role_id ->
        "Administrator"

      _ ->
        "Author"
    end
  end
end
