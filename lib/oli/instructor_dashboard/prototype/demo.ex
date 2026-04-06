defmodule Oli.InstructorDashboard.Prototype.Demo do
  @moduledoc """
  Quick manual entry point for exercising the prototype snapshot pipeline.
  """

  alias Oli.InstructorDashboard.Prototype.InProcessCache
  alias Oli.InstructorDashboard.Prototype.LiveDataController
  alias Oli.InstructorDashboard.Prototype.Scope

  def run(scope_opts \\ %{}) do
    scope = Scope.new(scope_opts)
    cache = InProcessCache.new()

    {:ok, cold_snapshot, cache, cold_meta} = LiveDataController.load(scope, cache: cache)

    IO.inspect(cold_meta, label: "Cold load metadata")
    IO.inspect(cold_snapshot.projections, label: "Cold projections")

    {:ok, warm_snapshot, _cache, warm_meta} = LiveDataController.load(scope, cache: cache)

    IO.inspect(warm_meta, label: "Warm load metadata")
    IO.inspect(warm_snapshot.projections, label: "Warm projections")

    warm_snapshot
  end
end
