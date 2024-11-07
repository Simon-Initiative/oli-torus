defmodule OliWeb.UserAuthorizationController do
  use OliWeb, :controller

  import Ecto.Query, warn: false
  import OliWeb.UserAuth, only: [require_authenticated_user: 2]

  alias Oli.Accounts
  alias Oli.AssentAuth.UserAssentAuth
  alias OliWeb.UserAuth
  alias OliWeb.Common.AssentAuthWeb
  alias OliWeb.Common.AssentAuthWeb.AssentAuthWebConfig

  require Logger

  plug :require_authenticated_user when action in [:delete]
  plug :load_assent_auth_config
  plug :assign_callback_url when action in [:new, :callback]
  plug :maybe_assign_user_return_to when action in [:callback]
  plug :load_session_params when action in [:callback]
  # plug :load_user_by_invitation_token when action in [:callback]

  def new(conn, %{"provider" => provider}) do
    config = conn.assigns.assent_auth_config

    provider
    |> AssentAuthWeb.authorize_url(config)
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
    config = conn.assigns.assent_auth_config
    user_return_to = params["user_return_to"] || ~p"/users/settings"

    case AssentAuthWeb.delete_user_identity_provider(conn, provider, config) do
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
    config = conn.assigns.assent_auth_config

    # The session params (used for OAuth 2.0 and OIDC strategies) stored in the
    # request phase will be used in the callback phase

    redirect_to = conn.assigns[:user_return_to] || ~p"/users/log_in"

    provider
    |> AssentAuthWeb.provider_callback(params, conn.assigns.session_params, config)
    |> case do
      {:ok, %{user: user} = response} ->
        # Authorization successful
        other_params =
          response
          |> Map.delete(:user)
          |> Map.put(:userinfo, user)

        case AssentAuthWeb.handle_authorization_success(
               conn,
               provider,
               user,
               other_params,
               config
             ) do
          {:ok, conn} ->
            conn

          {:error, conn, error} ->
            Logger.error("Error handling authorization success: #{inspect(error)}")

            case error do
              {:create_user, {:email_already_exists, _}} ->
                conn
                |> put_flash(
                  :error,
                  "An account associated with this email already exists. Please log in with your password to continue."
                )
                |> redirect(to: redirect_to)

              _ ->
                conn
                |> put_flash(:error, "Something went wrong. Please try again or contact support.")
                |> redirect(to: redirect_to)
            end
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

  defp load_assent_auth_config(conn, _opts) do
    conn
    |> Plug.Conn.assign(
      :assent_auth_config,
      %AssentAuthWebConfig{
        authentication_providers: UserAssentAuth.authentication_providers(),
        redirect_uri: fn provider -> ~p"/auth/#{provider}/callback" end,
        current_user_assigns_key: :current_user,
        get_user_by_provider_uid: &UserAssentAuth.get_user_by_provider_uid(&1, &2),
        log_in_user: &UserAuth.log_in_user(&1, &2),
        deliver_user_confirmation_instructions: fn user ->
          Accounts.deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
        end,
        assent_auth_module: UserAssentAuth
      }
    )
  end

  defp assign_callback_url(conn, _opts) do
    url = ~p"/auth/#{conn.params["provider"]}/callback"

    assign(conn, :callback_url, url)
  end

  defp maybe_assign_user_return_to(conn, _opts) do
    case get_session(conn, :user_return_to) do
      nil ->
        conn

      user_return_to ->
        conn
        |> delete_session(:user_return_to)
        |> Plug.Conn.assign(:user_return_to, user_return_to)
    end
  end

  defp load_session_params(conn, _opts) do
    session_params = get_session(conn, :session_params)

    conn
    |> delete_session(:session_params)
    |> Plug.Conn.assign(:session_params, session_params)
  end

  defp store_session_params(conn, session_params),
    do: put_session(conn, :session_params, session_params)

  defp maybe_store_user_return_to(%{params: %{"user_return_to" => user_return_to}} = conn),
    do: put_session(conn, :user_return_to, user_return_to)

  defp maybe_store_user_return_to(conn), do: conn
end
