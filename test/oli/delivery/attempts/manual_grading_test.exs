defmodule Oli.Delivery.Attempts.ManualGradingTest do
  use Oli.DataCase

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Attempts.ManualGrading
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Activities.Model.{Part}
  alias Oli.Delivery.Attempts.Core

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

  describe "applying scores and feedback" do
    setup do
      map = Seeder.base_project_with_resource2()
      Oli.Resources.update_revision(map.revision2, %{graded: true})

      map
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{title: "title 1"}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{title: "title 2"}, :publication, :project, :author, :activity_b)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_c)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :active},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user1,
        :page2,
        :revision2,
        :attempt2
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user2,
        :page2,
        :revision2,
        :attempt3
      )
      |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)
      |> add_submitted_activity(:attempt2, :activity_b, :attempt_2b)
      |> add_submitted_activity(:attempt3, :activity_b, :attempt_3b)
      |> add_submitted_activity(:attempt3, :activity_c, :attempt_3c)
    end

    test "basic application of scores", %{
      section: section,
      attempt_1a: attempt_1a,
      attempt_2b: attempt_2b,
      attempt_3b: attempt_3b,
      attempt_3c: attempt_3c,
      publication: publication
    } do
      Seeder.ensure_published(publication.id)

      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 4, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: nil,
            page_id: nil,
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :active
      aa = Core.get_activity_attempt_by(attempt_guid: attempt.attempt_guid)
      assert aa.lifecycle_state == :evaluated

      attempt = Enum.find(results, fn a -> a.id == attempt_2b.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :evaluated
      aa = Core.get_activity_attempt_by(attempt_guid: attempt.attempt_guid)
      assert aa.lifecycle_state == :evaluated

      attempt = Enum.find(results, fn a -> a.id == attempt_3b.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :submitted

      attempt = Enum.find(results, fn a -> a.id == attempt_3c.id end)
      ManualGrading.apply_manual_scoring(section, attempt, create_score_feedbacks(attempt))

      ra = Core.get_resource_attempt_by(attempt_guid: attempt.resource_attempt_guid)
      assert ra.lifecycle_state == :evaluated

      # Verify that manual scoring of the last activity triggers grade roll up to the resource access
      resource_access =
        Oli.Repo.get!(Oli.Delivery.Attempts.Core.ResourceAccess, ra.resource_access_id)

      assert resource_access.out_of == 2.0
      assert resource_access.score == 2.0
    end
  end

  def create_score_feedbacks(activity_attempt) do
    Oli.Delivery.Attempts.Core.get_latest_part_attempts(activity_attempt.attempt_guid)
    |> Enum.reduce(%{}, fn pa, m ->
      Map.put(m, pa.attempt_guid, %{score: 1, out_of: 1, feedback: "test"})
    end)
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
            page_id: nil,
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
            page_id: nil,
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
            page_id: nil,
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
            page_id: nil,
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
            page_id: nil,
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
            page_id: nil,
            graded: nil,
            text_search: "title 2"
          }
        )

      assert Enum.count(result) == 2
      assert Enum.at(result, 0).total_count == 2
    end
  end

  describe "apply_manual_scoring/3" do
    setup do
      map = Seeder.base_project_with_resource2()
      Oli.Resources.update_revision(map.revision2, %{graded: true})

      map
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{title: "activity manual"},
        :publication,
        :project,
        :author,
        :activity_a
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :submitted},
        :user1,
        :page2,
        :revision2,
        :attempt1
      )
      |> add_submitted_activity(:attempt1, :activity_a, :attempt_1a)
    end

    test "applies manual scoring and updates states", %{
      section: section,
      attempt_1a: attempt_1a
    } do
      results =
        ManualGrading.browse_submitted_attempts(
          section,
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :date_submitted, direction: :desc},
          %BrowseOptions{
            user_id: nil,
            activity_id: nil,
            page_id: nil,
            graded: nil,
            text_search: nil
          }
        )

      attempt = Enum.find(results, fn a -> a.id == attempt_1a.id end)
      assert attempt.lifecycle_state == :submitted
      assert attempt.graded

      # Applies manual scoring
      result =
        Oli.Delivery.Attempts.ManualGrading.apply_manual_scoring(
          section,
          attempt,
          create_score_feedbacks(attempt)
        )

      # Returns {:ok, [guid, ...]}
      assert {:ok, part_guids} = result
      assert is_list(part_guids)
      assert length(part_guids) == 1

      # Verifies that the returned GUIDs are the ones associated with the part attempts
      part_attempts = Oli.Delivery.Attempts.Core.get_latest_part_attempts(attempt_1a.attempt_guid)
      expected_guids = Enum.map(part_attempts, & &1.attempt_guid)
      assert Enum.sort(part_guids) == Enum.sort(expected_guids)

      # The activity attempt must be evaluated
      aa = Oli.Delivery.Attempts.Core.get_activity_attempt_by(id: attempt_1a.id)
      assert aa.lifecycle_state == :evaluated

      # The resource attempt must be evaluated
      ra = Oli.Delivery.Attempts.Core.get_resource_attempt_by(id: aa.resource_attempt_id)
      assert ra.lifecycle_state == :evaluated
    end
  end
end
