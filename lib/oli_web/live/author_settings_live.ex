defmodule OliWeb.AuthorSettingsLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias OliWeb.Common.Properties.{Groups, Group}

  def render(assigns) do
    ~H"""
    <h2 class="text-3xl mb-8">Account Settings</h2>

    <Groups.render>
      <Group.render label="Details" description="View and change your authoring account details">
        <div class="account-section">
          <div class="grid grid-cols-12 my-4">
            <.form
              for={@author_form}
              id="author_form"
              class="col-span-12 flex flex-col gap-2 mb-10"
              phx-submit="update_author"
              phx-change="validate_author"
            >
              <.input field={@author_form[:given_name]} type="text" label="First name" />
              <.input field={@author_form[:family_name]} type="text" label="Last name" />

              <div>
                <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
              </div>
            </.form>

            <div :if={!Enum.empty?(providers_for(@current_author))} class="col-span-12 mb-10">
              <h4 class="mt-3">Credentials Managed By</h4>
              <div :for={provider <- providers_for(@current_author)} class="my-2">
                <% # MER-3835 TODO %>
              </div>
            </div>

            <.form
              for={@email_form}
              id="email_form"
              class="col-span-12 flex flex-col gap-2 mb-10"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input field={@email_form[:email]} type="email" label="Email" required />
              <.input
                field={@email_form[:current_password]}
                name="current_password"
                id="current_password_for_email"
                type="password"
                label="Current password"
                value={@email_form_current_password}
                required
              />

              <div>
                <.button variant={:primary} phx-disable-with="Changing...">Change Email</.button>
              </div>
            </.form>

            <.form
              for={@password_form}
              id="password_form"
              class="col-span-12 flex flex-col gap-2 mb-10"
              action={~p"/authors/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <.input
                field={@password_form[:email]}
                type="hidden"
                id="hidden_author_email"
                value={@current_email}
              />
              <.input
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
                <.button variant={:primary} phx-disable-with="Changing...">Change Password</.button>
              </div>
            </.form>
          </div>
        </div>
      </Group.render>
      <Group.render label="Preferences" description="Adjust your authoring preferences">
        <div>
          <div class="mt-2">
            <input
              type="checkbox"
              id="show_relative_dates"
              class="form-check-input"
              checked={@show_relative_dates}
              phx-hook="CheckboxListener"
              phx-value-change="update_preference"
            />
            <label for="show_relative_dates" class="form-check-label">
              Show dates formatted as relative to today
            </label>
          </div>

          <div class="mt-8">
            <label for="editor_selector" class="form-select-label block mb-1">
              Default editor
            </label>
            <.input
              type="select"
              id="editor"
              name="editor"
              value={@editor}
              phx-hook="SelectListener"
              phx-change="update_preference"
              options={[
                {"markdown", "Markdown"},
                {"slate", "Rich text editor"}
              ]}
            />
          </div>
        </div>
      </Group.render>
    </Groups.render>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_author_email(socket.assigns.current_author, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/authors/settings")}
  end

  def mount(_params, _session, socket) do
    author = socket.assigns.current_author
    author_changeset = Accounts.change_author_details(author)
    email_changeset = Accounts.change_author_email(author)
    password_changeset = Accounts.change_author_password(author)

    editor = Accounts.get_author_preference(author, :editor)
    show_relative_dates = Accounts.get_author_preference(author, :show_relative_dates)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, author.email)
      |> assign(:author_form, to_form(author_changeset))
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:editor, editor)
      |> assign(:show_relative_dates, show_relative_dates)
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_author", params, socket) do
    %{"author" => author_params} = params

    author_form =
      socket.assigns.current_author
      |> Accounts.change_author_details(author_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, author_form: author_form)}
  end

  def handle_event("update_author", params, socket) do
    %{"author" => author_params} = params
    author = socket.assigns.current_author

    case Accounts.update_author(author, author_params) do
      {:ok, author} ->
        author_form =
          author
          |> Accounts.change_author_details(author_params)
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Account details successfully updated.")
         |> assign(author_form: author_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, author_form: to_form(changeset))}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "author" => author_params} = params

    email_form =
      socket.assigns.current_author
      |> Accounts.change_author_email(author_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "author" => author_params} = params
    author = socket.assigns.current_author

    case Accounts.apply_author_email(author, password, author_params) do
      {:ok, applied_author} ->
        Accounts.deliver_author_update_email_instructions(
          applied_author,
          author.email,
          &url(~p"/authors/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "author" => author_params} = params

    password_form =
      socket.assigns.current_author
      |> Accounts.change_author_password(author_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "author" => author_params} = params
    author = socket.assigns.current_author

    case Accounts.update_author_password(author, password, author_params) do
      {:ok, author} ->
        password_form =
          author
          |> Accounts.change_author_password(author_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event(
        "update_preference",
        %{"id" => "show_relative_dates", "checked" => checked},
        socket
      ) do
    %{current_author: current_author} = socket.assigns

    {:ok, updated_author} =
      Accounts.set_author_preference(current_author.id, :show_relative_dates, checked)

    {:noreply, assign(socket, current_author: updated_author, show_relative_dates: checked)}
  end

  def handle_event("update_preference", %{"id" => "editor", "value" => value}, socket) do
    %{current_author: current_author} = socket.assigns

    {:ok, updated_author} = Accounts.set_author_preference(current_author.id, :editor, value)

    {:noreply, assign(socket, current_author: updated_author, editor: value)}
  end

  defp providers_for(%Author{} = author) do
    # MER-3835 TODO
    []
  end
end
