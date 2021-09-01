defmodule Oli.Authoring.Collaborators do
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias OliWeb.Router.Helpers, as: Routes
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

  defp get_or_invite_author(conn, email) do
    Accounts.get_author_by_email(email)
    |> case do
      nil ->
        case PowInvitation.Plug.create_user(conn, %{email: email}) do
          {:ok, user, _conn} -> {:ok, user, :new_user}
          {:error, _changeset, _conn} -> {:error, "Unable to create invitation for new author"}
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
    with {:ok, author, status} <- get_or_invite_author(conn, email),
         {:ok, results} <- add_collaborator(email, project_slug),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found."),
         {:ok, _mail} <- deliver_invitation_email(conn, author, project, status) do
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

  defp deliver_invitation_email(conn, user, project, status) do
    invited_by = Pow.Plug.current_user(conn)

    url =
      case status do
        :new_user ->
          token = PowInvitation.Plug.sign_invitation_token(conn, user)
          Routes.pow_invitation_invitation_path(conn, :edit, token)

        :existing_user ->
          Routes.project_path(conn, :overview, project.slug)
      end

    invited_by_user_id = Map.get(invited_by, invited_by.__struct__.pow_user_id_field())

    email =
      Oli.Email.invitation_email(
        user.email,
        :collaborator_invitation,
        %{
          invited_by: invited_by,
          invited_by_user_id: invited_by_user_id,
          url: Routes.url(conn) <> url,
          project_title: project.title
        }
      )

    Oli.Mailer.deliver_now(email)
    {:ok, "email sent"}
  end
end
