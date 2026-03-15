defmodule Oli.Conversation.AdaptiveTriggerInvocationCache do
  @moduledoc """
  Per-node cooldown cache for adaptive trigger invocations.

  Adaptive trigger requests originate in the browser, so this cache is used to
  collapse rapid duplicate submissions for the same user, section, resource, and
  component within a short time window.
  """

  @cache_name :adaptive_trigger_invocation_cache

  @spec register_once(term(), pos_integer()) :: :accepted | :duplicate | {:error, term()}
  def register_once(key, ttl_ms) when ttl_ms > 0 do
    case Cachex.transaction(@cache_name, [key], fn worker ->
           case Cachex.get(worker, key) do
             {:ok, nil} ->
               case Cachex.put(worker, key, true, ttl: ttl_ms) do
                 {:ok, true} -> :accepted
                 other -> {:error, {:cache_put_failed, other}}
               end

             {:ok, _value} ->
               :duplicate

             other ->
               {:error, {:cache_get_failed, other}}
           end
         end) do
      {:ok, result} -> result
      other -> {:error, {:cache_transaction_failed, other}}
    end
  end
end
