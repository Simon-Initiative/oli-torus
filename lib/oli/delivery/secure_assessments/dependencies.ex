defmodule Oli.Delivery.SecureAssessments.Dependencies do
  @moduledoc "Pinned, attempt-owned projections of adaptive shared inputs. Never grants global storage access."
  import Ecto.Query
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ActivityAttempt, ResourceAccess}
  alias Oli.Delivery.{ExtrinsicState, TextBlob}
  @snapshot "__secure_shared"

  @doc "Returns only shared namespaces explicitly declared or referenced in pinned assessment content."
  def manifest(attempt) do
    attempt = Repo.preload(attempt, :revision)

    activities =
      Repo.all(
        from a in ActivityAttempt,
          join: r in assoc(a, :revision),
          where: a.resource_attempt_id == ^attempt.id,
          distinct: r.id,
          select: r.content
      )

    content = attempt.revision.content
    declared = get_in(content, ["custom", "everApps"]) || []

    ids =
      Enum.flat_map(declared, fn
        %{"id" => id} when is_binary(id) -> [id]
        _ -> []
      end)

    referenced =
      Regex.scan(~r/\bapp\.([\w-]+)\./, Jason.encode!([content | activities]),
        capture: :all_but_first
      )
      |> List.flatten()

    Enum.uniq(ids ++ referenced)
    |> Enum.reject(&(&1 in ["active", "__proto__", "constructor", "prototype"]))
  end

  @doc "Reads the immutable shared-input snapshot plus this attempt's updates; review never seeds or writes."
  def read_shared(guid, user, keys \\ nil) do
    with %ResourceAttempt{} = attempt <- Repo.one(owned_attempt_query(guid, user)) do
      allowed = manifest(attempt)
      keys = keys || allowed

      case valid_keys?(keys, allowed) do
        false ->
          {:error, :dependency_not_allowed}

        true ->
          case Map.fetch(attempt.state || %{}, @snapshot) do
            {:ok, snapshot} -> {:ok, Map.take(snapshot, keys)}
            :error -> seed_snapshot(attempt, user, allowed, keys)
          end
      end
    else
      nil -> {:error, :not_found}
    end
  end

  # Storage calls must not hold a database connection or block finalization.
  # The short transaction below rechecks current lifecycle and never replaces
  # another request's snapshot or a newer relational state update.
  defp seed_snapshot(attempt, user, allowed, keys) do
    result =
      case attempt.lifecycle_state do
        :active -> shared_inputs(user, allowed)
        _ -> {:ok, %{}}
      end

    with {:ok, inputs} <- result,
         {:ok, saved} <- saved_state(attempt) do
      Repo.transaction(fn ->
        current = owned_attempt!(attempt.attempt_guid, user)
        state = current.state || %{}

        snapshot =
          case Map.fetch(state, @snapshot) do
            {:ok, snapshot} ->
              snapshot

            :error ->
              from_attempt = unflatten(Map.merge(saved, state), allowed)

              case current.lifecycle_state do
                :active ->
                  initial = merge_namespaces(inputs, from_attempt)

                  Repo.update!(
                    Ecto.Changeset.change(current, state: Map.put(state, @snapshot, initial))
                  )

                  initial

                _ ->
                  from_attempt
              end
          end

        Map.take(snapshot, keys)
      end)
    end
  end

  defp saved_state(attempt) do
    case Application.get_env(:oli, :blob_storage)[:use_deprecated_api] do
      true ->
        {:ok, attempt.state || %{}}

      _ ->
        with {:ok, text} <- TextBlob.Storage.read_dependency(attempt.attempt_guid, "{}"),
             {:ok, state} when is_map(state) <- Jason.decode(text) do
          {:ok, state}
        else
          _ -> {:error, :dependency_unavailable}
        end
    end
  end

  @doc "Writes declared shared keys to this active attempt only, never the learner's global values."
  def write_shared(guid, user, updates) when is_map(updates) and map_size(updates) <= 100 do
    with {:ok, _} <- read_shared(guid, user, Map.keys(updates)) do
      Repo.transaction(fn ->
        attempt = owned_attempt!(guid, user)

        case attempt.lifecycle_state do
          :active ->
            snapshot = Map.get(attempt.state, @snapshot, %{})

            merged = merge_namespaces(snapshot, updates)

            Repo.update!(
              Ecto.Changeset.change(attempt, state: Map.put(attempt.state, @snapshot, merged))
            )

            Map.take(merged, Map.keys(updates))

          _ ->
            Repo.rollback(:review_not_allowed)
        end
      end)
    end
  end

  def write_shared(_, _, _), do: {:error, :invalid_batch}

  @doc "Merges this attempt's shared snapshot into its normal adaptive page-state payload."
  def page_state(attempt, state) do
    snapshot = Map.get(Repo.reload!(attempt).state || %{}, @snapshot, %{})
    Map.merge(state, flatten(snapshot)) |> Map.delete(@snapshot)
  end

  defp valid_keys?(keys, allowed),
    do: is_list(keys) and length(keys) <= 100 and Enum.all?(keys, &(&1 in allowed))

  defp owned_attempt!(guid, user) do
    case Repo.one(from r in owned_attempt_query(guid, user), lock: "FOR UPDATE OF r0") do
      nil -> Repo.rollback(:not_found)
      attempt -> attempt
    end
  end

  defp owned_attempt_query(guid, user) do
    from r in ResourceAttempt,
      join: access in ResourceAccess,
      on: access.id == r.resource_access_id,
      where: r.attempt_guid == ^guid and access.user_id == ^user.id,
      select: r
  end

  defp merge_namespaces(left, right) do
    Map.merge(left, right, fn _, old, new ->
      case is_map(old) and is_map(new) do
        true -> Map.merge(old, new)
        false -> new
      end
    end)
  end

  defp shared_inputs(user, keys) do
    case Application.get_env(:oli, :blob_storage)[:use_deprecated_api] do
      true ->
        ExtrinsicState.read_global(user.id, MapSet.new(keys))

      _ ->
        keys
        |> Task.async_stream(
          fn key ->
            with {:ok, text} <- TextBlob.read_dependency(user, key, "{}"),
                 {:ok, value} <- Jason.decode(text) do
              {:ok, {key, value}}
            else
              _ -> {:error, :dependency_unavailable}
            end
          end,
          max_concurrency: 4,
          timeout: 10_000,
          on_timeout: :kill_task
        )
        |> Enum.reduce_while({:ok, %{}}, fn
          {:ok, {:ok, {key, value}}}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, key, value)}}
          _, _ -> {:halt, {:error, :dependency_unavailable}}
        end)
    end
  end

  defp flatten(snapshot),
    do:
      Enum.reduce(snapshot, %{}, fn
        {namespace, values}, acc when is_map(values) ->
          Enum.reduce(values, acc, fn {key, value}, acc ->
            Map.put(acc, "app.#{namespace}.#{key}", value)
          end)

        _, acc ->
          acc
      end)

  defp unflatten(state, allowed),
    do:
      Enum.reduce(state, %{}, fn {key, value}, acc ->
        case String.split(key, ".", parts: 3) do
          ["app", namespace, subkey] ->
            case namespace in allowed do
              true -> Map.update(acc, namespace, %{subkey => value}, &Map.put(&1, subkey, value))
              false -> acc
            end

          _ ->
            acc
        end
      end)
end
