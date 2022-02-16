defmodule OliWeb.Users.UsersDetailView do
  use OliWeb, :surface_view

  use OliWeb.Common.Modal

  import OliWeb.Common.Properties.Utils
  import OliWeb.Common.Utils

  alias Oli.Accounts
  alias Oli.Accounts.User

  alias OliWeb.Accounts.Modals.{
    LockAccountModal,
    UnlockAccountModal,
    DeleteAccountModal,
    ConfirmEmailModal
  }

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias OliWeb.Pow.UserContext
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.Actions
  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, Label, Field, Submit}
  alias Oli.Lti.LtiParams

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

  def breadcrumb(previous, %User{id: id} = user) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: name(user.name, user.given_name, user.family_name),
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, id)
        })
      ]
  end

  def mount(
        %{"user_id" => user_id},
        %{"csrf_token" => csrf_token},
        socket
      ) do
    user = user_with_platform_roles(user_id)

    case user do
      nil ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      user ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(user),
           user: user,
           csrf_token: csrf_token,
           changeset: user_changeset(user),
           user_lti_params: LtiParams.all_user_lti_params(user.id)
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
            {#if Application.fetch_env!(:oli, :age_verification)[:is_enabled] == "true"}
              <ReadOnly label="Confirmed is 13 or older on creation" value={boolean(@user.age_verified)}/>
            {/if}
            <div class="form-control mb-3">
              <Field name={:independent_learner}>
                <Checkbox/>
                <Label class="form-check-label mr-2">Independent Learner</Label>
              </Field>
            </div>
            <section class="mb-2">
              <heading>
                <p>Enable Independent Section Creation</p>
                <small>Allow this user to create "Independent" sections and enroll students via invitation link without an LMS</small>
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
        {#if !Enum.empty?(@user_lti_params)}
          <Group label="LTI Details" description="LTI 1.3 details provided by an LMS">
            <ul class="list-group">
              {#for lti_params <- @user_lti_params}
                <li class="list-group-item">
                  <div class="d-flex pb-2 mb-2 border-bottom">
                    <div class="flex-grow-1">{lti_params.issuer}</div>
                    <div>Last Updated: {date(lti_params.updated_at)}</div>
                  </div>
                  <div style="max-height: 400px; overflow: scroll;">
                    <pre> <code
                      id="lit_params_#{lti_params.id}" class="lti-params language-json" phx-update="ignore">{Jason.encode!(lti_params.params) |> Jason.Formatter.pretty_print()}</code>
                    </pre>
                  </div>
                </li>
              {/for}
            </ul>
          </Group>
        {/if}
        <Group label="Actions" description="Actions that can be taken for this user">
          {#if @user.independent_learner}
            <Actions user={@user} csrf_token={@csrf_token}/>
          {#else}
            <div>No actions available</div>
            <div class="text-secondary">LTI users are managed by their LMS</div>
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

    case Accounts.update_user(socket.assigns.user, %{email_confirmed_at: email_confirmed_at}) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user)
         |> hide_modal()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Error confirming user's email")}
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
    user = user_with_platform_roles(id)

    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User successfully deleted.")
         |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "User couldn't be deleted.")}
    end
  end

  def handle_event("change", %{"user" => params}, socket) do
    {:noreply, assign(socket, changeset: user_changeset(socket.assigns.user, params))}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    case Accounts.update_user(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user, changeset: user_changeset(user, params))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "User couldn't be updated.")}
    end
  end

  defp user_with_platform_roles(id) do
    Accounts.get_user(id, preload: [:platform_roles])
  end

  defp user_changeset(user, attrs \\ %{}) do
    User.noauth_changeset(user, attrs)
    |> Map.put(:action, :update)
  end
end
