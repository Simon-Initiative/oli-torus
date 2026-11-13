defmodule Oli.Auditing.Command do
  @moduledoc """
  Shared steps for audited configuration commands that create, update, or delete one row and
  record one event about it in the same `Ecto.Multi`.

  The audited facades (`Oli.Institutions.Audited`, `Oli.Groups.Audited`, and others) build the
  changeset and describe the event; this module owns the row lock, the before and after state,
  the change records under the event's field policy, and the write. An update that changes no
  audited field writes no event.

  An event description (`spec`) is a map with:

    * `:event_type` - the catalog event
    * `:policy` - the field policy used to compute `changes`
    * `:proposal` - a function `(record, operation) -> map` returning the rest of the event
      proposal (`:entity`, `:event_key`, and optionally `:scope`, `:refs`, `:affected`,
      `:details`); `operation` is `:created`, `:updated`, or `:deleted`
    * `:changes` (optional) - a function `(record, operation) -> map` that replaces the
      computed field changes, for rows recorded as a change of another entity (for example a
      membership recorded as `members` of its community), or `(record, operation, computed)`
      to extend them (for example with a credential's lifecycle transition)
    * `:record_unchanged` (optional) - `true` to record an update even when no audited field
      changed, for transitions that only replace a secret (a token rotation)
    * `:delete` (optional) - a function `(record) -> record | Ecto.Changeset.t() | {:error, term()}`
      that prepares the deletion, for schemas that check associations or refuse some rows

  Every function stores its result under `name` and uses `{name, step}` for internal steps.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Ecto.Multi
  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context}
  alias Oli.Repo

  @type operation :: :created | :updated | :deleted

  @type spec :: %{
          required(:event_type) => atom(),
          required(:policy) => Changes.field_spec(),
          required(:proposal) => (struct(), operation() -> map()),
          optional(:changes) =>
            (struct(), operation() -> map()) | (struct(), operation(), map() -> map()),
          optional(:record_unchanged) => boolean(),
          optional(:delete) => (struct() -> struct() | Ecto.Changeset.t() | {:error, term()})
        }

  @doc """
  Runs the steps that `build` adds to a new `Ecto.Multi` in their own transaction and returns
  the result stored under `name`. Returns `{:error, :nested_transaction}` inside another
  transaction, so callers that own one compose the `*_multi` functions instead.
  """
  @spec run(Multi.name(), (Multi.t() -> Multi.t())) :: {:ok, term()} | {:error, term()}
  def run(name, build) when is_function(build, 1) do
    case Repo.in_transaction?() do
      true ->
        {:error, :nested_transaction}

      false ->
        Multi.new()
        |> build.()
        |> Repo.transaction()
        |> case do
          {:ok, changes} -> {:ok, Map.fetch!(changes, name)}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  @doc "Inserts `changeset` and records the creation with one-sided changes."
  @spec insert(Multi.t(), Multi.name(), Context.t(), Ecto.Changeset.t(), spec()) :: Multi.t()
  def insert(%Multi{} = multi, name, %Context{} = context, %Ecto.Changeset{} = changeset, spec) do
    multi
    |> Multi.run({name, :inserted}, fn repo, _changes -> repo.insert(changeset) end)
    |> Auditing.append({name, :event}, fn changes ->
      record = Map.fetch!(changes, {name, :inserted})
      event(context, spec, record, :created, Changes.diff(nil, record, spec.policy))
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :inserted})} end)
  end

  @doc """
  Locks the row of `schema` with `id`, applies the changeset that `change` builds from it, and
  records the audited fields that changed. A missing row returns `:not_found`; `change` may
  return `{:error, reason}` to stop without writing.
  """
  @spec update(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {module(), term()},
          (struct() -> Ecto.Changeset.t() | {:error, term()}),
          spec()
        ) :: Multi.t()
  def update(%Multi{} = multi, name, %Context{} = context, {schema, id}, change, spec)
      when is_function(change, 1) do
    multi
    |> Multi.run({name, :before}, fn repo, _changes -> lock(repo, schema, id) end)
    |> Multi.run({name, :after}, fn repo, changes ->
      case changes |> Map.fetch!({name, :before}) |> change.() do
        %Ecto.Changeset{} = changeset -> repo.update(changeset)
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Auditing.append({name, :event}, fn changes ->
      before = Map.fetch!(changes, {name, :before})
      updated = Map.fetch!(changes, {name, :after})

      diff = Changes.diff(before, updated, spec.policy)

      case map_size(diff) == 0 and not Map.get(spec, :record_unchanged, false) do
        true -> :skip
        false -> event(context, spec, updated, :updated, diff)
      end
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :after})} end)
  end

  @doc """
  Locks and deletes the row of `schema` with `id`, and records the deletion with one-sided
  changes. A row still referenced through a restrictive foreign key returns `:delete_failed`
  and logs only the schema and ID.
  """
  @spec delete(Multi.t(), Multi.name(), Context.t(), {module(), term()}, spec()) :: Multi.t()
  def delete(%Multi{} = multi, name, %Context{} = context, {schema, id}, spec) do
    multi
    |> Multi.run({name, :before}, fn repo, _changes -> lock(repo, schema, id, :delete) end)
    |> Multi.run({name, :deleted}, fn repo, changes ->
      prepare = Map.get(spec, :delete, & &1)

      case changes |> Map.fetch!({name, :before}) |> prepare.() do
        {:error, reason} -> {:error, reason}
        record_or_changeset -> delete_row(record_or_changeset, repo)
      end
    end)
    |> Auditing.append({name, :event}, fn changes ->
      record = Map.fetch!(changes, {name, :before})
      event(context, spec, record, :deleted, Changes.diff(record, nil, spec.policy))
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :deleted})} end)
  end

  @doc """
  Locks and returns the row of `schema` whose primary key is `id`, or `{:error, :not_found}`.

  `:update` (the default) takes `FOR NO KEY UPDATE`: concurrent updates of the row wait, but
  inserts that only reference it (foreign keys) do not. `:delete` takes `FOR UPDATE`, which also
  blocks new references while the row is being removed.
  """
  @spec lock(Ecto.Repo.t(), module(), term(), :update | :delete) ::
          {:ok, struct()} | {:error, :not_found}
  def lock(repo, schema, id, mode \\ :update) do
    [primary_key] = schema.__schema__(:primary_key)
    query = from(r in schema, where: field(r, ^primary_key) == ^id)

    locked =
      case mode do
        :update -> from(r in query, lock: "FOR NO KEY UPDATE")
        :delete -> from(r in query, lock: "FOR UPDATE")
      end

    case repo.one(locked) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @doc "Builds the event changeset for `record` from `spec` and the computed `changes`."
  @spec event(Context.t(), spec(), struct(), :created | :updated | :deleted, map()) ::
          {:ok, Ecto.Changeset.t()} | {:error, term()}
  def event(context, spec, record, operation, changes) do
    changes =
      case Map.fetch(spec, :changes) do
        {:ok, fun} when is_function(fun, 3) -> fun.(record, operation, changes)
        {:ok, fun} -> fun.(record, operation)
        :error -> changes
      end

    proposal =
      record
      |> spec.proposal.(operation)
      |> Map.put(:event_type, spec.event_type)
      |> Map.put(:changes, changes)

    Auditing.build(context, proposal)
  end

  # Postgres has already marked the transaction as failed after a restrictive foreign key, so
  # the caller must return an error and let it roll back.
  defp delete_row(record_or_changeset, repo) do
    repo.delete(record_or_changeset)
  rescue
    error in Ecto.ConstraintError ->
      case error.type do
        :foreign_key ->
          %schema{} = row = row(record_or_changeset)
          [primary_key] = schema.__schema__(:primary_key)
          id = Map.fetch!(row, primary_key)

          Logger.warning(
            "Audited delete failed schema=#{inspect(schema)} id=#{id} reason=referenced"
          )

          {:error, :delete_failed}

        _ ->
          reraise error, __STACKTRACE__
      end
  end

  defp row(%Ecto.Changeset{data: data}), do: data
  defp row(record), do: record
end
