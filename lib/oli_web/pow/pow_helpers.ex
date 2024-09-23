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
      # session_ttl_renewal: :timer.minutes(15),    # default is 15 minutes
      # default is 30 minutes
      credentials_cache_store: {Pow.Store.CredentialsCache, ttl: :timer.hours(24)},
      plug: Pow.Plug.Session,
      web_module: OliWeb,
      routes_backend: OliWeb.Pow.UserRoutes,
      extensions: [PowResetPassword, PowEmailConfirmation, PowPersistentSession, PowInvitation],
      controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
      messages_backend: OliWeb.Pow.Messages,
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
      # session_ttl_renewal: :timer.minutes(15),    # default is 15 minutes
      # default is 30 minutes
      credentials_cache_store: {Pow.Store.CredentialsCache, ttl: :timer.hours(24)},
      plug: Pow.Plug.Session,
      web_module: OliWeb,
      routes_backend: OliWeb.Pow.AuthorRoutes,
      extensions: [PowResetPassword, PowEmailConfirmation, PowPersistentSession, PowInvitation],
      controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
      cache_store_backend: Pow.Store.Backend.MnesiaCache,
      users_context: OliWeb.Pow.AuthorContext,
      messages_backend: OliWeb.Pow.Messages,
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

  def delete_pow_user(conn, type) do
    conn
    |> use_pow_config(type)
    |> Pow.Plug.delete()
    |> PowPersistentSession.Plug.delete()
  end

  def create_pow_user(conn, type, account) do
    conn
    |> use_pow_config(type)
    |> Pow.Plug.create(account)
    |> PowPersistentSession.Plug.create(account)
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
    providers = get_providers(conn)

    providers_length = length(providers)

    providers
    |> Enum.with_index(1)
    |> generate_provider_links(conn, providers_length, link_opts)
  end

  defp get_providers(conn) do
    available_providers = Plug.available_providers(conn)
    providers_for_user = Plug.providers_for_current_user(conn)

    available_providers
    |> Enum.map(&{&1, &1 in providers_for_user})
  end

  defp generate_provider_links(list_providers_with_index, conn, providers_length, link_opts) do
    list_providers_with_index
    |> Enum.map(fn
      {{provider, true}, index} ->
        deauthorization_link(conn, provider, providers_length == index, link_opts)

      {{provider, false}, index} ->
        authorization_link(conn, provider, providers_length == index, link_opts)
    end)
  end

  @doc """
  Generates an authorization link for a provider.
  The link is used to sign up or register a user using a provider. If
  `:invited_user` is assigned to the conn, the invitation token will be passed
  on through the URL query params.
  """
  def authorization_link(conn, provider, is_last_provider, opts \\ []) do
    opts = build_otps(opts, conn, provider)

    button_box = build_button_box(conn, provider)

    link = Link.link(button_box, opts)

    if is_last_provider do
      link
    else
      or_text =
        Tag.content_tag(:div, "OR", [{:data, [test: [or: "test-data"]]}, class: "text-center"])

      Tag.content_tag(:div, [link, Tag.tag(:br), or_text])
    end
  end

  defp build_button_box(conn, provider) do
    icon = provider_icon(provider)
    provider_name = provider_name(provider, downcase: true)
    msg_box = build_msg_box(conn, provider, provider_name)
    Tag.content_tag(:div, [icon, msg_box], class: provider_name <> "-auth-container")
  end

  defp build_msg_box(conn, provider, provider_name) do
    msg =
      AuthorizationController.extension_messages(conn).login_with_provider(%{
        conn
        | params: %{"provider" => provider}
      })

    Tag.content_tag(:div, msg, class: provider_name <> "-text-container")
  end

  defp build_otps(opts, conn, provider) do
    path = build_authentication_path(conn, provider)

    opts = Keyword.merge(opts, to: path)

    Keyword.merge(opts, class: "btn btn-md #{provider_class(provider)} btn-block social-signin")
  end

  defp build_authentication_path(conn, provider) do
    query_params = invitation_token_query_params(conn) ++ request_path_query_params(conn)

    AuthorizationController.routes(conn).path_for(
      conn,
      AuthorizationController,
      :new,
      [provider],
      query_params
    )
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
  @spec deauthorization_link(Conn.t(), atom(), boolean(), keyword()) :: HTML.safe()
  def deauthorization_link(conn, provider, is_last_provider, opts \\ []) do
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
    link = Link.link(button_box, opts)

    if is_last_provider do
      link
    else
      or_text = Tag.content_tag(:div, "OR", class: "text-center")

      Tag.content_tag(:div, [link, Tag.tag(:br), or_text])
    end
  end

  def provider_icon(provider) do
    case provider do
      :google ->
        HTML.raw(
          "<div class=\"w-[64px] #{provider_name(provider, downcase: true)}-icon-container\"><img class=\"#{provider_name(provider, downcase: true)}-icon\" src=\"/images/icons/google-icon.svg\"/></div>"
        )

      :github ->
        HTML.raw(
          "<div class=\"w-[64px] #{provider_name(provider, downcase: true)}-icon-container\"><i class=\"fab fa-github #{provider_name(provider, downcase: true)}-icon\"></i></div>"
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
