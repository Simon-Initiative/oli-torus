defmodule OliWeb.Components.Auth do
  use OliWeb, :html

  attr :title, :string, default: "Sign in"
  attr :form, :any, required: true
  attr :action, :string, required: true
  attr :section, :string, default: nil
  attr :from_invitation_link?, :boolean, default: false
  attr :class, :string, default: ""
  attr :on_confirm, :string
  attr :provider_links, :list, required: true
  attr :registration_link, :string, default: nil

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

      <.form :let={f} for={@form} action={@action} phx-update="ignore">
        <div class="flex flex-col gap-y-2">
          <div class="w-80 h-11 m-auto form-label-group border-none">
            <%= email_input(f, :email,
              class:
                "form-control dark:placeholder:text-zinc-300 pl-6 h-11 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
              placeholder: "Email",
              required: true,
              autofocus: true
            ) %>
            <%= error_tag(f, :email) %>
          </div>
          <div class="w-80 h-11 m-auto form-label-group border-none">
            <%= password_input(f, :password,
              class:
                "form-control dark:placeholder:text-zinc-300 pl-6 h-11 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
              placeholder: "Password",
              required: true
            ) %>
            <%= error_tag(f, :password) %>
          </div>
        </div>
        <div class="mb-4 d-flex flex-row justify-between px-8 pb-2 pt-6">
          <%= unless Application.fetch_env!(:oli, :always_use_persistent_login_sessions) do %>
            <div class="flex items-center gap-x-2 custom-control custom-checkbox">
              <%= checkbox(f, :remember_me, class: "w-4 h-4 dark:#171717 border dark:border-white") %>
              <%= label(f, :remember_me, "Remember me", class: "text-center leading-snug") %>
            </div>
          <% else %>
            <div></div>
          <% end %>
          <div class="custom-control">
            <%= link("Forgot password?",
              to: ~p"/users/reset_password",
              tabindex: "1",
              class: "text-center text-[#4ca6ff] font-bold leading-snug"
            ) %>
          </div>
        </div>

        <%= if @section do %>
          <%= hidden_input(f, :section, value: @section) %>
        <% end %>

        <div class="flex justify-center">
          <%= submit("Sign In",
            class:
              "w-80 h-11 bg-[#0062f2] text-white hover:bg-[#0052cb] mx-auto leading-7 rounded-md mb-10 mt-2"
          ) %>
        </div>

        <hr
          :if={@from_invitation_link? || @registration_link}
          class="mt-0 mb-6 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10"
        />
        <div :if={@from_invitation_link? || @registration_link} class="flex justify-center mb-8">
          <%= link("Create an Account",
            to: @registration_link || ~p"/users/register",
            class: "text-center text-[#4ca6ff] text-lg font-bold leading-snug"
          ) %>
        </div>
      </.form>
    </div>
    """
  end
end
