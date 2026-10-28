defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.SummariesTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Summaries

  defp activity(attempts) do
    %{resource_id: 7, revision: %{title: "Question"}, attempts: attempts}
  end

  test "a summary the analytics helpers produced is marked complete" do
    summary = Summaries.from_result(%{id: 7, preview_rendered: "<div/>"}, activity(4))

    assert summary.summary_status == :complete
    assert summary.preview_rendered == "<div/>"
  end

  test "an activity with attempts and no summary reports unavailable analytics" do
    summary = Summaries.from_result(nil, activity(4))

    assert summary.summary_status == :unavailable
    assert summary.preview_rendered == nil
    assert summary.first_attempt_pct == 0.0
  end

  test "an activity with no attempts reports that nothing was observed" do
    assert Summaries.from_result(nil, activity(0)).summary_status == :no_observations
    assert Summaries.without_analytics(activity(0)).summary_status == :no_observations
  end

  test "a row without an attempts count is treated as unobserved rather than unavailable" do
    assert Summaries.without_analytics(%{resource_id: 7, revision: %{}, attempts: nil}).summary_status ==
             :no_observations
  end
end
