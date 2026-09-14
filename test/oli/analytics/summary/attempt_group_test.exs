defmodule Oli.Analytics.Summary.AttemptGroupTest do
  use Oli.DataCase

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}
  alias Oli.LearningModel.LktAoaFixtures

  test "uses the available Section publication when project_id is unavailable" do
    %{section: section, group: group} = LktAoaFixtures.lkt_fixture()
    remix_project = Oli.Factory.insert(:project)
    remix_publication = Oli.Factory.insert(:publication, project: remix_project)

    Oli.Factory.insert(:section_project_publication,
      section: section,
      project: remix_project,
      publication: remix_publication
    )

    part_attempt = hd(group.part_attempts)
    activity_attempt = part_attempt.activity_attempt
    resource_attempt = Repo.get!(ResourceAttempt, activity_attempt.resource_attempt_id)
    resource_access = Repo.get!(ResourceAccess, resource_attempt.resource_access_id)

    rebuilt =
      AttemptGroup.from_attempt_summary(
        [
          {part_attempt, activity_attempt, resource_attempt, resource_access,
           part_attempt.activity_revision}
        ],
        nil,
        "localhost"
      )

    assert rebuilt.context.publication_id == group.context.publication_id
  end
end
