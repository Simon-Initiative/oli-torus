defmodule Oli.Dashboard.Cache.RevisitIsolationTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.RevisitCache

  test "revisit cache does not leak payloads across users for same context/container/oracle identity" do
    revisit_cache = start_supervised!({RevisitCache, []})

    opts = [
      revisit_cache: revisit_cache,
      revisit_eligible: true,
      key_meta: %{oracle_version: 1, data_version: 1}
    ]

    context_user_1 = %{
      dashboard_context_type: :section,
      dashboard_context_id: 700,
      user_id: 1001
    }

    context_user_2 = %{
      dashboard_context_type: :section,
      dashboard_context_id: 700,
      user_id: 1002
    }

    scope = %{container_type: :container, container_id: 222}

    user_1_key =
      revisit_key(
        1001,
        700,
        222,
        :support
      )

    assert :ok = RevisitCache.write(revisit_cache, user_1_key, %{students: 5})

    assert {:ok, user_1_lookup} =
             Cache.lookup_revisit(1001, context_user_1, scope, [:support], opts)

    assert user_1_lookup.hits == %{support: %{students: 5}}
    assert user_1_lookup.misses == []
    assert user_1_lookup.source == :revisit

    assert {:ok, user_2_lookup} =
             Cache.lookup_revisit(1002, context_user_2, scope, [:support], opts)

    assert user_2_lookup.hits == %{}
    assert user_2_lookup.misses == [:support]
    assert user_2_lookup.source == :none
  end

  defp revisit_key(user_id, context_id, container_id, oracle_key) do
    {:ok, key} =
      Key.revisit(
        user_id,
        %{dashboard_context_id: context_id},
        %{container_type: :container, container_id: container_id},
        oracle_key,
        %{oracle_version: 1, data_version: 1}
      )

    key
  end
end
