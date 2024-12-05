defmodule Oli.Authoring.Collaborators do
  use OliWeb, :verified_routes
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Authoring.Course
  import Oli.Utils

  def get_collaborator(author_id, project_id) do
    Repo.get_by(AuthorProject, %{author_id: author_id, project_id: project_id})
  end

  def change_collaborator(email, project_slug) do
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
            project_role_id: project_role.id
          })

        _ ->
          {:error, "The author is already a project collaborator."}
      end
    else
      # trap_nil wraps the message in a tuple which must be destructured
      {:error, {message}} -> {:error, message}
    end
  end

  defp get_or_create_invited_author(email) do
    Accounts.get_author_by_email(email)
    |> case do
      nil ->
        case Accounts.create_invited_author(email) do
          {:ok, author} -> {:ok, author, :new_user}
          {:error, _changeset} -> {:error, "Unable to create invitation for new author"}
        end

      author ->
        if not is_nil(author.invitation_token) and is_nil(author.invitation_accepted_at) do
          {:ok, author, :new_user}
        else
          {:ok, author, :existing_user}
        end
    end
  end

  def add_collaborator(conn, email, project_slug) do
    with {:ok, author, status} <- get_or_create_invited_author(email),
         {:ok, results} <- add_collaborator(email, project_slug),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found."),
         {:ok, _mail} <-
           deliver_collaborator_invitation_email(conn, author, project, status) do
      {:ok, results}
    else
      {:error, message} -> {:error, message}
    end
  end

  def add_collaborator(author = %Accounts.Author{}, project_slug) when is_binary(project_slug) do
    add_collaborator(author.email, project_slug)
  end

  def add_collaborator(email, project = %Course.Project{}) when is_binary(email) do
    add_collaborator(email, project.slug)
  end

  def add_collaborator(author = %Accounts.Author{}, project = %Course.Project{}) do
    add_collaborator(author.email, project.slug)
  end

  def add_collaborator(email, project_slug) when is_binary(email) and is_binary(project_slug) do
    changeset_or_error = change_collaborator(email, project_slug)

    case changeset_or_error do
      %Ecto.Changeset{} -> Repo.insert(changeset_or_error)
      {:error, _e} -> changeset_or_error
    end
  end

  def remove_collaborator(email, project_slug)
      when is_binary(email) and is_binary(project_slug) do
    with {:ok, author} <-
           Accounts.get_author_by_email(email)
           |> trap_nil("An author with that email was not found."),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found."),
         {:ok, author_project} <-
           Repo.get_by(
             AuthorProject,
             %{
               author_id: author.id,
               project_id: project.id
             }
           )
           |> trap_nil("The author is not a collaborator on the project.") do
      project_role_type = Repo.preload(author_project, [:project_role]).project_role.type

      if project_role_type == "owner" do
        {:error, "That author is the project owner."}
      else
        Repo.delete(author_project)
      end
    else
      {:error, {message}} -> {:error, message}
    end
  end

  defp deliver_collaborator_invitation_email(conn, collaborator_author, project, status) do
    invited_by = conn.assigns.current_author

    url =
      case status do
        :new_user ->
          token = PowInvitation.Plug.sign_invitation_token(conn, collaborator_author)
          author_invitation_url(conn, token)

        :existing_user ->
          ~p"/workspaces/course_author/#{project.slug}/overview"
      end

    email =
      Oli.Email.create_email(
        collaborator_author.email,
        "Collaborator Invitation",
        :collaborator_invitation,
        %{
          invited_by: invited_by,
          invited_by_user_id: invited_by.id,
          url: url,
          project_title: project.title
        }
      )

    Oli.Mailer.deliver(email)
    {:ok, "email sent"}
  end

  defp author_invitation_url(conn, token) do
    throw("NOT IMPLEMENTED")
  end
end
