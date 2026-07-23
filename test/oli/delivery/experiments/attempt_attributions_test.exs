defmodule Oli.Delivery.Experiments.AttemptAttributionsTest do
  use Oli.DataCase

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Delivery.Experiments.AttemptAttributions

  test "does not query experiment assignments for sections without experiments" do
    section = insert(:section, has_experiments: false)

    activity_attempt = %{id: 1, attempt_guid: "activity-attempt-guid"}
    part_attempt = %{id: 1, attempt_guid: "part-attempt-guid", activity_attempt: activity_attempt}

    attempt_group = %AttemptGroup{
      context: %Context{
        host_name: "http://example.edu",
        user_id: insert(:user).id,
        section_id: section.id,
        project_id: insert(:project).id,
        publication_id: insert(:publication).id
      },
      part_attempts: [part_attempt],
      activity_attempts: [activity_attempt],
      resource_attempt: %{}
    }

    log =
      capture_log([level: :debug], fn ->
        assert AttemptAttributions.for_attempt_group(attempt_group) == %{
                 part_attempts: %{},
                 activity_attempts: %{},
                 page_attempt: []
               }
      end)

    refute log =~ "experiment_assignments"
  end
end
