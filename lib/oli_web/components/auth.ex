defmodule OliWeb.Components.Auth do
  use OliWeb, :html

  attr :title, :string, default: "Sign in"
  attr :form, :any, required: true
  attr :action, :string, required: true
  attr :section, :string, default: nil
  attr :from_invitation_link?, :boolean, default: false
  attr :class, :string, default: ""
  attr :provider_links, :list, required: true
  attr :registration_link, :string, default: nil
  attr :reset_password_link, :string, required: true

  def log_in_form(assigns) do
    ~H"""
    <div class={["w-96 dark:bg-neutral-700 sm:rounded-md sm:shadow-lg dark:text-white", @class]}>
      <div class="text-center text-xl font-normal leading-7 py-8">
        <%= @title %>
      </div>

      <%= for link <- @provider_links, do: raw(link) %>
      <div :if={not Enum.empty?(@provider_links)} class="my-4 text-center  leading-snug">
        OR
      </div>

      <.form :let={f} id="log_in_form" for={@form} action={@action} phx-update="ignore">
        <div class="w-80 mx-auto flex flex-col gap-2 py-8">
          <div>
            <%= email_input(f, :email,
              class:
                "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
              placeholder: "Email",
              required: true,
              autofocus: true
            ) %>
            <%= error_tag(f, :email) %>
          </div>
          <div>
            <%= password_input(f, :password,
              class:
                "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
              placeholder: "Password",
              required: true
            ) %>
            <%= error_tag(f, :password) %>
          </div>

          <div class="flex flex-row justify-between mb-6">
            <div class="flex items-center gap-x-2 custom-control custom-checkbox">
              <%= checkbox(f, :remember_me, class: "w-4 h-4 dark:#171717 border dark:border-white") %>
              <%= label(f, :remember_me, "Remember me", class: "text-center leading-snug") %>
            </div>
            <div class="custom-control">
              <%= link("Forgot password?",
                to: @reset_password_link,
                class: "text-center text-[#4ca6ff] font-bold leading-snug"
              ) %>
            </div>
          </div>

          <%= if @section do %>
            <%= hidden_input(f, :section, value: @section) %>
          <% end %>

          <.button
            phx-disable-with="Signing in..."
            class="bg-[#0062f2] text-white hover:bg-[#0052cb] disabled:bg-transparent rounded-md mt-4"
          >
            Sign in
          </.button>

          <hr
            :if={@from_invitation_link? || @registration_link}
            class="mt-8 mb-3 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10"
          />

          <.button
            :if={@from_invitation_link? || @registration_link}
            variant={:link}
            href={@registration_link || ~p"/users/register"}
            class="!text-white"
          >
            Create an account
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :title, :string, default: "Create Account"
  attr :form, :any, required: true
  attr :action, :string, required: true
  attr :class, :string, default: ""
  attr :provider_links, :list, required: true
  attr :log_in_link, :string, default: nil
  attr :link_account, :boolean, default: false
  attr :trigger_submit, :boolean, required: true
  attr :check_errors, :boolean, default: false
  attr :recaptcha_error, :any, required: true

  def registration_form(assigns) do
    ~H"""
    <div class={[
      "w-96 dark:bg-neutral-700 sm:rounded-md sm:shadow-lg dark:text-white",
      @class
    ]}>
      <div class="text-center text-xl font-normal leading-7 py-8">
        <%= @title %>
      </div>

      <%= for link <- @provider_links, do: raw(link) %>
      <div :if={not Enum.empty?(@provider_links)} class="my-4 text-center  leading-snug">
        OR
      </div>

      <.form
        :let={f}
        id="registration_form"
        for={@form}
        action={@action}
        method="post"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
      >
        <div class="w-80 mx-auto flex flex-col gap-2 py-8">
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input
            field={@form[:email]}
            type="text"
            placeholder="Email"
            class={"w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                      error_class(f, :email, "is-invalid")}
            label_class="control-label"
            required
            autofocus={focusHelper(f, :email, default: true)}
          />

          <.input
            field={@form[:given_name]}
            type="text"
            placeholder="First name"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, :given_name, "is-invalid")}
            required
            autofocus={focusHelper(f, :given_name, default: true)}
          />

          <.input
            field={@form[:family_name]}
            type="text"
            placeholder="Last name"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, :family_name, "is-invalid")}
            required
            autofocus={focusHelper(f, :family_name, default: true)}
          />

          <.input
            field={@form[:password]}
            type="password"
            placeholder="Password"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, [:password, :password_confirmation], "is-invalid")}
            required
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            placeholder="Confirm password"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, [:password_confirmation], "is-invalid")}
            required
          />

          <div class="w-80 mx-auto">
            <div
              id="recaptcha"
              phx-hook="Recaptcha"
              data-sitekey={Application.fetch_env!(:oli, :recaptcha)[:site_key]}
              data-theme="dark"
              phx-update="ignore"
            >
            </div>

            <.error :if={@recaptcha_error}><%= @recaptcha_error %></.error>
          </div>

          <%= if @link_account do %>
            <%= hidden_input(f, :link_account, value: @link_account) %>
          <% end %>

          <.button
            phx-disable-with="Creating account..."
            class="bg-[#0062f2] text-white hover:bg-[#0052cb] disabled:bg-transparent rounded-md mt-4"
          >
            Create an account
          </.button>

          <hr
            :if={@log_in_link}
            class="mt-8 mb-3 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10"
          />

          <.button variant={:link} href={@log_in_link} class="!text-white">
            Sign in to existing account
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
