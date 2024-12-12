defmodule OliWeb.UserForgotPasswordLive do
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
          <.form_box for={@form} id="reset_password_form" phx-submit="send_email">
            <:title>
              Forgot your password?
            </:title>
            <:subtitle>
              We'll send a password reset link to your inbox
            </:subtitle>

            <.input field={@form[:email]} type="email" placeholder="Email" required />

            <:actions>
              <.button variant={:primary} phx-disable-with="Sending..." class="w-full mt-4">
                Send password reset instructions
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

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_independent_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
