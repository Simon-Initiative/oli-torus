defmodule Oli.MCP.Auth do
  @moduledoc """
  Authentication context for MCP (Model Context Protocol) Bearer tokens.

  Provides functionality to create, validate, and manage Bearer tokens
  that allow external AI agents to access project content via the MCP server.

  Tokens are scoped to a specific author and project combination.
  Like API keys, we store only the MD5 hash of the token, not the token itself.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.MCP.Auth.BearerToken
  alias Oli.MCP.Auth.TokenGenerator
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Authors.AuthorProject

  @doc """
  Creates a new bearer token for the given author and project.

  Returns {:ok, {%BearerToken{}, token_string}} on success,
  {:error, changeset} on failure.

  The token_string is only returned once and should be displayed
  to the user immediately as it cannot be retrieved again.
  """
  def create_token(author_id, project_id, hint \\ nil) do
    # Verify author has access to the project before creating token
    with :ok <- verify_author_project_access(author_id, project_id) do
      token = TokenGenerator.generate()
      hash = TokenGenerator.hash(token)

      # Auto-generate hint if not provided
      hint = hint || TokenGenerator.create_hint(token)

      %BearerToken{}
      |> BearerToken.changeset(%{
        author_id: author_id,
        project_id: project_id,
        hash: hash,
        hint: hint
      })
      |> Repo.insert()
      |> case do
        {:ok, bearer_token} -> {:ok, {bearer_token, token}}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  Gets the bearer token for a specific author and project combination.

  Returns the BearerToken struct or nil if not found.
  """
  def get_token_by_author_and_project(author_id, project_id) do
    Repo.get_by(BearerToken, author_id: author_id, project_id: project_id)
  end

  @doc """
  Regenerates the token for an existing author/project combination.

  Replaces the existing token with a new one. Returns the same format
  as create_token/3.
  """
  def regenerate_token(author_id, project_id, hint \\ nil) do
    # Verify author has access to the project before regenerating
    with :ok <- verify_author_project_access(author_id, project_id) do
      case get_token_by_author_and_project(author_id, project_id) do
        nil ->
          create_token(author_id, project_id, hint)

        existing_token ->
          token = TokenGenerator.generate()
          hash = TokenGenerator.hash(token)

          # Auto-generate hint if not provided
          hint = hint || TokenGenerator.create_hint(token)

          existing_token
          |> BearerToken.changeset(%{hash: hash, hint: hint})
          |> Repo.update()
          |> case do
            {:ok, bearer_token} -> {:ok, {bearer_token, token}}
            {:error, changeset} -> {:error, changeset}
          end
      end
    end
  end

  @doc """
  Deletes a bearer token by its ID.
  """
  def delete_token(id) do
    case Repo.get(BearerToken, id) do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

  @doc """
  Validates a bearer token and returns authentication context.

  Returns {:ok, %{author_id: id, project_id: id}} if valid,
  {:error, reason} if invalid.

  Also updates the last_used_at timestamp for valid tokens.
  """
  def validate_token(token) when is_binary(token) do
    # First check token format for early rejection
    unless TokenGenerator.valid_format?(token) do
      {:error, :invalid_token_format}
    else
      hash = TokenGenerator.hash(token)

      case Repo.get_by(BearerToken, hash: hash) do
        nil ->
          {:error, :invalid_token}

        %BearerToken{status: "disabled"} ->
          {:error, :token_disabled}

        %BearerToken{} = bearer_token ->
          # Verify the associated project and author still exist and are active
          with :ok <- verify_token_associations(bearer_token) do
            # Update last used timestamp
            update_last_used(bearer_token)

            {:ok,
             %{
               author_id: bearer_token.author_id,
               project_id: bearer_token.project_id
             }}
          end
      end
    end
  end

  @doc """
  Validates that a token has access to a specific project.

  Returns true if the token is valid and has access to the project,
  false otherwise.
  """
  def validate_project_access(token, project_slug)
      when is_binary(token) and is_binary(project_slug) do
    with {:ok, %{project_id: project_id}} <- validate_token(token),
         %Project{slug: ^project_slug} <- Repo.get(Project, project_id) do
      true
    else
      _ -> false
    end
  end

  @doc """
  Lists all bearer tokens for a specific author.
  """
  def list_tokens_for_author(author_id) do
    Repo.all(
      from bt in BearerToken,
        where: bt.author_id == ^author_id,
        preload: [:project],
        order_by: [desc: bt.updated_at]
    )
  end

  @doc """
  Lists all bearer tokens for a specific project.
  """
  def list_tokens_for_project(project_id) do
    Repo.all(
      from bt in BearerToken,
        where: bt.project_id == ^project_id,
        preload: [:author],
        order_by: [desc: bt.updated_at]
    )
  end

  @doc """
  Updates the status of a bearer token (enabled/disabled).
  """
  def update_token_status(token_id, status) when status in ["enabled", "disabled"] do
    case Repo.get(BearerToken, token_id) do
      nil ->
        {:error, :not_found}

      token ->
        token
        |> BearerToken.changeset(%{status: status})
        |> Repo.update()
    end
  end

  @doc """
  Creates a changeset for a bearer token.
  """
  def change_token(%BearerToken{} = token, attrs \\ %{}) do
    BearerToken.changeset(token, attrs)
  end

  @doc """
  Verifies that an author can perform token operations for a project.

  Returns :ok if the author is a collaborator on the project,
  {:error, reason} otherwise.
  """
  def verify_author_can_manage_token(author_id, project_id) do
    verify_author_project_access(author_id, project_id)
  end

  # Private functions

  defp update_last_used(%BearerToken{} = token) do
    token
    |> BearerToken.changeset(%{last_used_at: DateTime.utc_now()})
    |> Repo.update()
  end

  defp verify_author_project_access(author_id, project_id) do
    # Check if author is a collaborator on the project
    case Repo.get_by(AuthorProject, author_id: author_id, project_id: project_id) do
      nil ->
        {:error, :unauthorized_project_access}

      _author_project ->
        # Also verify the project exists and is not deleted
        case Repo.get(Project, project_id) do
          nil ->
            {:error, :project_not_found}

          %Project{status: :deleted} ->
            {:error, :project_deleted}

          %Project{} ->
            :ok
        end
    end
  end

  defp verify_token_associations(%BearerToken{author_id: author_id, project_id: project_id}) do
    # Verify both the author and project still exist and are valid
    with {:project, %Project{status: status}} when status != :deleted <-
           {:project, Repo.get(Project, project_id)},
         {:author, author} when not is_nil(author) <-
           {:author, Repo.get(Oli.Accounts.Author, author_id)},
         {:author_project, author_project} when not is_nil(author_project) <-
           {:author_project, Repo.get_by(AuthorProject, author_id: author_id, project_id: project_id)} do
      :ok
    else
      {:project, nil} -> {:error, :project_not_found}
      {:project, %Project{status: :deleted}} -> {:error, :project_deleted}
      {:author, nil} -> {:error, :author_not_found}
      {:author_project, nil} -> {:error, :unauthorized_project_access}
    end
  end
end
