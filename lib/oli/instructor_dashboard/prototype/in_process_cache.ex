defmodule Oli.InstructorDashboard.Prototype.InProcessCache do
  @moduledoc """
  Prototype in-process cache keyed by scope and oracle key.
  """

  alias Oli.InstructorDashboard.Prototype.Scope

  @enforce_keys [:entries]
  defstruct [:entries]

  @type t :: %__MODULE__{entries: %{cache_key() => term()}}
  @type cache_key :: {map(), atom()}

  def new do
    %__MODULE__{entries: %{}}
  end

  def fetch(%__MODULE__{} = cache, %Scope{} = scope, oracle_key) when is_atom(oracle_key) do
    case Map.fetch(cache.entries, cache_key(scope, oracle_key)) do
      {:ok, payload} -> {:hit, payload}
      :error -> :miss
    end
  end

  def put(%__MODULE__{} = cache, %Scope{} = scope, oracle_key, payload)
      when is_atom(oracle_key) do
    %__MODULE__{
      cache
      | entries: Map.put(cache.entries, cache_key(scope, oracle_key), payload)
    }
  end

  defp cache_key(%Scope{} = scope, oracle_key) do
    {scope_key(scope), oracle_key}
  end

  defp scope_key(%Scope{} = scope) do
    %{
      context_type: scope.context_type,
      context_id: scope.context_id,
      container_type: scope.container_type,
      container_id: scope.container_id,
      filters: scope.filters
    }
  end
end
