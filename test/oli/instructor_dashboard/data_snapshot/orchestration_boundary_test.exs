defmodule Oli.InstructorDashboard.DataSnapshot.OrchestrationBoundaryTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot

  describe "orchestration boundary guardrails" do
    # @ac "AC-006"
    test "exposes orchestration contracts and explicit non-goals" do
      exports =
        DataSnapshot.__info__(:functions)
        |> Enum.map(fn {name, _arity} -> name end)

      assert :get_or_build in exports
      assert :get_projection in exports
      assert :boundary_non_goals in exports

      assert DataSnapshot.boundary_non_goals() == [
               :queue_token_orchestration,
               :cache_policy,
               :direct_oracle_queries,
               :direct_analytics_queries
             ]
    end

    # @ac "AC-006"
    test "orchestration modules do not reference cache policy internals or direct query stacks" do
      for path <- [
            "lib/oli/instructor_dashboard/data_snapshot.ex",
            "lib/oli/dashboard/snapshot/assembler.ex",
            "lib/oli/dashboard/snapshot/projections.ex"
          ] do
        content = File.read!(path)

        refute String.contains?(content, "Oli.Dashboard.Cache.Key")
        refute String.contains?(content, "Cache.Policy")
        refute String.contains?(content, "MissCoalescer")
        refute String.contains?(content, "RevisitCache")
        refute String.contains?(content, "Ecto.Query")
        refute String.contains?(content, "Repo.")
        refute String.contains?(content, "Oli.Analytics")
      end
    end
  end
end
