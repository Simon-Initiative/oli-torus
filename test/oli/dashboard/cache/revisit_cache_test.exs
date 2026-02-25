defmodule Oli.Dashboard.Cache.RevisitCacheTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.RevisitCache

  setup do
    clock_ref = start_supervised!({Agent, fn -> 0 end})
    clock = fn -> Agent.get(clock_ref, & &1) end

    revisit_cache =
      start_supervised!({RevisitCache, clock: clock})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 910,
      user_id: 45
    }

    scope = %{container_type: :container, container_id: 3001}

    opts = [
      revisit_cache: revisit_cache,
      revisit_eligible: true,
      key_meta: %{oracle_version: 1, data_version: 1},
      ttl_ms: 100
    ]

    %{
      revisit_cache: revisit_cache,
      clock_ref: clock_ref,
      context: context,
      scope: scope,
      opts: opts
    }
  end

  describe "lookup_revisit/5 eligibility and fallback" do
    test "hydrates from revisit cache for explicit-container eligible flow", %{
      revisit_cache: revisit_cache,
      context: context,
      scope: scope,
      opts: opts
    } do
      key = revisit_key(45, 910, %{container_type: :container, container_id: 3001}, :progress)
      assert :ok = RevisitCache.write(revisit_cache, key, %{value: 88})

      assert {:ok, result} =
               Cache.lookup_revisit(45, context, scope, [:progress, :objectives], opts)

      assert result.hits == %{progress: %{value: 88}}
      assert result.misses == [:objectives]
      assert result.source == :mixed
    end

    test "hydrates from revisit cache for course scope when explicit-entry eligible", %{
      revisit_cache: revisit_cache,
      context: context,
      opts: opts
    } do
      key = revisit_key(45, 910, %{container_type: :course, container_id: nil}, :progress)
      assert :ok = RevisitCache.write(revisit_cache, key, %{value: 44})

      assert {:ok, result} =
               Cache.lookup_revisit(
                 45,
                 context,
                 %{container_type: :course, container_id: nil},
                 [:progress],
                 opts
               )

      assert result.hits == %{progress: %{value: 44}}
      assert result.misses == []
      assert result.source == :revisit
    end

    test "skips revisit lookup when explicit-entry flag is missing", %{
      revisit_cache: revisit_cache,
      context: context
    } do
      key = revisit_key(45, 910, %{container_type: :container, container_id: 3001}, :progress)
      assert :ok = RevisitCache.write(revisit_cache, key, %{value: 44})

      assert {:ok, result} =
               Cache.lookup_revisit(
                 45,
                 context,
                 %{container_type: :container, container_id: 3001},
                 [:progress],
                 key_meta: %{oracle_version: 1, data_version: 1},
                 revisit_cache: revisit_cache
               )

      assert result.hits == %{}
      assert result.misses == [:progress]
      assert result.source == :none
    end

    test "degrades to deterministic misses when revisit cache is unavailable", %{
      context: context,
      scope: scope
    } do
      assert {:ok, result} =
               Cache.lookup_revisit(
                 45,
                 context,
                 scope,
                 [:progress, :objectives],
                 revisit_eligible: true,
                 key_meta: %{oracle_version: 1, data_version: 1}
               )

      assert result.hits == %{}
      assert result.misses == [:progress, :objectives]
      assert result.source == :none
    end
  end

  describe "revisit ttl behavior" do
    test "expires revisit entries after ttl and treats expired entries as misses", %{
      revisit_cache: revisit_cache,
      clock_ref: clock_ref
    } do
      key = revisit_key(45, 910, %{container_type: :container, container_id: 3001}, :objectives)
      assert :ok = RevisitCache.write(revisit_cache, key, %{value: 17})

      advance_clock(clock_ref, 101)

      assert {:ok, first_lookup} = RevisitCache.lookup(revisit_cache, [key], ttl_ms: 100)
      assert first_lookup.hits == %{}
      assert first_lookup.misses == [key]
      assert first_lookup.expired == [key]

      assert {:ok, second_lookup} = RevisitCache.lookup(revisit_cache, [key], ttl_ms: 100)
      assert second_lookup.hits == %{}
      assert second_lookup.misses == [key]
      assert second_lookup.expired == []
    end
  end

  defp revisit_key(user_id, context_id, scope, oracle_key) do
    {:ok, key} =
      Key.revisit(
        user_id,
        %{dashboard_context_id: context_id},
        scope,
        oracle_key,
        %{oracle_version: 1, data_version: 1}
      )

    key
  end

  defp advance_clock(clock_ref, milliseconds) do
    Agent.update(clock_ref, &(&1 + milliseconds))
  end
end
