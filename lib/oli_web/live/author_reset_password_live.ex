defmodule OliWeb.AuthorResetPasswordLive do
  use OliWeb, :live_view

  import OliWeb.Backgrounds

  alias Oli.Accounts

  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.author_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <.form_box
            for={@form}
            id="reset_password_form"
            phx-submit="reset_password"
            phx-change="validate"
          >
            <:title>
              Reset Password
            </:title>

            <.error :if={@form.errors != []}>
              Oops, something went wrong! Please check the errors below.
            </.error>

            <.input field={@form[:password]} type="password" label="New password" required />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              required
            />
            <:actions>
              <.button variant={:primary} phx-disable-with="Resetting..." class="w-full mt-4">
                Reset Password
              </.button>
            </:actions>
          </.form_box>
        </div>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_author_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{author: author} ->
          Accounts.change_author_password(author)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the author after reset password to avoid a
  # leaked token giving the author access to the account.
  def handle_event("reset_password", %{"author" => author_params}, socket) do
    case Accounts.reset_author_password(socket.assigns.author, author_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/authors/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"author" => author_params}, socket) do
    changeset = Accounts.change_author_password(socket.assigns.author, author_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_author_and_token(socket, %{"token" => token}) do
    if author = Accounts.get_author_by_reset_password_token(token) do
      assign(socket, author: author, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/authors/log_in")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "author"))
  end
end
