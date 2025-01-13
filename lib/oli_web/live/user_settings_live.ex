defmodule OliWeb.UserSettingsLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}
  alias Oli.AssentAuth.UserAssentAuth
  alias OliWeb.Common.Properties.{Groups, Group}

  def render(assigns) do
    ~H"""
    <h2 class="text-3xl mb-8">Account Settings</h2>

    <Groups.render>
      <Group.render label="Details" description="View and change your user account details">
        <div class="account-section">
          <div class="grid grid-cols-12 my-4">
            <.form
              for={@user_form}
              id="user_form"
              class="col-span-12 flex flex-col gap-2 mb-10"
              phx-submit="update_user"
              phx-change="validate_user"
            >
              <.input field={@user_form[:name]} type="text" label="Full name" readonly />
              <.input field={@user_form[:given_name]} type="text" label="First name" />
              <.input field={@user_form[:family_name]} type="text" label="Last name" />

              <div>
                <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
              </div>
            </.form>

            <.form
              for={@email_form}
              id="email_form"
              class="col-span-12 flex flex-col gap-2 mb-10"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="Email"
                required
                readonly={!@has_password}
              />
              <.input
                :if={@has_password}
                field={@email_form[:current_password]}
                name="current_password"
                id="current_password_for_email"
                type="password"
                label="Current password"
                value={@email_form_current_password}
                required
              />

              <div :if={@has_password}>
                <.button variant={:primary} phx-disable-with="Changing...">Change Email</.button>
              </div>
            </.form>

            <.form
              for={@password_form}
              id="password_form"
              class="col-span-12 flex flex-col gap-2 mb-10"
              action={~p"/users/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <.input
                field={@password_form[:email]}
                type="hidden"
                id="hidden_user_email"
                value={@current_email}
              />
              <.input
                :if={@has_password}
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                label="Current password"
                id="current_password_for_password"
                value={@current_password}
                required
              />

              <.input field={@password_form[:password]} type="password" label="New password" required />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
              />

              <div>
                <.button :if={@has_password} variant={:primary} phx-disable-with="Changing...">
                  Change Password
                </.button>
                <.button :if={!@has_password} variant={:primary} phx-disable-with="Creating...">
                  Create Password
                </.button>
              </div>
            </.form>
          </div>

          <div class="grid grid-cols-12 my-4">
            <div :if={!Enum.empty?(@login_providers)} class="col-span-4 flex flex-col gap-3 mb-10">
              <h4 class="mt-3">Third Party Login Providers</h4>

              <%= for {provider, managed?} <- @login_providers do %>
                <%= if managed? do %>
                  <Components.Auth.deauthorization_link
                    provider={provider}
                    href={~p"/users/auth/#{provider}"}
                    user_return_to={~p"/users/settings"}
                  />
                <% else %>
                  <Components.Auth.authorization_link
                    provider={provider}
                    user_return_to={~p"/users/settings"}
                    href={~p"/users/auth/#{provider}/new"}
                  />
                <% end %>
              <% end %>
            </div>
          </div>

          <div class="grid grid-cols-12 my-4">
            <div
              :if={Accounts.can_manage_linked_account?(@current_user)}
              class="col-span-4 flex flex-col gap-3 mb-10"
            >
              <h4 class="mt-3">Linked Authoring Account</h4>

              <%= case Accounts.linked_author_account(@current_user) do %>
                <% nil -> %>
                  <.link href={~p"/users/link_account"}>
                    Link authoring account
                  </.link>
                <% %Author{email: linked_author_account_email} -> %>
                  <div class="overflow-hidden text-ellipsis" role="linked authoring account email">
                    <%= linked_author_account_email %>
                  </div>

                  <.link href={~p"/users/link_account"}>
                    Manage linked account
                  </.link>
              <% end %>
            </div>
          </div>
        </div>
      </Group.render>
    </Groups.render>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    user_changeset = Accounts.change_user_details(user)
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    editor = Accounts.get_user_preference(user, :editor)
    show_relative_dates = Accounts.get_user_preference(user, :show_relative_dates)

    socket =
      socket
      |> assign(:active_workspace, :student)
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:user_form, to_form(user_changeset))
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:editor, editor)
      |> assign(:show_relative_dates, show_relative_dates)
      |> assign(:trigger_submit, false)
      |> assign(:login_providers, login_providers_and_statuses(user))
      |> assign(:has_password, UserAssentAuth.has_password?(user))

    {:ok, socket}
  end

  def handle_event("validate_user", params, socket) do
    %{"user" => user_params} = params

    user_form =
      socket.assigns.current_user
      |> Accounts.change_user_details(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, user_form: user_form)}
  end

  def handle_event("update_user", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user(user, user_params) do
      {:ok, user} ->
        user_form =
          user
          |> Accounts.change_user_details(user_params)
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Account details successfully updated.")
         |> assign(user_form: user_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, user_form: to_form(changeset))}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, password_form: password_form, current_password: params["current_password"])}
  end

  def handle_event(
        "update_password",
        %{"current_password" => password, "user" => user_params},
        socket
      ) do
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("update_password", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.create_user_password(user, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply,
         assign(socket, trigger_submit: true, password_form: password_form, has_password: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp login_providers_and_statuses(%User{} = user) do
    user_identity_providers_map =
      UserAssentAuth.list_user_identities(user)
      |> Enum.reduce(%{}, fn identity, acc ->
        Map.put(acc, String.to_existing_atom(identity.provider), true)
      end)

    UserAssentAuth.authentication_providers()
    |> Keyword.keys()
    |> Enum.map(&{&1, Map.has_key?(user_identity_providers_map, &1)})
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end
end
