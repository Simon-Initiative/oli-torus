defmodule Oli.GenAI.Agent.Critic do
  @moduledoc "Optional loop/quality checks and replan hints."

  @spec looping?(steps :: list()) :: boolean
  def looping?(steps) when is_list(steps) do
    cond do
      # Need at least 6 steps to detect meaningful loops
      length(steps) < 6 ->
        false
        
      # Check for identical consecutive tool calls (real loop indicator)
      has_identical_consecutive_tool_calls?(steps) ->
        true
        
      # Check for alternating pattern loops (tool A -> tool B -> tool A -> tool B)
      has_alternating_pattern_loop?(steps) ->
        true
        
      # Check for same tool called repeatedly with same arguments
      has_repeated_identical_tool_calls?(steps) ->
        true
        
      true ->
        false
    end
  end

  def looping?(_), do: false

  @spec should_replan?(state :: map()) :: boolean
  def should_replan?(state) do
    steps = Map.get(state, :steps, [])
    
    cond do
      # If we've been looping
      looping?(steps) ->
        true
      
      # If we have many failed tool calls
      recent_failures = count_recent_failures(steps) ->
        recent_failures >= 3
      
      # If we're far from completing the plan
      true ->
        steps_completed = length(steps)
        plan_size = Map.get(state, :plan, []) |> length()
        plan_size > 0 and steps_completed > plan_size * 2
    end
  end

  @spec critique(state :: map()) :: String.t()
  def critique(state) do
    steps = Map.get(state, :steps, [])
    _goal = Map.get(state, :goal, "")
    
    issues = []
    
    issues = if looping?(steps) do
      ["Appears to be stuck in a loop of repetitive actions" | issues]
    else
      issues
    end
    
    issues = if count_recent_failures(steps) >= 2 do
      ["Multiple recent tool failures suggest approach may need adjustment" | issues]
    else
      issues
    end
    
    issues = if length(steps) > 20 do
      ["Taking many steps - consider if goal is too broad or approach inefficient" | issues]
    else
      issues
    end
    
    if issues == [] do
      "Progress appears normal"
    else
      "Issues detected: " <> Enum.join(issues, "; ")
    end
  end

  defp count_recent_failures(steps) do
    steps
    |> Enum.take(5)
    |> Enum.count(fn step ->
      case step do
        %{observation: %{error: _}} -> true
        %{observation: observation} when is_binary(observation) ->
          String.contains?(observation, "error") or String.contains?(observation, "failed")
        _ -> false
      end
    end)
  end

  # Check for identical consecutive tool calls (same tool, same args back-to-back)
  defp has_identical_consecutive_tool_calls?(steps) do
    steps
    |> Enum.take(4)  # Check last 4 steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [step1, step2] ->
      actions_identical?(step1.action, step2.action)
    end)
  end

  # Check for alternating pattern (A -> B -> A -> B)
  defp has_alternating_pattern_loop?(steps) do
    case Enum.take(steps, 4) do
      [s1, s2, s3, s4] ->
        actions_identical?(s1.action, s3.action) and 
        actions_identical?(s2.action, s4.action) and
        not actions_identical?(s1.action, s2.action)
      _ -> false
    end
  end

  # Check for same tool called multiple times with identical arguments
  defp has_repeated_identical_tool_calls?(steps) do
    tool_calls = steps
    |> Enum.take(6)
    |> Enum.filter(fn step -> 
      case step.action do
        %{type: "tool"} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn step -> step.action end)

    # If we have the same tool call 3+ times in recent history, it's likely a loop
    if length(tool_calls) >= 3 do
      tool_calls
      |> Enum.frequencies_by(&normalize_action/1)
      |> Enum.any?(fn {_action, count} -> count >= 3 end)
    else
      false
    end
  end

  # Check if two actions are identical (same type, tool name, and key arguments)
  defp actions_identical?(%{type: "tool", name: name1, args: args1}, %{type: "tool", name: name2, args: args2}) do
    name1 == name2 and key_args_match?(args1, args2)
  end
  
  defp actions_identical?(action1, action2) do
    normalize_action(action1) == normalize_action(action2)
  end

  # Compare key arguments (ignore large JSON payloads that might differ slightly)
  defp key_args_match?(args1, args2) when is_map(args1) and is_map(args2) do
    # Compare all args except large JSON strings
    filtered_args1 = Map.reject(args1, fn {_k, v} -> is_large_json?(v) end)
    filtered_args2 = Map.reject(args2, fn {_k, v} -> is_large_json?(v) end)
    filtered_args1 == filtered_args2
  end
  
  defp key_args_match?(args1, args2), do: args1 == args2

  defp is_large_json?(value) when is_binary(value) and byte_size(value) > 200 do
    String.starts_with?(value, "{") and String.ends_with?(value, "}")
  end
  
  defp is_large_json?(_), do: false

  # Create a normalized representation of an action for comparison
  defp normalize_action(%{type: "tool", name: name, args: args}) do
    # Normalize args by removing large JSON payloads
    normalized_args = case args do
      args when is_map(args) ->
        Map.reject(args, fn {_k, v} -> is_large_json?(v) end)
      args -> args
    end
    {:tool, name, normalized_args}
  end

  defp normalize_action(%{type: type, content: content}) when type in ["message"] do
    # For messages, just use first few words to avoid false positives from minor variations
    normalized_content = case content do
      content when is_binary(content) -> String.slice(content, 0, 50)
      content -> content
    end
    {:message, normalized_content}
  end

  defp normalize_action(%{type: type} = action) do
    {type, Map.drop(action, [:type])}
  end

  defp normalize_action(action), do: action
end