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

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.Actions

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

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
        _session,
        socket
      ) do
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
           breadcrumbs: set_breadcrumbs(user),
           user: user,
           form: user_form(user),
           user_lti_params: LtiParams.all_user_lti_params(user.id),
           enrolled_sections: enrolled_sections,
           disabled_edit: true,
           user_name: user.name,
           password_reset_link: ""
         )}
    end
  end

  attr(:breadcrumbs, :any)
  attr(:form, :map)
  attr(:csrf_token, :any)
  attr(:modal, :any, default: nil)
  attr(:title, :string, default: "User Details")
  attr(:user, User, required: true)
  attr(:disabled_edit, :boolean, default: true)
  attr(:disabled_submit, :boolean, default: false)
  attr(:user_name, :string)
  attr(:password_reset_link, :string)

  def render(assigns) do
    ~H"""
    <div>
      <%= render_modal(assigns) %>
      <Groups.render>
        <Group.render label="Details" description="User details">
          <.form for={@form} phx-change="change" phx-submit="submit" autocomplete="off">
            <ReadOnly.render label="Sub" value={@user.sub} />
            <ReadOnly.render label="Name" value={@user_name} />
            <div class="form-group">
              <.input
                field={@form[:given_name]}
                label="Given Name"
                class="form-control"
                disabled={@disabled_edit}
                error_position={:top}
              />
            </div>
            <div class="form-group">
              <.input
                field={@form[:family_name]}
                label="Last Name"
                class="form-control"
                disabled={@disabled_edit}
                error_position={:top}
              />
            </div>
            <div class="form-group">
              <.input
                field={@form[:email]}
                label="Email"
                class="form-control"
                disabled={@disabled_edit}
                error_position={:top}
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
              <.input
                field={@form[:independent_learner]}
                type="checkbox"
                label="Independent Learner"
                class="form-check-input"
                disabled={@disabled_edit}
              />
            </div>
            <section class="mb-2">
              <heading>
                <p>Enable Independent Section Creation</p>
                <small>
                  Allow this user to create "Independent" sections and enroll students via invitation link without an LMS
                </small>
              </heading>
              <div class="form-control">
                <.input
                  field={@form[:can_create_sections]}
                  type="checkbox"
                  label="Can Create Sections"
                  class="form-check-input"
                  disabled={@disabled_edit}
                />
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
              <.button
                variant={:primary}
                type="submit"
                class="float-right mt-2"
                disabled={@disabled_submit}
              >
                Save
              </.button>
            <% end %>
          </.form>
          <%= if @disabled_edit do %>
            <.button variant={:primary} class="float-right mt-2" phx-click="start_edit">
              Edit
            </.button>
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
          <.live_component
            module={OliWeb.Users.UserEnrolledSections}
            id="user_enrolled_sections"
            user={@user}
            params={@params}
            ctx={@ctx}
            enrolled_sections={@enrolled_sections}
          />
        </Group.render>
        <Group.render label="Actions" description="Actions that can be taken for this user">
          <%= if @user.independent_learner do %>
            <Actions.render
              user_id={@user.id}
              account_locked={!is_nil(@user.locked_at)}
              email_confirmation_pending={Accounts.user_confirmation_pending?(@user)}
              password_reset_link={@password_reset_link}
            />
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

  def handle_event("generate_reset_password_link", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    encoded_token = Accounts.generate_user_reset_password_token(user)

    password_reset_link =
      url(~p"/users/reset_password/#{encoded_token}")

    socket = assign(socket, password_reset_link: password_reset_link)

    {:noreply, socket}
  end

  def handle_event("show_confirm_email_modal", _, socket) do
    modal_assigns = %{
      user: socket.assigns.user
    }

    modal = fn assigns ->
      ~H"""
      <ConfirmEmailModal.render id="confirm_email" user={@user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("confirm_email", _, socket) do
    case Accounts.admin_confirm_user(socket.assigns.user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user)
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Error confirming user's email")}
    end
  end

  def handle_event("resend_confirmation_link", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    case Accounts.deliver_user_confirmation_instructions(
           user,
           &url(~p"/users/confirm/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Confirmation link sent.")}

      {:error, :already_confirmed} ->
        {:noreply, put_flash(socket, :info, "Email is already confirmed.")}
    end
  end

  def handle_event("send_reset_password_link", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    case Accounts.deliver_user_reset_password_instructions(
           user,
           &url(~p"/users/reset_password/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Password reset link sent.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Error sending password reset link: #{error}")}
    end
  end

  def handle_event("show_lock_account_modal", _, socket) do
    modal_assigns = %{user: socket.assigns.user}

    modal = fn assigns ->
      ~H"""
      <LockAccountModal.render id="lock_account" user={assigns.modal_assigns.user} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("lock_account", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    case Accounts.lock_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(user: user_with_platform_roles(id))
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "Failed to lock user account.")
         |> hide_modal(modal_assigns: nil)}
    end
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

  def handle_event("unlock_account", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    case Accounts.unlock_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(user: user_with_platform_roles(id))
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "Failed to unlock user account.")
         |> hide_modal(modal_assigns: nil)}
    end
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

  def handle_event("delete_account", %{"id" => id}, socket) do
    user = user_with_platform_roles(id)

    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User successfully deleted.")
         |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "User couldn't be deleted.")}
    end
  end

  def handle_event("change", %{"user" => params}, socket) do
    form = user_form(socket.assigns.user, params)

    socket =
      socket
      |> assign(form: form)
      |> assign(disabled_submit: !Enum.empty?(form.errors))
      |> assign(user_name: "#{params["given_name"]} #{params["family_name"]}")

    {:noreply, socket}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    case Accounts.update_user(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User successfully updated.")
         |> assign(user: user)
         |> assign(form: user_form(user, params))
         |> assign(disabled_edit: true)
         |> assign(user_name: "#{params["given_name"]} #{params["family_name"]}")}

      {:error, error} ->
        form = to_form(error)

        {:noreply,
         socket
         |> assign(form: form)
         |> assign(disabled_submit: !Enum.empty?(form.errors))}
    end
  end

  def handle_event("start_edit", _, socket) do
    {:noreply, socket |> assign(disabled_edit: false)}
  end

  defp user_with_platform_roles(id) do
    Accounts.get_user(id, preload: [:platform_roles])
  end

  defp user_form(user, attrs \\ %{}) do
    user
    |> User.noauth_changeset(attrs)
    |> Map.put(:action, :update)
    |> to_form()
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
