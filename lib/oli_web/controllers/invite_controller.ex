defmodule OliWeb.InviteController do
  use OliWeb, :controller

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts
  alias Oli.Delivery.Sections

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
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

  def create_bulk(conn, %{
        "emails" => emails,
        "role" => role,
        "section_slug" => section_slug,
        "inviter" => inviter
      }) do
    existing_users = Oli.Accounts.get_users_by_email(emails)
    non_found_users = emails -- Enum.map(existing_users, & &1.email)
    section = Sections.get_section_by_slug(section_slug)

    inviter_struct =
      if inviter == "author", do: conn.assigns.current_author, else: conn.assigns.current_user

    # Enroll users
    Oli.Repo.transaction(fn ->
      {_count, new_users} = Oli.Accounts.bulk_invite_users(non_found_users, inviter_struct)

      users_ids = Enum.map(new_users ++ existing_users, & &1.id)
      do_section_enrollment(users_ids, section, role)

      # Send emails to users
      users =
        Enum.map(existing_users, &Map.put(&1, :status, :existing_user)) ++
          Enum.map(new_users, &Map.put(&1, :status, :new_user))

      Enum.map(users, fn user ->
        {button_label, url} =
          case user.status do
            :new_user ->
              token = PowInvitation.Plug.sign_invitation_token(conn, user)
              {"Join now", Routes.delivery_pow_invitation_invitation_path(conn, :edit, token)}

            :existing_user ->
              {"Go to the course", ~p"/sections/#{section.slug}"}
          end

        Oli.Email.invitation_email(user.email, :enrollment_invitation, %{
          inviter: inviter_struct.name,
          url: Routes.url(conn) <> url,
          role: role,
          section_title: section.title,
          button_label: button_label
        })
        |> Oli.Mailer.deliver_now()
      end)
    end)

    redirect_after_enrollment(conn, section_slug)
  end

  defp do_section_enrollment(users_ids, section, role) do
    context_identifier = contextualize_role(role)
    context_role = ContextRoles.get_role(context_identifier)
    Sections.enroll(users_ids, section.id, [context_role])
  end

  defp contextualize_role("instructor"), do: :context_instructor
  defp contextualize_role(_role), do: :context_learner

  defp redirect_after_enrollment(conn, section_slug) do
    path =
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
        section_slug,
        :reports,
        :students
      )

    conn
    |> put_flash(:info, "Users were enrolled successfully")
    |> redirect(to: path)
  end

  defp render_invite_page(conn, page, keywords) do
    render(conn, page, Keyword.put_new(keywords, :active, :invite))
  end

  defp invite_author(conn, email) do
    with {:ok, author} <- get_or_invite_author(conn, email),
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

  defp get_or_invite_author(conn, email) do
    Accounts.get_author_by_email(email)
    |> case do
      nil ->
        case PowInvitation.Plug.create_user(conn, %{email: email}) do
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

  defp deliver_invitation_email(conn, user) do
    invited_by = Pow.Plug.current_user(conn)
    token = PowInvitation.Plug.sign_invitation_token(conn, user)
    url = Routes.pow_invitation_invitation_path(conn, :edit, token)

    invited_by_user_id = Map.get(invited_by, invited_by.__struct__.pow_user_id_field())

    email =
      Oli.Email.invitation_email(
        user.email,
        :author_invitation,
        %{
          invited_by: invited_by,
          invited_by_user_id: invited_by_user_id,
          url: Routes.url(conn) <> url
        }
      )

    Oli.Mailer.deliver_now(email)
    {:ok, "email sent"}
  end
end
