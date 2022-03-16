defmodule OliWeb.Pow.PowHelpers do
  alias PowAssent.Plug

  alias Phoenix.{HTML, HTML.Link, HTML.Tag, Naming}
  alias PowAssent.Phoenix.AuthorizationController

  def get_pow_config(:user) do
    [
      repo: Oli.Repo,
      user: Oli.Accounts.User,
      current_user_assigns_key: :current_user,
      session_key: "user_auth",
      plug: Pow.Plug.Session,
      web_module: OliWeb,
      routes_backend: OliWeb.Pow.UserRoutes,
      extensions: [PowResetPassword, PowEmailConfirmation, PowPersistentSession, PowInvitation],
      controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
      cache_store_backend: Pow.Store.Backend.MnesiaCache,
      users_context: OliWeb.Pow.UserContext,
      mailer_backend: OliWeb.Pow.Mailer,
      web_mailer_module: OliWeb,
      pow_assent: [
        user_identities_context: OliWeb.Pow.UserIdentities,
        providers: providers_config_list(:user)
      ]
    ]
  end

  def get_pow_config(:author) do
    [
      repo: Oli.Repo,
      user: Oli.Accounts.Author,
      current_user_assigns_key: :current_author,
      session_key: "author_auth",
      plug: Pow.Plug.Session,
      web_module: OliWeb,
      routes_backend: OliWeb.Pow.AuthorRoutes,
      extensions: [PowResetPassword, PowEmailConfirmation, PowPersistentSession, PowInvitation],
      controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
      cache_store_backend: Pow.Store.Backend.MnesiaCache,
      users_context: OliWeb.Pow.AuthorContext,
      mailer_backend: OliWeb.Pow.Mailer,
      web_mailer_module: OliWeb,
      pow_assent: [
        user_identities_context: OliWeb.Pow.AuthorIdentities,
        providers: providers_config_list(:author)
      ]
    ]
  end

  def use_pow_config(conn, :user) do
    Pow.Plug.put_config(conn, get_pow_config(:user))
  end

  def use_pow_config(conn, :author) do
    Pow.Plug.put_config(conn, get_pow_config(:author))
  end

  def current_pow_config(conn) do
    Pow.Plug.fetch_config(conn)
    |> Keyword.get(:user)
  end

  ## provider_links forked from original pow_assent codebase to support custom styling for providers ##
  # https://github.com/pow-auth/pow_assent/blob/master/lib/pow_assent/phoenix/views/view_helpers.ex

  @doc """
  Generates list of authorization links for all configured providers.
  The list of providers will be fetched from the PowAssent configuration, and
  `authorization_link/2` will be called on each.
  If a user is assigned to the conn, the authorized providers for a user will
  be looked up with `PowAssent.Plug.providers_for_current_user/1`.
  `deauthorization_link/2` will be used for any already authorized providers.
  """
  def provider_links(conn, link_opts \\ []) do
    available_providers = Plug.available_providers(conn)
    providers_for_user = Plug.providers_for_current_user(conn)

    available_providers
    |> Enum.map(&{&1, &1 in providers_for_user})
    |> Enum.map(fn
      {provider, true} -> deauthorization_link(conn, provider, link_opts)
      {provider, false} -> authorization_link(conn, provider, link_opts)
    end)
  end

  @doc """
  Generates an authorization link for a provider.
  The link is used to sign up or register a user using a provider. If
  `:invited_user` is assigned to the conn, the invitation token will be passed
  on through the URL query params.
  """
  def authorization_link(conn, provider, opts \\ []) do
    query_params = invitation_token_query_params(conn) ++ request_path_query_params(conn)

    msg =
      AuthorizationController.extension_messages(conn).login_with_provider(%{
        conn
        | params: %{"provider" => provider}
      })

    icon = provider_icon(provider)

    path =
      AuthorizationController.routes(conn).path_for(
        conn,
        AuthorizationController,
        :new,
        [provider],
        query_params
      )

    opts = Keyword.merge(opts, to: path)

    opts =
      Keyword.merge(opts, class: "btn btn-md #{provider_class(provider)} btn-block social-signin")

    provider_name = provider_name(provider, downcase: true)

    msg_box = Tag.content_tag(:div, msg, class: provider_name <> "-text-container")

    button_box = Tag.content_tag(:div, [icon, msg_box], class: provider_name <> "-auth-container")

    Link.link(button_box, opts)
  end

  defp invitation_token_query_params(%{assigns: %{invited_user: %{invitation_token: token}}}),
    do: [invitation_token: token]

  defp invitation_token_query_params(_conn), do: []

  defp request_path_query_params(%{assigns: %{request_path: request_path}}),
    do: [request_path: request_path]

  defp request_path_query_params(_conn), do: []

  @doc """
  Generates a provider deauthorization link.
  The link is used to remove authorization with the provider.
  """
  @spec deauthorization_link(Conn.t(), atom(), keyword()) :: HTML.safe()
  def deauthorization_link(conn, provider, opts \\ []) do
    msg =
      AuthorizationController.extension_messages(conn).remove_provider_authentication(%{
        conn
        | params: %{"provider" => provider}
      })

    icon = provider_icon(provider)

    path =
      AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :delete, [
        provider
      ])

    opts = Keyword.merge(opts, to: path, method: :delete)

    opts =
      Keyword.merge(opts, class: "btn btn-md #{provider_class(provider)} btn-block social-signin")

    provider_name = provider_name(provider, downcase: true)

    msg_box = Tag.content_tag(:div, msg, class: provider_name <> "-text-container")

    button_box = Tag.content_tag(:div, [icon, msg_box], class: provider_name <> "-auth-container")

    Link.link(button_box, opts)
  end

  def provider_icon(provider) do
    case provider do
      :google ->
        HTML.raw(
          "<div class=\"#{provider_name(provider, downcase: true)}-icon-container\"><img class=\"#{provider_name(provider, downcase: true)}-icon\" src=\"/images/icons/google-icon.svg\"/></div>"
        )

      :github ->
        HTML.raw(
          "<div class=\"#{provider_name(provider, downcase: true)}-icon-container\"><i class=\"fab fa-github #{provider_name(provider, downcase: true)}-icon\"></i></div>"
        )

      _ ->
        HTML.raw(nil)
    end
  end

  def provider_class(provider) do
    provider
    |> provider_name(downcase: true)
    |> (&"provider-#{&1}").()
  end

  def provider_name(provider) do
    provider
    |> Naming.humanize()
    |> String.upcase()
  end

  def provider_name(provider, downcase: true) do
    provider
    |> Naming.humanize()
    |> String.downcase()
  end

  defp providers_config_list(user_type) do
    []
    |> maybe_add_provider(:github, user_type)
    |> maybe_add_provider(:google, user_type)
  end

  defp maybe_add_provider(providers_list, provider, user_type) do
    prefix =
      if provider == :github do
        "#{user_type}_#{provider}"
      else
        provider
      end

    client_id = Application.fetch_env!(:oli, :auth_providers)[:"#{prefix}_client_id"]
    client_secret = Application.fetch_env!(:oli, :auth_providers)[:"#{prefix}_client_secret"]

    if blank?(client_id) or blank?(client_secret) do
      providers_list
    else
      Keyword.put(providers_list, provider, provider_config(provider, client_id, client_secret))
    end
  end

  defp provider_config(:google, client_id, client_secret) do
    [
      client_id: client_id,
      client_secret: client_secret,
      strategy: Assent.Strategy.Google,
      authorization_params: [
        scope: "email profile"
      ],
      session_params: ["type"]
    ]
  end

  defp provider_config(:github, client_id, client_secret) do
    [
      client_id: client_id,
      client_secret: client_secret,
      strategy: Assent.Strategy.Github,
      authorization_params: [
        scope: "read:user user:email"
      ],
      session_params: ["type"]
    ]
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false
end
