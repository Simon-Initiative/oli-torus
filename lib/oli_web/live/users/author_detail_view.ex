defmodule OliWeb.Users.AuthorsDetailView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, :live}
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
  alias Surface.Components.Form
  alias Surface.Components.Form.{Label, Field, Submit, TextInput}
  alias OliWeb.Common.SessionContext

  prop(author, :any)
  data(breadcrumbs, :any)
  data(title, :string, default: "Author Details")
  data(user, :struct, default: nil)
  data(modal, :any, default: nil)
  data(csrf_token, :any)
  data(changeset, :changeset)
  data(disabled_edit, :boolean, default: true)

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
        %{"csrf_token" => csrf_token, "current_author_id" => author_id} = session,
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
           csrf_token: csrf_token,
           changeset: author_changeset(user),
           disabled_edit: true,
           ctx: SessionContext.init(socket, session)
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div>
      {render_modal(assigns)}
      <Groups.render>
        <Group.render label="Details" description="User details">
          <Form for={@changeset} change="change" submit="submit" opts={autocomplete: "off"}>
            <ReadOnly.render label="Name" value={@user.name}/>
            <Field name={:given_name} class="form-group">
              <Label text="First Name"/>
              <TextInput class="form-control" opts={disabled: @disabled_edit}/>
            </Field>
            <Field name={:family_name} class="form-group">
              <Label text="Last Name"/>
              <TextInput class="form-control" opts={disabled: @disabled_edit}/>
            </Field>
            <Field name={:email} class="form-group">
              <Label text="Email"/>
              <TextInput class="form-control" opts={disabled: @disabled_edit}/>
            </Field>
            <ReadOnly.render label="Role" value={role(@user.system_role_id)}/>
            {#unless @disabled_edit}
              <Submit class={"float-right btn btn-md btn-primary mt-2"}>Save</Submit>
            {/unless}
          </Form>
          {#if @disabled_edit}
            <button class={"float-right btn btn-md btn-primary mt-2"} phx-click="start_edit">Edit</button>
          {/if}
        </Group.render>
        <Group.render label="Projects" description="Projects that the Author has either created or is a collaborator within">
          {live_component OliWeb.Users.AuthorProjects,
            id: "author_projects",
            user: @user,
            ctx: @ctx
          }
        </Group.render>
        <Group.render label="Actions" description="Actions that can be taken for this user">
          {#if @user.id != @author.id and @user.email != System.get_env("ADMIN_EMAIL", "admin@example.edu")}
            <Actions.render user={@user} csrf_token={@csrf_token} for_author={true}/>
          {/if}
        </Group.render>
      </Groups.render>
    </div>
    """
  end

  def handle_event("show_confirm_email_modal", _, socket) do
    modal_assigns = %{
      id: "confirm_email",
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~F"""
        <ConfirmEmailModal.render {...@modal_assigns} />
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
      id: "unlock_account",
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~F"""
        <UnlockAccountModal.render {...@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
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
      id: "delete_account",
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~F"""
        <DeleteAccountModal.render {...@modal_assigns} />
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
         |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Author couldn't be deleted.")}
    end
  end

  def handle_event("show_lock_account_modal", _, socket) do
    modal_assigns = %{
      id: "lock_account",
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~F"""
        <LockAccountModal.render {...@modal_assigns} />
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
      id: "grant_admin",
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~F"""
        <GrantAdminModal.render {...@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("grant_admin", %{"id" => id}, socket) do
    admin_role_id = SystemRole.role_id().admin
    author = Accounts.get_author!(id)

    {:noreply,
     socket
     |> change_system_role(author, admin_role_id)
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("show_revoke_admin_modal", _, socket) do
    modal_assigns = %{
      id: "revoke_admin",
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~F"""
        <RevokeAdminModal.render {...@modal_assigns} />
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
    admin_role_id = SystemRole.role_id().admin

    case system_role_id do
      ^admin_role_id ->
        "Administrator"

      _ ->
        "Author"
    end
  end
end
