defmodule OliWeb.Delivery.ActivityInsightsStateTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.ActivityInsightsState

  test "starts with empty caches and collapsed rows" do
    state = ActivityInsightsState.initial_state()

    assert state.activity_summary_cache == %{}
    assert state.loaded_activity_summaries == %{}
    assert MapSet.equal?(state.expanded_activity_ids, MapSet.new())
  end

  test "projects expanded IDs into table row IDs" do
    assert ActivityInsightsState.expanded_rows(MapSet.new([4, 9])) ==
             MapSet.new(["row_4", "row_9"])
  end

  test "reset clears loaded details and expansion without touching the summary cache" do
    reset = ActivityInsightsState.reset()

    assert reset.loaded_activity_summaries == %{}
    assert MapSet.equal?(reset.expanded_activity_ids, MapSet.new())

    # The cache and the repair flag are intentionally absent so that assigning the
    # result leaves those keys untouched on the socket.
    refute Map.has_key?(reset, :activity_summary_cache)
    refute Map.has_key?(reset, :repair_poll_scheduled)
  end
end
