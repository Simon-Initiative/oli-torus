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
  alias Oli.MCP.Auth.BearerTokenUsage
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

  # Usage tracking functions

  @doc """
  Tracks usage of a bearer token for analytics and monitoring.

  Creates a usage record with minimal, non-sensitive metadata.
  """
  def track_usage(bearer_token_id, event_type, opts \\ []) do
    attrs = %{
      bearer_token_id: bearer_token_id,
      event_type: event_type,
      occurred_at: DateTime.utc_now(),
      tool_name: Keyword.get(opts, :tool_name),
      resource_uri: Keyword.get(opts, :resource_uri),
      request_id: Keyword.get(opts, :request_id),
      status: Keyword.get(opts, :status, "success")
    }

    %BearerTokenUsage{}
    |> BearerTokenUsage.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, usage} -> {:ok, usage}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Tracks usage by token string rather than ID.
  Helper function for use in authentication flows.
  """
  def track_usage_by_token(token, event_type, opts \\ []) when is_binary(token) do
    hash = TokenGenerator.hash(token)

    case Repo.get_by(BearerToken, hash: hash) do
      %BearerToken{id: token_id} ->
        track_usage(token_id, event_type, opts)

      nil ->
        {:error, :token_not_found}
    end
  end

  @doc """
  Browse bearer tokens with usage statistics for admin interface.
  
  Returns tokens with preloaded associations and usage counts.
  """
  defmodule BrowseOptions do
    defstruct [
      :text_search,
      :include_disabled,
      :author_id,
      :project_id
    ]
  end

  def browse_tokens_with_usage(%Oli.Repo.Paging{limit: limit, offset: offset}, %Oli.Repo.Sorting{} = sorting, %BrowseOptions{} = options) do
    # First, get the total count
    total_count_query = BearerToken
    |> join(:inner, [bt], author in Oli.Accounts.Author, on: bt.author_id == author.id)
    |> join(:inner, [bt], project in Project, on: bt.project_id == project.id)
    |> apply_browse_filters(options)
    |> select([bt, author, project], count(bt.id))
    
    total_count = Repo.one(total_count_query)

    # Then get the actual results
    results = BearerToken
    |> join(:left, [bt], usage in BearerTokenUsage, on: usage.bearer_token_id == bt.id)
    |> join(:inner, [bt], author in Oli.Accounts.Author, on: bt.author_id == author.id)
    |> join(:inner, [bt], project in Project, on: bt.project_id == project.id)
    |> apply_browse_filters(options)
    |> select([bt, usage, author, project], %{
      bearer_token: bt,
      author: author,
      project: project,
      usage_last_7_days: fragment("COUNT(CASE WHEN ? >= NOW() - INTERVAL '7 days' THEN 1 END)", usage.occurred_at),
      total_usage: count(usage.id)
    })
    |> group_by([bt, usage, author, project], [bt.id, author.id, project.id])
    |> apply_sorting(sorting)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    
    # Add total_count and bearer_token_id to each result
    Enum.map(results, fn result ->
      result
      |> Map.put(:total_count, total_count)
      |> Map.put(:bearer_token_id, result.bearer_token.id)
    end)
  end

  defp apply_browse_filters(query, %BrowseOptions{} = options) do
    query
    |> maybe_filter_text_search(options.text_search)
    |> maybe_filter_include_disabled(options.include_disabled)
    |> maybe_filter_author(options.author_id)
    |> maybe_filter_project(options.project_id)
  end

  defp maybe_filter_text_search(query, nil), do: query
  defp maybe_filter_text_search(query, ""), do: query
  defp maybe_filter_text_search(query, text_search) do
    search_term = "%#{text_search}%"
    
    where(query, [bt, usage, author, project], 
      ilike(author.name, ^search_term) or 
      ilike(author.email, ^search_term) or
      ilike(project.title, ^search_term) or
      ilike(bt.hint, ^search_term)
    )
  end

  defp maybe_filter_include_disabled(query, true), do: query
  defp maybe_filter_include_disabled(query, false) do
    where(query, [bt], bt.status == "enabled")
  end
  defp maybe_filter_include_disabled(query, nil), do: query

  defp maybe_filter_author(query, nil), do: query
  defp maybe_filter_author(query, author_id) do
    where(query, [bt], bt.author_id == ^author_id)
  end

  defp maybe_filter_project(query, nil), do: query
  defp maybe_filter_project(query, project_id) do
    where(query, [bt], bt.project_id == ^project_id)
  end

  defp apply_sorting(query, %Oli.Repo.Sorting{field: field, direction: direction}) do
    case field do
      :author_name -> order_by(query, [bt, usage, author, project], [{^direction, author.name}])
      :project_title -> order_by(query, [bt, usage, author, project], [{^direction, project.title}])
      :hint -> order_by(query, [bt, usage, author, project], [{^direction, bt.hint}])
      :status -> order_by(query, [bt, usage, author, project], [{^direction, bt.status}])
      :inserted_at -> order_by(query, [bt, usage, author, project], [{^direction, bt.inserted_at}])
      :last_used_at -> order_by(query, [bt, usage, author, project], [{^direction, bt.last_used_at}])
      :usage_last_7_days -> order_by(query, [bt, usage, author, project], [{^direction, fragment("COUNT(CASE WHEN ? >= NOW() - INTERVAL '7 days' THEN 1 END)", usage.occurred_at)}])
      :total_usage -> order_by(query, [bt, usage, author, project], [{^direction, count(usage.id)}])
      _ -> order_by(query, [bt, usage, author, project], [{^direction, bt.inserted_at}])
    end
  end
end
