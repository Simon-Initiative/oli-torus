defmodule OliWeb.CollaboratorController do
  use OliWeb, :controller

  import Oli.Utils

  alias Oli.Authoring.Collaborators

  require Logger

  @max_invitation_emails 20

  def create(
        conn,
        %{
          "collaborator_emails" => collaborator_emails,
          "authors" => authors_emails
        } = params
      ) do
    project_id = conn.params["project_id"]
    g_recaptcha_response = Map.get(params, "g-recaptcha-response", "")

    case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
      {:success, true} ->
        all_emails =
          collaborator_emails
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(fn e -> e != "" end)

        {valid_emails, invalid_emails} = Enum.split_with(all_emails, &Oli.Utils.validate_email/1)

        authors =
          authors_emails
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(fn e -> e != "" end)

        is_collaborator? =
          Enum.all?(valid_emails, fn elem ->
            Enum.member?(authors, elem)
          end)

        case is_collaborator? do
          true ->
            conn
            |> put_flash(
              :error,
              if(Enum.count(valid_emails) > 1,
                do: "These people are already collaborators in this project.",
                else: "This person is already a collaborator in this project."
              )
            )
            |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")

          false ->
            if Enum.count(valid_emails) > @max_invitation_emails do
              conn
              |> put_flash(
                :error,
                "Collaborator invitations cannot exceed #{@max_invitation_emails} emails at a time. Please try again with fewer invites"
              )
              |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
            else
              valid_emails
              |> Enum.reduce({conn, []}, fn email, {conn, failures} ->
                invite_collaborator(conn, email, project_id, failures)
              end)
              |> case do
                {conn, []} ->
                  if !Enum.empty?(invalid_emails) do
                    log_error(
                      "Failed to invite some collaborators due to invalid email(s)",
                      invalid_emails
                    )

                    conn
                    |> put_flash(
                      :error,
                      "Failed to invite some collaborators due to invalid email(s): #{Enum.join(invalid_emails, ", ")}"
                    )
                    |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
                  else
                    conn
                    |> put_flash(:info, "Collaborator invitations sent!")
                    |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
                  end

                {conn, failures} ->
                  if Enum.count(failures) == Enum.count(valid_emails) do
                    log_error("Failed to invite collaborators", failures)

                    conn
                    |> put_flash(:error, "Failed to invite collaborators")
                    |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
                  else
                    failed_emails = Enum.map(failures, fn {email, _msg} -> email end)

                    invalid_email_msg =
                      if Enum.empty?(invalid_emails) do
                        ""
                      else
                        " Invalid email(s): #{Enum.join(invalid_emails, ", ")}"
                      end

                    log_error(
                      "Failed to invite some collaborators: #{Enum.join(failed_emails, ", ")}" <>
                        invalid_email_msg,
                      failures
                    )

                    conn
                    |> put_flash(
                      :error,
                      "Failed to invite some collaborators: #{Enum.join(failed_emails, ", ")}" <>
                        invalid_email_msg
                    )
                    |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
                  end
              end
            end
        end

      {:success, false} ->
        conn
        |> put_flash(:error, "reCaptcha failed, please try again")
        |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
    end
  end

  def update(_conn, %{"author" => _author}) do
    # For later use -> change author role within project
  end

  def delete(conn, %{"project_id" => project_slug, "author_email" => author_email}) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:author, fn _repo, _changes ->
      case Oli.Accounts.get_author_by_email(author_email) do
        nil -> {:error, "Author not found"}
        author -> {:ok, author}
      end
    end)
    |> Ecto.Multi.run(:remove_author_from_project, fn _repo, _changes ->
      Collaborators.remove_collaborator(author_email, project_slug)
    end)
    |> Ecto.Multi.run(:remove_invitation, fn _repo, %{author: author} ->
      case author.password_hash do
        nil ->
          # the author was invited but still did not accept the invitation
          # We then delete the author and the correponding author_token will be deleted automatically (on delete cascade)
          Oli.Accounts.delete_author(author)

        _some_hashed_password ->
          # the author is already a member of Torus
          # so we must manually delete the author_token created when the invitation was sent

          Oli.Accounts.AuthorToken.author_and_contexts_query(
            author,
            ["collaborator_invitation:#{project_slug}"]
          )
          |> Oli.Repo.one()
          |> case do
            nil ->
              {:ok, "Author token already deleted"}

            author_token ->
              Oli.Repo.delete(author_token)
          end
      end
    end)
    |> Oli.Repo.transaction()
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Author removed from project")
        |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/overview")

      _ ->
        conn
        |> put_flash(:error, "We couldn't remove that author from the project.")
        |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/overview")
    end
  end

  defp invite_collaborator(conn, email, project_id, failures) do
    case Collaborators.invite_collaborator(conn.assigns.current_author.name, email, project_id) do
      {:ok, _results} ->
        {conn, failures}

      {:error, message} ->
        {conn, [{email, message} | failures]}
    end
  end
end
