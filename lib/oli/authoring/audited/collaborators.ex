defmodule Oli.Authoring.Audited.Collaborators do
  @moduledoc false
  # Collaborator commands of `Oli.Authoring.Audited`, which validates their arguments, and the
  # collaboration writes they and project creation run.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Audited.Support, only: [record: 2]

  alias Ecto.Multi
  alias Oli.Accounts
  alias Oli.Accounts.{Author, AuthorToken}
  alias Oli.Auditing.Changes
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  @collaborator_fields %{status: :value, role: :value}

  ## Commands

  def add_collaborator(context, author, project) do
    Repo.transaction(fn ->
      with {:ok, author_project} <- insert_collaborator(author, project, :accepted),
           :ok <- record_collaborator(context, project, author_project, nil) do
        author_project
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def invite_collaborator(context, inviter_name, inviter_email, email, project_slug) do
    result =
      Repo.transaction(fn ->
        with {:ok, project} <-
               project_slug |> Course.get_project_by_slug() |> found("The project was not found."),
             {:ok, author} <- invited_author(context, email),
             {:ok, author_project} <- insert_collaborator(author, project, :pending_confirmation),
             :ok <- record_collaborator(context, project, author_project, nil),
             {:ok, email_data} <- insert_invitation_token(author, project_slug) do
          {author_project, email_data, project}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    with {:ok, {author_project, email_data, project}} <- result,
         {:ok, _mail} <-
           Oli.Authoring.Collaborators.send_email_invitation(
             email_data,
             inviter_name,
             inviter_email,
             project.title
           ) do
      {:ok, author_project}
    end
  end

  def respond_to_invitation(context, author_id, project_id, status) do
    with {:ok, author_project} <- lock_collaborator(author_id, project_id) do
      case author_project.status do
        :pending_confirmation ->
          with {:ok, updated} <- update_collaborator_status(author_project, status),
               project <- Repo.get!(Project, project_id),
               :ok <- record_collaborator(context, project, updated, author_project) do
            {:ok, updated}
          end

        _other ->
          {:ok, author_project}
      end
    end
  end

  def remove_collaborator(context, author_email, project_slug) do
    with {:ok, author} <-
           author_email
           |> Accounts.get_author_by_email()
           |> found("An author with that email was not found."),
         {:ok, project} <-
           project_slug |> Course.get_project_by_slug() |> found("The project was not found."),
         {:ok, author_project} <- locked_collaborator(author.id, project.id),
         :ok <- not_owner(author_project),
         {:ok, _deleted} <- delete_collaborator(author_project),
         :ok <- record_collaborator(context, project, nil, author_project) do
      {:ok, author_project}
    end
  end

  defp invited_author(context, email) do
    case Accounts.get_author_by_email(email) do
      nil ->
        case Accounts.Audited.invite_author_multi(Multi.new(), :author, context, email)
             |> Repo.transaction() do
          {:ok, %{author: author}} ->
            {:ok, author}

          {:error, _step, _reason, _changes} ->
            {:error, "Unable to create invitation for new author"}
        end

      author ->
        {:ok, author}
    end
  end

  defp insert_invitation_token(author, project_slug) do
    {token, author_token} =
      AuthorToken.build_email_token(author, "collaborator_invitation:#{project_slug}")

    with {:ok, _} <- Repo.insert(author_token) do
      {:ok, %{sent_to: author_token.sent_to, token: token}}
    end
  end

  defp locked_collaborator(author_id, project_id) do
    case lock_collaborator(author_id, project_id) do
      {:ok, author_project} -> {:ok, author_project}
      {:error, :not_found} -> {:error, "The author is not a collaborator on the project."}
    end
  end

  defp not_owner(author_project) do
    case role_type(author_project) do
      "owner" -> {:error, "That author is the project owner."}
      _ -> :ok
    end
  end

  defp record_collaborator(context, project, after_state, before_state) do
    author_id = (after_state || before_state).author_id

    changes =
      Changes.diff(
        collaborator_state(before_state),
        collaborator_state(after_state),
        @collaborator_fields
      )

    record(context, %{
      event_type: :project_collaborator_changed,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id},
      affected: {:author, author_id},
      event_key: "project:#{project.id}:collaborator:#{author_id}:changed",
      changes: changes
    })
  end

  defp collaborator_state(nil), do: nil

  defp collaborator_state(%AuthorProject{} = author_project),
    do: %{status: author_project.status, role: role_type(author_project)}

  defp found(nil, message), do: {:error, message}
  defp found(value, _message), do: {:ok, value}

  ## Writes

  @doc """
  Inserts the collaboration of `author` on `project` with `status`. The first collaborator of a
  project is its owner; everyone else is a contributor.
  """
  def insert_collaborator(%Author{} = author, %Project{} = project, status) do
    case Oli.Authoring.Collaborators.change_collaborator(author.email, project.slug, status) do
      %Ecto.Changeset{} = changeset -> Repo.insert(changeset)
      {:error, message} -> {:error, message}
    end
  end

  @doc "Locks the collaboration of `author_id` on `project_id` and returns it with its role."
  def lock_collaborator(author_id, project_id) do
    from(ap in AuthorProject,
      where: ap.author_id == ^author_id and ap.project_id == ^project_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      author_project -> {:ok, Repo.preload(author_project, :project_role)}
    end
  end

  @doc "Updates the status of a collaboration."
  def update_collaborator_status(%AuthorProject{} = author_project, status) do
    author_project
    |> AuthorProject.changeset(%{status: status})
    |> Repo.update()
  end

  @doc "Deletes a collaboration."
  def delete_collaborator(%AuthorProject{} = author_project), do: Repo.delete(author_project)

  @doc "Returns the role type (`owner` or `contributor`) of a collaboration."
  def role_type(%AuthorProject{project_role: %ProjectRole{type: type}}), do: type

  def role_type(%AuthorProject{} = author_project),
    do: author_project |> Repo.preload(:project_role) |> role_type()
end
