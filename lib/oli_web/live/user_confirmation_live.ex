defmodule OliWeb.UserConfirmationLive do
  use OliWeb, :live_view

  import OliWeb.Backgrounds

  alias Oli.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.student_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <.form_box for={@form} id="confirmation_form" phx-submit="confirm_account">
            <:title>
              Confirm Account
            </:title>
            <:subtitle>
              Please confirm your account email address by clicking the button below.
            </:subtitle>

            <.input field={@form[:token]} type="hidden" />
            <.input :if={@section} field={@form[:section]} type="hidden" value={@section} />

            <:actions>
              <.button variant={:primary} phx-disable-with="Confirming..." class="w-full mt-4">
                Confirm
              </.button>
            </:actions>
          </.form_box>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")
    {:ok, assign(socket, form: form, section: nil), temporary_assigns: [form: nil]}
  end

  def handle_params(unsigned_params, _uri, socket) do
    section = unsigned_params["section"]

    {:noreply,
     assign(socket,
       section: section
     )}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token} = user_params}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email successfully confirmed.")
         |> redirect(to: ~p"/users/log_in?#{maybe_section_param(user_params["section"])}")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{email_confirmed_at: email_confirmed_at}}
          when not is_nil(email_confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end

  defp maybe_section_param(nil), do: []
  defp maybe_section_param(section), do: [section: section]
end
