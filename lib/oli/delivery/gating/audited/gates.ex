defmodule Oli.Delivery.Gating.Audited.Gates do
  @moduledoc false
  # Gating condition writes: moved here from `Oli.Delivery.Gating`
  # (`create/update/delete_gating_condition_with_index`, which the gating LiveViews called, and
  # the bare `create/update/delete_gating_condition`, which Scenarios and seeders called without
  # rebuilding the index in the same transaction).
  #
  # The section is locked first, the condition (and, for a deleted gate, its student exceptions)
  # is read under the lock as the before-state, and the gating index is rebuilt only when the
  # gated top-level resource changes.

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Sections.{Section, SectionResourceMigration}
  alias Oli.Repo

  @prerequisite_types [:started, :finished, :progress]

  def create(%Context{} = context, %Section{id: section_id}, attrs) do
    # The condition belongs to `section`, whatever section `attrs` names
    changeset =
      GatingCondition.changeset(
        %GatingCondition{section_id: section_id},
        Map.drop(attrs, [:section_id, "section_id"])
      )

    case changeset.valid? do
      false ->
        {:error, changeset}

      true ->
        run(context, section_id, nil, fn nil ->
          with {:ok, gate} <- Repo.insert(changeset), do: {:ok, gate, [{nil, gate}]}
        end)
    end
  end

  def update(%Context{} = context, %Section{id: section_id}, %GatingCondition{} = gate, attrs) do
    run(context, section_id, gate.id, fn current ->
      current
      |> GatingCondition.changeset(attrs)
      |> Ecto.Changeset.validate_change(:section_id, fn :section_id, new_section_id ->
        case new_section_id == section_id do
          true -> []
          false -> [section_id: "cannot move a gate to another section"]
        end
      end)
      |> Repo.update()
      |> case do
        {:ok, updated} -> {:ok, updated, [{current, updated}]}
        error -> error
      end
    end)
  end

  def delete(%Context{} = context, %Section{id: section_id}, %GatingCondition{} = gate) do
    run(context, section_id, gate.id, fn current ->
      exceptions =
        case current.parent_id do
          nil -> Repo.all(from(gc in GatingCondition, where: gc.parent_id == ^current.id))
          _parent -> []
        end

      ids = [current.id | Enum.map(exceptions, & &1.id)]
      {_count, _} = Repo.delete_all(from(gc in GatingCondition, where: gc.id in ^ids))

      {:ok, current, Enum.map([current | exceptions], &{&1, nil})}
    end)
  end

  # `mutation` receives the condition read under the lock (`nil` for a creation) and returns
  # `{:ok, result, pairs}`, where `pairs` are the `{before, after}` states to record.
  defp run(context, section_id, gate_id, mutation) do
    case Repo.in_transaction?() do
      true ->
        {:error, :nested_transaction}

      false ->
        Repo.transaction(fn ->
          section = SectionResourceMigration.lock_section!(section_id)
          current = current_gate(section_id, gate_id)

          with {:ok, result, pairs} <- mutation.(current),
               :ok <- maybe_rebuild_index(section, current, pairs),
               :ok <- record(context, section_id, pairs) do
            result
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
    end
  end

  defp current_gate(_section_id, nil), do: nil

  defp current_gate(section_id, id) do
    case Repo.get_by(GatingCondition, id: id, section_id: section_id) do
      nil -> Repo.rollback(:gating_condition_not_found)
      gate -> gate
    end
  end

  # The index lists the resources that have a top-level gate; student exceptions do not
  # change it.
  defp maybe_rebuild_index(section, current, pairs) do
    after_gate =
      case pairs do
        [{_before, after_gate} | _exceptions] -> after_gate
        [] -> nil
      end

    case indexed_resource(current) == indexed_resource(after_gate) do
      true ->
        :ok

      false ->
        case Gating.rebuild_resource_gating_index(section) do
          {:ok, _section} -> :ok
          error -> error
        end
    end
  end

  defp indexed_resource(%GatingCondition{parent_id: nil, resource_id: resource_id}),
    do: resource_id

  defp indexed_resource(_gate), do: nil

  defp record(context, section_id, pairs) do
    pairs
    |> Enum.reduce_while({:ok, []}, fn {before, after_gate}, {:ok, changesets} ->
      case Auditing.build(context, proposal(section_id, before, after_gate)) do
        {:ok, changeset} -> {:cont, {:ok, [changeset | changesets]}}
        {:error, :no_changes} -> {:cont, {:ok, changesets}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, changesets} -> changesets |> Enum.reverse() |> Auditing.insert_all()
      error -> error
    end
  end

  defp proposal(section_id, before, after_gate) do
    %GatingCondition{} = gate = after_gate || before
    {event_type, key} = event(gate)

    %{
      event_type: event_type,
      entity: {:gating_condition, gate.id, %{id: gate.id}},
      scope: %{section_id: section_id, resource_id: gate.resource_id},
      event_key: "gating:#{gate.id}:#{key}",
      changes: Changes.diff(state(before), state(after_gate), Fields.gating())
    }
    |> put_affected(gate.user_id)
  end

  defp event(%GatingCondition{type: type}) when type in @prerequisite_types,
    do: {:prerequisite_changed, "prerequisite_changed"}

  defp event(%GatingCondition{}), do: {:gating_changed, "changed"}

  defp put_affected(proposal, nil), do: proposal
  defp put_affected(proposal, user_id), do: Map.put(proposal, :affected, {:user, user_id})

  # The recorded fields of a condition, with its data flattened (the source resource of a
  # prerequisite as `source_resource_id`).
  defp state(nil), do: nil

  defp state(%GatingCondition{} = gate) do
    data = gate.data || %{}

    %{
      type: gate.type,
      graded_resource_policy: gate.graded_resource_policy,
      parent_id: gate.parent_id,
      start_datetime: Map.get(data, :start_datetime),
      end_datetime: Map.get(data, :end_datetime),
      source_resource_id: Map.get(data, :resource_id),
      minimum_percentage: Map.get(data, :minimum_percentage)
    }
  end
end
