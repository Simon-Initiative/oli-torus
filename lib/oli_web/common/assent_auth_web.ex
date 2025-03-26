defmodule OliWeb.Common.AssentAuthWeb do
  use OliWeb, :verified_routes

  alias OliWeb.Common.AssentAuthWeb

  defmodule Config do
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
  def handle_authorization_success(conn, provider, user_params, config) do
    with user_params <- normalize_username(user_params),
         # Split the user params into user identity params and user params
         {:ok, user_identity_params} <-
           split_user_identity_params(user_params, provider),
         # Get the current user from the connection
         current_user <- current_user(conn, config),
         # Create or add new user identity
         {:ok, {status, user}} <-
           create_or_add_identity(current_user, user_identity_params, user_params, config),
         # Check if email confirmation is required
         {:ok, email_confirmation_required?} <-
           maybe_require_email_confirmation(user, config),
         # Create a session for the user
         conn <- create_session(conn, user, config),
         conn <- assign_current_user(conn, user, config) do
      if email_confirmation_required? do
        {:email_confirmation_required, status, conn}
      else
        {:ok, status, conn}
      end
    else
      {:error, error} ->
        {:error, error, conn}
    end
  end

  defp normalize_username(%{"preferred_username" => username} = params) do
    params
    |> Map.delete("preferred_username")
    |> Map.put("username", username)
  end

  defp normalize_username(params), do: params

  defp split_user_identity_params(%{"sub" => uid} = _user_params, provider) do
    user_identity_params = %{"uid" => uid, "provider" => provider}

    {:ok, user_identity_params}
  end

  defp split_user_identity_params(params, _provider) do
    {:error, {:invalid_user_identity_params, {:missing_param, "sub", params}}}
  end

  defp create_or_add_identity(
         current_user,
         user_identity_params,
         user_params,
         config
       ) do
    case {current_user, get_existing_user(user_identity_params, config)} do
      # no current user and no user with the same provider and uid, create a new user
      {nil, nil} ->
        create_user(user_identity_params, user_params, config)

      # no current user and user with the same provider and uid exists, just log in the user
      {nil, user} ->
        {:ok, {:authenticate, user}}

      # no user with the same provider and uid, add the identity for the current user
      {current_user, _user} ->
        add_identity_provider(current_user, user_identity_params, config)
    end
  end

  defp get_existing_user(%{"provider" => provider, "uid" => uid}, config) do
    get_user_by_provider_uid(provider, uid, config)
  end

  ## Create a user with the provider and provider user params.
  defp create_user(user_identity_params, user_params, config) do
    user_identity_params
    |> convert_params()
    |> assent_auth_module(config).create_user_with_identity(user_params)
    |> user_identity_bound_different_user_error()
    |> user_with_email_already_exists_error()
    |> case do
      {:ok, user} ->
        {:ok, {:create_user, user}}

      {:error, changeset} ->
        {:error, {:create_user, changeset}}
    end
  end

  ## Upserts a user identity for the current user. If successful, a new session will be created.
  defp add_identity_provider(
         user,
         user_identity_params,
         config
       ) do
    user_identity_params = convert_params(user_identity_params)

    user
    |> assent_auth_module(config).add_identity_provider(user_identity_params)
    |> user_identity_bound_different_user_error()
    |> case do
      {:ok, _user_identity} ->
        {:ok, {:add_identity_provider, user}}

      {:error, changeset} ->
        {:error, {:add_identity_provider, changeset}}
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

  defp maybe_require_email_confirmation(
         user,
         config
       ) do
    if assent_auth_module(config).email_confirmed?(user) do
      {:ok, false}
    else
      deliver_user_confirmation_instructions(user, config)

      {:ok, true}
    end
  end

  ### Utility functions

  defp provider_config!(provider, config) do
    provider = ensure_atom_key(provider)

    config.authentication_providers
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

  defp create_session(conn, user, %AssentAuthWeb.Config{
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
