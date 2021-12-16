defmodule OliWeb.Users.UsersDetailView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, Label, Field, Submit}
  use OliWeb.Common.Modal

  import OliWeb.Common.Properties.Utils
  import OliWeb.Common.Utils

  alias Oli.Repo
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Pow.UserContext
  alias OliWeb.Users.Actions

  alias OliWeb.Accounts.Modals.{
    LockAccountModal,
    UnlockAccountModal,
    DeleteAccountModal,
    ConfirmEmailModal
  }

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "User Details"
  data user, :struct, default: nil
  data modal, :any, default: nil
  data csrf_token, :any
  data changeset, :changeset

  defp set_breadcrumbs(user) do
    OliWeb.Admin.AdminView.breadcrumb()
    |> OliWeb.Users.UsersView.breadcrumb()
    |> breadcrumb(user)
  end

  def mount(
        %{"user_id" => user_id},
        %{"csrf_token" => csrf_token, "current_author_id" => author_id},
        socket
      ) do
    user =
      Accounts.get_user_by(id: user_id)
      |> Repo.preload(:platform_roles)

    case user do
      nil ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      user ->
        author = Repo.get(Author, author_id)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(user),
           author: author,
           user: user,
           csrf_token: csrf_token,
           changeset: user_changeset(user)
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div>
      {render_modal(assigns)}
      <Groups>
        <Group label="Details" description="User details">
          <Form for={@changeset} change="change" submit="submit" opts={autocomplete: "off"}>
            <ReadOnly label="Sub" value={@user.sub}/>
            <ReadOnly label="Name" value={@user.name}/>
            <ReadOnly label="First Name" value={@user.given_name}/>
            <ReadOnly label="Last Name" value={@user.family_name}/>
            <ReadOnly label="Email" value={@user.email}/>
            <ReadOnly label="Guest" value={boolean(@user.guest)}/>
            <div class="form-control mb-3">
              <Field name={:independent_learner}>
                <Checkbox/>
                <Label class="form-check-label mr-2">Independent Learner</Label>
              </Field>
            </div>

            <section class="mb-2">
              <heading>
                <p>Enable Independent Section Creation</p>
                <small>This ability allows delivery users to create and deliver "Independent" sections through OLI without a connected LMS, either Open and Free or limited to students who enroll through an invitation link.</small>
              </heading>
              <div class="form-control">
                <Field name={:can_create_sections}>
                  <Checkbox />
                  <Label class="form-check-label mr-2">Can Create Sections</Label>
                </Field>
              </div>
            </section>

            <ReadOnly label="Research Opt Out" value={boolean(@user.research_opt_out)}/>
            <ReadOnly label="Email Confirmed" value={date(@user.email_confirmed_at)}/>
            <ReadOnly label="Created" value={date(@user.inserted_at)}/>
            <ReadOnly label="Last Updated" value={date(@user.updated_at)}/>
            <Submit class="float-right btn btn-md btn-primary mt-2">Save</Submit>
          </Form>
        </Group>
        <Group label="Actions" description="Actions that can be taken for this user">
          {#if @user.independent_learner}
            <Actions user={@user} csrf_token={@csrf_token}/>
          {#else}
            <div></div>
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

    user =
      socket.assigns.user
      |> Oli.Accounts.User.noauth_changeset(%{email_confirmed_at: email_confirmed_at})
      |> Repo.update!()

    {:noreply,
     socket
     |> assign(user: user)
     |> hide_modal()}
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
    user = user_with_platform_roles(id)
    UserContext.lock(user)

    {:noreply,
     socket
     |> assign(user: user_with_platform_roles(id))
     |> hide_modal()}
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
    user = user_with_platform_roles(id)
    UserContext.unlock(user)

    {:noreply,
     socket
     |> assign(user: user_with_platform_roles(id))
     |> hide_modal()}
  end

  def handle_event("show_delete_account_modal", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    modal = %{
      component: DeleteAccountModal,
      assigns: %{
        id: "delete_account",
        user: user
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event(
        "delete_account",
        %{"id" => id},
        socket
      ) do
    user = user_with_platform_roles(id)

    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         redirect(socket, to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView))}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, e)}
    end
  end

  def handle_event("change", %{"user" => params}, socket) do
    {:noreply, assign(socket, changeset: user_changeset(socket.assigns.user, params))}
  end

  def handle_event("submit", _params, socket) do
    Repo.update!(socket.assigns.changeset)

    {:noreply,
     socket
     |> assign(user: user_with_platform_roles(socket.assigns.user.id))}
  end

  def user_with_platform_roles(id) do
    Accounts.get_user!(id, preload: [:platform_roles])
  end

  def user_changeset(user, attrs \\ %{}) do
    User.noauth_changeset(user, attrs)
    |> Map.put(:action, :update)
  end

  def breadcrumb(previous, %User{id: id} = user) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: name(user.name, user.given_name, user.family_name),
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, id)
        })
      ]
  end
end
