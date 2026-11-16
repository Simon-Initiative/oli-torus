defmodule Oli.Authoring.Collaborators do
  use OliWeb, :verified_routes

  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.{Email, Mailer}
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Authoring.Course
  import Oli.Utils

  def get_collaborator(author_id, project_id) do
    Repo.get_by(AuthorProject, %{author_id: author_id, project_id: project_id})
  end

  def change_collaborator(email, project_slug, status) do
    with {:ok, author} <-
           Accounts.get_author_by_email(email)
           |> trap_nil("An author with that email was not found."),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found."),
         {:ok, project_role} <-
           Repo.get_by(
             ProjectRole,
             %{
               type:
                 if Enum.empty?(Repo.preload(project, [:authors]).authors) do
                   "owner"
                 else
                   "contributor"
                 end
             }
           )
           |> trap_nil("The project role was not found.") do
      case Repo.get_by(
             AuthorProject,
             %{
               author_id: author.id,
               project_id: project.id
             }
           ) do
        nil ->
          %AuthorProject{}
          |> AuthorProject.changeset(%{
            author_id: author.id,
            project_id: project.id,
            project_role_id: project_role.id,
            status: status
          })

        _ ->
          {:error, "The author is already a project collaborator."}
      end
    else
      # trap_nil wraps the message in a tuple which must be destructured
      {:error, {message}} -> {:error, message}
    end
  end

  @doc """
  Sends the invitation email for a collaboration created by
  `Oli.Authoring.Audited.invite_collaborator/5`.
  """
  def send_email_invitation(email_data, inviter_name, inviter_email, project_title) do
    Email.create_email(
      email_data.sent_to,
      "You were invited as a collaborator to \"#{project_title}\"",
      :collaborator_invitation,
      %{
        inviter: inviter_name,
        url: url(OliWeb.Endpoint, ~p"/collaborators/invite/#{email_data.token}"),
        project_title: project_title
      }
    )
    |> Email.maybe_reply_to({inviter_name, inviter_email})
    |> Mailer.deliver()
  end
end
