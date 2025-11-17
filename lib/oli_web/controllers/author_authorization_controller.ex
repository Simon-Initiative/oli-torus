defmodule OliWeb.AuthorAuthorizationController do
  use OliWeb, :controller

  import Ecto.Query, warn: false
  import OliWeb.AuthorAuth, only: [require_authenticated_author: 2]

  alias Phoenix.Naming
  alias Oli.Accounts
  alias Oli.AssentAuth.AuthorAssentAuth
  alias OliWeb.AuthorAuth
  alias OliWeb.Common.AssentAuthWeb

  require Logger

  plug :require_authenticated_author when action in [:delete]
  plug :load_assent_auth_config
  plug :assign_callback_url when action in [:new, :callback]
  plug :maybe_assign_user_return_to when action in [:callback]
  plug :load_session_params when action in [:callback]
  # plug :load_author_by_invitation_token when action in [:callback]

  def new(conn, %{"provider" => provider} = params) do
    config = conn.assigns.assent_auth_config

    # Store invitation token and project context for validation
    # The canonical invited email will be retrieved from the invitation token in the database.
    conn =
      conn
      |> maybe_store_invitation_token(params["invitation_token"])
      |> maybe_store_project_context(params["project"])

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

    case AssentAuthWeb.provider_callback(provider, params, conn.assigns.session_params, config) do
      # Authorization successful
      {:ok, %{user: user_params} = _response} ->
        # Retrieve and validate the canonical invited email from the invitation token (if present)
        # This prevents invitation email spoofing via URL parameters
        case load_and_validate_invitation_email(conn, user_params) do
          {:ok, conn} ->
            handle_validated_authorization(conn, provider, user_params, config, redirect_to)

          {:error, :email_mismatch, invited_email, sso_email} ->
            # Get the invitation token to redirect back to the invitation page
            invitation_redirect = get_invitation_redirect_path(conn)

            conn
            |> clear_invitation_session_data()
            |> put_flash(
              :error,
              "The email associated with your #{String.capitalize(provider)} account (#{sso_email}) does not match the invitation email (#{invited_email}). Please use the correct account or sign in with your password."
            )
            |> redirect(to: invitation_redirect || redirect_to)

          {:error, :invalid_token} ->
            invitation_redirect = get_invitation_redirect_path(conn)

            conn
            |> clear_invitation_session_data()
            |> put_flash(
              :error,
              "The invitation link is invalid or has expired."
            )
            |> redirect(to: invitation_redirect || redirect_to)
        end

      {:error, error} ->
        # Authorization failed
        Logger.error("Error requesting authorization URL: #{inspect(error)}")

        conn
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

      {:ok, status, conn} ->
        conn = AuthorAuth.maybe_link_user_author_account(conn, conn.assigns.current_author)

        # Check if this is from a collaborator invitation that needs to be accepted
        conn = maybe_accept_pending_invitation(conn, status)

        redirect(conn, to: redirect_to)

      {:email_confirmation_required, _status, conn} ->
        conn
        |> put_flash(
          :info,
          "Please confirm your email address to continue. A confirmation email has been sent."
        )
        |> redirect(to: ~p"/authors/confirm")

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
            # Check if this is an invitation scenario where we should link SSO to existing invited author
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
        get_session(conn, :from_invitation_link) ||
        not is_nil(conn.params["project"])

    email = user_params["email"]

    case {from_invitation, email} do
      {true, email} when is_binary(email) ->
        # Coming from invitation, try to link SSO to existing invited author
        case Accounts.get_author_by_email(email) do
          nil ->
            # Author doesn't exist, show standard error
            conn
            |> put_flash(
              :error,
              "An account associated with this email already exists. Please log in with your password or a different provider to continue."
            )
            |> redirect(to: redirect_to)

          author ->
            # Author exists, check if it's an invited author (no password set)
            is_invited = invited_author?(author)

            if is_invited do
              # Link SSO identity to invited author
              link_sso_to_invited_author(conn, author, provider, user_params, nil, redirect_to)
            else
              # Author has password, they need to log in with password first
              Logger.warning(
                "Author #{author.email} has password or identities, cannot auto-link SSO"
              )

              conn
              |> put_flash(
                :error,
                "An account associated with this email already exists. Please log in with your password or a different provider to continue."
              )
              |> redirect(to: redirect_to)
            end
        end

      _ ->
        # Not from invitation, show standard error
        conn
        |> put_flash(
          :error,
          "An account associated with this email already exists. Please log in with your password or a different provider to continue."
        )
        |> redirect(to: redirect_to)
    end
  end

  defp invited_author?(author) do
    # Invited authors have no password hash and no SSO identities
    author = Oli.Repo.preload(author, :user_identities)
    is_nil(author.password_hash) && Enum.empty?(author.user_identities)
  end

  defp link_sso_to_invited_author(conn, author, provider, user_params, _config, redirect_to) do
    # Extract user identity params
    case user_params do
      %{"sub" => uid} ->
        user_identity_params = %{"uid" => uid, "provider" => provider}
        project_slug = get_session(conn, :invitation_project_slug)

        # Build attrs from SSO params
        sso_attrs =
          %{
            "given_name" => user_params["given_name"],
            "family_name" => user_params["family_name"],
            "picture" => user_params["picture"]
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        # Add SSO identity and accept invitation
        with {:ok, _author_identity} <-
               Oli.AssentAuth.AuthorAssentAuth.add_identity_provider(
                 author,
                 user_identity_params
               ),
             {:ok, author} <- accept_invitation(author, project_slug, sso_attrs) do
          # Successfully linked SSO and accepted invitation

          conn = OliWeb.AuthorAuth.create_session(conn, author)
          conn = assign(conn, :current_author, author)
          conn = OliWeb.AuthorAuth.maybe_link_user_author_account(conn, author)
          # Clear all invitation session data to prevent interference with future logins
          conn = clear_invitation_session_data(conn)

          redirect(conn, to: redirect_to)
        else
          {:error, :author_project_not_found} ->
            Logger.error("Author project not found for collaborator invitation")

            conn
            |> put_flash(
              :error,
              "Unable to accept the invitation. The project may no longer exist."
            )
            |> redirect(to: redirect_to)

          {:error, changeset} ->
            Logger.error(
              "Failed to link SSO identity or accept invitation for invited author: #{inspect(author.email)}, error: #{inspect(changeset)}"
            )

            conn
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

  # Check if there's a pending collaborator invitation and accept it for existing authenticated authors
  defp maybe_accept_pending_invitation(conn, :authenticate) do
    # Only for authenticate status (existing SSO authors signing in)
    project_slug = get_session(conn, :invitation_project_slug)
    author = conn.assigns.current_author

    if project_slug && author do
      case Oli.Authoring.Course.get_author_project(project_slug, author.id,
             filter_by_status: false
           ) do
        nil ->
          Logger.warning("No author_project found for #{author.email} in project #{project_slug}")
          conn

        %{status: :accepted} = _author_project ->
          clear_invitation_session_data(conn)

        author_project ->
          case author_project
               |> Oli.Authoring.Authors.AuthorProject.changeset(%{status: :accepted})
               |> Oli.Repo.update() do
            {:ok, _} ->
              clear_invitation_session_data(conn)

            {:error, changeset} ->
              Logger.error("Failed to accept collaborator invitation: #{inspect(changeset)}")
              conn
          end
      end
    else
      conn
    end
  end

  defp maybe_accept_pending_invitation(conn, _status), do: conn

  # Accept author invitation via SSO - handles both general author invitations and collaborator invitations
  # For SSO, we skip password validation since the user authenticates via OAuth
  defp accept_invitation(author, project_slug, attrs) when is_binary(project_slug) do
    # This is a collaborator invitation - need to update author_project status
    case Oli.Authoring.Course.get_author_project(project_slug, author.id, filter_by_status: false) do
      nil ->
        {:error, :author_project_not_found}

      author_project ->
        accept_collaborator_invitation_sso(author, author_project, attrs)
    end
  end

  defp accept_invitation(author, _project_slug, attrs) do
    # General author invitation
    accept_author_invitation_sso(author, attrs)
  end

  # Accept author invitation for SSO users (no password validation)
  defp accept_author_invitation_sso(author, attrs) do
    now = Oli.DateTime.utc_now() |> DateTime.truncate(:second)

    author
    |> Ecto.Changeset.cast(attrs, [:given_name, :family_name, :picture])
    |> Ecto.Changeset.put_change(:invitation_accepted_at, now)
    |> Ecto.Changeset.put_change(:email_confirmed_at, now)
    |> Oli.Repo.update()
  end

  # Accept collaborator invitation for SSO users (no password validation)
  defp accept_collaborator_invitation_sso(author, author_project, attrs) do
    Oli.Repo.transaction(fn ->
      now = Oli.DateTime.utc_now() |> DateTime.truncate(:second)

      author =
        author
        |> Ecto.Changeset.cast(attrs, [:given_name, :family_name, :picture])
        |> Ecto.Changeset.put_change(:invitation_accepted_at, now)
        |> Ecto.Changeset.put_change(:email_confirmed_at, now)
        |> Oli.Repo.update!()

      author_project
      |> Oli.Authoring.Authors.AuthorProject.changeset(%{status: :accepted})
      |> Oli.Repo.update!()

      author
    end)
  end

  ## Plugs

  defp load_assent_auth_config(conn, _opts) do
    conn
    |> Plug.Conn.assign(
      :assent_auth_config,
      %AssentAuthWeb.Config{
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

  defp maybe_store_invitation_token(conn, nil) do
    # Clear stale invitation token when starting a new non-invitation flow
    conn
    |> delete_session(:invitation_token)
    |> delete_session(:validated_invitation_email)
  end

  defp maybe_store_invitation_token(conn, token) when is_binary(token) do
    put_session(conn, :invitation_token, token)
  end

  defp maybe_store_invitation_token(conn, _) do
    conn
    |> delete_session(:invitation_token)
    |> delete_session(:validated_invitation_email)
  end

  defp maybe_store_project_context(conn, nil), do: conn

  defp maybe_store_project_context(conn, project_slug) when is_binary(project_slug) do
    put_session(conn, :invitation_project_slug, project_slug)
  end

  defp maybe_store_project_context(conn, _), do: conn

  # Securely retrieve and validate the invitation email from the database
  # This prevents invitation email spoofing attacks by:
  # 1. Retrieving the canonical invited email from the invitation token (not from URL params)
  # 2. Validating the token exists and is not expired
  # 3. Comparing the SSO email with the invited email from the database
  defp load_and_validate_invitation_email(conn, user_params) do
    invitation_token = get_session(conn, :invitation_token)
    project_slug = get_session(conn, :invitation_project_slug)

    cond do
      # No invitation context - regular SSO login
      is_nil(invitation_token) && is_nil(project_slug) ->
        {:ok, conn}

      # Has invitation token - validate it and retrieve canonical email
      not is_nil(invitation_token) ->
        case retrieve_invited_email_from_token(invitation_token, project_slug) do
          {:ok, invited_email} ->
            # Now compare SSO email with the canonical invited email from database
            sso_email = normalize_email(user_params["email"])
            normalized_invited_email = normalize_email(invited_email)

            if sso_email == normalized_invited_email do
              # Store the validated email for use in invitation acceptance logic
              {:ok, put_session(conn, :validated_invitation_email, true)}
            else
              {:error, :email_mismatch, invited_email, user_params["email"]}
            end

          {:error, :invalid_token} ->
            {:error, :invalid_token}
        end

      # Has project slug but no token - invalid state
      true ->
        Logger.warning("Invitation context has project_slug but no invitation_token")
        {:error, :invalid_token}
    end
  end

  # Retrieve the canonical invited email from the invitation token in the database
  defp retrieve_invited_email_from_token(token, project_slug) do
    result =
      if project_slug do
        # Collaborator invitation
        Accounts.get_author_token_by_collaboration_invitation_token(token)
      else
        # General author invitation
        Accounts.get_author_token_by_author_invitation_token(token)
      end

    case result do
      %{author: author} when not is_nil(author) ->
        {:ok, author.email}

      nil ->
        Logger.warning("Invalid or expired invitation token")
        {:error, :invalid_token}
    end
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  # Get the invitation redirect path based on stored session data
  defp get_invitation_redirect_path(conn) do
    token = get_session(conn, :invitation_token)
    project_slug = get_session(conn, :invitation_project_slug)

    cond do
      token && project_slug ->
        # Collaborator invitation
        ~p"/collaborators/invite/#{token}"

      token ->
        # General author invitation
        ~p"/authors/invite/#{token}"

      true ->
        nil
    end
  end

  # Clear all invitation-related session data
  defp clear_invitation_session_data(conn) do
    conn
    |> delete_session(:invitation_token)
    |> delete_session(:invitation_project_slug)
    |> delete_session(:validated_invitation_email)
  end
end
