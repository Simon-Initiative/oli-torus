defmodule Oli.Validation.ActivityDomain.IDs do
  @moduledoc false
  alias Oli.Validation.ActivityDomain.Issue

  @doc false
  def check(slug, model) do
    entries = []
    entries = content(model["stem"], ["stem"], entries, true)
    entries = collection(model["choices"], ["choices"], entries, :definition)

    entries =
      collection(
        model["items"],
        ["items"],
        entries,
        case slug do
          "oli_likert" -> :likert_item
          _ -> :definition
        end
      )

    entries =
      list(model["inputs"], ["inputs"], entries, fn item, path, acc ->
        add(item, path, :input, acc)
      end)

    entries = collection(model["feedback"], ["feedback"], entries, :definition)
    authoring = model["authoring"]

    entries =
      list(authoring["parts"], ["parts", "authoring"], entries, fn part, path, acc ->
        role =
          case slug do
            "oli_likert" -> :likert_part
            _ -> :definition
          end

        acc = add(part, path, role, acc)
        acc = collection(part["hints"], ["hints" | path], acc, :definition)
        acc = content(part["explanation"], ["explanation" | path], acc)

        acc =
          list(part["triggers"], ["triggers" | path], acc, fn item, p, a ->
            add(item, p, :definition, a)
          end)

        list(part["responses"], ["responses" | path], acc, fn response, p, a ->
          a = add(response, p, :definition, a)
          content(response["feedback"], ["feedback" | p], a)
        end)
      end)

    entries =
      list(authoring["transformations"], ["transformations", "authoring"], entries, fn item,
                                                                                       path,
                                                                                       acc ->
        acc = add(item, path, :definition, acc)

        list(item["data"], ["data" | path], acc, fn variable, p, a ->
          add(variable, p, :definition, a)
        end)
      end)

    entries
    |> Enum.reverse()
    |> Enum.reduce({%{}, []}, fn {id, role, path}, {seen, issues} ->
      previous = Map.get(seen, id, [])

      issue =
        case {previous, length(issues) < 100} do
          {[], _} ->
            []

          {_, false} ->
            []

          {[{old_role, _}], true}
          when (old_role == :input and role == :input_ref) or
                 (old_role == :input_ref and role == :input) or
                 (old_role == :likert_item and role == :likert_part) or
                 (old_role == :likert_part and role == :likert_item) ->
            []

          {[{_, first} | _], true} ->
            [
              Issue.new(
                "duplicate_id",
                ["id" | path],
                "ID is already defined elsewhere in this activity",
                [["id" | first]]
              )
            ]
        end

      {Map.put(seen, id, Enum.take(previous ++ [{role, path}], 2)),
       Enum.take(issue ++ issues, 100)}
    end)
    |> elem(1)
    |> Enum.reverse()
    |> Enum.take(100)
  end

  defp add(%{"id" => id}, path, role, entries) when is_binary(id) or is_integer(id),
    do: [{to_string(id), role, path} | entries]

  defp add(_, _, _, entries), do: entries

  defp list(values, path, entries, fun) when is_list(values),
    do:
      values
      |> Enum.with_index()
      |> Enum.reduce(entries, fn {value, i}, acc -> fun.(value, [i | path], acc) end)

  defp list(_, _, entries, _), do: entries

  defp collection(values, path, entries, role),
    do: list(values, path, entries, fn item, p, acc -> content(item, p, acc, false, role) end)

  defp content(item, path, entries, stem \\ false, role \\ :definition)

  defp content(%{} = item, path, entries, stem, role) do
    entries = add(item, path, role, entries)

    case item["content"] do
      %{"model" => values} -> rich(values, ["model", "content" | path], entries, stem)
      value -> rich(value, ["content" | path], entries, stem)
    end
  end

  defp content(_, _, entries, _, _), do: entries

  defp rich(values, path, entries, stem) when is_list(values),
    do: list(values, path, entries, fn item, p, acc -> rich(item, p, acc, stem) end)

  defp rich(%{} = item, path, entries, stem) do
    entries =
      case {item["type"], stem} do
        {"input_ref", true} -> add(item, path, :input_ref, entries)
        {"input_ref", false} -> entries
        _ -> add(item, path, :definition, entries)
      end

    keys =
      case item["type"] do
        "popup" ->
          ["children", "content"]

        type when type in ["audio", "code", "img", "table", "iframe", "youtube"] ->
          ["children", "caption"]

        type when is_binary(type) ->
          ["children"]

        _ ->
          []
      end

    Enum.reduce(keys, entries, fn key, acc -> rich(item[key], [key | path], acc, stem) end)
  end

  defp rich(_, _, entries, _), do: entries
end
