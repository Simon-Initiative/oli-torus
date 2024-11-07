defmodule OliWeb.Common.AssentAuthWeb do
  use OliWeb, :verified_routes

  alias OliWeb.Common.AssentAuthWeb.AssentAuthWebConfig

  defmodule AssentAuthWebConfig do
    @moduledoc """
    Configuration required for AssentAuthWeb module.
    """
    @enforce_keys [
      :authentication_providers,
      :redirect_uri,
      :log_in_user,
      :deliver_user_confirmation_instructions,
      :get_user_by_provider_uid,
      :assent_auth_module
    ]

    defstruct [
      :authentication_providers,
      :redirect_uri,
      :current_user_assigns_key,
      :log_in_user,
      :deliver_user_confirmation_instructions,
      :get_user_by_provider_uid,
      :assent_auth_module
    ]

    @type t() :: %__MODULE__{
            authentication_providers: Keyword.t(),
            redirect_uri: (atom -> String.t()),
            current_user_assigns_key: Atom.t() | nil,
            log_in_user: (Plug.Conn.t(), any() -> Plug.Conn.t()),
            deliver_user_confirmation_instructions: (any() -> any()),
            get_user_by_provider_uid: (String.t(), String.t() -> any()),
            assent_auth_module: module()
          }
  end

  @doc """
  Returns the authorization URL for the given provider.
  """
  def authorize_url(provider, config) do
    provider_config = provider_config!(provider, config)

    provider_config[:strategy].authorize_url(provider_config)
  end

  @doc """
  Handles the provider callback.
  """
  def provider_callback(provider, params, session_params, config) do
    provider_config = provider_config!(provider, config)

    provider_config
    |> Assent.Config.put(:session_params, session_params)
    |> provider_config[:strategy].callback(params)
  end

  @doc """
  Handles the a successful authorization after the provider callback.
  """
  def handle_authorization_success(conn, provider, user, other_params, config) do
    user
    |> normalize_username()
    |> split_user_identity_params()
    |> handle_user_identity_params(other_params, provider)
    |> put_private_callback_state(conn)
    |> maybe_authenticate(config)
    |> maybe_upsert_user_identity(config)
    |> maybe_create_user(config)
    |> case do
      %{private: %{assent_callback_state: {:ok, :create_user}}} = conn ->
        conn
        |> maybe_trigger_registration_email_confirmation(config)
        |> (&{:ok, &1}).()

      %{private: %{assent_callback_state: {:ok, _method}}} = conn ->
        {:ok, conn}

      %{private: %{assent_callback_state: {:error, error}, assent_callback_error: changeset}} =
          conn ->
        {:error, conn, {error, changeset}}

      conn ->
        {:error, conn, :unknown}
    end
  end

  defp normalize_username(%{"preferred_username" => username} = params) do
    params
    |> Map.delete("preferred_username")
    |> Map.put("username", username)
  end

  defp normalize_username(params), do: params

  defp split_user_identity_params(%{"sub" => uid} = params) do
    # users might have multiple login providers, so we need to remove the sub key
    # so that it doesn't get used as the sub identifier for the user. A unique
    # sub identifier will be generated for the user on creation.
    user_params = Map.delete(params, "sub")

    {%{"uid" => uid}, user_params}
  end

  defp handle_user_identity_params(
         {user_identity_params, user_params},
         other_params,
         provider
       ) do
    user_identity_params = Map.put(user_identity_params, "provider", provider)
    other_params = for {key, value} <- other_params, into: %{}, do: {Atom.to_string(key), value}

    user_identity_params =
      user_identity_params
      |> Map.put("provider", provider)
      |> Map.merge(other_params)

    {user_identity_params, user_params}
  end

  defp put_private_callback_state({user_identity_params, user_params}, conn) do
    conn
    |> Plug.Conn.put_private(:assent_callback_state, {:ok, :strategy})
    |> Plug.Conn.put_private(:assent_callback_params, %{
      user_identity: user_identity_params,
      user: user_params
    })
  end

  defp maybe_authenticate(
         %{private: %{assent_callback_state: {:ok, :strategy}, assent_callback_params: params}} =
           conn,
         config
       ) do
    user_identity_params = Map.fetch!(params, :user_identity)

    case current_user(conn, config) do
      nil ->
        case authenticate(conn, user_identity_params, config) do
          {:ok, conn} -> conn
          {:error, conn} -> conn
        end

      _user ->
        conn
    end
  end

  defp maybe_authenticate(conn, _config), do: conn

  ## Authenticates a user with provider and provider user params. If successful, a new session will be created.
  defp authenticate(conn, %{"provider" => provider, "uid" => uid}, config) do
    case get_user_by_provider_uid(provider, uid, config) do
      nil -> {:error, conn}
      user -> {:ok, log_in_user(conn, user, config)}
    end
  end

  defp maybe_upsert_user_identity(
         %{private: %{assent_callback_state: {:ok, :strategy}, assent_callback_params: params}} =
           conn,
         config
       ) do
    user_identity_params = Map.fetch!(params, :user_identity)

    case current_user(conn, config) do
      nil ->
        conn

      _user ->
        conn
        |> upsert_identity(user_identity_params, config)
        |> case do
          {:ok, _user_identity, conn} ->
            Plug.Conn.put_private(conn, :assent_callback_state, {:ok, :upsert_user_identity})

          {:error, changeset, conn} ->
            conn
            |> Plug.Conn.put_private(:assent_callback_state, {:error, :upsert_user_identity})
            |> Plug.Conn.put_private(:assent_callback_error, changeset)
        end
    end
  end

  ## Will upsert identity for the current user. If successful, a new session will be created.
  defp upsert_identity(
         conn,
         user_identity_params,
         config
       ) do
    user = current_user(conn, config)

    user_identity_params = convert_params(user_identity_params)

    user
    |> assent_auth_module(config).upsert(user_identity_params)
    |> user_identity_bound_different_user_error()
    |> case do
      {:ok, user_identity} ->
        {:ok, user_identity, log_in_user(conn, user, config)}

      {:error, error} ->
        {:error, error, conn}
    end
  end

  defp maybe_create_user(conn, config),
    do: maybe_create_user(current_user(conn, config), conn, config)

  defp maybe_create_user(
         nil,
         %{private: %{assent_callback_state: {:ok, :strategy}, assent_callback_params: params}} =
           conn,
         config
       ) do
    user_params = Map.fetch!(params, :user)
    user_identity_params = Map.fetch!(params, :user_identity)

    conn
    |> create_user(user_identity_params, user_params, config)
    |> case do
      {:ok, _user, conn} ->
        Plug.Conn.put_private(conn, :assent_callback_state, {:ok, :create_user})

      {:error, changeset, conn} ->
        conn
        |> Plug.Conn.put_private(:assent_callback_state, {:error, :create_user})
        |> Plug.Conn.put_private(:assent_callback_error, changeset)
    end
  end

  defp maybe_create_user(_user, conn, _config), do: conn

  ## Create a user with the provider and provider user params.
  defp create_user(conn, user_identity_params, user_params, config) do
    user_identity_params
    |> convert_params()
    |> assent_auth_module(config).create_user_with_identity(user_params)
    |> user_identity_bound_different_user_error()
    |> user_with_email_already_exists_error()
    |> case do
      {:ok, user} -> {:ok, user, log_in_user(conn, user, config)}
      {:error, error} -> {:error, error, conn}
    end
  end

  @doc """
  Removes the identity provider from the current user.
  """
  def delete_user_identity_provider(
        conn,
        provider,
        config
      ) do
    user =
      current_user(conn, config).id
      |> assent_auth_module(config).get_user_with_identities()

    user.user_identities
    |> Enum.split_with(&(&1.provider == provider))
    |> assent_auth_module(config).delete_identity_providers(user)
  end

  defp maybe_trigger_registration_email_confirmation(conn, config) do
    %{user: user} = conn.private[:assent_callback_params]

    if email_verified?(user) do
      conn
    else
      deliver_user_confirmation_instructions(user, config)

      conn
    end
  end

  defp user_identity_bound_different_user_error({:error, %{errors: errors} = changeset}) do
    case unique_constraint_error?(errors, :uid_provider) do
      true -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end

  defp user_identity_bound_different_user_error(any), do: any

  ### Utility functions

  defp provider_config!(provider, config) do
    provider = ensure_atom_key(provider)

    config.authentication_providers()
    |> Keyword.get(provider)
    |> Assent.Config.put(
      :redirect_uri,
      unverified_url(OliWeb.Endpoint, redirect_uri(provider, config))
    )
  end

  defp ensure_atom_key(provider) when is_atom(provider), do: provider
  defp ensure_atom_key(provider) when is_binary(provider), do: String.to_existing_atom(provider)

  defp redirect_uri(provider, config) do
    config.redirect_uri.(provider)
  end

  defp current_user(%{assigns: assigns}, config) do
    key = current_user_assigns_key(config)

    Map.get(assigns, key)
  end

  def assign_current_user(conn, user, config) do
    key = current_user_assigns_key(config)

    Plug.Conn.assign(conn, key, user)
  end

  defp current_user_assigns_key(config) do
    Map.get(config, :current_user_assigns_key, :current_user)
  end

  defp log_in_user(conn, user, %AssentAuthWebConfig{
         log_in_user: log_in_user
       }) do
    log_in_user.(conn, user)
  end

  defp deliver_user_confirmation_instructions(user, config) do
    config.deliver_user_confirmation_instructions.(user)
  end

  defp get_user_by_provider_uid(provider, uid, config) do
    config.get_user_by_provider_uid.(provider, uid)
  end

  defp assent_auth_module(config) do
    config.assent_auth_module
  end

  defp convert_params(params) when is_map(params) do
    params
    |> Enum.map(&convert_param/1)
    |> :maps.from_list()
  end

  defp convert_param({:uid, value}), do: convert_param({"uid", value})

  defp convert_param({"uid", value}) when is_integer(value),
    do: convert_param({"uid", Integer.to_string(value)})

  defp convert_param({key, value}) when is_atom(key), do: {Atom.to_string(key), value}
  defp convert_param({key, value}) when is_binary(key), do: {key, value}

  defp user_identity_bound_different_user_error(
         {:error, %{changes: %{user_identities: [%{errors: errors}]}} = changeset}
       ) do
    case unique_constraint_error?(errors, :uid_provider) do
      true -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end

  defp user_identity_bound_different_user_error(any), do: any

  defp user_with_email_already_exists_error({:error, %{errors: errors} = changeset}) do
    case unique_constraint_error?(errors, :email) do
      true -> {:error, {:email_already_exists, changeset}}
      false -> {:error, changeset}
    end
  end

  defp user_with_email_already_exists_error(any), do: any

  defp unique_constraint_error?(errors, field) do
    Enum.find_value(errors, false, fn
      {^field, {_msg, [constraint: :unique, constraint_name: _name]}} -> true
      _any -> false
    end)
  end

  defp email_verified?(%{"email_verified" => true}), do: true
  defp email_verified?(%{email_verified: true}), do: true
  defp email_verified?(_params), do: false
end
