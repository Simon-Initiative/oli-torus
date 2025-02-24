defmodule OliWeb.UserAuthorizationController do
  use OliWeb, :controller

  import Ecto.Query, warn: false
  import OliWeb.UserAuth, only: [require_authenticated_user: 2]

  alias Phoenix.Naming
  alias Oli.Accounts
  alias Oli.AssentAuth.UserAssentAuth
  alias OliWeb.UserAuth
  alias OliWeb.Common.AssentAuthWeb

  require Logger

  plug :require_authenticated_user when action in [:delete]
  plug :load_assent_auth_config
  plug :assign_callback_url when action in [:new, :callback]
  plug :maybe_assign_user_return_to when action in [:callback]
  plug :load_session_params when action in [:callback]
  # plug :load_user_by_invitation_token when action in [:callback]

  def new(conn, %{"provider" => provider}) do
    config = conn.assigns.assent_auth_config

    conn =
      case List.keyfind(conn.req_headers, "referer", 0) do
        {"referer", referer} ->
          if String.ends_with?(referer, "/instructors/log_in") do
            conn
            |> put_session(:user_return_to, ~p"/instructors/log_in")
          else
            conn
          end

        nil ->
          conn
      end

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
          "Authentication cannot be removed until you've entered a password for your account."
        )
        |> redirect(to: user_return_to)
    end
  end

  def callback(conn, %{"provider" => provider} = params) do
    config = conn.assigns.assent_auth_config

    # The session params (used for OAuth 2.0 and OIDC strategies) stored in the
    # request phase will be used in the callback phase
    redirect_to = conn.assigns[:user_return_to] || ~p"/users/log_in"

    case AssentAuthWeb.provider_callback(provider, params, conn.assigns.session_params, config) do
      # Authorization successful
      {:ok, %{user: user_params} = _response} ->
        case AssentAuthWeb.handle_authorization_success(
               conn,
               provider,
               user_params,
               config
             ) do
          {:ok, :add_identity_provider, conn} ->
            conn
            |> put_flash(
              :info,
              "Successfully added #{String.capitalize(provider)} authentication provider."
            )
            |> redirect(to: redirect_to)

          {:ok, _status, conn} ->
            conn
            |> redirect(to: redirect_to)

          {:email_confirmation_required, _status, conn} ->
            conn
            |> put_flash(
              :info,
              "Please confirm your email address to continue. A confirmation email has been sent."
            )
            |> redirect(to: ~p"/users/confirm")

          {:error, error, conn} ->
            Logger.error("Error handling authorization success: #{inspect(error)}")

            case error do
              {:add_identity_provider, {:bound_to_different_user, _changeset}} ->
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
      %AssentAuthWeb.Config{
        authentication_providers: UserAssentAuth.authentication_providers(),
        redirect_uri: fn provider -> ~p"/users/auth/#{provider}/callback" end,
        current_user_assigns_key: :current_user,
        get_user_by_provider_uid: &UserAssentAuth.get_user_by_provider_uid(&1, &2),
        create_session: &UserAuth.create_session(&1, &2),
        deliver_user_confirmation_instructions: fn user ->
          Accounts.deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
        end,
        assent_auth_module: UserAssentAuth
      }
    )
  end

  defp assign_callback_url(conn, _opts) do
    url = ~p"/users/auth/#{conn.params["provider"]}/callback"

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
