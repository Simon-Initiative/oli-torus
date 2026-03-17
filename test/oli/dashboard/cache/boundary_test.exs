defmodule Oli.Dashboard.Cache.BoundaryTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Telemetry

  describe "cache facade boundary surface" do
    test "exposes only cache contracts and no queue/token orchestration API" do
      exports =
        Cache.__info__(:functions)
        |> Enum.map(fn {name, _arity} -> name end)

      assert :lookup_required in exports
      assert :lookup_revisit in exports
      assert :write_oracle in exports
      assert :coalesce_or_build in exports
      assert :touch_container in exports

      refute Enum.any?(exports, fn name ->
               name
               |> Atom.to_string()
               |> String.contains?(["queue", "token", "stale"])
             end)

      assert Cache.boundary_non_goals() == [
               :request_queueing,
               :token_generation,
               :stale_result_suppression
             ]
    end

    test "cache modules do not reference coordinator request queue/token internals" do
      for path <- [
            "lib/oli/dashboard/cache.ex",
            "lib/oli/dashboard/cache/in_process_store.ex",
            "lib/oli/dashboard/cache/key.ex",
            "lib/oli/dashboard/cache/miss_coalescer.ex",
            "lib/oli/dashboard/cache/policy.ex",
            "lib/oli/dashboard/cache/telemetry.ex",
            "lib/oli/dashboard/revisit_cache.ex"
          ] do
        content = File.read!(path)
        refute String.contains?(content, "queued_request")
        refute String.contains?(content, "request_token")
        refute String.contains?(content, "stale_token")
      end
    end
  end

  describe "telemetry metadata schema guardrails" do
    test "lookup and write schemas forbid PII fields" do
      lookup_schema = Telemetry.lookup_metadata_schema()
      write_schema = Telemetry.write_metadata_schema()

      assert lookup_schema.forbidden_pii == [
               :user_id,
               :dashboard_context_id,
               :container_id,
               :payload
             ]

      assert write_schema.forbidden_pii == [
               :user_id,
               :dashboard_context_id,
               :container_id,
               :payload
             ]
    end

    test "metadata sanitization drops PII inputs" do
      sanitized_lookup =
        Telemetry.sanitize_lookup_metadata(%{
          cache_tier: :inprocess,
          outcome: :hit,
          container_type: :container,
          oracle_key_count: 3,
          user_id: 1001,
          dashboard_context_id: 2002,
          container_id: 3003
        })

      sanitized_write =
        Telemetry.sanitize_write_metadata(%{
          cache_tier: :revisit,
          outcome: :accepted,
          container_type: :course,
          oracle_key: :progress,
          user_id: 1001,
          payload: %{sensitive: true}
        })

      refute Map.has_key?(sanitized_lookup, :user_id)
      refute Map.has_key?(sanitized_lookup, :dashboard_context_id)
      refute Map.has_key?(sanitized_lookup, :container_id)
      refute Map.has_key?(sanitized_write, :user_id)
      refute Map.has_key?(sanitized_write, :payload)
    end
  end
end
