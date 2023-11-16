defmodule Oli.Conversation.Common do

  def estimate_token_length(function) when is_map(function) do
    Jason.encode!(function)
    |> estimate_token_length()
  end

  def estimate_token_length(content) do
    String.length(content) |> div(4)
  end

  def summarize_prompt() do
    """
    You are a converstational summarization agent that is tasked with summarizing long conversations between
    human users and a large language model conversational agent. Your primary goal is to summarize the conversation
    into a single "summary" paragraph of no longer that 5 or 6 sentences which captures the essence of the conversation.
    You are given a conversation below as a series of "assistant" and "user" messages. You can summarize the conversation
    along the lines of "user asked about X. Assistant responded with Y. User asked about Z. Assistant responded with A. etc"
    """
  end

end
