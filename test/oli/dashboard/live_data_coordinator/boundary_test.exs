defmodule Oli.Dashboard.LiveDataCoordinator.BoundaryTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator

  describe "coordinator boundary surface" do
    test "exposes coordinator contracts and explicit non-goals" do
      exports =
        LiveDataCoordinator.__info__(:functions)
        |> Enum.map(fn {name, _arity} -> name end)

      assert :new_session in exports
      assert :request_scope_change in exports
      assert :handle_oracle_result in exports
      assert :handle_request_timeout in exports
      assert :handle_timeout in exports
      assert :boundary_non_goals in exports

      assert LiveDataCoordinator.boundary_non_goals() == [
               :cache_keying,
               :ttl_policy,
               :lru_eviction,
               :revisit_retention,
               :miss_coalescing
             ]
    end

    test "coordinator modules do not reference cache policy internals" do
      # @ac "AC-005"
      for path <- [
            "lib/oli/dashboard/live_data_coordinator.ex",
            "lib/oli/dashboard/live_data_coordinator/actions.ex",
            "lib/oli/dashboard/live_data_coordinator/state.ex",
            "lib/oli/dashboard/live_data_coordinator/telemetry.ex"
          ] do
        content = File.read!(path)

        refute String.contains?(content, "Oli.Dashboard.Cache.Key")
        refute String.contains?(content, "Cache.Policy")
        refute String.contains?(content, "MissCoalescer")
        refute String.contains?(content, "RevisitCache")
        refute String.contains?(content, "container_cap_for_enrollment")
        refute String.contains?(content, "inprocess_ttl")
      end
    end
  end
end
