defmodule Oli.Dashboard.Snapshot.BoundaryTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Contract

  describe "snapshot boundary guardrails" do
    # @ac "AC-006"
    test "exposes explicit boundary non-goals" do
      assert Contract.boundary_non_goals() == [
               :queue_token_orchestration,
               :cache_policy,
               :direct_oracle_queries,
               :direct_analytics_queries
             ]
    end

    # @ac "AC-006"
    test "snapshot transformation modules do not reference orchestration/cache/query internals" do
      snapshot_module_paths =
        Path.wildcard("lib/oli/dashboard/snapshot/**/*.ex")
        |> Enum.uniq()

      assert snapshot_module_paths != []

      for path <- snapshot_module_paths do
        content = File.read!(path)

        refute String.contains?(content, "Oli.Dashboard.LiveDataCoordinator")
        refute String.contains?(content, "Oli.Dashboard.Cache.Policy")
        refute String.contains?(content, "Oli.Dashboard.Cache.Key")
        refute String.contains?(content, "Oli.Dashboard.Cache.MissCoalescer")
        refute String.contains?(content, "Ecto.Query")
        refute String.contains?(content, "Repo.")
        refute String.contains?(content, "Oli.Analytics")
      end
    end
  end
end
