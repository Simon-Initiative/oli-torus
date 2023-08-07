defmodule OliWeb.Users.UsersDetailView do
  use OliWeb, :surface_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Properties.Utils
  import OliWeb.Common.Utils
  import Ecto.Changeset

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Delivery.{Metrics, Paywall, Sections}
  alias Oli.Lti.LtiParams

  alias OliWeb.Accounts.Modals.{
    LockAccountModal,
    UnlockAccountModal,
    DeleteAccountModal,
    ConfirmEmailModal
  }

  alias OliWeb.Common.{Breadcrumb, SessionContext}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias OliWeb.Pow.UserContext
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.Actions
  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, Label, Field, Submit, TextInput}

  data(breadcrumbs, :any)
  data(changeset, :changeset)
  data(csrf_token, :any)
  data(modal, :any, default: nil)
  data(title, :string, default: "User Details")
  data(user, :struct, default: nil)
  data(disabled_edit, :boolean, default: true)

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
        %{"csrf_token" => csrf_token} = session,
        socket
      ) do
    ctx = SessionContext.init(socket, session)
    user = user_with_platform_roles(user_id)

    case user do
      nil ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}

      user ->
        enrolled_sections =
          Sections.list_user_enrolled_sections(user)
          |> add_necessary_information(user)

        {:ok,
         assign(socket,
           ctx: ctx,
           breadcrumbs: set_breadcrumbs(user),
           user: user,
           csrf_token: csrf_token,
           changeset: user_changeset(user),
           user_lti_params: LtiParams.all_user_lti_params(user.id),
           enrolled_sections: enrolled_sections,
           disabled_edit: true
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~F"""
    <div>
      {render_modal(assigns)}
      <Groups.render>
        <Group.render label="Details" description="User details">
          <Form for={@changeset} change="change" submit="submit" opts={autocomplete: "off"}>
            <ReadOnly label="Sub" value={@user.sub}/>
            <ReadOnly label="Name" value={@user.name}/>
            <Field name={:given_name} class="form-group">
              <Label text="Given Name"/>
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
            <ReadOnly label="Guest" value={boolean(@user.guest)}/>
            {#if Application.fetch_env!(:oli, :age_verification)[:is_enabled] == "true"}
              <ReadOnly label="Confirmed is 13 or older on creation" value={boolean(@user.age_verified)}/>
            {/if}
            <div class="form-control mb-3">
              <Field name={:independent_learner}>
                <Checkbox class="form-check-input" value={get_field(@changeset, :independent_learner)} opts={disabled: @disabled_edit}/>
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
                  <Checkbox class="form-check-input" value={get_field(@changeset, :can_create_sections)} opts={disabled: @disabled_edit}/>
                  <Label class="form-check-label mr-2">Can Create Sections</Label>
                </Field>
              </div>
            </section>
            <ReadOnly label="Research Opt Out" value={boolean(@user.research_opt_out)}/>
            <ReadOnly label="Email Confirmed" value={render_date(@user, :email_confirmed_at, @ctx)}/>
            <ReadOnly label="Created" value={render_date(@user, :inserted_at, @ctx)}/>
            <ReadOnly label="Last Updated" value={render_date(@user, :updated_at, @ctx)}/>
            {#unless @disabled_edit}
              <Submit class={"float-right btn btn-md btn-primary mt-2"}>Save</Submit>
            {/unless}
          </Form>
            {#if @disabled_edit}
              <button class={"float-right btn btn-md btn-primary mt-2"} phx-click="start_edit">Edit</button>
            {/if}
        </Group.render>
        {#if !Enum.empty?(@user_lti_params)}
          <Group.render label="LTI Details" description="LTI 1.3 details provided by an LMS">
            <ul class="list-group">
              {#for lti_params <- @user_lti_params}
                <li class="list-group-item">
                  <div class="d-flex pb-2 mb-2 border-b">
                    <div class="flex-grow-1">{lti_params.issuer}</div>
                    <div>Last Updated: {render_date(lti_params, :updated_at, @ctx)}</div>
                  </div>
                  <div style="max-height: 400px; overflow: scroll;">
                    <pre> <code
                      id="lit_params_#{lti_params.id}" class="lti-params language-json" phx-update="ignore">{Jason.encode!(lti_params.params) |> Jason.Formatter.pretty_print()}</code>
                    </pre>
                  </div>
                </li>
              {/for}
            </ul>
          </Group.render>
        {/if}
        <Group.render label="Enrolled Sections" description="Course sections to which the student is enrolled">
          {live_component OliWeb.Users.UserEnrolledSections,
            id: "user_enrolled_sections",
            user: @user,
            params: @params,
            ctx: @ctx,
            enrolled_sections: @enrolled_sections
          }
        </Group.render>
        <Group.render label="Actions" description="Actions that can be taken for this user">
          {#if @user.independent_learner}
            <Actions user={@user} csrf_token={@csrf_token}/>
          {#else}
            <div>No actions available</div>
            <div class="text-secondary">LTI users are managed by their LMS</div>
          {/if}
        </Group.render>
      </Groups.render>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    socket =
      socket
      |> assign(params: params)

    {:noreply, socket}
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

    case Accounts.update_user(socket.assigns.user, %{email_confirmed_at: email_confirmed_at}) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user)
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Error confirming user's email")}
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
    user = user_with_platform_roles(id)
    UserContext.lock(user)

    {:noreply,
     socket
     |> assign(user: user_with_platform_roles(id))
     |> hide_modal(modal_assigns: nil)}
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
    user = user_with_platform_roles(id)
    UserContext.unlock(user)

    {:noreply,
     socket
     |> assign(user: user_with_platform_roles(id))
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
         |> put_flash(:info, "User successfully updated.")
         |> assign(user: user, changeset: user_changeset(user, params), disabled_edit: true)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "User couldn't be updated.")}
    end
  end

  def handle_event("start_edit", _, socket) do
    {:noreply, socket |> assign(disabled_edit: false)}
  end

  defp user_with_platform_roles(id) do
    Accounts.get_user(id, preload: [:platform_roles])
  end

  defp user_changeset(user, attrs \\ %{}) do
    User.noauth_changeset(user, attrs)
    |> Map.put(:action, :update)
  end

  defp add_necessary_information(sections, user) do
    Enum.map(sections, fn section ->
      Map.merge(
        section,
        %{
          enrollment_status:
            if(Sections.is_enrolled?(user.id, section.slug), do: "Enrolled", else: "Suspended"),
          enrollment_role:
            if(Sections.is_instructor?(user, section.slug), do: "Instructor", else: "Student"),
          payment_status: Paywall.summarize_access(user, section).reason,
          last_accessed: Metrics.get_last_access_for_user_in_a_section(user.id, section.id)
        }
      )
    end)
  end
end
