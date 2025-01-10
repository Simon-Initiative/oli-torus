defmodule OliWeb.LinkAccountLive do
  use OliWeb, :live_view

  require Logger

  import OliWeb.Backgrounds
  import OliWeb.Components.Auth

  alias Oli.Accounts

  on_mount {OliWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "author")

    authentication_providers =
      Oli.AssentAuth.AuthorAssentAuth.authentication_providers() |> Keyword.keys()

    linked_account = Accounts.linked_author_account(socket.assigns.current_user)

    {:ok,
     assign(socket,
       form: form,
       authentication_providers: authentication_providers,
       linked_account: linked_account
     ), temporary_assigns: [form: form]}
  end

  def handle_event(
        "unlink",
        _params,
        socket
      ) do
    case Accounts.unlink_user_author_account(socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account unlinked successfully.")
         |> redirect(to: ~p"/users/link_account")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to unlink account.")
         |> redirect(to: ~p"/users/link_account")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.author_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <div class={["w-96 px-10 dark:bg-neutral-700 sm:rounded-md sm:shadow-lg dark:text-white"]}>
            <div class="text-center text-xl font-normal leading-7 py-8">
              Link Authoring Account
            </div>
            <p class="text-center">
              Sign in with your authoring account credentials below to link your account.
            </p>

            <div
              :if={not Enum.empty?(@authentication_providers)}
              class="mx-auto flex flex-col gap-2 py-8"
            >
              <.authorization_link
                :for={provider <- @authentication_providers}
                provider={provider}
                href={~p"/authors/auth/#{provider}/new?link_account_user_id=#{@current_user.id}"}
              />
            </div>

            <.form :let={f} id="link_account_form" for={@form} action={~p"/authors/log_in"}>
              <div class="mx-auto flex flex-col gap-2 py-8">
                <div>
                  <%= email_input(f, :email,
                    class:
                      "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
                    placeholder: "Email",
                    required: true,
                    autofocus: focusHelper(f, :email, default: true)
                  ) %>
                  <%= error_tag(f, :email) %>
                </div>
                <div>
                  <%= password_input(f, :password,
                    class:
                      "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
                    placeholder: "Password",
                    required: true,
                    autofocus: focusHelper(f, :password, default: true)
                  ) %>
                  <%= error_tag(f, :password) %>
                </div>

                <%= hidden_input(f, :link_account_user_id, value: @current_user.id) %>

                <.button
                  type="submit"
                  variant={:primary}
                  phx-disable-with="Processing..."
                  class="bg-[#0062f2] text-white hover:bg-[#0052cb] disabled:bg-transparent rounded-md mt-4"
                >
                  Link Account
                </.button>
              </div>
            </.form>

            <hr class="mt-4 mb-3 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10" />

            <.button
              :if={@linked_account}
              variant={:tertiary}
              phx-disable-with="Unlinking..."
              phx-click="unlink"
              class="w-full inline-block text-center mt-2"
            >
              Unlink <%= @linked_account.email %>
            </.button>

            <.button
              variant={:secondary}
              href={value_or(assigns[:cancel_path], ~p"/")}
              class="w-full inline-block text-center mt-2"
            >
              Cancel
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
