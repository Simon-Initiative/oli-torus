defmodule OliWeb.LinkAccountLive do
  use OliWeb, :live_view

  require Logger

  import OliWeb.Backgrounds
  import OliWeb.Components.Auth

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount {OliWeb.AuthorAuth, :mount_current_author}

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
        "link_current_author",
        _params,
        socket
      ) do
    case Accounts.link_user_author_account(
           socket.assigns.current_user,
           socket.assigns.current_author
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your authoring account has been linked to your user account.")
         |> redirect(to: ~p"/users/settings")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to link account.")
         |> redirect(to: ~p"/users/link_account")}
    end
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
          <div class={[
            "w-96 px-10 py-8 dark:bg-neutral-700 sm:rounded-md sm:shadow-lg dark:text-white"
          ]}>
            <div class="text-center text-xl font-normal leading-7 pb-8">
              Link Authoring Account
            </div>

            <%= case {@current_author, @linked_account} do %>
              <% {_, %Author{}} -> %>
                <.account_already_linked linked_account={@linked_account} />
              <% {nil, _} -> %>
                <.link_account_form
                  current_user={@current_user}
                  authentication_providers={@authentication_providers}
                  form={@form}
                />
              <% {_, _} -> %>
                <.link_current_author current_author={@current_author} />
            <% end %>

            <hr class="mt-4 mb-3 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10" />

            <.button
              variant={:secondary}
              href={value_or(assigns[:cancel_path], ~p"/users/settings")}
              class="w-full inline-block text-center mt-2"
            >
              Back to Account Settings
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :current_user, User, required: true
  attr :authentication_providers, :list, required: true
  attr :form, :map, required: true

  def link_account_form(assigns) do
    ~H"""
    <p class="text-center">
      Sign in with your authoring account credentials below to link your account.
    </p>

    <div :if={not Enum.empty?(@authentication_providers)} class="mx-auto flex flex-col gap-2 py-8">
      <.authorization_link
        :for={provider <- @authentication_providers}
        provider={provider}
        href={~p"/authors/auth/#{provider}/new?link_account_user_id=#{@current_user.id}"}
      />
    </div>

    <.form :let={f} id="link_account_form" for={@form} action={~p"/authors/log_in"}>
      <div class="mx-auto flex flex-col gap-2 py-8">
        <div>
          {email_input(f, :email,
            class:
              "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
            placeholder: "Email",
            required: true,
            autofocus: focusHelper(f, :email, default: true)
          )}
          {error_tag(f, :email)}
        </div>
        <div>
          {password_input(f, :password,
            class:
              "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
            placeholder: "Password",
            required: true,
            autofocus: focusHelper(f, :password, default: true)
          )}
          {error_tag(f, :password)}
        </div>

        {hidden_input(f, :link_account_user_id, value: @current_user.id)}

        <.button
          type="submit"
          variant={:primary}
          phx-disable-with="Processing..."
          class="bg-[#0062f2] text-white hover:bg-[#0052cb] disabled:bg-transparent rounded-md mt-4"
        >
          Link account
        </.button>
      </div>
    </.form>
    """
  end

  attr :current_author, Author, default: nil

  def link_current_author(assigns) do
    ~H"""
    <p class="text-center">
      You are currently signed in as <b><%= @current_author.email %></b>. You must sign out of this author account before linking an account.
    </p>

    <div class="mx-auto flex flex-col gap-2 py-8">
      <%= link to: ~p"/authors/log_out?request_path=/users/link_account", method: "delete", class: "text-base px-6 py-2 rounded text-primary-700 hover:text-primary-700 bg-primary-50 hover:bg-primary-100 active:bg-primary-200 focus:ring-2 focus:ring-primary-100 dark:text-primary-300 dark:bg-primary-800 dark:hover:bg-primary-700 dark:active:bg-primary-600 focus:outline-none dark:focus:ring-primary-800 hover:no-underline w-full inline-block text-center mt-2" do %>
        Sign out of author account
      <% end %>
    </div>
    """
  end

  attr :linked_account, Author, default: nil

  def account_already_linked(assigns) do
    ~H"""
    <p class="text-center">
      Your account is currently linked to <b><%= @linked_account.email %></b>.
    </p>

    <div class="mx-auto flex flex-col gap-2 py-8">
      <.button
        :if={@linked_account}
        variant={:tertiary}
        phx-disable-with="Unlinking..."
        phx-click="unlink"
        class="bg-[#0062f2] text-white hover:bg-[#0052cb] disabled:bg-transparent rounded-md mt-4"
      >
        Unlink account
      </.button>
    </div>
    """
  end
end
