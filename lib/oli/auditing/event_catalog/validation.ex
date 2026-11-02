defmodule Oli.Auditing.EventCatalog.Validation do
  @moduledoc """
  Validates a version 2 audit row against the envelope rules and its event contract.

  The input is a map keyed by column name (atoms), as `Oli.Auditing.build/2` prepares it before
  casting. Enumerated columns may be atoms or strings. Error messages name columns and fields,
  never submitted values.
  """

  alias Oli.Auditing.{Changes, Context, Sensitive, Snapshot}
  alias Oli.Auditing.EventCatalog
  alias Oli.Auditing.EventCatalog.Contract

  @outcomes ~w(succeeded initiated failed canceled partial unknown)a
  @ref_roles ~w(scope source previous resulting linked provider)a
  @event_key ~r/^[a-z0-9_]+(:[a-z0-9_\-]+)*$/
  @type_name ~r/^[a-z][a-z0-9_]{1,63}$/
  @scope_columns ~w(project_id section_id resource_id institution_id)a
  @max_details_bytes 16_384
  # Larger than details: each field keeps its value before and after, and some are long texts.
  @max_changes_bytes 65_536
  @actor_snapshot_fields %{
    user: ~w(id name email),
    author: ~w(id name email),
    system: ~w(key label)
  }

  @type error :: {atom(), String.t()}

  @doc "Returns every outcome accepted in the envelope."
  @spec outcomes() :: [atom()]
  def outcomes, do: @outcomes

  @doc "Returns every reference role accepted in `refs`."
  @spec ref_roles() :: [atom()]
  def ref_roles, do: @ref_roles

  @doc "Returns the maximum serialized size of `details`, in bytes."
  @spec max_details_bytes() :: pos_integer()
  def max_details_bytes, do: @max_details_bytes

  @doc "Returns the maximum serialized size of `changes`, in bytes."
  @spec max_changes_bytes() :: pos_integer()
  def max_changes_bytes, do: @max_changes_bytes

  @doc """
  Validates `attrs`. Returns `:ok`, `{:error, :no_changes}` for an empty change set on a
  `:skip` contract, or `{:error, errors}`.
  """
  @spec validate(map()) :: :ok | {:error, :no_changes | [error()]}
  def validate(attrs) when is_map(attrs) do
    case contract_for(attrs) do
      {:ok, contract} ->
        errors =
          [
            &validate_envelope/2,
            &validate_actor/2,
            &validate_entity/2,
            &validate_scope/2,
            &validate_affected/2,
            &validate_outcome/2,
            &validate_refs/2,
            &validate_details/2,
            &validate_changes/2
          ]
          |> Enum.flat_map(& &1.(contract, attrs))

        case errors do
          [] -> no_op(contract, attrs)
          errors -> {:error, errors}
        end

      {:error, error} ->
        {:error, [error]}
    end
  end

  defp contract_for(attrs) do
    with {:ok, name} <- EventCatalog.cast_name(Map.get(attrs, :event_type)),
         {:ok, %Contract{v1_only: false, deprecated: false} = contract} <-
           EventCatalog.fetch(name) do
      {:ok, contract}
    else
      {:ok, %Contract{}} -> {:error, {:event_type, "is not accepted for new events"}}
      _ -> {:error, {:event_type, "is not a catalog event"}}
    end
  end

  defp validate_envelope(_contract, attrs) do
    [
      check(match?(%DateTime{}, Map.get(attrs, :occurred_at)), :occurred_at, "is required"),
      check(uuid?(Map.get(attrs, :operation_id)), :operation_id, "must be a UUID"),
      check(
        is_nil(Map.get(attrs, :parent_operation_id)) or
          uuid?(Map.get(attrs, :parent_operation_id)),
        :parent_operation_id,
        "must be a UUID"
      ),
      check(event_key?(Map.get(attrs, :event_key)), :event_key, "has an invalid format"),
      check(member?(Map.get(attrs, :source), Context.sources()), :source, "is not allowed"),
      check(
        is_nil(Map.get(attrs, :legacy_source)),
        :legacy_source,
        "is only allowed on migrated history"
      ),
      check(is_nil(Map.get(attrs, :legacy_id)), :legacy_id, "is only allowed on migrated history")
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp validate_actor(contract, attrs) do
    kind = attrs |> Map.get(:actor_type) |> cast_member(~w(user author system)a)
    user_id = Map.get(attrs, :user_id)
    author_id = Map.get(attrs, :author_id)
    actor_key = Map.get(attrs, :actor_key)

    shape_ok =
      case kind do
        :user ->
          positive_id?(user_id) and is_nil(author_id) and is_nil(actor_key)

        :author ->
          positive_id?(author_id) and is_nil(user_id) and is_nil(actor_key)

        :system ->
          member?(actor_key, Context.system_keys()) and is_nil(user_id) and is_nil(author_id)

        _ ->
          false
      end

    snapshot = Map.get(attrs, :actor_snapshot, %{})

    snapshot_error =
      with :ok <- Snapshot.validate(snapshot),
           :ok <- validate_actor_snapshot_fields(kind, snapshot) do
        nil
      else
        {:error, message} -> {:actor_snapshot, message}
      end

    [
      check(shape_ok, :actor_type, "must identify exactly one user, author, or system actor"),
      check(kind in contract.actor_kinds, :actor_type, "is not allowed for this event"),
      snapshot_error
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Account actors keep id, name, and email; system actors keep their key and label.
  defp validate_actor_snapshot_fields(kind, snapshot) do
    case Map.fetch(@actor_snapshot_fields, kind) do
      {:ok, fields} ->
        case Enum.reject(Map.keys(snapshot), &(&1 in fields)) do
          [] -> :ok
          _ -> {:error, "has fields that do not apply to a #{kind} actor"}
        end

      :error ->
        :ok
    end
  end

  defp validate_entity(contract, attrs) do
    entity_type = Map.get(attrs, :entity_type)
    entity_id = Map.get(attrs, :entity_id)

    snapshot_error =
      case Snapshot.validate(Map.get(attrs, :entity_snapshot, %{})) do
        :ok -> nil
        {:error, message} -> {:entity_snapshot, message}
      end

    [
      check(
        member?(entity_type, contract.entity_types) and
          Regex.match?(@type_name, to_string(entity_type)),
        :entity_type,
        "is not allowed for this event"
      ),
      check(
        Snapshot.valid_text?(entity_id) and entity_id != "",
        :entity_id,
        "must be 1 to 255 characters"
      ),
      snapshot_error
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp validate_scope(contract, attrs) do
    present = Enum.filter(@scope_columns, &positive_id?(Map.get(attrs, &1)))

    invalid =
      for column <- @scope_columns,
          not is_nil(Map.get(attrs, column)),
          column not in present,
          do: {column, "must be a positive integer"}

    missing = for column <- contract.required, column not in present, do: {column, "is required"}

    one_of =
      case contract.required_one_of do
        [] ->
          []

        columns ->
          case Enum.any?(columns, &(&1 in present)) do
            true -> []
            false -> [{hd(columns), "one of #{Enum.join(columns, ", ")} is required"}]
          end
      end

    invalid ++ missing ++ one_of
  end

  defp validate_affected(contract, attrs) do
    user = Map.get(attrs, :affected_user_id)
    author = Map.get(attrs, :affected_author_id)
    present = Enum.reject([user: user, author: author], fn {_kind, id} -> is_nil(id) end)

    disallowed =
      for {kind, _id} <- present,
          kind not in contract.affected_kinds,
          do: {affected_column(kind), "is not allowed for this event"}

    invalid =
      for {kind, id} <- present, not positive_id?(id), do: {affected_column(kind), "is invalid"}

    required =
      case contract.affected_required and present == [] do
        true -> [{affected_column(hd(contract.affected_kinds)), "an affected person is required"}]
        false -> []
      end

    subject =
      case contract.subject_is_affected do
        true -> validate_subject(attrs, present)
        false -> []
      end

    disallowed ++ invalid ++ required ++ subject
  end

  defp validate_subject(attrs, present) do
    entity_type = Map.get(attrs, :entity_type)
    entity_id = Map.get(attrs, :entity_id)

    case Enum.find(present, fn {kind, _id} -> member?(entity_type, [kind]) end) do
      {_kind, id} when is_integer(id) and is_binary(entity_id) ->
        check_list(
          entity_id == Integer.to_string(id),
          :entity_id,
          "must equal the affected account"
        )

      _ ->
        [{:entity_id, "must equal the affected account"}]
    end
  end

  defp validate_outcome(contract, attrs) do
    check_list(
      member?(Map.get(attrs, :outcome), contract.outcomes),
      :outcome,
      "is not allowed for this event"
    )
  end

  defp validate_refs(contract, attrs) do
    case Map.get(attrs, :refs, []) do
      refs when is_list(refs) ->
        refs
        |> Enum.with_index()
        |> Enum.flat_map(fn {ref, index} -> validate_ref(contract, ref, index) end)

      _ ->
        [{:refs, "must be a list"}]
    end
  end

  defp validate_ref(contract, %{} = ref, index) do
    role = Map.get(ref, "role")
    type = Map.get(ref, "type")
    id = Map.get(ref, "id")
    label = Map.get(ref, "label")

    valid =
      Enum.all?(Map.keys(ref), &(&1 in ~w(role type id label))) and
        member?(role, contract.ref_roles) and
        is_binary(type) and Regex.match?(@type_name, type) and
        (positive_id?(id) or (Snapshot.valid_text?(id) and id != "")) and
        (is_nil(label) or Snapshot.valid_text?(label))

    check_list(valid, :refs, "entry #{index} is invalid for this event")
  end

  defp validate_ref(_contract, _ref, index), do: [{:refs, "entry #{index} must be a map"}]

  defp validate_details(contract, attrs) do
    details = Map.get(attrs, :details, %{})

    case is_map(details) and not is_struct(details) do
      false ->
        [{:details, "must be a map"}]

      true ->
        unknown =
          details
          |> Map.keys()
          |> Enum.reject(&(is_binary(&1) and &1 in contract.detail_keys))
          |> Enum.map(fn
            key when is_binary(key) -> {:details, "unknown key #{key}"}
            _key -> {:details, "keys must be strings"}
          end)

        secret =
          case Sensitive.find_key(details) do
            nil -> []
            path -> [{:details, "contains a secret-looking key at #{Enum.join(path, ".")}"}]
          end

        values =
          details
          |> Enum.reject(fn {key, value} -> not is_binary(key) or detail_value?(value, 2) end)
          |> Enum.map(fn {key, _value} -> {:details, "key #{key} has an unsupported value"} end)

        size =
          with true <- unknown == [] and values == [],
               {:ok, json} <- Jason.encode(details),
               true <- byte_size(json) > @max_details_bytes do
            [{:details, "exceed #{@max_details_bytes} bytes"}]
          else
            {:error, _} -> [{:details, "must be JSON-encodable"}]
            false -> []
          end

        unknown ++ secret ++ values ++ size
    end
  end

  # Keys are limited by the contract, but values can be long user text, so the serialized size is
  # capped too; the cap also bounds nesting in practice.
  defp validate_changes(contract, attrs) do
    changes = Map.get(attrs, :changes, %{})

    with :ok <- Changes.validate(changes, contract.change_fields),
         {:ok, json} <- Jason.encode(changes),
         true <- byte_size(json) > @max_changes_bytes do
      [{:changes, "exceed #{@max_changes_bytes} bytes"}]
    else
      {:error, message} when is_binary(message) -> [{:changes, message}]
      {:error, _encode_error} -> [{:changes, "must be JSON-encodable"}]
      false -> []
    end
  end

  defp no_op(%Contract{no_op: :skip}, attrs) do
    case Map.get(attrs, :changes, %{}) == %{} do
      true -> {:error, :no_changes}
      false -> :ok
    end
  end

  defp no_op(_contract, _attrs), do: :ok

  defp detail_value?(value, _depth) when is_binary(value), do: String.valid?(value)

  defp detail_value?(value, _depth) when is_number(value) or is_boolean(value) or is_nil(value),
    do: true

  defp detail_value?(list, _depth) when is_list(list), do: scalar_list?(list)

  defp detail_value?(map, depth) when is_map(map) and not is_struct(map) and depth > 0,
    do: Enum.all?(map, fn {key, value} -> is_binary(key) and detail_value?(value, depth - 1) end)

  defp detail_value?(_value, _depth), do: false

  defp scalar_list?([]), do: true
  defp scalar_list?([head | tail]), do: detail_value?(head, 0) and scalar_list?(tail)
  defp scalar_list?(_improper_tail), do: false

  defp event_key?(key),
    do: is_binary(key) and byte_size(key) in 1..200 and Regex.match?(@event_key, key)

  defp uuid?(value), do: match?({:ok, _}, Ecto.UUID.cast(value))

  defp positive_id?(id), do: is_integer(id) and id > 0

  defp affected_column(:user), do: :affected_user_id
  defp affected_column(:author), do: :affected_author_id

  defp member?(value, allowed) when is_atom(value) and not is_nil(value), do: value in allowed

  defp member?(value, allowed) when is_binary(value),
    do: Enum.any?(allowed, &(Atom.to_string(&1) == value))

  defp member?(_value, _allowed), do: false

  defp cast_member(value, allowed) when is_atom(value),
    do: Enum.find(allowed, &(&1 == value))

  defp cast_member(value, allowed) when is_binary(value),
    do: Enum.find(allowed, &(Atom.to_string(&1) == value))

  defp cast_member(_value, _allowed), do: nil

  defp check(true, _column, _message), do: nil
  defp check(_false, column, message), do: {column, message}

  defp check_list(condition, column, message) do
    case check(condition, column, message) do
      nil -> []
      error -> [error]
    end
  end
end
