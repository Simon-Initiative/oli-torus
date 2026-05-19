defmodule Oli.Dashboard.Cache.WriteOracleTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.InProcessStore

  setup do
    inprocess_store = start_supervised!({InProcessStore, enrollment_count: 100})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 4321,
      user_id: 999
    }

    opts = [inprocess_store: inprocess_store, key_meta: %{oracle_version: 1, data_version: 1}]

    %{inprocess_store: inprocess_store, context: context, opts: opts}
  end

  describe "write_oracle/6 identity guard" do
    test "accepts list payloads when identity guard passes", %{context: context, opts: opts} do
      scope = %{container_type: :container, container_id: 100}
      payload = [%{student_id: 1, progress_pct: 73.0}]

      assert :ok =
               Cache.write_oracle(
                 context,
                 scope,
                 :progress_proficiency,
                 payload,
                 %{
                   dashboard_context_id: 4321,
                   container_type: :container,
                   container_id: 100,
                   oracle_version: 1,
                   data_version: 1
                 },
                 opts
               )

      assert {:ok, result} =
               Cache.lookup_required(context, scope, [:progress_proficiency], opts)

      assert result.hits == %{progress_proficiency: payload}
      assert result.misses == []
    end

    test "accepts late write when identity guard passes", %{context: context, opts: opts} do
      active_scope = %{container_type: :container, container_id: 200}
      late_scope = %{container_type: :container, container_id: 100}

      assert :ok =
               Cache.write_oracle(
                 context,
                 late_scope,
                 :progress,
                 %{value: 73},
                 %{
                   dashboard_context_id: 4321,
                   container_type: :container,
                   container_id: 100,
                   oracle_version: 1,
                   data_version: 1
                 },
                 Keyword.merge(opts, active_scope: active_scope, allow_late_write: true)
               )

      assert {:ok, late_result} = Cache.lookup_required(context, late_scope, [:progress], opts)
      assert late_result.hits == %{progress: %{value: 73}}
      assert late_result.misses == []
    end

    test "rejects late write when policy disallows it", %{context: context, opts: opts} do
      active_scope = %{container_type: :container, container_id: 200}
      late_scope = %{container_type: :container, container_id: 100}

      assert {:error, {:identity_guard_rejected, :late_write_disallowed}} =
               Cache.write_oracle(
                 context,
                 late_scope,
                 :progress,
                 %{value: 73},
                 %{
                   dashboard_context_id: 4321,
                   container_type: :container,
                   container_id: 100,
                   oracle_version: 1,
                   data_version: 1
                 },
                 Keyword.merge(opts, active_scope: active_scope, allow_late_write: false)
               )
    end

    test "rejects identity mismatches for context and container metadata", %{
      context: context,
      opts: opts
    } do
      scope = %{container_type: :container, container_id: 100}

      assert {:error, {:identity_guard_rejected, :dashboard_context_mismatch}} =
               Cache.write_oracle(
                 context,
                 scope,
                 :progress,
                 %{value: 73},
                 %{
                   dashboard_context_id: 9999,
                   oracle_version: 1,
                   data_version: 1
                 },
                 opts
               )

      assert {:error, {:identity_guard_rejected, :container_id_mismatch}} =
               Cache.write_oracle(
                 context,
                 scope,
                 :progress,
                 %{value: 73},
                 %{
                   dashboard_context_id: 4321,
                   container_type: :container,
                   container_id: 101,
                   oracle_version: 1,
                   data_version: 1
                 },
                 opts
               )
    end
  end
end
