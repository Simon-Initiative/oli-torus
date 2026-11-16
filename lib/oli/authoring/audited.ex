defmodule Oli.Authoring.Audited do
  @moduledoc """
  Application boundary for audited authoring commands: project lifecycle and collaborators.

  Each command writes its change and its events in one transaction. A project's owner is the
  author who creates, copies, or imports it, and is recorded as the affected author of the
  creation event; ownership never changes afterwards. Collaborator changes record
  `project_collaborator_changed` with the collaborator as the affected author and the `status`
  and `role` before and after.

  Commands do not authorize the actor; callers keep their existing authorization. Checks that
  lived in the migrated functions (the owner cannot be removed) run inside the transaction.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Ecto.Multi
  alias Oli.Accounts
  alias Oli.Accounts.{Author, AuthorToken}
  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context}
  alias Oli.Authoring.Audited.Projects
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.{Collaborators, Course}
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  @collaborator_fields %{status: :value, role: :value}

  @type command_error :: :invalid_request | :not_found | :nested_transaction | term()

  ## Projects

  @doc """
  Creates a project titled `title` owned by `author`, with its root container and initial
  working publication, and records `project_created`.

  Options:

    * `:learning_model_version` - defaults to `:lkt_aoa`, the application default.
    * `:lo_well_formed` - sets the trusted learning-objective flag instead of the schema default.

  Only trusted setup (Scenarios) passes options.

  Returns the same map as before (`:project`, `:resource_revision`, `:publication`, ...).
  """
  @spec create_project(Context.t(), String.t(), %Author{}, map(), keyword()) ::
          {:ok, map()} | {:error, command_error()}
  def create_project(context, title, author, attrs \\ %{}, opts \\ [])

  def create_project(%Context{} = context, title, %Author{} = author, attrs, opts)
      when is_map(attrs) do
    learning_model_version = Keyword.get(opts, :learning_model_version, :lkt_aoa)
    lo_well_formed = Keyword.get(opts, :lo_well_formed, :use_default)

    create(context, :project_created, fn ->
      Projects.create(title, author, attrs, learning_model_version, lo_well_formed)
    end)
  end

  def create_project(_context, _title, _author, _attrs, _opts), do: {:error, :invalid_request}

  @doc """
  Creates the project of an imported course archive with its validated learning model and
  records `project_imported`. Runs inside the archive ingest transaction, so a failed import
  rolls the project and its event back.
  """
  @spec import_project(Context.t(), String.t(), %Author{}, :naive | :lkt_aoa, map()) ::
          {:ok, map()} | {:error, command_error()}
  def import_project(
        %Context{} = context,
        title,
        %Author{} = author,
        learning_model_version,
        attrs
      )
      when learning_model_version in [:naive, :lkt_aoa] and is_map(attrs) do
    lo_well_formed = Map.get(attrs, :lo_well_formed)
    attrs = Map.delete(attrs, :lo_well_formed)

    create(context, :project_imported, fn ->
      Projects.create(title, author, attrs, learning_model_version, lo_well_formed)
    end)
  end

  def import_project(_context, _title, _author, _learning_model_version, _attrs),
    do: {:error, :invalid_request}

  @doc """
  Copies the project with `project_slug` for `author`, who becomes the owner of the copy, and
  records `project_duplicated` with the source project.

  Options: `:author_in_project_title` appends the author's email to the title instead of
  " Copy", as before.
  """
  @spec duplicate_project(Context.t(), String.t(), %Author{}, keyword()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def duplicate_project(context, project_slug, author, opts \\ [])

  def duplicate_project(%Context{} = context, project_slug, %Author{} = author, opts)
      when is_binary(project_slug) do
    Repo.transaction(fn ->
      with {:ok, {base_project, project}} <- Projects.duplicate(project_slug, author, opts),
           :ok <-
             record(context, project_event(:project_duplicated, project, author, base_project)) do
        project
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def duplicate_project(_context, _project_slug, _author, _opts), do: {:error, :invalid_request}

  @doc """
  Marks the project with ID `project_id` deleted and records `project_deleted`. A project that
  is already deleted returns it unchanged, without an event.
  """
  @spec delete_project(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def delete_project(%Context{} = context, project_id) when is_integer(project_id) do
    Repo.transaction(fn ->
      with {:ok, project} <- Projects.lock_project(project_id),
           {:ok, deleted} <- delete_once(context, project) do
        deleted
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_project(_context, _project_id), do: {:error, :invalid_request}

  defp delete_once(_context, %Project{status: :deleted} = project), do: {:ok, project}

  defp delete_once(context, project) do
    with {:ok, deleted} <- Projects.mark_deleted(project),
         :ok <- record(context, project_event(:project_deleted, deleted, nil, nil)) do
      {:ok, deleted}
    end
  end

  # Function-style transactions (the creation steps use them) compose as savepoints of an
  # enclosing transaction, so the archive ingest can call `import_project/5` inside its own.
  defp create(context, event_type, build) do
    Repo.transaction(fn ->
      with {:ok, %{project: project, author_project: owner} = created} <- build.(),
           :ok <- record(context, project_event(event_type, project, owner, nil)) do
        created
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp project_event(event_type, %Project{} = project, owner, source) do
    key =
      case event_type do
        :project_created -> "created"
        :project_imported -> "imported"
        :project_duplicated -> "duplicated"
        :project_deleted -> "deleted"
      end

    %{
      event_type: event_type,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id},
      event_key: "project:#{project.id}:#{key}",
      details: %{project_title: project.title}
    }
    |> put_owner(owner)
    |> put_source(source)
  end

  defp put_owner(proposal, nil), do: proposal
  defp put_owner(proposal, %Author{id: id}), do: Map.put(proposal, :affected, {:author, id})

  defp put_owner(proposal, %AuthorProject{author_id: id}),
    do: Map.put(proposal, :affected, {:author, id})

  defp put_source(proposal, nil), do: proposal

  defp put_source(proposal, %Project{} = source) do
    proposal
    |> Map.put(:refs, [%{role: :source, type: :project, id: source.id, label: source.title}])
    |> Map.update!(:details, &Map.put(&1, :source_project_id, source.id))
  end

  ## Collaborators

  @doc """
  Adds `author` to `project` as an accepted collaborator (the owner when the project has no
  collaborators yet) and records `project_collaborator_changed`.
  """
  @spec add_collaborator(Context.t(), %Author{}, %Project{}) ::
          {:ok, %AuthorProject{}} | {:error, command_error()}
  def add_collaborator(%Context{} = context, %Author{} = author, %Project{} = project) do
    Repo.transaction(fn ->
      with {:ok, author_project} <- Projects.insert_collaborator(author, project, :accepted),
           :ok <- record_collaborator(context, project, author_project, nil) do
        author_project
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def add_collaborator(_context, _author, _project), do: {:error, :invalid_request}

  @doc """
  Invites `email` to collaborate on the project with `project_slug`: creates the invited author
  when there is none (`account_created`, with `context` as the inviter), the pending
  collaboration (`project_collaborator_changed`), and the invitation token, in one transaction.
  The email is sent after the commit.

  Returns `{:ok, author_project}` or `{:error, message}` with the message shown to the inviter,
  as before.
  """
  @spec invite_collaborator(Context.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, %AuthorProject{}} | {:error, term()}
  def invite_collaborator(%Context{} = context, inviter_name, inviter_email, email, project_slug) do
    result =
      Repo.transaction(fn ->
        with {:ok, project} <-
               project_slug |> Course.get_project_by_slug() |> found("The project was not found."),
             {:ok, author} <- invited_author(context, email),
             {:ok, author_project} <-
               Projects.insert_collaborator(author, project, :pending_confirmation),
             :ok <- record_collaborator(context, project, author_project, nil),
             {:ok, email_data} <- insert_invitation_token(author, project_slug) do
          {author_project, email_data, project}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    with {:ok, {author_project, email_data, project}} <- result,
         {:ok, _mail} <-
           Collaborators.send_email_invitation(
             email_data,
             inviter_name,
             inviter_email,
             project.title
           ) do
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

  @doc """
  Adds to `multi` the answer of the invited author to a pending collaboration
  (`:accepted` or `:rejected`) and records `project_collaborator_changed` with the invited
  author as actor. A collaboration that is no longer pending is left unchanged, without an event.
  The result under `name` is the collaboration.
  """
  @spec respond_to_invitation_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {pos_integer(), pos_integer(), :accepted | :rejected}
        ) :: Multi.t()
  def respond_to_invitation_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {author_id, project_id, status}
      )
      when status in [:accepted, :rejected] do
    Multi.run(multi, name, fn _repo, _changes ->
      respond(context, author_id, project_id, status)
    end)
  end

  def respond_to_invitation_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  @doc "Runs `respond_to_invitation_multi/4` in its own transaction."
  @spec respond_to_invitation(Context.t(), {pos_integer(), pos_integer(), :accepted | :rejected}) ::
          {:ok, %AuthorProject{}} | {:error, command_error()}
  def respond_to_invitation(context, args) do
    Multi.new()
    |> respond_to_invitation_multi(:author_project, context, args)
    |> Repo.transaction()
    |> case do
      {:ok, %{author_project: author_project}} -> {:ok, author_project}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp respond(context, author_id, project_id, status) do
    with {:ok, author_project} <- Projects.lock_collaborator(author_id, project_id) do
      case author_project.status do
        :pending_confirmation ->
          with {:ok, updated} <- Projects.update_collaborator_status(author_project, status),
               project <- Repo.get!(Project, project_id),
               :ok <- record_collaborator(context, project, updated, author_project) do
            {:ok, updated}
          end

        _other ->
          {:ok, author_project}
      end
    end
  end

  @doc """
  Adds to `multi` the removal of the author with `author_email` from the project with
  `project_slug` and records `project_collaborator_changed`. The owner cannot be removed, as
  before. The result under `name` is the removed collaboration.
  """
  @spec remove_collaborator_multi(Multi.t(), Multi.name(), Context.t(), {String.t(), String.t()}) ::
          Multi.t()
  def remove_collaborator_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {author_email, project_slug}
      )
      when is_binary(author_email) and is_binary(project_slug) do
    Multi.run(multi, name, fn _repo, _changes ->
      with {:ok, author} <-
             author_email
             |> Accounts.get_author_by_email()
             |> found("An author with that email was not found."),
           {:ok, project} <-
             project_slug |> Course.get_project_by_slug() |> found("The project was not found."),
           {:ok, author_project} <- locked_collaborator(author.id, project.id),
           :ok <- not_owner(author_project),
           {:ok, _deleted} <- Projects.delete_collaborator(author_project),
           :ok <- record_collaborator(context, project, nil, author_project) do
        {:ok, author_project}
      end
    end)
  end

  def remove_collaborator_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  defp locked_collaborator(author_id, project_id) do
    case Projects.lock_collaborator(author_id, project_id) do
      {:ok, author_project} -> {:ok, author_project}
      {:error, :not_found} -> {:error, "The author is not a collaborator on the project."}
    end
  end

  defp not_owner(author_project) do
    case Projects.role_type(author_project) do
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
    do: %{status: author_project.status, role: Projects.role_type(author_project)}

  ## Shared

  defp found(nil, message), do: {:error, message}
  defp found(value, _message), do: {:ok, value}

  defp record(context, proposal) do
    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end
end
