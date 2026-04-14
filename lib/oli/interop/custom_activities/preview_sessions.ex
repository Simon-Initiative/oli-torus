defmodule Oli.Interop.CustomActivities.PreviewSessions do
  @moduledoc false

  @cache_name :embedded_preview_sessions
  @ttl_ms :timer.hours(2)

  @spec put(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def put(session_guid, session) when is_binary(session_guid) and is_map(session) do
    case Cachex.put(@cache_name, session_guid, session, ttl: @ttl_ms) do
      {:ok, true} -> {:ok, session}
      other -> {:error, {:cache_put_failed, other}}
    end
  end

  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def get(session_guid) when is_binary(session_guid) do
    case Cachex.get(@cache_name, session_guid) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, session} -> {:ok, session}
      other -> {:error, {:cache_get_failed, other}}
    end
  end

  @spec update(String.t(), (map() -> map())) :: {:ok, map()} | {:error, :not_found | term()}
  def update(session_guid, updater) when is_binary(session_guid) and is_function(updater, 1) do
    case Cachex.transaction(@cache_name, [session_guid], fn worker ->
           case Cachex.get(worker, session_guid) do
             {:ok, nil} ->
               {:error, :not_found}

             {:ok, session} ->
               updated_session = updater.(session)

               case Cachex.put(worker, session_guid, updated_session, ttl: @ttl_ms) do
                 {:ok, true} -> {:ok, updated_session}
                 other -> {:error, {:cache_put_failed, other}}
               end

             other ->
               {:error, {:cache_get_failed, other}}
           end
         end) do
      {:ok, result} -> result
      other -> {:error, {:cache_transaction_failed, other}}
    end
  end
end
