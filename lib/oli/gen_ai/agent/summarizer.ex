defmodule Oli.GenAI.Agent.Summarizer do
  @moduledoc "Maintains rolling context summary and prunes the short window."

  @spec rollup(summary :: String.t(), observation :: term()) :: String.t()
  def rollup(summary, observation) do
    # Simple rollup - append observation summary to existing summary
    obs_text = case observation do
      %{content: content} when is_binary(content) ->
        String.slice(content, 0, 200)
      
      text when is_binary(text) ->
        String.slice(text, 0, 200)
      
      other ->
        inspect(other) |> String.slice(0, 100)
    end
    
    new_summary = if summary == "" do
      "Recent: #{obs_text}"
    else
      "#{summary} | #{obs_text}"
    end
    
    # Keep summary under 2000 characters
    if String.length(new_summary) > 2000 do
      "..." <> String.slice(new_summary, -1900, 1900)
    else
      new_summary
    end
  end

  @spec prune_window(window :: list(), max :: pos_integer) :: list()
  def prune_window(window, max) when is_list(window) and is_integer(max) and max > 0 do
    if length(window) <= max do
      window
    else
      # Keep the most recent messages and system messages
      {system_msgs, other_msgs} = Enum.split_with(window, fn msg ->
        Map.get(msg, :role) == :system
      end)
      
      # Take the most recent non-system messages
      recent_msgs = Enum.take(other_msgs, max - length(system_msgs))
      
      system_msgs ++ recent_msgs
    end
  end

  def prune_window(window, _max), do: window
end