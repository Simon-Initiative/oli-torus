defmodule OliWeb.Users.UsersDetailView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Properties.Utils
  import OliWeb.Common.Utils

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

  @impl true
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

  attr(:breadcrumbs, :any)
  attr(:changeset, :map)
  attr(:csrf_token, :any)
  attr(:modal, :any, default: nil)
  attr(:title, :string, default: "User Details")
  attr(:user, :map, default: nil)
  attr(:disabled_edit, :boolean, default: true)

  def render(assigns) do
    ~H"""
    <div>
      <%= render_modal(assigns) %>
      <Groups.render>
        <Group.render label="Details" description="User details">
          <.form for={@changeset} phx-change="change" phx-submit="submit" autocomplete="off">
            <ReadOnly.render label="Sub" value={@user.sub} />
            <ReadOnly.render label="Name" value={@user.name} />
            <div class="form-group">
              <label for="given_name">Given Name</label>
              <input
                value={@changeset.data.given_name}
                id="given_name"
                name="user[given_name]"
                class="form-control"
                disabled={@disabled_edit}
              />
            </div>
            <div class="form-group">
              <label for="family_name">Last Name</label>
              <input
                value={@changeset.data.family_name}
                id="family_name"
                name="user[family_name]"
                class="form-control"
                disabled={@disabled_edit}
              />
            </div>
            <div class="form-group">
              <label for="email">Email</label>
              <input
                value={@changeset.data.email}
                id="email"
                name="user[email]"
                class="form-control"
                disabled={@disabled_edit}
              />
            </div>
            <ReadOnly.render label="Guest" value={boolean(@user.guest)} />
            <%= if Application.fetch_env!(:oli, :age_verification)[:is_enabled] == "true" do %>
              <ReadOnly.render
                label="Confirmed is 13 or older on creation"
                value={boolean(@user.age_verified)}
              />
            <% end %>
            <div class="form-control mb-3">
              <input
                id="independent_learner"
                name="user[independent_learner]"
                type="checkbox"
                class="form-check-input"
                checked={fetch_field(@changeset, :independent_learner)}
                disabled={@disabled_edit}
              />
              <label for="independent_learner" class="form-check-label mr-2">
                Independent Learner
              </label>
            </div>
            <section class="mb-2">
              <heading>
                <p>Enable Independent Section Creation</p>
                <small>
                  Allow this user to create "Independent" sections and enroll students via invitation link without an LMS
                </small>
              </heading>
              <div class="form-control">
                <input
                  id="can_create_sections"
                  name="user[can_create_sections]"
                  type="checkbox"
                  class="form-check-input"
                  checked={fetch_field(@changeset, :can_create_sections)}
                  disabled={@disabled_edit}
                />
                <label for="can_create_sections" class="form-check-label mr-2">
                  Can Create Sections
                </label>
              </div>
            </section>
            <ReadOnly.render label="Research Opt Out" value={boolean(@user.research_opt_out)} />
            <ReadOnly.render
              label="Email Confirmed"
              value={render_date(@user, :email_confirmed_at, @ctx)}
            />
            <ReadOnly.render label="Created" value={render_date(@user, :inserted_at, @ctx)} />
            <ReadOnly.render label="Last Updated" value={render_date(@user, :updated_at, @ctx)} />
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
        <%= if !Enum.empty?(@user_lti_params) do %>
          <Group.render label="LTI Details" description="LTI 1.3 details provided by an LMS">
            <ul class="list-group">
              <li :for={lti_params <- @user_lti_params} class="list-group-item">
                <div class="d-flex pb-2 mb-2 border-b">
                  <div class="flex-grow-1"><%= lti_params.issuer %></div>
                  <div>Last Updated: <%= render_date(lti_params, :updated_at, @ctx) %></div>
                </div>
                <div style="max-height: 400px; overflow: scroll;">
                  <pre> <code
                    id="lit_params_#{lti_params.id}" class="lti-params language-json" phx-update="ignore"><%= Jason.encode!(lti_params.params) |> Jason.Formatter.pretty_print() %></code>
                  </pre>
                </div>
              </li>
            </ul>
          </Group.render>
        <% end %>
        <Group.render
          label="Enrolled Sections"
          description="Course sections to which the student is enrolled"
        >
          <%= live_component(OliWeb.Users.UserEnrolledSections,
            id: "user_enrolled_sections",
            user: @user,
            params: @params,
            ctx: @ctx,
            enrolled_sections: @enrolled_sections
          ) %>
        </Group.render>
        <Group.render label="Actions" description="Actions that can be taken for this user">
          <%= if @user.independent_learner do %>
            <Actions.render user={@user} csrf_token={@csrf_token} />
          <% else %>
            <div>No actions available</div>
            <div class="text-secondary">LTI users are managed by their LMS</div>
          <% end %>
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
      ~H"""
      <UnlockAccountModal.render id="unlock_account" user={assigns.modal_assigns.user} />
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
    {:noreply,
     assign(socket, changeset: user_changeset(socket.assigns.user, cast_params(params)))}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    case Accounts.update_user(socket.assigns.user, cast_params(params)) do
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

  defp cast_params(params) do
    params
    |> Map.put("independent_learner", if(params["independent_learner"], do: true, else: false))
    |> Map.put("can_create_sections", if(params["can_create_sections"], do: true, else: false))
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
