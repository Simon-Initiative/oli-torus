defmodule OliWeb.UserAuthorizationController do
  alias OliWeb.UserAuth
  use OliWeb, :controller

  import Ecto.Query, warn: false
  import OliWeb.UserAuth, only: [require_authenticated_user: 2]

  alias Plug.Conn
  alias Assent.Config
  alias Oli.AssentAuth
  alias Oli.Accounts
  alias OliWeb.UserAuth

  require Logger

  @private_session_key :assent_session

  plug :require_authenticated_user when action in [:delete]
  plug :assign_callback_url when action in [:new, :callback]
  plug :init_session when action in [:new, :callback]
  plug :maybe_assign_user_return_to when action in [:callback]
  plug :load_session_params when action in [:callback]
  plug :set_registration_option when action in [:callback]
  # plug :load_user_by_invitation_token when action in [:callback]

  def new(conn, %{"provider" => provider}) do
    provider
    |> authorize_url()
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        # Session params (used for OAuth 2.0 and OIDC strategies) will be
        # retrieved when user returns for the callback phase
        conn
        |> store_session_params(session_params)
        |> maybe_store_user_return_to()
        # Redirect end-user to provider to authorize access to their account
        |> redirect(external: url)

      {:error, error} ->
        # Something went wrong generating the request authorization url
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, %{"provider" => provider} = params) do
    user_return_to = params["user_return_to"] || ~p"/users/settings"

    case delete_user_identity_provider(conn.assigns.current_user, provider) do
      {:ok, _} ->
        conn
        |> put_flash(
          :info,
          "Successfully removed #{String.capitalize(provider)} authentication provider."
        )
        |> redirect(to: user_return_to)

      {:error, {:no_password, _changeset}} ->
        conn
        |> put_flash(
          :error,
          "You must have a password or another provider set up to remove this authentication provider."
        )
        |> redirect(to: user_return_to)
    end
  end

  def callback(conn, %{"provider" => provider} = params) do
    # The session params (used for OAuth 2.0 and OIDC strategies) stored in the
    # request phase will be used in the callback phase

    redirect_to = conn.assigns[:user_return_to] || ~p"/users/log_in"

    provider
    |> provider_callback(params, conn.assigns.session_params)
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
            |> redirect(to: redirect_to)
        end

      {:error, error} ->
        # Authorization failed
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: redirect_to)
    end
  end

  ## Plugs

  defp assign_callback_url(conn, _opts) do
    url = ~p"/auth/#{conn.params["provider"]}/callback"

    assign(conn, :callback_url, url)
  end

  defp init_session(conn, _opts) do
    value = Map.get(conn.private, @private_session_key, default_value(conn))

    conn
    |> Conn.put_private(@private_session_key, value)
  end

  defp default_value(%{private: %{@private_session_key => session}}), do: session
  defp default_value(_conn), do: %{}

  defp maybe_assign_user_return_to(conn, _opts) do
    case get_session(conn, :user_return_to) do
      nil ->
        conn

      user_return_to ->
        conn
        |> delete_session(:user_return_to)
        |> Conn.assign(:user_return_to, user_return_to)
    end
  end

  defp load_session_params(conn, _opts) do
    session_params = get_session(conn, :session_params)

    conn
    |> delete_session(:session_params)
    |> Conn.assign(:session_params, session_params)
  end

  defp set_registration_option(%{private: %{assent_registration: _any}} = conn, _opts), do: conn

  defp set_registration_option(conn, _opts),
    do: Conn.put_private(conn, :assent_registration, ~p"/users/register")

  defp store_session_params(conn, session_params),
    do: put_session(conn, :session_params, session_params)

  defp maybe_store_user_return_to(%{params: %{"user_return_to" => user_return_to}} = conn),
    do: put_session(conn, :user_return_to, user_return_to)

  defp maybe_store_user_return_to(conn), do: conn

  ## Functions

  defp authorize_url(provider) do
    config = config!(provider)

    config[:strategy].authorize_url(config)
  end

  defp provider_callback(provider, params, session_params) do
    config = config!(provider)

    config
    |> Assent.Config.put(:session_params, session_params)
    |> config[:strategy].callback(params)
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

  ## Authenticates a user with provider and provider user params. If successful, a new session will be created.
  defp authenticate(conn, %{"provider" => provider, "uid" => uid}) do
    case AssentAuth.get_user_by_provider_uid(provider, uid) do
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

  ## Will upsert identity for the current user. If successful, a new session will be created.
  defp upsert_identity(conn, user_identity_params) do
    user = conn.assigns[:current_user]

    user_identity_params = convert_params(user_identity_params)

    user
    |> AssentAuth.upsert(user_identity_params)
    |> user_identity_bound_different_user_error()
    |> case do
      {:ok, user_identity} ->
        {:ok, user_identity, UserAuth.log_in_user(conn, user)}

      {:error, error} ->
        {:error, error, conn}
    end
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

  ## Create a user with the provider and provider user params.
  defp create_user(conn, user_identity_params, user_params) do
    user_identity_params
    |> convert_params()
    |> AssentAuth.create_user_with_identity(user_params)
    |> user_user_identity_bound_different_user_error()
    |> case do
      {:ok, user} -> {:ok, user, UserAuth.log_in_user(conn, user)}
      {:error, error} -> {:error, error, conn}
    end
  end

  defp delete_user_identity_provider(user, provider) do
    user = AssentAuth.get_user_with_identities(user.id)

    user.user_identities
    |> Enum.split_with(&(&1.provider == provider))
    |> AssentAuth.delete_identity_providers(user)
  end

  defp maybe_trigger_registration_email_confirmation(conn) do
    %{user: user} = conn.private[:assent_callback_params]

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

  defp user_identity_bound_different_user_error({:error, %{errors: errors} = changeset}) do
    case unique_constraint_error?(errors, :uid_provider) do
      true -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end

  defp user_identity_bound_different_user_error(any), do: any

  ### Utility functions

  defp config!(provider) do
    provider
    |> String.to_existing_atom()
    |> AssentAuth.provider_config!()
    |> Config.put(
      :redirect_uri,
      url(OliWeb.Endpoint, ~p"/auth/#{provider}/callback")
    )
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
