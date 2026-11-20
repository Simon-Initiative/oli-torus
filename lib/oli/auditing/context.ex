defmodule Oli.Auditing.Context do
  @moduledoc """
  Who performed an audited action, from where, and as part of which operation.

  A context is built only from an authenticated `User`/`Author` struct or from the fixed
  catalog of system actors. It never carries a schema version, a sink, or a skip flag: those
  are decided by `Oli.Auditing`, not by callers.

  Events that belong to the same command share `operation_id` (for example, every row of a
  bulk student-exception update). `parent_operation_id` links an operation spawned by another
  one, such as a publication-application job started by a publish.
  """

  alias Oli.Accounts.{Author, User}
  alias Oli.Auditing.Snapshot

  # `unauthenticated_request` is the actor of requests made without signing in, where nobody
  # can be named: for example, someone types an email on the "forgot password" page and a reset
  # link is sent to that account. The account cannot be the actor, because whoever typed the
  # email may not own it.
  @system_actors %{
    playwright_setup: "Playwright setup",
    provider_provisioning: "Identity provider provisioning",
    scheduled_maintenance: "Scheduled maintenance",
    unauthenticated_request: "Unauthenticated request"
  }

  @account_sources [:ui, :api, :mcp, :job, :scenario, :application]
  @sources [:system | @account_sources]

  @enforce_keys [:actor_type, :actor_snapshot, :source, :operation_id]
  defstruct [
    :actor_type,
    :user_id,
    :author_id,
    :system_key,
    :actor_snapshot,
    :source,
    :operation_id,
    :parent_operation_id
  ]

  @type source :: :ui | :api | :mcp | :job | :scenario | :system | :application
  @type system_key ::
          :playwright_setup
          | :provider_provisioning
          | :scheduled_maintenance
          | :unauthenticated_request

  @type t :: %__MODULE__{
          actor_type: :user | :author | :system,
          user_id: pos_integer() | nil,
          author_id: pos_integer() | nil,
          system_key: system_key() | nil,
          actor_snapshot: map(),
          source: source(),
          operation_id: Ecto.UUID.t(),
          parent_operation_id: Ecto.UUID.t() | nil
        }

  @doc """
  Builds a context for an authenticated user or author.

  Options:
    * `:source` (required) - one of `:ui`, `:api`, `:mcp`, `:job`, `:scenario`, `:application`
    * `:operation_id` - defaults to a new UUID
    * `:parent_operation_id` - the operation that spawned this one, if any

  Raises `ArgumentError` for unknown options or an invalid source.
  """
  @spec for_actor(%User{} | %Author{}, keyword()) :: t()
  def for_actor(actor, opts)

  def for_actor(%User{id: id} = user, opts) when is_integer(id) do
    build(:user, %{user_id: id}, account_snapshot(user), opts, @account_sources)
  end

  def for_actor(%Author{id: id} = author, opts) when is_integer(id) do
    build(:author, %{author_id: id}, account_snapshot(author), opts, @account_sources)
  end

  @doc """
  Builds a context for a fixed system actor. Any key outside the catalog raises
  `FunctionClauseError`. The source defaults to `:system`.
  """
  @spec for_system(system_key(), keyword()) :: t()
  def for_system(key, opts \\ []) when is_map_key(@system_actors, key) do
    snapshot = %{"key" => Atom.to_string(key), "label" => Map.fetch!(@system_actors, key)}

    build(
      :system,
      %{system_key: key},
      snapshot,
      Keyword.put_new(opts, :source, :system),
      @sources
    )
  end

  @doc "Returns the system actor keys."
  @spec system_keys() :: [system_key()]
  def system_keys, do: Map.keys(@system_actors) |> Enum.sort()

  @doc "Returns the display label of a system actor key."
  @spec system_label(system_key()) :: String.t()
  def system_label(key), do: Map.fetch!(@system_actors, key)

  @doc "Returns every source value accepted in the event envelope."
  @spec sources() :: [source()]
  def sources, do: @sources

  @doc """
  Serializes `context` into JSON-safe job arguments: the actor kind, ID or system key,
  snapshot, and operation ID. `from_job_args/1` rebuilds the context of the job from them.
  """
  @spec to_job_args(t()) :: map()
  def to_job_args(%__MODULE__{} = context) do
    %{
      "actor_type" => Atom.to_string(context.actor_type),
      "actor_id" => context.user_id || context.author_id,
      "system_key" => context.system_key && Atom.to_string(context.system_key),
      "actor_snapshot" => context.actor_snapshot,
      "operation_id" => context.operation_id
    }
  end

  @doc """
  Rebuilds the context of a job from the arguments of `to_job_args/1`, without a query: the
  actor keeps the snapshot taken when the job was enqueued, even if the account was deleted
  since. The job's operation is new, with source `:job`, and its parent is the operation that
  enqueued it.

  Returns `:error` for arguments that do not name a known actor kind.
  """
  @spec from_job_args(map()) :: {:ok, t()} | :error
  def from_job_args(%{"actor_type" => actor_type, "operation_id" => parent} = args) do
    with {:ok, actor} <- job_actor(actor_type, args),
         {:ok, parent} <- Ecto.UUID.cast(parent) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(actor, %{
           source: :job,
           operation_id: Ecto.UUID.generate(),
           parent_operation_id: parent
         })
       )}
    end
  end

  def from_job_args(_args), do: :error

  defp job_actor(type, %{"actor_id" => id, "actor_snapshot" => %{} = snapshot})
       when type in ["user", "author"] and is_integer(id) and id > 0 do
    {id_key, actor_type} =
      case type do
        "user" -> {:user_id, :user}
        "author" -> {:author_id, :author}
      end

    {:ok, %{actor_type: actor_type, actor_snapshot: snapshot} |> Map.put(id_key, id)}
  end

  defp job_actor("system", %{"system_key" => key}) when is_binary(key) do
    case Enum.find(Map.keys(@system_actors), &(Atom.to_string(&1) == key)) do
      nil ->
        :error

      system_key ->
        {:ok,
         %{
           actor_type: :system,
           system_key: system_key,
           actor_snapshot: %{"key" => key, "label" => Map.fetch!(@system_actors, system_key)}
         }}
    end
  end

  defp job_actor(_type, _args), do: :error

  defp build(actor_type, ids, snapshot, opts, allowed_sources) do
    opts = Keyword.validate!(opts, [:source, :operation_id, :parent_operation_id])

    source =
      with {:ok, source} <- Keyword.fetch(opts, :source),
           true <- source in allowed_sources do
        source
      else
        :error -> raise ArgumentError, "an audit source is required"
        false -> raise ArgumentError, "invalid audit source"
      end

    struct!(
      __MODULE__,
      Map.merge(ids, %{
        actor_type: actor_type,
        actor_snapshot: snapshot,
        source: source,
        operation_id: cast_uuid!(Keyword.get(opts, :operation_id, Ecto.UUID.generate())),
        parent_operation_id: cast_uuid!(Keyword.get(opts, :parent_operation_id))
      })
    )
  end

  defp account_snapshot(account), do: account |> Map.take([:id, :name, :email]) |> Snapshot.of()

  defp cast_uuid!(nil), do: nil

  defp cast_uuid!(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> uuid
      :error -> raise ArgumentError, "operation identifiers must be UUIDs"
    end
  end
end
