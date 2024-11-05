defmodule OliWeb.UserAuthorizationController do
  alias OliWeb.UserAuth
  use OliWeb, :controller

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Plug.Conn
  alias Assent.Config
  alias Oli.UserIdentities.UserIdentity
  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Repo

  require Logger

  def new(conn, %{"provider" => provider}) do
    provider
    |> authorize_url()
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        # Session params (used for OAuth 2.0 and OIDC strategies) will be
        # retrieved when user returns for the callback phase
        conn = put_session(conn, :session_params, session_params)

        # Redirect end-user to provider to authorize access to their account
        conn
        |> put_resp_header("location", url)
        |> send_resp(302, "")

      {:error, error} ->
        # Something went wrong generating the request authorization url
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, %{"provider" => provider}) do
    case delete_user_identity_provider(conn.assigns.current_user, provider) do
      {:ok, _} ->
        conn
        |> put_flash(
          :info,
          "Successfully removed #{String.capitalize(provider)} authentication provider."
        )
        |> redirect(to: ~p"/users/settings")

      {:error, {:no_password, _changeset}} ->
        conn
        |> put_flash(
          :error,
          "You must have a password or another provider set up to remove this authentication provider."
        )
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  def callback(conn, %{"provider" => provider} = params) do
    # The session params (used for OAuth 2.0 and OIDC strategies) stored in the
    # request phase will be used in the callback phase
    session_params = get_session(conn, :session_params)

    provider
    |> provider_callback(params, session_params)
    |> case do
      {:ok, %{user: user} = response} ->
        # Authorization successful
        other_params =
          response
          |> Map.delete(:user)
          |> Map.put(:userinfo, user)

        case handle_authorization_success(conn, provider, user, other_params) do
          {:ok, conn} ->
            conn

          {:error, conn} ->
            Logger.error("Error handling authorization success")

            conn
            |> put_flash(:error, "Something went wrong. Please try again or contact support.")
            |> redirect(to: ~p"/users/log_in")
        end

      {:error, error} ->
        # Authorization failed
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def authorize_url(provider) do
    config = config!(provider)

    config[:strategy].authorize_url(config)
  end

  def provider_callback(provider, params, session_params) do
    config = config!(provider)

    config
    |> Assent.Config.put(:session_params, session_params)
    |> config[:strategy].callback(params)
  end

  defp config!(provider) do
    provider_config_key =
      provider
      |> String.to_existing_atom()

    config =
      Application.get_env(:oli, :user_auth_providers)[provider_config_key] ||
        raise "No provider configuration for #{provider}"

    Config.put(
      config,
      :redirect_uri,
      url(OliWeb.Endpoint, ~p"/auth/#{provider}/callback")
    )
  end

  defp handle_authorization_success(conn, provider, user, other_params) do
    user
    |> normalize_username()
    |> split_user_identity_params()
    |> handle_user_identity_params(other_params, provider)
    |> put_private_callback_state(conn)
    |> maybe_authenticate()
    |> maybe_upsert_user_identity()
    |> maybe_create_user()
    |> case do
      %{private: %{assent_callback_state: {:ok, :create_user}}} = conn ->
        conn
        |> maybe_trigger_registration_email_confirmation()
        |> (&{:ok, &1}).()

      %{private: %{assent_callback_state: {:ok, _method}}} = conn ->
        {:ok, conn}

      conn ->
        {:error, conn}
    end
  end

  defp normalize_username(%{"preferred_username" => username} = params) do
    params
    |> Map.delete("preferred_username")
    |> Map.put("username", username)
  end

  defp normalize_username(params), do: params

  defp split_user_identity_params(%{"sub" => uid} = params) do
    {%{"uid" => uid}, params}
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
    |> Conn.put_private(:assent_callback_state, {:ok, :strategy})
    |> Conn.put_private(:assent_callback_params, %{
      user_identity: user_identity_params,
      user: user_params
    })
  end

  defp maybe_authenticate(
         %{private: %{assent_callback_state: {:ok, :strategy}, assent_callback_params: params}} =
           conn
       ) do
    user_identity_params = Map.fetch!(params, :user_identity)

    case conn.assigns[:current_user] do
      nil ->
        case authenticate(conn, user_identity_params) do
          {:ok, conn} -> conn
          {:error, conn} -> conn
        end

      _user ->
        conn
    end
  end

  defp maybe_authenticate(conn), do: conn

  @doc """
  Authenticates a user with provider and provider user params.

  If successful, a new session will be created.
  """
  def authenticate(conn, %{"provider" => provider, "uid" => uid}) do
    case get_user_by_provider_uid(provider, uid) do
      nil -> {:error, conn}
      user -> {:ok, UserAuth.log_in_user(conn, user)}
    end
  end

  defp maybe_upsert_user_identity(
         %{private: %{assent_callback_state: {:ok, :strategy}, assent_callback_params: params}} =
           conn
       ) do
    user_identity_params = Map.fetch!(params, :user_identity)

    case conn.assigns[:current_user] do
      nil ->
        conn

      _user ->
        conn
        |> upsert_identity(user_identity_params)
        |> case do
          {:ok, _user_identity, conn} ->
            Conn.put_private(conn, :assent_callback_state, {:ok, :upsert_user_identity})

          {:error, changeset, conn} ->
            conn
            |> Conn.put_private(:assent_callback_state, {:error, :upsert_user_identity})
            |> Conn.put_private(:assent_callback_error, changeset)
        end
    end
  end

  @doc """
  Will upsert identity for the current user.

  If successful, a new session will be created.
  """
  def upsert_identity(conn, user_identity_params) do
    user = conn.assigns[:current_user]

    user
    |> upsert(user_identity_params)
    |> case do
      {:ok, user_identity} ->
        {:ok, user_identity, UserAuth.log_in_user(conn, user)}

      {:error, error} ->
        {:error, error, conn}
    end
  end

  @doc """
  Upserts a user identity.

  If a matching user identity already exists for the user, the identity will be updated,
  otherwise a new identity is inserted.
  """
  def upsert(user, user_identity_params) do
    params = convert_params(user_identity_params)
    {uid_provider_params, additional_params} = Map.split(params, ["uid", "provider"])

    get_user_identity(uid_provider_params["provider"], uid_provider_params["uid"])
    |> case do
      nil -> insert_identity(user, params)
      identity -> update_identity(identity, additional_params)
    end
    |> user_identity_bound_different_user_error()
  end

  defp user_identity_bound_different_user_error({:error, %{errors: errors} = changeset}) do
    case unique_constraint_error?(errors, :uid_provider) do
      true -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end

  defp user_identity_bound_different_user_error(any), do: any

  defp insert_identity(user, user_identity_params) do
    user_identity = Ecto.build_assoc(user, :user_identities)

    user_identity
    |> user_identity.__struct__.changeset(user_identity_params)
    |> Repo.insert()
  end

  defp update_identity(user_identity, additional_params) do
    user_identity
    |> user_identity.__struct__.changeset(additional_params)
    |> Repo.insert()
  end

  defp maybe_create_user(conn), do: maybe_create_user(conn.assigns[:current_user], conn)

  defp maybe_create_user(nil, %{private: %{assent_registration: false}} = conn) do
    conn
    |> Conn.put_private(:assent_callback_state, {:error, :create_user})
    |> Conn.put_private(:assent_callback_error, nil)
  end

  defp maybe_create_user(
         nil,
         %{private: %{assent_callback_state: {:ok, :strategy}, assent_callback_params: params}} =
           conn
       ) do
    user_params = Map.fetch!(params, :user)
    user_identity_params = Map.fetch!(params, :user_identity)

    conn
    |> create_user(user_identity_params, user_params)
    |> case do
      {:ok, _user, conn} ->
        Conn.put_private(conn, :assent_callback_state, {:ok, :create_user})

      {:error, changeset, conn} ->
        conn
        |> Conn.put_private(:assent_callback_state, {:error, :create_user})
        |> Conn.put_private(:assent_callback_error, changeset)
    end
  end

  defp maybe_create_user(_user, conn), do: conn

  @doc """
  Create a user with the provider and provider user params.

  If successful, a new session will be created. After session has been created
  the callbacks stored with `put_create_session_callback/2` will run.
  """
  def create_user(conn, user_identity_params, user_params) do
    user_identity_params
    |> create_user_with_identity(user_params)
    |> case do
      {:ok, user} -> {:ok, user, UserAuth.log_in_user(conn, user)}
      {:error, error} -> {:error, error, conn}
    end
  end

  @doc """
  Creates a user with user identity.

  User schema module and repo module will be fetched from config.
  """
  def create_user_with_identity(user_identity_params, user_params) do
    params = convert_params(user_identity_params)

    %User{}
    |> User.user_identity_changeset(params, user_params)
    |> Repo.insert()
    |> user_user_identity_bound_different_user_error()
  end

  @doc """
  Gets a user by identity provider and uid.
  """
  def get_user_by_provider_uid(provider, uid) do
    from(user in User,
      join: user_identity in assoc(user, :user_identities),
      where: user_identity.provider == ^provider and user_identity.uid == ^uid
    )
    |> Repo.one()
  end

  @doc """
  Gets a user identity by provider and uid.
  """
  def get_user_identity(provider, uid) do
    from(u in UserIdentity,
      where: u.provider == ^provider and u.uid == ^uid
    )
    |> Repo.one()
  end

  def get_user_with_identities(user_id) do
    from(user in User,
      where: user.id == ^user_id,
      preload: [:user_identities]
    )
    |> Repo.one()
  end

  @doc """
  Deletes a user identity for the provider and user.
  """
  def delete_user_identity_provider(user, provider) do
    user = get_user_with_identities(user.id)

    user.user_identities
    |> Enum.split_with(&(&1.provider == provider))
    |> maybe_delete_identity_providers(user)
  end

  defp maybe_delete_identity_providers(
         {user_identities, rest},
         %{password_hash: password_hash}
       )
       when length(rest) > 0 or not is_nil(password_hash) do
    results =
      from(uid in UserIdentity,
        where: uid.id in ^Enum.map(user_identities, & &1.id)
      )
      |> Repo.delete_all()

    {:ok, results}
  end

  defp maybe_delete_identity_providers(_any, user) do
    changeset =
      user
      |> Changeset.change()
      |> Changeset.validate_required(:password_hash)

    {:error, {:no_password, changeset}}
  end

  defp maybe_trigger_registration_email_confirmation(conn) do
    %{user: user} = conn.private[:pow_assent_callback_params]

    if email_verified?(user) do
      conn
    else
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )

      conn
    end
  end

  ### Utility functions

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

  defp user_user_identity_bound_different_user_error(
         {:error, %{changes: %{user_identities: [%{errors: errors}]}} = changeset}
       ) do
    case unique_constraint_error?(errors, :uid_provider) do
      true -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end

  defp user_user_identity_bound_different_user_error(any), do: any

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
