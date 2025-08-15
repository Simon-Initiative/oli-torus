defmodule OliWeb.Components.Auth do
  use OliWeb, :html

  attr :title, :string, default: "Sign in"
  attr :form, :any, required: true
  attr :action, :string, required: true
  attr :section, :string, default: nil
  attr :from_invitation_link?, :boolean, default: false
  attr :class, :string, default: ""
  attr :authentication_providers, :list, default: []
  attr :auth_provider_path_fn, :any
  attr :registration_link, :string, default: nil
  attr :reset_password_link, :string, required: true
  attr :disabled_inputs, :list, default: []
  attr :trigger_submit, :boolean, default: false
  attr :submit_event, :any, default: nil

  def login_form(assigns) do
    ~H"""
    <div class={["w-96 dark:bg-neutral-700 rounded-md sm:shadow-lg dark:text-white", @class]}>
      <div class="text-center text-xl font-normal leading-7 py-8">
        {@title}
      </div>

      <div
        :if={not Enum.empty?(@authentication_providers)}
        class="w-80 mx-auto flex flex-col gap-2 py-8"
      >
        <.authorization_link
          :for={provider <- @authentication_providers}
          provider={provider}
          href={@auth_provider_path_fn.(provider)}
        />
      </div>

      <.form
        :let={f}
        id="login_form"
        for={@form}
        action={@action}
        phx-submit={@submit_event}
        phx-trigger-action={@trigger_submit}
      >
        <div class="w-80 mx-auto flex flex-col gap-2 py-8">
          <div>
            {email_input(f, :email,
              class:
                "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
              placeholder: "Email",
              required: true,
              autofocus: focusHelper(f, :email, default: true),
              disabled: :email in @disabled_inputs
            )}
            {error_tag(f, :email)}
          </div>
          <div>
            {password_input(f, :password,
              class:
                "w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug",
              placeholder: "Password",
              required: true,
              autofocus: focusHelper(f, :password, default: true),
              disabled: :password in @disabled_inputs
            )}
            {error_tag(f, :password)}
          </div>

          <div class="flex flex-row justify-between mb-6">
            <div class="flex items-center gap-x-2 custom-control custom-checkbox">
              {checkbox(f, :remember_me, class: "w-4 h-4 dark:#171717 border dark:border-white")}
              {label(f, :remember_me, "Remember me", class: "text-center leading-snug")}
            </div>
            <div class="custom-control">
              {link("Forgot password?",
                to: @reset_password_link,
                class: "text-center text-[#4ca6ff] font-bold leading-snug"
              )}
            </div>
          </div>

          <%= if @from_invitation_link? do %>
            {hidden_input(f, :from_invitation_link?, value: @from_invitation_link?)}
          <% end %>

          <%= if @section do %>
            {hidden_input(f, :section, value: @section)}
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
            href={(@registration_link || ~p"/users/register") <> maybe_params([section: @section, from_invitation_link?: @from_invitation_link?])}
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
  attr :section, :string, default: nil
  attr :from_invitation_link?, :boolean, default: false
  attr :class, :string, default: ""
  attr :authentication_providers, :list, default: []
  attr :auth_provider_path_fn, :any
  attr :log_in_link, :string, default: nil
  attr :link_account, :boolean, default: false
  attr :trigger_submit, :boolean, required: true
  attr :check_errors, :boolean, default: false
  attr :recaptcha_error, :any, required: true
  attr :disabled_inputs, :list, default: []

  def registration_form(assigns) do
    ~H"""
    <div class={[
      "w-96 dark:bg-neutral-700 rounded-md sm:shadow-lg dark:text-white",
      @class
    ]}>
      <div class="text-center text-xl font-normal leading-7 py-8">
        {@title}
      </div>

      <div
        :if={not Enum.empty?(@authentication_providers)}
        class="w-80 mx-auto flex flex-col gap-2 py-8"
      >
        <.authorization_link
          :for={provider <- @authentication_providers}
          provider={provider}
          href={@auth_provider_path_fn.(provider)}
        />
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
            disabled={:email in @disabled_inputs}
            phx-debounce={500}
            autofocus={focusHelper(f, :email, default: true)}
          />

          <.input
            field={@form[:given_name]}
            type="text"
            placeholder="First name"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, :given_name, "is-invalid")}
            required
            disabled={:given_name in @disabled_inputs}
            phx-debounce={500}
            autofocus={focusHelper(f, :given_name, default: true)}
          />

          <.input
            field={@form[:family_name]}
            type="text"
            placeholder="Last name"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, :family_name, "is-invalid")}
            required
            disabled={:family_name in @disabled_inputs}
            phx-debounce={500}
            autofocus={focusHelper(f, :family_name, default: true)}
          />

          <.input
            field={@form[:password]}
            type="password"
            placeholder="Password"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, [:password, :password_confirmation], "is-invalid")}
            disabled={:password in @disabled_inputs}
            phx-debounce={500}
            required
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            placeholder="Confirm password"
            class={"dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug" <>
                  error_class(f, [:password_confirmation], "is-invalid")}
            disabled={:password_confirmation in @disabled_inputs}
            phx-debounce={500}
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

            <.error :if={@recaptcha_error}>{@recaptcha_error}</.error>
          </div>

          <%= if @link_account do %>
            {hidden_input(f, :link_account, value: @link_account)}
          <% end %>

          <%= if @from_invitation_link? do %>
            {hidden_input(f, :from_invitation_link?, value: @from_invitation_link?)}
          <% end %>

          <%= if @section do %>
            {hidden_input(f, :section, value: @section)}
          <% end %>

          <.button
            phx-disable-with="Creating account..."
            class="bg-[#0062f2] text-white hover:bg-[#0052cb] disabled:bg-transparent rounded-md mt-4"
          >
            Create account
          </.button>

          <hr
            :if={@log_in_link}
            class="mt-8 mb-3 h-0.5 w-3/4 mx-auto border-t-0 bg-neutral-100 dark:bg-white/10"
          />

          <.button
            :if={@log_in_link}
            variant={:link}
            href={@log_in_link <> maybe_params([
            section: @section,
            from_invitation_link?: @from_invitation_link?
          ])}
            class="!text-white"
          >
            Sign in to existing account
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  Renders an authorization link for a provider.

  The link is used to sign up or register a user using a provider. If
  `:invited_user` is assigned to the conn, the invitation token will be passed
  on through the URL query params.

  ## Examples

      <.authorization_link provider="github" />

      <.authorization_link provider="github">Sign in with Github</.authorization_link>
  """
  attr :provider, :atom, required: true
  attr :href, :string, required: true
  attr :navigate, :string, default: nil
  attr :user_return_to, :string, default: nil

  attr :rest, :global,
    include: ~w(csrf_token download hreflang method referrerpolicy rel target type)

  slot :inner_block

  def authorization_link(%{navigate: nil, href: href} = assigns) do
    assigns =
      assign(assigns,
        navigate: maybe_user_return_to(href, assigns.user_return_to)
      )

    authorization_link(assigns)
  end

  def authorization_link(%{provider: :google} = assigns) do
    ~H"""
    <.sign_in_with_google navigate={@navigate} {@rest}>
      {render_slot(@inner_block) || "Sign in with Google"}
    </.sign_in_with_google>
    """
  end

  def authorization_link(%{provider: :github} = assigns) do
    ~H"""
    <.sign_in_with_github navigate={@navigate} {@rest}>
      {render_slot(@inner_block) || "Sign in with GitHub"}
    </.sign_in_with_github>
    """
  end

  def authorization_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      aria-label={"Sign in with #{provider_title(@provider)}"}
      class="bg-white border border-gray-400 rounded-md p-2 text-body dark:text-body-dark text-center hover:no-underline"
      {@rest}
    >
      {render_slot(@inner_block) || "Sign in with #{provider_title(@provider)}"}
    </.link>
    """
  end

  @doc """
  Renders a deauthorization link for a provider.

  The link is used to remove authorization with the provider.

  ## Examples

      <.deauthorization_link provider="github" href={~p"/users/auth/github"}>

      <.deauthorization_link provider="github" href={~p"/users/auth/github"}>Remove Github authentication</.deauthorization_link>
  """
  attr :provider, :atom, required: true
  attr :href, :string, required: true
  attr :navigate, :string, default: nil
  attr :user_return_to, :string, default: nil

  attr :rest, :global,
    include: ~w(csrf_token download hreflang method referrerpolicy rel target type)

  slot :inner_block

  def deauthorization_link(%{navigate: nil, href: href} = assigns) do
    assigns =
      assign(assigns,
        navigate: maybe_user_return_to(href, assigns.user_return_to)
      )

    deauthorization_link(assigns)
  end

  def deauthorization_link(%{provider: :google} = assigns) do
    ~H"""
    <.sign_in_with_google navigate={@navigate} method="delete" {@rest}>
      Remove Google credentials
    </.sign_in_with_google>
    """
  end

  def deauthorization_link(%{provider: :github} = assigns) do
    ~H"""
    <.sign_in_with_github navigate={@navigate} method="delete" {@rest}>
      Remove Github credentials
    </.sign_in_with_github>
    """
  end

  def deauthorization_link(assigns) do
    ~H"""
    <.link href={@navigate} method="delete" {@rest}>
      Remove {provider_title(@provider)} credentials
    </.link>
    """
  end

  defp maybe_user_return_to(path, nil), do: path
  defp maybe_user_return_to(path, user_return_to), do: "#{path}?user_return_to=#{user_return_to}"

  def provider_title(provider) do
    provider
    |> Atom.to_string()
    |> String.capitalize()
  end

  attr :navigate, :string, required: true

  attr :rest, :global,
    include: ~w(csrf_token download hreflang method referrerpolicy rel target type)

  slot :inner_block, required: true

  defp sign_in_with_google(assigns) do
    ~H"""
    <.link
      href={@navigate}
      aria-label="Sign in with Google"
      class="p-0.5 pr-3 max-w-md flex items-center bg-white hover:bg-gray-100 border border-button-border-light rounded-md hover:no-underline"
      {@rest}
    >
      <div class="flex items-center justify-center bg-white w-9 h-9 rounded-l mr-[10px]">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5">
          <title>Sign in with Google</title>
          <desc>Google G Logo</desc>
          <path
            d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
            class="fill-google-logo-blue"
          >
          </path>
          <path
            d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            class="fill-google-logo-green"
          >
          </path>
          <path
            d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
            class="fill-google-logo-yellow"
          >
          </path>
          <path
            d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
            class="fill-google-logo-red"
          >
          </path>
        </svg>
      </div>
      <div class="flex-1 text-sm text-google-text-gray text-center tracking-wider mr-[36px]">
        {render_slot(@inner_block)}
      </div>
    </.link>
    """
  end

  attr :navigate, :string, required: true

  attr :rest, :global,
    include: ~w(csrf_token download hreflang method referrerpolicy rel target type)

  slot :inner_block

  defp sign_in_with_github(assigns) do
    ~H"""
    <.link
      href={@navigate}
      aria-label="Sign in with Github"
      class="py-2 px-4 max-w-md flex justify-center items-center bg-gray-600 hover:bg-gray-700 focus:ring-gray-500 focus:ring-offset-gray-200 text-white w-full transition ease-in duration-200 text-center text-base font-semibold shadow-md focus:outline-none focus:ring-2 focus:ring-offset-2 rounded-lg hover:no-underline hover:text-white"
      {@rest}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="20"
        height="20"
        fill="currentColor"
        class="mr-2"
        viewBox="0 0 1792 1792"
      >
        <path d="M896 128q209 0 385.5 103t279.5 279.5 103 385.5q0 251-146.5 451.5t-378.5 277.5q-27 5-40-7t-13-30q0-3 .5-76.5t.5-134.5q0-97-52-142 57-6 102.5-18t94-39 81-66.5 53-105 20.5-150.5q0-119-79-206 37-91-8-204-28-9-81 11t-92 44l-38 24q-93-26-192-26t-192 26q-16-11-42.5-27t-83.5-38.5-85-13.5q-45 113-8 204-79 87-79 206 0 85 20.5 150t52.5 105 80.5 67 94 39 102.5 18q-39 36-49 103-21 10-45 15t-57 5-65.5-21.5-55.5-62.5q-19-32-48.5-52t-49.5-24l-20-3q-21 0-29 4.5t-5 11.5 9 14 13 12l7 5q22 10 43.5 38t31.5 51l10 23q13 38 44 61.5t67 30 69.5 7 55.5-3.5l23-4q0 38 .5 88.5t.5 54.5q0 18-13 30t-40 7q-232-77-378.5-277.5t-146.5-451.5q0-209 103-385.5t279.5-279.5 385.5-103zm-477 1103q3-7-7-12-10-3-13 2-3 7 7 12 9 6 13-2zm31 34q7-5-2-16-10-9-16-3-7 5 2 16 10 10 16 3zm30 45q9-7 0-19-8-13-17-6-9 5 0 18t17 7zm42 42q8-8-4-19-12-12-20-3-9 8 4 19 12 12 20 3zm57 25q3-11-13-16-15-4-19 7t13 15q15 6 19-6zm63 5q0-13-17-11-16 0-16 11 0 13 17 11 16 0 16-11zm58-10q-2-11-18-9-16 3-14 15t18 8 14-14z">
        </path>
      </svg>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp maybe_params(params) do
    has_params? = Enum.any?(params, fn {_, v} -> v end)

    if has_params? do
      query =
        params
        |> Enum.reduce([], fn {k, v}, acc ->
          if v do
            [{k, v} | acc]
          else
            acc
          end
        end)
        |> URI.encode_query()

      "?#{query}"
    else
      ""
    end
  end
end
