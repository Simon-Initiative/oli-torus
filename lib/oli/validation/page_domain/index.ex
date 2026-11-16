defmodule Oli.Validation.PageDomain.Index do
  @moduledoc false
  alias Oli.Activities.Realizer.Logic
  alias Oli.Validation.ActivityDomain.Issue

  @max_resource_id 9_223_372_036_854_775_807

  @doc false
  def collect(content),
    do: walk(content, [], :content, %{ids: %{}, references: [], issues: [], issue_count: 0})

  @doc false
  def issue(state, code, path, message, related \\ [])
  def issue(%{issue_count: 100} = state, _, _, _, _), do: state

  def issue(state, code, path, message, related),
    do: %{
      state
      | issues: [Issue.new(code, path, message, related) | state.issues],
        issue_count: state.issue_count + 1
    }

  defp walk(value, path, context, state) when is_map(value) do
    state = state |> identity(value, path) |> references(value, path, context)

    value
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce(state, fn {key, child}, acc ->
      child_context =
        case {value["type"], key, context} do
          {"selection", "logic", _} -> :logic
          {"learning_objectives", "learning_objectives", _} -> :objectives
          {_, _, :logic} -> :logic
          {_, _, :objectives} -> :objectives
          _ -> :content
        end

      walk(child, [key | path], child_context, acc)
    end)
  end

  defp walk(values, path, context, state) when is_list(values),
    do:
      values
      |> Enum.with_index()
      |> Enum.reduce(state, fn {value, i}, acc -> walk(value, [i | path], context, acc) end)

  defp walk(_, _, _, state), do: state

  defp identity(state, %{"id" => id}, path) when is_binary(id) or is_integer(id) do
    key = to_string(id)
    here = ["id" | path]

    case Map.fetch(state.ids, key) do
      {:ok, first} ->
        issue(state, "duplicate_id", here, "ID is already defined in this page", [first])

      :error ->
        %{state | ids: Map.put(state.ids, key, here)}
    end
  end

  defp identity(state, _, _), do: state

  defp references(state, %{"fact" => fact, "value" => values}, path, :logic)
       when fact in ["tags", "objectives"] and is_list(values),
       do:
         reference_list(
           state,
           values,
           ["value" | path],
           case fact do
             "tags" -> "tag"
             _ -> "objective"
           end
         )

  defp references(state, %{"fact" => "type", "value" => values}, path, :logic)
       when is_list(values) do
    case Enum.all?(values, &(is_integer(&1) and &1 > 0)) do
      true ->
        state

      false ->
        issue(
          state,
          "invalid_logic_value",
          ["value" | path],
          "Activity type operands must be positive registration IDs"
        )
    end
  end

  defp references(state, value, path, :objectives) do
    state = optional_reference(state, value, "resource_id", "objective", path)
    state = optional_list(state, value, "revisit_pages", "page", path)
    optional_list(state, value, "practice_pages", "page", path)
  end

  defp references(state, value, path, _) do
    state =
      case {path, value} do
        {[], _} -> optional_list(state, value, "bibrefs", "bibentry", path)
        _ -> state
      end

    case value["type"] do
      "activity-reference" -> optional_reference(state, value, "activity_id", "activity", path)
      "report" -> optional_reference(state, value, "activityId", "activity", path)
      "alternatives" -> optional_reference(state, value, "alternatives_id", "alternatives", path)
      "cite" -> optional_reference(state, value, "bibref", "bibentry", path)
      "page_link" -> optional_reference(state, value, "idref", "page", path)
      "selection" -> selection(state, value, path)
      _ -> state
    end
  end

  defp selection(state, value, path) do
    state =
      case value["count"] do
        n when is_integer(n) and n > 0 ->
          state

        _ ->
          issue(
            state,
            "invalid_selection_count",
            ["count" | path],
            "Selection count must be a positive integer"
          )
      end

    case valid_logic?(value) do
      true ->
        state

      false ->
        issue(
          state,
          "invalid_selection_logic",
          ["logic" | path],
          "Selection logic cannot be parsed by the activity bank"
        )
    end
  end

  defp valid_logic?(%{"logic" => logic}) do
    case Logic.parse(logic) do
      {:ok, _} -> true
      _ -> false
    end
  rescue
    _ in [FunctionClauseError, BadMapError, CaseClauseError] -> false
  end

  defp valid_logic?(_), do: false

  defp optional_reference(state, value, key, type, path) do
    case Map.fetch(value, key) do
      {:ok, id} -> reference(state, id, type, [key | path])
      :error -> state
    end
  end

  defp optional_list(state, value, key, type, path) do
    case Map.get(value, key) do
      values when is_list(values) -> reference_list(state, values, [key | path], type)
      _ -> state
    end
  end

  defp reference_list(state, values, path, type),
    do:
      values
      |> Enum.with_index()
      |> Enum.reduce(state, fn {id, i}, acc -> reference(acc, id, type, [i | path]) end)

  defp reference(state, id, type, path) do
    case resource_id(id) do
      {:ok, id} ->
        %{state | references: [{id, type, path} | state.references]}

      :error ->
        issue(state, "invalid_resource_id", path, "Expected a positive integer resource ID")
    end
  end

  defp resource_id(id) when is_integer(id) and id > 0 and id <= @max_resource_id, do: {:ok, id}

  defp resource_id(id) when is_binary(id) and byte_size(id) in 1..19 do
    case Integer.parse(id) do
      {value, ""} when value > 0 and value <= @max_resource_id ->
        case String.match?(id, ~r/\A[0-9]+\z/) do
          true -> {:ok, value}
          false -> :error
        end

      _ ->
        :error
    end
  end

  defp resource_id(_), do: :error
end
