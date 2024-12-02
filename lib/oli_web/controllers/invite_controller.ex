defmodule OliWeb.InviteController do
  use OliWeb, :controller

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Delivery.Sections

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

    # Enroll users
    Repo.transaction(fn ->
      {_count, new_users} =
        Accounts.bulk_create_invited_users(non_found_users, inviter_struct)

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
              {"Join now",
               ~p"/users/register?#{[section: section.slug, from_invitation_link?: true]}"}

            :existing_user ->
              {"Go to the course", ~p"/sections/#{section.slug}?#{[from_invitation_link?: true]}"}
          end

        Email.create_email(
          user.email,
          "You were invited as #{if role == "instructor", do: "an instructor", else: "a student"} to \"#{section.title}\"",
          :enrollment_invitation,
          %{
            inviter: inviter_struct.name,
            url: url,
            role: role,
            section_title: section.title,
            button_label: button_label
          }
        )
        |> Mailer.deliver()
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
        :overview,
        :students
      )

    conn
    |> put_flash(:info, "Users were enrolled successfully")
    |> redirect(to: path)
  end
end
