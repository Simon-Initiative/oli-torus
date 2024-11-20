defmodule Oli.Activities.Realizer.Selection do
  @moduledoc """
  Represents a selection embedded within a page.
  """

  @derive Jason.Encoder
  @enforce_keys [:id, :count, :logic, :purpose, :type]
  defstruct [:id, :count, :logic, :purpose, :type]

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Selection
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Executor
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Logic.Expression

  @type t() :: %__MODULE__{
          id: String.t(),
          count: integer(),
          logic: %Logic{},
          purpose: String.t(),
          type: String.t()
        }

  def parse(%{"count" => count, "id" => id, "logic" => logic} = json) do
    case Logic.parse(logic) do
      {:ok, logic} ->
        purpose = Map.get(json, "purpose", "none")

        {:ok, %Selection{id: id, count: count, logic: logic, purpose: purpose, type: "selection"}}

      e ->
        e
    end
  end

  def parse(_) do
    {:error, "invalid selection"}
  end

  @doc """
  Fulfills a selection by querying the database for matching activities.

  Returns {:ok, %Result{}} when the selection is filled.

  Returns {:partial, %Result{}} when the query succeeds but less than the requested
  count of activities is returned.  This includes the case where zero activities are returned.

  Returns {:error, e} on a failure to execute the query.
  """
  def fulfill(%Selection{count: count} = selection, %Source{bank: nil} = source) do
    run(selection, source, %Paging{limit: count, offset: 0})
  end

  def fulfill(%Selection{count: count} = selection, %Source{} = source) do
    {all, _} = fulfill_from_bank(selection, source)
    returned_count = Enum.count(all)

    if returned_count < count do
      {:partial, %Result{rows: all, rowCount: returned_count, totalCount: returned_count}}
    else
      {:ok, %Result{rows: all, rowCount: returned_count, totalCount: returned_count}}
    end
  end

  def fulfill_from_bank(%Selection{count: count} = selection, %Source{bank: bank} = source) do
    blacklisted = MapSet.new(source.blacklisted_activity_ids)

    {func, expressions} =
      case selection.logic.conditions do
        nil -> {&Enum.all?/2, []}
        %Logic.Clause{children: children, operator: :all} -> {&Enum.all?/2, children}
        %Logic.Clause{children: children} -> {&Enum.any?/2, children}
        %Logic.Expression{} = e -> {&Enum.all?/2, [e]}
      end

    Enum.reduce_while(bank, {[], 1}, fn activity, {all, total} ->
      case !MapSet.member?(blacklisted, activity.resource_id) and
             func.(expressions, &evaluate_expression(&1, activity)) do
        true ->
          if total == count do
            {:halt, {[activity | all], total + 1}}
          else
            {:cont, {[activity | all], total + 1}}
          end

        false ->
          {:cont, {all, total}}
      end
    end)
  end

  defp evaluate_expression(%Expression{fact: :tags} = e, activity) do
    do_evaluate_expression(e, activity, :tags)
  end

  defp evaluate_expression(%Expression{fact: :objectives} = e, activity) do
    do_evaluate_expression(e, activity, :objectives)
  end

  defp evaluate_expression(%Expression{fact: :type, operator: operator, value: value}, activity) do
    case operator do
      :contains ->
        MapSet.new([activity.activity_type_id]) |> MapSet.subset?(MapSet.new(value))

      :does_not_contain ->
        MapSet.new([activity.activity_type_id]) |> MapSet.subset?(MapSet.new(value)) |> Kernel.!()

      :equals ->
        value == activity.activity_type_id

      :does_not_equal ->
        value != activity.activity_type_id
    end
  end

  defp do_evaluate_expression(%Expression{operator: operator, value: value}, activity, field) do
    case operator do
      :contains ->
        MapSet.new(value) |> MapSet.subset?(Map.get(activity, field))

      :does_not_contain ->
        MapSet.new(value) |> MapSet.subset?(Map.get(activity, field)) |> Kernel.!()

      :equals ->
        MapSet.equal?(Map.get(activity, field), MapSet.new(value))

      :does_not_equal ->
        !MapSet.equal?(Map.get(activity, field), MapSet.new(value))
    end
  end

  @doc """
  Tests the fulfillment of a selection by querying the database for matching activities.

  Returns {:ok, %Result{}} when the selection is filled.

  Returns {:partial, %Result{}} when the query succeeds but less than the requested
  count of activities is returned.  This includes the case where zero activities are returned.

  Returns {:error, e} on a failure to execute the query.
  """
  def test(%Selection{} = selection, %Source{} = source) do
    run(selection, source, %Paging{limit: selection.count, offset: 0})
  end

  defp run(%Selection{count: count, logic: logic}, %Source{} = source, %Paging{} = paging) do
    case Builder.build(logic, source, paging, :random)
         |> Executor.execute() do
      {:ok, %Result{totalCount: ^count} = result} ->
        {:ok, result}

      {:ok, result} ->
        {:partial, result}

      e ->
        e
    end
  end
end
