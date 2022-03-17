defmodule Oli.Delivery.Attempts.PageLifecycleTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Activities.Model.{Part}

  @content_automatic_by_default %{
    "stem" => "1",
    "authoring" => %{
      "parts" => [
        %{
          "id" => "1",
          "responses" => [],
          "scoringStrategy" => "best",
          "evaluationStrategy" => "regex"
        }
      ]
    }
  }

  @content_automatic %{
    "stem" => "1",
    "authoring" => %{
      "parts" => [
        %{
          "id" => "1",
          "responses" => [],
          "scoringStrategy" => "best",
          "evaluationStrategy" => "regex",
          "gradingApproach" => "automatic"
        }
      ]
    }
  }

  @content_manual %{
    "stem" => "2",
    "authoring" => %{
      "parts" => [
        %{
          "id" => "1",
          "responses" => [],
          "scoringStrategy" => "best",
          "gradingApproach" => "manual"
        }
      ]
    }
  }

  def add_manual_activity(map, resource_attempt_tag, activity_tag, activity_attempt_tag) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: @content_manual, lifecycle_state: :active},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :manual,
        lifecycle_state: :active,
        part_id: "1"
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
      activity_attempt_tag
    )
  end

  def add_automatic_activity(
        map,
        resource_attempt_tag,
        activity_tag,
        activity_attempt_tag,
        content
      ) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: content, lifecycle_state: :active},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :automatic,
        lifecycle_state: :active,
        part_id: "1"
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
      activity_attempt_tag
    )
  end

  describe "browsing manual graded attempts" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{title: "title 1"}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{title: "title 2"}, :publication, :project, :author, :activity_b)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_c)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_d)
      |> Seeder.add_page(%{graded: true}, :graded_page1)
      |> Seeder.add_page(%{graded: true}, :graded_page2)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page1,
        :attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page2,
        :attempt2
      )
      |> add_automatic_activity(:attempt1, :activity_a, :attempt_1a, @content_automatic)
      |> add_automatic_activity(
        :attempt1,
        :activity_b,
        :attempt_1b,
        @content_automatic_by_default
      )
      |> add_manual_activity(:attempt2, :activity_c, :attempt_2c)
      |> add_automatic_activity(:attempt2, :activity_d, :attempt_2d, @content_automatic)
    end

    test "finalization results in correct end state for resource attempts", %{
      section: section,
      attempt1: attempt1,
      attempt2: attempt2
    } do
      {:ok, %ResourceAccess{} = resource_access1} =
        PageLifecycle.finalize(section.slug, attempt1.attempt_guid)

      {:ok, %ResourceAccess{} = resource_access2} =
        PageLifecycle.finalize(section.slug, attempt2.attempt_guid)

      ra1 = Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)
      ra2 = Core.get_resource_attempt_by(attempt_guid: attempt2.attempt_guid)

      # Attempt 1 should be in an "evaluated" state, with a score rolled up to the
      # resoure access record, since all activities present were automatically graded
      refute is_nil(resource_access1.score)
      assert ra1.lifecycle_state == :evaluated
      refute is_nil(ra1.date_evaluated)
      refute is_nil(ra1.date_submitted)

      # Attempt 2 should be in a "submitted" state since at least one activity
      # present involved manual grading. No score should exist at the resource access level.
      assert is_nil(resource_access2.score)
      assert ra2.lifecycle_state == :submitted
      assert is_nil(ra2.date_evaluated)
      refute is_nil(ra2.date_submitted)
    end
  end
end
