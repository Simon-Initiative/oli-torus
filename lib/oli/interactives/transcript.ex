defmodule Oli.Interactives.Transcript do
  @moduledoc "Projects visible messages, commands and tool results into a bounded author transcript."
  @max_text 120_000
  @max_items 200
  @item_text 12_000

  @doc "Creates an empty transcript projection."
  def new, do: %{items: %{}, order: [], finals: MapSet.new()}

  @doc "Restores saved items in chronological order; completed items cannot be replaced by buffered deltas."
  def restore(items),
    do:
      Enum.reduce(
        items,
        new(),
        &put_item(&2, &1, &1["status"] in ["completed", "failed", "incomplete"])
      )

  @doc "Applies one visible event; internal reasoning and input messages are omitted."
  def apply(state, %{"item" => item} = event) when is_map(item) do
    put_item(state, item, String.ends_with?(event["type"] || "", ".done"))
  end

  def apply(state, %{"type" => type, "item_id" => id} = event) when is_binary(id) do
    case {MapSet.member?(state.finals, id), type} do
      {true, _} ->
        state

      {false, "agent.session.turn.output_text.delta"} ->
        update_text(state, id, event["content_index"] || 0, event["delta"] || "", :append)

      {false, "agent.session.turn.output_text.done"} ->
        update_text(state, id, event["content_index"] || 0, event["text"] || "", :replace)

      {false, "agent.output.command_execution_output.delta"} ->
        item = Map.get(state.items, id, %{"id" => id, "type" => "command_execution"})

        put_item(
          state,
          Map.put(item, "output", clip((item["output"] || "") <> (event["delta"] || ""))),
          false
        )

      _ ->
        state
    end
  end

  def apply(state, _), do: state

  @doc "Renders a plain-text tail; never emits provider reasoning or raw event JSON."
  def text(state) do
    state.order
    |> Enum.map(&render(state.items[&1]))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> clip()
  end

  defp update_text(state, id, index, text, operation) when is_integer(index) and index in 0..31 do
    item =
      Map.get(state.items, id, %{
        "id" => id,
        "type" => "message",
        "role" => "assistant",
        "content" => []
      })

    content = item["content"] || []

    content =
      content ++
        List.duplicate(
          %{"type" => "output_text", "text" => ""},
          max(0, index + 1 - length(content))
        )

    content =
      List.update_at(content, index, fn part ->
        value =
          case operation do
            :append -> (part["text"] || "") <> text
            :replace -> text
          end

        Map.put(part, "text", clip(value))
      end)

    put_item(state, Map.put(item, "content", content), false)
  end

  defp update_text(state, _, _, _, _), do: state

  defp put_item(state, %{"id" => id} = item, final) when is_binary(id) do
    item = bounded_item(item)

    case is_nil(item) or MapSet.member?(state.finals, id) do
      true ->
        state

      false ->
        order =
          case Map.has_key?(state.items, id) do
            true -> state.order
            false -> state.order ++ [id]
          end

        order = Enum.take(order, -@max_items)

        %{
          items: state.items |> Map.put(id, item) |> Map.take(order),
          order: order,
          finals:
            case final do
              true -> MapSet.put(state.finals, id)
              false -> state.finals
            end
            |> MapSet.intersection(MapSet.new(order))
        }
    end
  end

  defp put_item(state, _, _), do: state

  defp bounded_item(%{"type" => "message", "role" => "assistant"} = item) do
    case item["phase"] in [nil, "commentary", "final_answer"] do
      false ->
        nil

      true ->
        {parts, _} =
          (item["content"] || [])
          |> Enum.reverse()
          |> Enum.map_reduce(@item_text, fn part, remaining ->
            text =
              case part["type"] do
                "output_text" -> part["text"] || ""
                _ -> ""
              end

            text = tail(text, remaining)
            {%{"type" => "output_text", "text" => text}, remaining - String.length(text)}
          end)

        item |> Map.take(~w(id type role phase status)) |> Map.put("content", Enum.reverse(parts))
    end
  end

  defp bounded_item(%{"type" => "command_execution"} = item) do
    item
    |> Map.take(~w(id type status))
    |> Map.put("command", tail(item["command"] || "Running command…", 2_000))
    |> Map.put("output", tail(item["output"] || "", @item_text))
  end

  defp bounded_item(%{"type" => "function_call"} = item),
    do: Map.take(item, ~w(id type name status))

  defp bounded_item(%{"type" => "function_call_output"} = item) do
    output =
      case item["output"] do
        value when is_binary(value) ->
          value

        value when is_list(value) ->
          Enum.filter(value, &(&1["type"] == "input_text"))
          |> Enum.map_join("\n", &(&1["text"] || ""))

        _ ->
          ""
      end

    item |> Map.take(~w(id type status)) |> Map.put("output", tail(output, @item_text))
  end

  defp bounded_item(_), do: nil

  defp render(%{"type" => "message", "role" => "assistant"} = item) do
    case item["phase"] in [nil, "commentary", "final_answer"] do
      true ->
        (item["content"] || [])
        |> Enum.filter(&(&1["type"] == "output_text"))
        |> Enum.map_join("", &(&1["text"] || ""))

      false ->
        ""
    end
  end

  defp render(%{"type" => "command_execution"} = item) do
    "$ #{item["command"] || "Running command…"}\n#{item["output"] || ""}"
  end

  defp render(%{"type" => "function_call"} = item),
    do: "Tool: #{item["name"]} (#{item["status"] || "running"})"

  defp render(%{"type" => "function_call_output"} = item) do
    output =
      case item["output"] do
        value when is_binary(value) ->
          value

        value when is_list(value) ->
          Enum.filter(value, &(&1["type"] == "input_text"))
          |> Enum.map_join("\n", &(&1["text"] || ""))

        _ ->
          ""
      end

    "Tool result: #{output}"
  end

  defp render(_), do: ""
  defp clip(text), do: tail(text, @max_text)
  defp tail(text, limit), do: String.slice(text, max(String.length(text) - limit, 0), limit)
end
