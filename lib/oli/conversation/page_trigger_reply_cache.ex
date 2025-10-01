defmodule Oli.Conversation.PageTriggerReplyCache do
  @moduledoc """
  Per-node cache for assistant replies to page visit triggers, keyed by
  page `revision_id`. Used to avoid unnecessary LLM calls for repeated
  visits to the same page revision.

  This cache is intentionally non-distributed. Each node maintains its
  own entries. Eviction is handled by Cachex according to the limit
  configured in the application supervisor.
  """

  @cache_name :ai_page_trigger_reply_cache

  @spec get(any()) :: {:hit, String.t()} | :miss | {:error, term()}
  def get(revision_id) do
    case Cachex.get(@cache_name, revision_id) do
      {:ok, nil} -> :miss
      {:ok, value} -> {:hit, value}
      other -> {:error, other}
    end
  end

  @spec put(any(), String.t()) :: :ok | {:error, term()}
  def put(revision_id, reply_text) when is_binary(reply_text) do
    case Cachex.put(@cache_name, revision_id, reply_text) do
      {:ok, _} -> :ok
      other -> {:error, other}
    end
  end
end
