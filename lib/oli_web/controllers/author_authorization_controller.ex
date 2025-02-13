defmodule OliWeb.AuthorAuthorizationController do
  use OliWeb, :controller

  import Ecto.Query, warn: false
  import OliWeb.AuthorAuth, only: [require_authenticated_author: 2]

  alias Phoenix.Naming
  alias Oli.Accounts
  alias Oli.AssentAuth.AuthorAssentAuth
  alias OliWeb.AuthorAuth
  alias OliWeb.Common.AssentAuthWeb
  alias OliWeb.Common.AssentAuthWeb.AssentAuthWebConfig

  require Logger

  plug :require_authenticated_author when action in [:delete]
  plug :load_assent_auth_config
  plug :assign_callback_url when action in [:new, :callback]
  plug :maybe_assign_user_return_to when action in [:callback]
  plug :load_session_params when action in [:callback]
  # plug :load_author_by_invitation_token when action in [:callback]

  def new(conn, %{"provider" => provider} = params) do
    config = conn.assigns.assent_auth_config

    provider
    |> AssentAuthWeb.authorize_url(config)
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        # Session params (used for OAuth 2.0 and OIDC strategies) will be
        # retrieved when author returns for the callback phase
        conn
        |> store_session_params(session_params)
        |> maybe_store_user_return_to()
        |> AuthorAuth.maybe_store_link_account_user_id(params)
        # Redirect end-user to provider to authorize access to their account
        |> redirect(external: url)

      {:error, error} ->
        # Something went wrong generating the request authorization url
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: ~p"/authors/log_in")
    end
  end

  def delete(conn, %{"provider" => provider} = params) do
    config = conn.assigns.assent_auth_config
    user_return_to = params["user_return_to"] || ~p"/authors/settings"

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
          "Authentication cannot be removed until you've entered a password for your account."
        )
        |> redirect(to: user_return_to)
    end
  end

  def callback(conn, %{"provider" => provider} = params) do
    config = conn.assigns.assent_auth_config

    # The session params (used for OAuth 2.0 and OIDC strategies) stored in the
    # request phase will be used in the callback phase

    redirect_to = conn.assigns[:user_return_to] || ~p"/authors/log_in"

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
            |> AuthorAuth.maybe_link_user_author_account(conn.assigns.current_author)
            |> redirect(to: redirect_to)

          {:email_confirmation_required, conn} ->
            conn
            |> put_flash(
              :info,
              "Please confirm your email address to continue. A confirmation email has been sent."
            )
            |> redirect(to: ~p"/authors/confirm")

          {:error, conn, error} ->
            Logger.error("Error handling authorization success: #{inspect(error)}")

            case error do
              {:upsert_user_identity, {:bound_to_different_user, _changeset}} ->
                conn
                |> put_flash(
                  :error,
                  "The #{Naming.humanize(conn.params["provider"])} account is already bound to another user."
                )
                |> redirect(to: redirect_to)

              {:create_user, {:email_already_exists, _}} ->
                conn
                |> put_flash(
                  :error,
                  "An account associated with this email already exists. Please log in with your password or a different provider to continue."
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
        authentication_providers: AuthorAssentAuth.authentication_providers(),
        redirect_uri: fn provider -> ~p"/authors/auth/#{provider}/callback" end,
        current_user_assigns_key: :current_author,
        get_user_by_provider_uid: &AuthorAssentAuth.get_user_by_provider_uid(&1, &2),
        create_session: &AuthorAuth.create_session(&1, &2),
        deliver_user_confirmation_instructions: fn user ->
          Accounts.deliver_author_confirmation_instructions(
            user,
            &url(~p"/authors/confirm/#{&1}")
          )
        end,
        assent_auth_module: AuthorAssentAuth
      }
    )
  end

  defp assign_callback_url(conn, _opts) do
    url = ~p"/authors/auth/#{conn.params["provider"]}/callback"

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
