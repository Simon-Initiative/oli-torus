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
      :create_session,
      :deliver_user_confirmation_instructions,
      :get_user_by_provider_uid,
      :assent_auth_module
    ]

    defstruct [
      :authentication_providers,
      :redirect_uri,
      :current_user_assigns_key,
      :create_session,
      :deliver_user_confirmation_instructions,
      :get_user_by_provider_uid,
      :assent_auth_module
    ]

    @type t() :: %__MODULE__{
            authentication_providers: Keyword.t(),
            redirect_uri: (atom -> String.t()),
            current_user_assigns_key: atom() | nil,
            create_session: (Plug.Conn.t(), any() -> Plug.Conn.t()),
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
    |> build_user_identity_params(other_params, provider, conn)
    |> maybe_authenticate(config)
    |> maybe_upsert_user_identity(config)
    |> create_or_update_user(config)
    # Regardless of whether the user was just created or updated, we will send a confirmation
    # email if the user's email has not yet been confirmed.
    |> maybe_send_confirmation_email(config)
    |> case do
      %{private: %{assent_callback_state: {:ok, :email_confirmation_required}}} = conn ->
        {:email_confirmation_required, conn}

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

  defp build_user_identity_params(%{"sub" => uid} = user_params, other_params, provider, conn) do
    # Convert other_params keys to strings
    other_params = for {key, value} <- other_params, into: %{}, do: {Atom.to_string(key), value}

    # Merge user params with provider and other params
    user_identity_params =
      %{"uid" => uid}
      |> Map.put("provider", provider)
      |> Map.merge(other_params)

    conn
    |> Plug.Conn.put_private(:assent_callback_state, {:ok, :strategy})
    |> Plug.Conn.put_private(:assent_callback_params, %{
      user_identity: user_identity_params,
      user: user_params
    })
  end

  defp build_user_identity_params(user_params, _other_params, _provider, conn) do
    Logger.error("No sub found in user params: #{inspect(user_params)}")

    conn
    |> Plug.Conn.put_private(:assent_callback_state, {:error, :invalid_user_identity_params})
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

  ## Authenticates a user with provider and provider user params. If successful, a new
  ## session will be created and the current user will be put in the connection assigns.
  defp authenticate(conn, %{"provider" => provider, "uid" => uid}, config) do
    case get_user_by_provider_uid(provider, uid, config) do
      nil ->
        {:error, conn}

      user ->
        {:ok,
         conn
         |> create_session(user, config)
         |> assign_current_user(user, config)}
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

  defp maybe_upsert_user_identity(conn, _config), do: conn

  ## Will upsert identity for the current user. If successful, a new session will be created.
  defp upsert_identity(
         conn,
         user_identity_params,
         config
       ) do
    user = current_user(conn, config)

    user_identity_params = convert_params(user_identity_params)

    user
    |> assent_auth_module(config).upsert_identity(user_identity_params)
    |> user_identity_bound_different_user_error()
    |> case do
      {:ok, user_identity} ->
        {:ok, user_identity, create_session(conn, user, config)}

      {:error, error} ->
        {:error, error, conn}
    end
  end

  defp create_or_update_user(
         %{private: %{assent_callback_state: {:ok, _method}, assent_callback_params: params}} =
           conn,
         config
       ) do
    user_params = Map.fetch!(params, :user)
    user_identity_params = Map.fetch!(params, :user_identity)

    case current_user(conn, config) do
      nil ->
        conn
        |> create_user(user_identity_params, user_params, config)
        |> case do
          {:ok, user, conn} ->
            conn
            |> Plug.Conn.put_private(:assent_callback_state, {:ok, :create_user})
            |> create_session(user, config)
            |> assign_current_user(user, config)

          {:error, changeset, conn} ->
            conn
            |> Plug.Conn.put_private(:assent_callback_state, {:error, :create_user})
            |> Plug.Conn.put_private(:assent_callback_error, changeset)
        end

      user ->
        conn
        |> update_user(user, user_params, config)
        |> case do
          {:ok, user, conn} ->
            conn
            |> Plug.Conn.put_private(:assent_callback_state, {:ok, :update_user})
            |> create_session(user, config)
            |> assign_current_user(user, config)

          {:error, changeset, conn} ->
            conn
            |> Plug.Conn.put_private(:assent_callback_state, {:error, :update_user})
            |> Plug.Conn.put_private(:assent_callback_error, changeset)
        end
    end
  end

  defp create_or_update_user(conn, _config), do: conn

  ## Create a user with the provider and provider user params.
  defp create_user(conn, user_identity_params, user_params, config) do
    user_identity_params
    |> convert_params()
    |> assent_auth_module(config).create_user_with_identity(user_params)
    |> user_identity_bound_different_user_error()
    |> user_with_email_already_exists_error()
    |> case do
      {:ok, user} -> {:ok, user, create_session(conn, user, config)}
      {:error, error} -> {:error, error, conn}
    end
  end

  defp update_user(conn, user, user_params, config) do
    user
    |> assent_auth_module(config).update_user_details(user_params)
    |> case do
      {:ok, user} -> {:ok, user, create_session(conn, user, config)}
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

  defp maybe_send_confirmation_email(
         %{private: %{assent_callback_state: {:ok, _method}}} = conn,
         config
       ) do
    user = current_user(conn, config)

    if assent_auth_module(config).email_confirmed?(user) do
      conn
    else
      deliver_user_confirmation_instructions(user, config)

      conn
      |> Plug.Conn.put_private(:assent_callback_state, {:ok, :email_confirmation_required})
    end
  end

  defp maybe_send_confirmation_email(conn, _config), do: conn

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

  defp assign_current_user(conn, user, config) do
    key = current_user_assigns_key(config)

    Plug.Conn.assign(conn, key, user)
  end

  defp current_user_assigns_key(config) do
    Map.get(config, :current_user_assigns_key, :current_user)
  end

  defp create_session(conn, user, %AssentAuthWebConfig{
         create_session: create_session
       }) do
    create_session.(conn, user)
  end

  defp deliver_user_confirmation_instructions(user, config) do
    config.deliver_user_confirmation_instructions.(user)
  end

  defp get_user_by_provider_uid(provider, uid, config) do
    config.get_user_by_provider_uid.(provider, ensure_string(uid))
  end

  defp ensure_string(value) when is_binary(value), do: value
  defp ensure_string(value) when is_integer(value), do: Integer.to_string(value)

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

  defp user_identity_bound_different_user_error({:error, %{errors: errors} = changeset}) do
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
end
