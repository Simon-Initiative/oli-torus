defmodule OliWeb.InviteController do
  use OliWeb, :controller

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.UserToken
  alias Oli.Delivery.Sections
  alias Oli.{Email, Mailer}
  alias OliWeb.UserSessionController

  def index(conn, _params) do
    render_invite_page(conn, "index.html", title: "Invite")
  end

  def create(conn, %{"email" => email} = params) do
    g_recaptcha_response = Map.get(params, "g-recaptcha-response", "")

    case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
      {:success, true} ->
        invite_author(conn, email)

      {:success, false} ->
        conn
        |> put_flash(:error, "reCaptcha failed, please try again")
        |> redirect(to: Routes.invite_path(conn, :index))
    end
  end

  @doc """
  After a user accepts an intivation we log the user in and redirects him to the section.
  """
  def accept_user_invitation(conn, %{"email" => email, "section_slug" => section_slug} = params) do
    params =
      params
      |> put_in(["user", "email"], email)
      |> put_in(["user", "request_path"], ~p"/sections/#{section_slug}")

    UserSessionController.create(conn, params, flash_message: nil)
  end

  def create_bulk(conn, %{
        "emails" => emails,
        "role" => role,
        "section_slug" => section_slug,
        "inviter" => inviter
      }) do
    existing_users = Accounts.get_users_by_email(emails)
    non_found_users = emails -- Enum.map(existing_users, & &1.email)
    section = Sections.get_section_by_slug(section_slug)

    inviter_struct =
      if inviter == "author", do: conn.assigns.current_author, else: conn.assigns.current_user

    Ecto.Multi.new()
    |> Ecto.Multi.run(:new_users, fn _repo, _changes ->
      case Accounts.bulk_create_invited_users(non_found_users, inviter_struct) do
        {:error, reason} ->
          {:error, reason}

        {count, new_users} ->
          {:ok, {count, new_users}}
      end
    end)
    |> Ecto.Multi.run(:enrollments, fn _repo, %{new_users: {_, new_users}} ->
      do_section_enrollment(new_users ++ existing_users, section, role)
    end)
    |> Ecto.Multi.run(:email_data, fn _repo, %{new_users: {_, new_users}} ->
      bulk_create_invitation_tokens(new_users ++ existing_users, section_slug)
    end)
    |> Ecto.Multi.run(:send_invitations, fn _repo, %{email_data: email_data} ->
      case send_email_invitations(email_data, inviter_struct.name, role, section.title) do
        :ok ->
          {:ok, :ok}

        {:error, reason} ->
          {:error, reason}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Users were invited successfully")
        |> redirect(
          to:
            ~p"/sections/#{section_slug}/instructor_dashboard/overview/students?filter_by=pending_confirmation"
        )

      {:error, _} ->
        conn
        |> put_flash(:error, "An error occurred while inviting users")
        |> redirect(to: ~p"/sections/#{section_slug}/instructor_dashboard/overview/students")
    end
  end

  defp do_section_enrollment(users, section, role) do
    context_identifier = contextualize_role(role)
    context_role = ContextRoles.get_role(context_identifier)
    user_ids = Enum.map(users, & &1.id)

    Sections.enroll(user_ids, section.id, [context_role], :pending_confirmation)
  end

  defp bulk_create_invitation_tokens(users, section_slug) do
    now = Oli.DateTime.utc_now() |> DateTime.truncate(:second)

    %{email_data: email_data, user_tokens: user_tokens} =
      users
      |> Enum.reduce(%{email_data: [], user_tokens: []}, fn user, acc ->
        {non_hashed_token, user_token} =
          UserToken.build_email_token(user, "enrollment_invitation:#{section_slug}")

        user_token =
          %{
            user_id: user_token.user_id,
            token: user_token.token,
            context: user_token.context,
            sent_to: user_token.sent_to,
            inserted_at: now
          }

        %{
          acc
          | email_data: [
              %{sent_to: user_token.sent_to, token: non_hashed_token} | acc.email_data
            ],
            user_tokens: [user_token | acc.user_tokens]
        }
      end)

    {_count, _user_tokens} = Repo.insert_all(UserToken, user_tokens)

    {:ok, email_data}
  end

  defp send_email_invitations(email_data, inviter_name, role, section_title) do
    Enum.each(email_data, fn data ->
      Email.create_email(
        data.sent_to,
        "You were invited as #{if role == "instructor", do: "an instructor", else: "a student"} to \"#{section_title}\"",
        :enrollment_invitation,
        %{
          inviter: inviter_name,
          url:
            OliWeb.Router.Helpers.users_invite_path(
              OliWeb.Endpoint,
              OliWeb.Users.Invitations.UsersInviteView,
              data.token
            ),
          role: role,
          section_title: section_title,
          button_label: "Go to invitation"
        }
      )
      |> Mailer.deliver()
    end)
  end

  defp contextualize_role("instructor"), do: :context_instructor
  defp contextualize_role(_role), do: :context_learner

  defp render_invite_page(conn, page, keywords) do
    render(conn, page, Keyword.put_new(keywords, :active, :invite))
  end

  defp invite_author(conn, email) do
    with {:ok, author} <- get_or_create_invited_author(conn, email),
         {:ok, _mail} <- deliver_invitation_email(conn, author) do
      conn
      |> put_flash(:info, "Author invitation sent successfully.")
      |> redirect(to: Routes.invite_path(conn, :index))
    else
      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't invite #{email}. #{message}")
        |> redirect(to: Routes.invite_path(conn, :index))
    end
  end

  defp get_or_create_invited_author(conn, email) do
    Accounts.get_author_by_email(email)
    |> case do
      nil ->
        case create_user(conn, %{email: email}) do
          {:ok, user, _conn} -> {:ok, user}
          {:error, _changeset, _conn} -> {:error, "Unable to create invitation for new author"}
        end

      author ->
        if not is_nil(author.invitation_token) and is_nil(author.invitation_accepted_at) do
          {:error, "User has a pending invitation already"}
        else
          {:error, "User is already an author"}
        end
    end
  end

  defp deliver_invitation_email(_conn, _user) do
    # TODO: MER-4068
    throw("NOT IMPLEMENTED")
  end

  defp create_user(_conn, _params) do
    # TODO: MER-4068
    throw("NOT IMPLEMENTED")
  end
end
