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
        emails =
          collaborator_emails
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(fn e -> e != "" end)

        authors =
          authors_emails
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(fn e -> e != "" end)

        is_collaborator? =
          Enum.all?(emails, fn elem ->
            Enum.member?(authors, elem)
          end)

        case is_collaborator? do
          true ->
            conn
            |> put_flash(
              :error,
              if(Enum.count(emails) > 1,
                do: "These people are already collaborators in this project.",
                else: "This person is already a collaborator in this project."
              )
            )
            |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")

          false ->
            if Enum.count(emails) > @max_invitation_emails do
              conn
              |> put_flash(
                :error,
                "Collaborator invitations cannot exceed #{@max_invitation_emails} emails at a time. Please try again with fewer invites"
              )
              |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
            else
              emails
              |> Enum.reduce({conn, []}, fn email, {conn, failures} ->
                add_collaborator(conn, email, project_id, failures)
              end)
              |> case do
                {conn, []} ->
                  conn
                  |> put_flash(:info, "Collaborator invitations sent!")
                  |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")

                {conn, failures} ->
                  if Enum.count(failures) == Enum.count(emails) do
                    log_error("Failed to add collaborators", failures)

                    conn
                    |> put_flash(:error, "Failed to add collaborators")
                    |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
                  else
                    failed_emails = Enum.map(failures, fn {email, _msg} -> email end)

                    log_error(
                      "Failed to add some collaborators: #{Enum.join(failed_emails, ", ")}",
                      failures
                    )

                    conn
                    |> put_flash(
                      :error,
                      "Failed to add some collaborators: #{Enum.join(failed_emails, ", ")}"
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

  def delete(conn, %{"project_id" => project_id, "author_email" => author_email}) do
    case Collaborators.remove_collaborator(author_email, project_id) do
      {:ok, _} ->
        redirect(conn, to: ~p"/workspaces/course_author/#{project_id}/overview")

      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't remove that author from the project. #{message}")
        |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
    end
  end

  defp add_collaborator(conn, email, project_id, failures) do
    case Collaborators.add_collaborator(conn, email, project_id) do
      {:ok, _results} ->
        {conn, failures}

      {:error, message} ->
        {conn, [{email, message} | failures]}
    end
  end
end
