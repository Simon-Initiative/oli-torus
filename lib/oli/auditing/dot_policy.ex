defmodule Oli.Auditing.DotPolicy do
  @moduledoc """
  Projects the DOT activation points (triggers) authored in page and activity content into a
  list that audit events can compare, and builds the `triggers` change record from two of them.

  `triggers/1` returns one entry per trigger, sorted by `"path"`:

      %{"path" => "group:3a9f", "trigger_type" => "group", "prompt" => "Summarize the group"}

  Paths identify a trigger by where it is authored, so an edit can be compared trigger by
  trigger:

    * `"page"` - the page trigger, `content["trigger"]`.
    * `"group:<id>"` - the trigger of a `group` element of the page model.
    * `"content:<id>"` - a `trigger` element inside a `content` block of the page model.
    * `"part:<part id>:<trigger id>"` - a trigger of an activity part
      (`content["authoring"]["parts"][*]["triggers"]`).
    * `"part:<part id>"` - an adaptive part that starts DOT: a `janus-ai-trigger` part, or a part
      with `custom.enableAiTrigger` (from `partsLayout` and `authoring.parts`).
    * `"rule:<rule>:<index>"` - an `activationPoint` action of an adaptive rule, keyed by the
      rule's event type and the action's position, since actions have no ID.

  Prompts are recorded up to #{2_000} characters; a longer prompt is cut and its entry carries
  `"prompt_truncated" => true`.

  Section and recommendation settings use the `Oli.Auditing.EventCatalog.Fields.dot_activation/0`
  policy. Extend that policy, and this projection for new trigger locations, instead of defining
  another one.
  """

  @max_prompt 2_000

  @type trigger :: %{required(String.t()) => String.t() | boolean() | nil}

  @doc """
  Returns the triggers authored in `content` (a page or activity content map), sorted by path.
  """
  @spec triggers(map() | nil) :: [trigger()]
  def triggers(content) when is_map(content) do
    [
      page_trigger(content),
      model_triggers(Map.get(content, "model")),
      part_triggers(content),
      adaptive_part_triggers(content),
      activation_points(content)
    ]
    |> List.flatten()
    |> Enum.uniq_by(& &1["path"])
    |> Enum.sort_by(& &1["path"])
  end

  def triggers(_content), do: []

  @doc """
  Returns the `triggers` change record between two projections from `triggers/1`, or an empty
  map when they are equal. Only triggers that were added, removed, or changed are recorded:
  `"before"` lists the changed and removed ones as they were, `"after"` the changed and added
  ones as they are.

      iex> Oli.Auditing.DotPolicy.changes([], [%{"path" => "page", "trigger_type" => "page", "prompt" => "Hi"}])
      %{"triggers" => %{"operation" => "set", "before" => [],
        "after" => [%{"path" => "page", "trigger_type" => "page", "prompt" => "Hi"}]}}
  """
  @spec changes([trigger()], [trigger()]) :: map()
  def changes(before, after_state) do
    before = Map.new(before, &{&1["path"], &1})
    after_state = Map.new(after_state, &{&1["path"], &1})

    changed =
      (Map.keys(before) ++ Map.keys(after_state))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.reject(&(Map.get(before, &1) == Map.get(after_state, &1)))

    case changed do
      [] ->
        %{}

      paths ->
        %{
          "triggers" => %{
            "operation" => "set",
            "before" => Enum.flat_map(paths, &List.wrap(Map.get(before, &1))),
            "after" => Enum.flat_map(paths, &List.wrap(Map.get(after_state, &1)))
          }
        }
    end
  end

  defp page_trigger(%{"trigger" => %{} = trigger}), do: [entry("page", trigger)]
  defp page_trigger(_content), do: []

  # Group triggers sit on `group` elements; content triggers are inline elements nested in the
  # children of `content` blocks, which `Oli.Resources.PageContent` does not walk.
  defp model_triggers(elements) when is_list(elements),
    do: Enum.flat_map(elements, &element_triggers/1)

  defp model_triggers(_model), do: []

  defp element_triggers(%{"type" => "group"} = group) do
    own =
      case group do
        %{"trigger" => %{} = trigger} -> [entry("group:#{group["id"]}", trigger)]
        _ -> []
      end

    own ++ model_triggers(group["children"])
  end

  defp element_triggers(%{"type" => "content"} = block), do: inline_triggers(block["children"])
  defp element_triggers(%{"children" => children}), do: model_triggers(children)
  defp element_triggers(_element), do: []

  defp inline_triggers(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &inline_trigger/1)
  defp inline_triggers(_nodes), do: []

  defp inline_trigger(%{"type" => "trigger"} = trigger),
    do: [entry("content:#{trigger["id"]}", trigger)]

  defp inline_trigger(%{"children" => children}), do: inline_triggers(children)
  defp inline_trigger(_node), do: []

  defp part_triggers(content) do
    content
    |> authoring_parts()
    |> Enum.flat_map(fn part ->
      part
      |> Map.get("triggers")
      |> List.wrap()
      |> Enum.filter(&is_map/1)
      |> Enum.map(&entry("part:#{part["id"]}:#{&1["id"]}", &1))
    end)
  end

  defp adaptive_part_triggers(content) do
    (List.wrap(content["partsLayout"]) ++ authoring_parts(content))
    |> Enum.filter(&is_map/1)
    |> Enum.flat_map(fn
      %{"type" => "janus-ai-trigger", "id" => id} = part ->
        [adaptive_entry(id, part["type"], get_in(part, ["custom", "prompt"]))]

      %{"id" => id, "custom" => %{"enableAiTrigger" => true} = custom} = part ->
        [adaptive_entry(id, part["type"], custom["aiTriggerPrompt"])]

      _part ->
        []
    end)
  end

  defp activation_points(content) do
    content
    |> get_in(["authoring", "rules"])
    |> List.wrap()
    |> Enum.filter(&is_map/1)
    |> Enum.flat_map(fn rule ->
      rule_id = get_in(rule, ["event", "type"])

      rule
      |> get_in(["event", "params", "actions"])
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {%{"type" => "activationPoint"} = action, index} ->
          params = action["params"] || %{}

          [
            with_prompt(
              %{
                "path" => "rule:#{rule_id}:#{index}",
                "trigger_type" => "activation_point:#{params["kind"] || "dot"}"
              },
              params["prompt"]
            )
          ]

        _action ->
          []
      end)
    end)
  end

  defp authoring_parts(content) do
    case get_in(content, ["authoring", "parts"]) do
      parts when is_list(parts) -> Enum.filter(parts, &is_map/1)
      _ -> []
    end
  end

  defp entry(path, trigger) do
    with_prompt(
      %{"path" => path, "trigger_type" => to_string_or_nil(trigger["trigger_type"])},
      trigger["prompt"]
    )
  end

  defp adaptive_entry(id, type, prompt),
    do: with_prompt(%{"path" => "part:#{id}", "trigger_type" => type}, prompt)

  defp with_prompt(entry, prompt) when is_binary(prompt) do
    case String.length(prompt) > @max_prompt do
      true ->
        entry
        |> Map.put("prompt", String.slice(prompt, 0, @max_prompt))
        |> Map.put("prompt_truncated", true)

      false ->
        Map.put(entry, "prompt", prompt)
    end
  end

  defp with_prompt(entry, _prompt), do: Map.put(entry, "prompt", nil)

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)
end
