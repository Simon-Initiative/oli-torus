defmodule OliWeb.UserSettingsLive do
  use OliWeb, :live_view

  import Oli.Utils

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.AssentAuth.UserAssentAuth
  alias OliWeb.Icons

  def render(assigns) do
    ~H"""
    <div class="bg-Background-bg-primary flex flex-col gap-4 items-center py-2 w-full">
      <!-- Back Button -->
      <.link
        navigate={@back_path}
        class="flex gap-2 items-center px-4 md:px-8 py-4 w-full cursor-pointer"
      >
        <div class="size-5">
          <Icons.back_arrow class="w-5 h-5 fill-Icon-icon-active stroke-Icon-icon-active" />
        </div>
        <div class="font-semibold text-sm leading-6 text-Text-text-high">
          Back
        </div>
      </.link>
      
    <!-- Content -->
      <div class="flex flex-col gap-8 items-start px-4 w-full max-w-[450px]">
        <!-- Title -->
        <div class="flex flex-col h-6 items-start w-full">
          <h1 class="font-bold text-lg leading-6 text-Text-text-high">
            Account Settings
          </h1>
        </div>
        
    <!-- Google Authentication Button (if exists) -->
        <%= if !Enum.empty?(@login_providers) && Enum.any?(@login_providers, fn {provider, _managed?} -> provider == :google end) do %>
          <div class="w-full">
            <%= for {provider, managed?} <- @login_providers do %>
              <%= if provider == :google do %>
                <%= if managed? do %>
                  <Components.Auth.account_settings_deauthorization_link
                    provider={provider}
                    href={~p"/users/auth/#{provider}"}
                    user_return_to={~p"/users/settings"}
                  >
                    Remove Google authentication
                  </Components.Auth.account_settings_deauthorization_link>
                <% else %>
                  <Components.Auth.account_settings_authorization_link
                    provider={provider}
                    href={~p"/users/auth/#{provider}/new"}
                  >
                    Connect Google authentication
                  </Components.Auth.account_settings_authorization_link>
                <% end %>
              <% end %>
            <% end %>
          </div>
        <% end %>
        <!-- Form Wrapper -->
        <div class="flex flex-col gap-4 items-start w-full">
          <!-- Combined Form -->
          <.form
            for={@password_form}
            id="settings_form"
            class="flex flex-col gap-4 w-full"
            phx-submit="submit_combined_form"
            action={~p"/users/log_in?_action=password_updated"}
            method="post"
            phx-trigger-action={@trigger_submit}
          >
            <input type="hidden" name="user[email]" id="hidden_user_email" value={@current_email} />
            <input type="hidden" name="settings_return_to" value={@back_path} />

            <div :if={@has_password} class="flex flex-col gap-2 w-full">
              <label class="font-semibold text-sm leading-4 text-Text-text-low">
                Current Password*
              </label>
              <div
                id="current_password_for_password_container"
                class="border border-Border-border-default flex flex-col h-14 items-start justify-center px-4 py-2 rounded-md w-full bg-Background-bg-primary"
                phx-update="ignore"
              >
                <input
                  type="password"
                  name={@password_form[:current_password].name}
                  id="current_password_for_password"
                  autocomplete="new-password"
                  class="!bg-Background-bg-primary border-none outline-none focus:outline-none focus:ring-0 text-base leading-6 w-full placeholder-[rgba(238,235,245,0.75)] p-0 text-[#353740] dark:text-[#EEEBF5]"
                  style="-webkit-text-fill-color: currentColor;"
                />
              </div>
            </div>

            <div class="flex flex-col gap-2 w-full">
              <label class="font-semibold text-sm leading-4 text-Text-text-low">
                E-mail
              </label>
              <div class="border border-Border-border-default flex flex-col h-14 items-start justify-center px-4 py-2 rounded-md w-full bg-Background-bg-primary">
                <input
                  type="email"
                  name={@email_form[:email].name}
                  id="email"
                  value={Phoenix.HTML.Form.normalize_value("email", @email_form[:email].value)}
                  class="!bg-Background-bg-primary border-none outline-none focus:outline-none focus:ring-0 text-base leading-6 text-Text-text-high w-full placeholder-[rgba(238,235,245,0.75)] p-0"
                  placeholder="your.email@example.com"
                  phx-change="validate_email"
                />
              </div>
            </div>

            <div class="flex flex-col gap-2 w-full">
              <label class="font-semibold text-sm leading-4 text-Text-text-low">
                First Name
              </label>
              <div class="border border-Border-border-default flex flex-col h-14 items-start justify-center px-4 py-2 rounded-md w-full bg-Background-bg-primary">
                <input
                  type="text"
                  name={@user_form[:given_name].name}
                  id="given_name"
                  value={Phoenix.HTML.Form.normalize_value("text", @user_form[:given_name].value)}
                  class="!bg-Background-bg-primary border-none outline-none focus:outline-none focus:ring-0 text-base leading-6 text-Text-text-high w-full placeholder-[rgba(238,235,245,0.75)] p-0"
                  placeholder="Darnell"
                  phx-change="validate_user"
                />
              </div>
              <div
                :for={{msg, opts} <- @user_form[:given_name].errors}
                class="mt-1 text-sm text-red-600"
              >
                {OliWeb.Components.Common.translate_error({msg, opts})}
              </div>
            </div>

            <div class="flex flex-col gap-2 w-full">
              <label class="font-semibold text-sm leading-4 text-Text-text-low">
                Last Name
              </label>
              <div class="border border-Border-border-default flex flex-col h-14 items-start justify-center px-4 py-2 rounded-md w-full bg-Background-bg-primary">
                <input
                  type="text"
                  name={@user_form[:family_name].name}
                  id="family_name"
                  value={Phoenix.HTML.Form.normalize_value("text", @user_form[:family_name].value)}
                  class="!bg-Background-bg-primary border-none outline-none focus:outline-none focus:ring-0 text-base leading-6 text-Text-text-high w-full placeholder-[rgba(238,235,245,0.75)] p-0"
                  placeholder="Lewis"
                  phx-change="validate_user"
                />
              </div>
              <div
                :for={{msg, opts} <- @user_form[:family_name].errors}
                class="mt-1 text-sm text-red-600"
              >
                {OliWeb.Components.Common.translate_error({msg, opts})}
              </div>
            </div>

            <div class="flex flex-col gap-2 w-full">
              <label class="font-semibold text-sm leading-4 text-Text-text-low">
                New Password
              </label>
              <div class="border border-Border-border-default flex flex-col h-14 items-start justify-center px-4 py-2 rounded-md w-full bg-Background-bg-primary">
                <input
                  type="password"
                  name={@password_form[:password].name}
                  id="password"
                  value={
                    Phoenix.HTML.Form.normalize_value("password", @password_form[:password].value)
                  }
                  class="!bg-Background-bg-primary border-none outline-none focus:outline-none focus:ring-0 text-base leading-6 text-Text-text-high w-full placeholder-[rgba(238,235,245,0.75)] p-0"
                  placeholder=""
                  phx-change="validate_password"
                />
              </div>
              <!-- Password errors -->
              <div
                :for={{msg, opts} <- @password_form[:password].errors}
                :if={not password_fields_both_empty?(@password_form)}
                class="mt-1 text-sm text-red-600"
              >
                {OliWeb.Components.Common.translate_error({msg, opts})}
              </div>
            </div>

            <div class="flex flex-col gap-2 w-full">
              <label class="font-semibold text-sm leading-4 text-Text-text-low">
                Confirm New Password
              </label>
              <div class="border border-Border-border-default flex flex-col h-14 items-start justify-center px-4 py-2 rounded-md w-full bg-Background-bg-primary">
                <input
                  type="password"
                  name={@password_form[:password_confirmation].name}
                  id="password_confirmation"
                  value={
                    Phoenix.HTML.Form.normalize_value(
                      "password",
                      @password_form[:password_confirmation].value
                    )
                  }
                  class="!bg-Background-bg-primary border-none outline-none focus:outline-none focus:ring-0 text-base leading-6 text-Text-text-high w-full placeholder-[rgba(238,235,245,0.75)] p-0"
                  placeholder=""
                  phx-change="validate_password"
                />
              </div>
              <!-- Password confirmation errors -->
              <div
                :for={{msg, opts} <- @password_form[:password_confirmation].errors}
                :if={not password_fields_both_empty?(@password_form)}
                class="mt-1 text-sm text-red-600"
              >
                {OliWeb.Components.Common.translate_error({msg, opts})}
              </div>
            </div>
            
    <!-- Buttons Wrapper -->
            <div class="flex flex-col gap-4 items-start w-full">
              <!-- Update Button -->
              <button
                type="submit"
                class="bg-Fill-Buttons-fill-primary flex gap-0 items-center justify-center px-6 py-3 rounded-md w-full"
                phx-disable-with="Updating..."
              >
                <div class="font-semibold text-sm leading-4 text-white">
                  Update
                </div>
              </button>
              
    <!-- Cancel Button -->
              <.link
                navigate={@back_path}
                class="bg-Background-bg-primary border border-Border-border-bold flex gap-0 items-center justify-center px-6 py-3 rounded-md w-full hover:no-underline"
              >
                <div class="font-semibold text-sm leading-4 text-Specially-Tokens-Text-text-button-secondary">
                  Cancel
                </div>
              </.link>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          socket
          |> clear_flash()
          |> put_flash(:info, "Email changed successfully.")

        :error ->
          socket
          |> clear_flash()
          |> put_flash(:error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    ctx = socket.assigns.ctx
    user_changeset = Accounts.change_user_details(user)
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    back_path =
      Map.get(session, "settings_return_to") || Map.get(session, "user_return_to") ||
        ~p"/users/settings"

    socket =
      socket
      |> assign(:active_workspace, :student)
      |> assign(:is_admin, Accounts.is_admin?(ctx.author))
      |> assign(:current_email, user.email)
      |> assign(:user_form, to_form(user_changeset))
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:login_providers, login_providers_and_statuses(user))
      |> assign(:has_password, UserAssentAuth.has_password?(user))
      |> assign(:back_path, back_path)

    {:ok, socket}
  end

  def handle_event("submit_combined_form", %{"user" => user_params} = _params, socket) do
    user = socket.assigns.current_user
    changes = detect_and_build_changes(socket, user, user_params)

    # Check if there are active changes
    has_changes = Enum.any?(changes, fn {_k, v} -> v != nil end)

    if has_changes do
      execute_all_updates(socket, user, changes)
    else
      {:noreply, socket |> clear_flash() |> put_flash(:info, "No changes to save.")}
    end
  end

  def handle_event("submit_combined_form", _params, socket) do
    handle_event("submit_combined_form", %{"user" => %{}}, socket)
  end

  def handle_event("validate_user", %{"user" => user_params}, socket) do
    %{user_form: user_form} = socket.assigns

    user_data = %User{
      given_name: get_in(user_params, ["given_name"]) || input_value(user_form[:given_name]),
      family_name: get_in(user_params, ["family_name"]) || input_value(user_form[:family_name])
    }

    user_changeset =
      user_data
      |> Accounts.change_user_details(user_params)
      |> Map.put(:action, :validate)

    user_form = to_form(user_changeset)

    {:noreply, assign(socket, user_form: user_form) |> clear_flash()}
  end

  def handle_event("validate_user", _params, socket), do: {:noreply, socket}

  def handle_event("validate_email", %{"user" => user_params}, socket) do
    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("validate_email", _params, socket), do: {:noreply, socket}

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    # Get current values from the form to preserve them
    current_password = input_value(socket.assigns.password_form[:password])
    current_confirmation = input_value(socket.assigns.password_form[:password_confirmation])

    # Merge current values with new params to preserve existing inputs
    merged_params = %{
      "password" => Map.get(user_params, "password", current_password),
      "password_confirmation" =>
        Map.get(user_params, "password_confirmation", current_confirmation)
    }

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(merged_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("validate_password", _params, socket), do: {:noreply, socket}

  # Private functions to handle individual update operations
  defp execute_user_update(user, user_params) do
    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        {:ok, updated_user, "Account details updated"}

      {:error, changeset} ->
        {:error, :user, changeset}
    end
  end

  defp execute_email_update(user, user_params) do
    current_password = user_params["current_password"]

    # Check if current password is provided
    if is_nil(current_password) or String.trim(current_password) == "" do
      changeset =
        user
        |> Accounts.change_user_email(user_params)
        |> Ecto.Changeset.add_error(:current_password, "is required to change email")

      {:error, :email, changeset}
    else
      case Accounts.apply_user_email(user, current_password, user_params) do
        {:ok, _applied_user} ->
          Accounts.deliver_user_update_email_instructions(
            user,
            user.email,
            &url(~p"/users/settings/confirm_email/#{&1}")
          )

          {:ok, user, "Email confirmation sent"}

        {:error, changeset} ->
          {:error, :email, changeset}
      end
    end
  end

  defp execute_password_update(user, user_params, socket) do
    case update_user_password_safely(user, user_params, socket) do
      {:ok, updated_user} ->
        {:ok, updated_user, "Password updated"}

      {:error, :password_update, changeset} ->
        {:error, :password, changeset}
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

  defp detect_and_build_changes(socket, user, user_params) do
    # Helper to get value from params or fallback to form field
    get_value = fn key, form_field -> Map.get(user_params, key) || input_value(form_field) end

    # Check for user profile changes (names)
    given_name =
      get_value.("given_name", socket.assigns.user_form[:given_name]) || user.given_name

    family_name =
      get_value.("family_name", socket.assigns.user_form[:family_name]) || user.family_name

    user_changes =
      if given_name != user.given_name || family_name != user.family_name do
        %{"given_name" => given_name, "family_name" => family_name}
      else
        nil
      end

    # Check for password changes (only if new password provided)
    password = get_value.("password", socket.assigns.password_form[:password])

    password_changes =
      if password && String.trim(password) != "" do
        %{
          "current_password" =>
            get_value.("current_password", socket.assigns.password_form[:current_password]),
          "password" => password,
          "password_confirmation" =>
            get_value.(
              "password_confirmation",
              socket.assigns.password_form[:password_confirmation]
            )
        }
      else
        nil
      end

    # Check for email changes (only if different from current)
    email = get_value.("email", socket.assigns.email_form[:email])

    email_changes =
      if email && email != user.email do
        %{
          "email" => email,
          "current_password" =>
            get_value.("current_password", socket.assigns.password_form[:current_password])
        }
      else
        nil
      end

    %{user: user_changes, password: password_changes, email: email_changes}
  end

  defp update_user_password_safely(user, password_params, socket) do
    # Extract validation variables
    current_password = password_params["current_password"]
    has_password = socket.assigns.has_password
    password_empty? = is_nil(current_password) or String.trim(current_password) == ""

    cond do
      # Case 1: User has password but didn't provide current password
      has_password and password_empty? ->
        changeset =
          Accounts.change_user_password(user, password_params)
          |> Ecto.Changeset.add_error(:current_password, "can't be blank")

        {:error, :password_update, changeset}

      # Case 2: User has password and provided current password - update it
      has_password ->
        case Accounts.update_user_password(user, current_password, password_params) do
          {:ok, user} ->
            {:ok, user}

          {:error, changeset} ->
            {:error, :password_update, changeset}
        end

      # Case 3: User doesn't have password yet - create new one
      true ->
        case Accounts.create_user_password(user, password_params) do
          {:ok, user} ->
            {:ok, user}

          {:error, changeset} ->
            {:error, :password_update, changeset}
        end
    end
  end

  defp execute_all_updates(socket, user, changes) do
    # Filter out nil changes and build execution pipeline
    active_changes = Enum.filter(changes, fn {_k, v} -> v != nil end) |> Enum.into(%{})

    # Build ordered pipeline of operations to execute
    update_pipeline =
      [
        active_changes[:user] && {:user, active_changes.user},
        active_changes[:password] && {:password, active_changes.password},
        active_changes[:email] && {:email, active_changes.email}
      ]
      |> Enum.filter(& &1)

    case execute_update_pipeline(update_pipeline, user, socket, []) do
      # Success: combine messages and update UI
      {:ok, updated_user, messages} ->
        success_message = Enum.join(messages, ". ")
        trigger_submit = Map.has_key?(active_changes, :password)

        {:noreply,
         socket
         |> maybe_put_success_flash(success_message, trigger_submit)
         |> assign(trigger_submit: trigger_submit)
         |> reset_forms(updated_user)}

      # Error: show specific error message and update form
      {:error, type, changeset} ->
        {field, message} =
          case type do
            :user ->
              {:user_form, "Failed to update account details."}

            :password ->
              {:password_form, "Failed to update password."}

            :email ->
              {:email_form, "Please provide your current password to change your email address."}
          end

        {:noreply,
         socket
         |> clear_flash()
         |> put_flash(:error, message)
         |> assign(field, to_form(changeset))}
    end
  end

  defp execute_update_pipeline([], user, _socket, messages),
    do: {:ok, user, Enum.reverse(messages)}

  defp execute_update_pipeline([{:user, params} | rest], user, socket, messages) do
    case execute_user_update(user, params) do
      {:ok, updated_user, message} ->
        execute_update_pipeline(rest, updated_user, socket, [message | messages])

      {:error, type, changeset} ->
        {:error, type, changeset}
    end
  end

  defp execute_update_pipeline([{:password, params} | rest], user, socket, messages) do
    case execute_password_update(user, params, socket) do
      {:ok, updated_user, message} ->
        execute_update_pipeline(rest, updated_user, socket, [message | messages])

      {:error, type, changeset} ->
        {:error, type, changeset}
    end
  end

  defp execute_update_pipeline([{:email, params} | rest], user, socket, messages) do
    case execute_email_update(user, params) do
      {:ok, updated_user, message} ->
        execute_update_pipeline(rest, updated_user, socket, [message | messages])

      {:error, type, changeset} ->
        {:error, type, changeset}
    end
  end

  defp reset_forms(socket, user) do
    user_form = user |> Accounts.change_user_details(%{}) |> to_form()
    email_form = user |> Accounts.change_user_email(%{}) |> to_form()
    password_form = user |> Accounts.change_user_password(%{}) |> to_form()

    socket
    |> assign(user_form: user_form, email_form: email_form, password_form: password_form)
    |> assign(current_email: user.email)
  end

  defp maybe_put_success_flash(socket, _message, true), do: socket

  defp maybe_put_success_flash(socket, message, false),
    do: socket |> clear_flash() |> put_flash(:info, message)

  defp password_fields_both_empty?(password_form) do
    password = input_value(password_form[:password])
    password_confirmation = input_value(password_form[:password_confirmation])

    (is_nil(password) or String.trim(password) == "") and
      (is_nil(password_confirmation) or String.trim(password_confirmation) == "")
  end
end
