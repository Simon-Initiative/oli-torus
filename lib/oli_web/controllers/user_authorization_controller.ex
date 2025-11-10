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

  def new(conn, %{"provider" => provider} = params) do
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

    # Store section and invitation context for post-auth handling
    conn =
      conn
      |> maybe_store_section_context(params["section"])
      |> maybe_store_invitation_context(params["from_invitation_link?"])
      |> maybe_store_invitation_email(params["invitation_email"])
      |> maybe_store_invitation_token(params["invitation_token"])

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
    redirect_to = determine_redirect_path(conn)

    case AssentAuthWeb.provider_callback(provider, params, conn.assigns.session_params, config) do
      # Authorization successful
      {:ok, %{user: user_params} = _response} ->
        # Validate email match if coming from invitation
        case validate_invitation_email(conn, user_params) do
          {:ok, conn} ->
            handle_validated_authorization(conn, provider, user_params, config, redirect_to)

          {:error, :email_mismatch, invited_email, sso_email} ->
            # Get the invitation token to redirect back to the invitation page
            invitation_redirect = get_invitation_redirect_path(conn)

            conn
            |> clear_enrollment_session_data()
            |> put_flash(
              :error,
              "The email associated with your #{String.capitalize(provider)} account (#{sso_email}) does not match the invitation email (#{invited_email}). Please use the correct account or sign in with your password."
            )
            |> redirect(to: invitation_redirect || redirect_to)
        end

      {:error, error} ->
        # Authorization failed
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
        |> clear_enrollment_session_data()
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: redirect_to)
    end
  end

  defp handle_validated_authorization(conn, provider, user_params, config, redirect_to) do
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
        |> clear_enrollment_session_data()
        |> redirect(to: redirect_to)

      {:email_confirmation_required, _status, conn} ->
        conn
        |> clear_enrollment_session_data()
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
            # Check if this is an invitation scenario where we should link SSO to existing invited user
            handle_invitation_sso_link(conn, provider, user_params, config, redirect_to)

          _ ->
            conn
            |> put_flash(:error, "Something went wrong. Please try again or contact support.")
            |> redirect(to: redirect_to)
        end
    end
  end

  defp handle_invitation_sso_link(conn, provider, user_params, _config, redirect_to) do
    # Check if we validated an invitation email (which means this is from an invitation)
    from_invitation =
      get_session(conn, :validated_invitation_email) ||
        get_session(conn, :from_invitation_link)

    email = user_params["email"]

    Logger.info(
      "SSO invitation linking check - from_invitation: #{inspect(from_invitation)}, email: #{inspect(email)}"
    )

    case {from_invitation, email} do
      {true, email} when is_binary(email) ->
        # Coming from invitation, try to link SSO to existing invited user
        case Accounts.get_user_by(email: email) do
          nil ->
            # User doesn't exist, show standard error
            conn
            |> put_flash(
              :error,
              "An account associated with this email already exists. Please log in with your password to continue."
            )
            |> redirect(to: redirect_to)

          user ->
            # User exists, check if it's an invited user (no password set)
            is_invited = invited_user?(user)

            Logger.info(
              "User found - invited: #{inspect(is_invited)}, has password: #{inspect(!is_nil(user.password_hash))}"
            )

            if is_invited do
              # Link SSO identity to invited user
              Logger.info("Linking SSO identity to invited user: #{user.email}")
              link_sso_to_invited_user(conn, user, provider, user_params, nil, redirect_to)
            else
              # User has password, they need to log in with password first
              Logger.warning(
                "User #{user.email} has password or identities, cannot auto-link SSO"
              )

              conn
              |> put_flash(
                :error,
                "An account associated with this email already exists. Please log in with your password to continue."
              )
              |> redirect(to: redirect_to)
            end
        end

      _ ->
        # Not from invitation, show standard error
        conn
        |> put_flash(
          :error,
          "An account associated with this email already exists. Please log in with your password to continue."
        )
        |> redirect(to: redirect_to)
    end
  end

  defp invited_user?(user) do
    # Invited users have no password hash and may have SSO identities
    user = Oli.Repo.preload(user, :user_identities)
    is_nil(user.password_hash) && Enum.empty?(user.user_identities)
  end

  defp link_sso_to_invited_user(conn, user, provider, user_params, _config, redirect_to) do
    # Extract user identity params
    case user_params do
      %{"sub" => uid} ->
        user_identity_params = %{"uid" => uid, "provider" => provider}
        section_slug = get_session(conn, :pending_section_enrollment)

        # Build attrs from SSO params
        sso_attrs =
          %{
            "given_name" => user_params["given_name"],
            "family_name" => user_params["family_name"],
            "picture" => user_params["picture"]
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        # Add SSO identity and accept invitation if there's a pending enrollment
        with {:ok, _user_identity} <-
               Oli.AssentAuth.UserAssentAuth.add_identity_provider(
                 user,
                 user_identity_params
               ),
             {:ok, user} <- accept_user_invitation(user, section_slug, sso_attrs) do
          # Successfully linked SSO and accepted invitation
          Logger.info("Successfully linked SSO and accepted invitation for user: #{user.email}")

          conn = OliWeb.UserAuth.create_session(conn, user)
          conn = assign(conn, :current_user, user)

          conn
          |> clear_enrollment_session_data()
          |> redirect(to: redirect_to)
        else
          {:error, :enrollment_not_found} ->
            Logger.error("Enrollment not found for user invitation")

            conn
            |> clear_enrollment_session_data()
            |> put_flash(
              :error,
              "Unable to accept the invitation. The section may no longer exist."
            )
            |> redirect(to: redirect_to)

          {:error, changeset} ->
            Logger.error(
              "Failed to link SSO identity or accept invitation for invited user: #{inspect(user.email)}, error: #{inspect(changeset)}"
            )

            conn
            |> clear_enrollment_session_data()
            |> put_flash(
              :error,
              "Unable to link your #{String.capitalize(provider)} account. Please try again or contact support."
            )
            |> redirect(to: redirect_to)
        end

      _ ->
        Logger.error("Missing 'sub' in SSO user params: #{inspect(user_params)}")

        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support.")
        |> redirect(to: redirect_to)
    end
  end

  # Accept user invitation - handles enrollment if section_slug is provided
  # Accept user invitation via SSO
  # For SSO, we skip password validation since the user authenticates via OAuth
  defp accept_user_invitation(user, section_slug, attrs) when is_binary(section_slug) do
    # This is a section invitation - need to update enrollment status
    case Oli.Delivery.Sections.get_enrollment(section_slug, user.id, filter_by_status: false) do
      nil ->
        {:error, :enrollment_not_found}

      enrollment ->
        accept_user_invitation_sso(user, enrollment, attrs)
    end
  end

  defp accept_user_invitation(user, _section_slug, attrs) do
    # No section enrollment, just update user timestamps
    accept_user_invitation_sso(user, nil, attrs)
  end

  # Accept user invitation for SSO users (no password validation)
  defp accept_user_invitation_sso(user, enrollment, attrs) do
    Oli.Repo.transaction(fn ->
      now = Oli.DateTime.utc_now() |> DateTime.truncate(:second)

      user =
        user
        |> Ecto.Changeset.cast(attrs, [:given_name, :family_name, :picture])
        |> Ecto.Changeset.put_change(:invitation_accepted_at, now)
        |> Ecto.Changeset.put_change(:email_confirmed_at, now)
        |> Oli.Repo.update!()

      if enrollment do
        enrollment
        |> Oli.Delivery.Sections.Enrollment.changeset(%{status: :enrolled})
        |> Oli.Repo.update!()
      end

      user
    end)
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

  defp maybe_store_section_context(conn, nil), do: conn

  defp maybe_store_section_context(conn, section) when is_binary(section) do
    put_session(conn, :pending_section_enrollment, section)
  end

  defp maybe_store_invitation_context(conn, nil), do: conn

  defp maybe_store_invitation_context(conn, "true") do
    put_session(conn, :from_invitation_link, true)
  end

  defp maybe_store_invitation_context(conn, _), do: conn

  defp maybe_store_invitation_email(conn, nil), do: conn

  defp maybe_store_invitation_email(conn, email) when is_binary(email) do
    put_session(conn, :invitation_email, email)
  end

  defp maybe_store_invitation_email(conn, _), do: conn

  defp maybe_store_invitation_token(conn, nil), do: conn

  defp maybe_store_invitation_token(conn, token) when is_binary(token) do
    put_session(conn, :invitation_token, token)
  end

  defp maybe_store_invitation_token(conn, _), do: conn

  defp validate_invitation_email(conn, user_params) do
    case get_session(conn, :invitation_email) do
      nil ->
        # Not from invitation, no validation needed
        {:ok, conn}

      invited_email ->
        sso_email = normalize_email(user_params["email"])
        normalized_invited_email = normalize_email(invited_email)

        conn = delete_session(conn, :invitation_email)

        if sso_email == normalized_invited_email do
          # Mark that we validated an invitation email for use in error handling
          {:ok, put_session(conn, :validated_invitation_email, true)}
        else
          {:error, :email_mismatch, invited_email, user_params["email"]}
        end
    end
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  defp clear_enrollment_session_data(conn) do
    conn
    |> delete_session(:pending_section_enrollment)
    |> delete_session(:from_invitation_link)
    |> delete_session(:validated_invitation_email)
    |> delete_session(:invitation_email)
    |> delete_session(:invitation_token)
  end

  # Get the invitation redirect path based on stored session data
  defp get_invitation_redirect_path(conn) do
    token = get_session(conn, :invitation_token)

    if token do
      ~p"/users/invite/#{token}"
    else
      nil
    end
  end

  defp determine_redirect_path(conn) do
    cond do
      # Check if there's a pending section enrollment
      section_slug = get_session(conn, :pending_section_enrollment) ->
        from_invitation = get_session(conn, :from_invitation_link)

        if from_invitation do
          ~p"/sections/#{section_slug}/enroll"
        else
          ~p"/sections/#{section_slug}"
        end

      # Fall back to normal user_return_to behavior
      user_return_to = conn.assigns[:user_return_to] ->
        user_return_to

      # Default fallback
      true ->
        ~p"/users/log_in"
    end
  end
end
