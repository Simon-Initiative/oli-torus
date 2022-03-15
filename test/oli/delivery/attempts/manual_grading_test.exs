defmodule Oli.Delivery.Attempts.ManualGradingTest do
  use Oli.DataCase

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Attempts.ManualGrading
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Activities.Model.{Part}

  def add_submitted_activity(map, resource_attempt_tag, activity_tag, activity_attempt_tag) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: :submitted},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :manual,
        date_submitted: DateTime.utc_now(),
        lifecycle_state: :submitted
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :manual},
      activity_attempt_tag
    )
  end

  def add_evaluated_activity(map, resource_attempt_tag, activity_tag, activity_attempt_tag) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: %{some: :thing}, lifecycle_state: :evaluated},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :automatic,
        date_submitted: DateTime.utc_now(),
        lifecycle_state: :evaluated
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :automatic},
      activity_attempt_tag
    )
  end

  describe "browsing manual graded attempts" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{title: "title 1"}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{title: "title 2"}, :publication, :project, :author, :activity_b)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_c)
      |> Seeder.add_activity(%{title: "title 4"}, :publication, :project, :author, :activity_d)
      |> Seeder.add_activity(%{title: "title 5"}, :publication, :project, :author, :activity_e)
      |> Seeder.add_page(%{graded: true}, :graded_page)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user2,
        :page1,
        :revision1,
        :attempt2
      )
      |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)
      |> add_submitted_activity(:attempt1, :activity_b, :attempt_1b)
      |> add_submitted_activity(:attempt1, :activity_c, :attempt_1c)
      |> add_submitted_activity(:attempt1, :activity_d, :attempt_1d)
      |> add_submitted_activity(:attempt2, :activity_a, :attempt_2a)
      |> add_submitted_activity(:attempt2, :activity_b, :attempt_2b)
      |> add_submitted_activity(:attempt2, :activity_c, :attempt_2c)
      |> add_submitted_activity(:attempt2, :activity_d, :attempt_2d)
      |> add_evaluated_activity(:attempt1, :activity_e, :attempt_1e)
      |> add_evaluated_activity(:attempt2, :activity_e, :attempt_2e)
    end

    test "basic browsing", %{
      section: section,
      user1: user1,
      activity_a: activity_a
    } do
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: nil,
            graded: nil,
            text_search: nil
          }
        )

      assert Enum.count(result) == 3
      assert Enum.at(result, 0).total_count == 8

      # Filter by user
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: user1.id,
            activity_id: nil,
            graded: nil,
            text_search: nil
          }
        )

      assert Enum.count(result) == 3
      assert Enum.at(result, 0).total_count == 4

      # Filter by activity
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: activity_a.resource.id,
            graded: nil,
            text_search: nil
          }
        )

      assert Enum.count(result) == 2
      assert Enum.at(result, 0).total_count == 2

      # Filter by graded = true
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: nil,
            graded: true,
            text_search: nil
          }
        )

      assert Enum.count(result) == 0

      # Filter by graded = false
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: nil,
            graded: false,
            text_search: nil
          }
        )

      assert Enum.count(result) == 3
      assert Enum.at(result, 0).total_count == 8

      # Filter by text search
      result =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 3, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: nil,
            graded: nil,
            text_search: "title 2"
          }
        )

      assert Enum.count(result) == 2
      assert Enum.at(result, 0).total_count == 2
    end
  end
end
