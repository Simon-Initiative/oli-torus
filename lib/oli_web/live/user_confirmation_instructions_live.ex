defmodule OliWeb.UserConfirmationInstructionsLive do
  use OliWeb, :live_view

  import OliWeb.Backgrounds

  alias Oli.Accounts

  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.student_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <.form_box for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
            <:title>
              Confirm Your Account
            </:title>
            <:subtitle>
              <p>
                Please check your inbox for a confirmation link.
              </p>

              <p class="mt-4">
                No confirmation instructions received? We'll send a new confirmation link to your inbox.
              </p>
            </:subtitle>

            <.input
              field={@form[:email]}
              type="email"
              class="w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug"
              placeholder="Email"
              required
            />

            <:actions>
              <.button variant={:primary} phx-disable-with="Sending..." class="w-full mt-4">
                Resend confirmation instructions
              </.button>

              <hr class="mt-8 mb-3 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10" />

              <.button variant={:link} href={~p"/users/log_in"} class="!text-white">
                Sign in
              </.button>
            </:actions>
          </.form_box>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_independent_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/users/confirm")}
  end
end
