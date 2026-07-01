defmodule Oli.Delivery.Attempts.PageLifecycleTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.AttemptState
  alias Oli.Delivery.Attempts.PageLifecycle.Hierarchy
  alias Oli.Delivery.Attempts.PageLifecycle.VisitContext
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Activities.Model.{Part}
  alias Oli.Repo

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
      %Part{id: "1", responses: [], hints: [], grading_approach: :automatic},
      activity_attempt_tag
    )
  end

  describe "starting attempts with instructor activity exclusions" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_activity(
          %{title: "title 1", content: @content_automatic, scope: "embedded"},
          :activity_a
        )
        |> Seeder.add_activity(
          %{title: "title 2", content: @content_automatic, scope: "embedded"},
          :activity_b
        )

      page_content = %{
        "model" => [
          %{
            "type" => "activity-reference",
            "activity_id" => map.activity_a.revision.resource_id,
            "id" => "activity-a"
          },
          %{
            "type" => "activity-reference",
            "activity_id" => map.activity_b.revision.resource_id,
            "id" => "activity-b"
          }
        ]
      }

      map
      |> Seeder.add_page(%{title: "graded page", graded: true, content: page_content}, :page)
      |> Seeder.create_section_resources()
    end

    test "new attempts exclude customized embedded activities without changing historical attempts",
         %{
           activity_a: activity_a,
           activity_b: activity_b,
           page: %{revision: revision},
           publication: publication,
           section: section,
           user1: user
         } do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      datashop_session_id = UUID.uuid4()

      Core.track_access(revision.resource_id, section.id, user.id)

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user.id)

      {:ok, first_resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user: user,
          audience_role: :student,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: publication.id,
          effective_settings: effective_settings
        })

      {:ok, %AttemptState{attempt_hierarchy: first_hierarchy}} =
        AttemptState.fetch_attempt_state(first_resource_attempt, revision)

      assert Map.has_key?(first_hierarchy, activity_a.revision.resource_id)
      assert Map.has_key?(first_hierarchy, activity_b.revision.resource_id)
      assert length(first_resource_attempt.content["model"]) == 2

      %ActivityExclusion{}
      |> ActivityExclusion.changeset(section.id, revision.resource_id, %{
        kind: :embedded_activity,
        excluded_resource_id: activity_a.revision.resource_id
      })
      |> Repo.insert!()

      {:ok, second_resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: first_resource_attempt,
          page_revision: revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user: user,
          audience_role: :student,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: publication.id,
          effective_settings: effective_settings
        })

      {:ok, %AttemptState{attempt_hierarchy: second_hierarchy}} =
        AttemptState.fetch_attempt_state(second_resource_attempt, revision)

      refute Map.has_key?(second_hierarchy, activity_a.revision.resource_id)
      assert Map.has_key?(second_hierarchy, activity_b.revision.resource_id)
      assert length(second_resource_attempt.content["model"]) == 1

      assert hd(second_resource_attempt.content["model"])["activity_id"] ==
               activity_b.revision.resource_id

      historical_attempt = Core.get_resource_attempt(id: first_resource_attempt.id)
      assert length(historical_attempt.content["model"]) == 2
    end
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
      datashop_session_id_user1 = UUID.uuid4()

      {:ok, %FinalizationSummary{resource_access: resource_access1}} =
        PageLifecycle.finalize(section.slug, attempt1.attempt_guid, datashop_session_id_user1)

      {:ok, %FinalizationSummary{resource_access: resource_access2}} =
        PageLifecycle.finalize(section.slug, attempt2.attempt_guid, datashop_session_id_user1)

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

  describe "reset ungraded page attempts" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{title: "title 1"}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{title: "title 2"}, :publication, :project, :author, :activity_b)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_c)
      |> Seeder.add_activity(%{title: "title 3"}, :publication, :project, :author, :activity_d)
      |> Seeder.add_page(%{ungraded: true}, :ungraded_page1)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page1,
        :attempt1
      )
      |> add_automatic_activity(:attempt1, :activity_a, :attempt_1a, @content_automatic)
      |> add_automatic_activity(
        :attempt1,
        :activity_b,
        :attempt_1b,
        @content_automatic_by_default
      )
    end

    test "finalization of ungraded page results in correct end state for resource attempts", %{
      section: section,
      attempt1: attempt1
    } do
      datashop_session_id_user1 = UUID.uuid4()

      ra1 = Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      assert ra1.lifecycle_state == :active
      assert is_nil(ra1.date_evaluated)
      assert is_nil(ra1.date_submitted)

      {:ok, %FinalizationSummary{graded: false}} =
        PageLifecycle.finalize(section.slug, attempt1.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      # Attempt 1 should be in an "evaluated" state, with a nil score since it was ungraded
      assert ra1.lifecycle_state == :evaluated
      refute is_nil(ra1.date_evaluated)
      refute is_nil(ra1.date_submitted)
    end
  end

  describe "adaptive page attempt rollup" do
    setup do
      adaptive_registration = Oli.Activities.get_registration_by_slug("oli_adaptive")

      screen_content = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-mcq",
            "gradingApproach" => "automatic",
            "custom" => %{
              "title" => "MCQ 1",
              "correctAnswer" => [true, false],
              "mcqItems" => [
                %{"nodes" => [%{"text" => "Option 1"}]},
                %{"nodes" => [%{"text" => "Option 2"}]}
              ]
            }
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_1",
              "type" => "janus-mcq",
              "gradingApproach" => "automatic"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_activity(
          %{
            title: "adaptive screen",
            activity_type_id: adaptive_registration.id,
            content: screen_content
          },
          :adaptive_activity
        )
        |> then(fn map ->
          screen_ref = %{
            "type" => "activity-reference",
            "activity_id" => map.adaptive_activity.resource.id
          }

          map
          |> Seeder.add_page(
            %{
              title: "graded adaptive page",
              graded: true,
              content: %{"advancedDelivery" => true, "model" => [screen_ref]}
            },
            :graded_adaptive_page
          )
          |> Seeder.add_page(
            %{
              title: "ungraded adaptive page",
              graded: false,
              content: %{"advancedDelivery" => true, "model" => [screen_ref]}
            },
            :ungraded_adaptive_page
          )
        end)
        |> Seeder.create_section_resources()

      map
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_adaptive_page,
        :graded_attempt
      )
      |> Seeder.create_activity_attempt(
        %{
          attempt_number: 1,
          lifecycle_state: :evaluated,
          score: 3.0,
          out_of: 4.0,
          scoreable: true
        },
        :adaptive_activity,
        :graded_attempt,
        :graded_activity_attempt
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_adaptive_page,
        :ungraded_attempt
      )
      |> Seeder.create_activity_attempt(
        %{
          attempt_number: 1,
          lifecycle_state: :evaluated,
          score: 2.0,
          out_of: 4.0,
          scoreable: true
        },
        :adaptive_activity,
        :ungraded_attempt,
        :ungraded_activity_attempt
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_adaptive_page,
        :ungraded_pending_attempt
      )
      |> Seeder.create_activity_attempt(
        %{
          attempt_number: 1,
          lifecycle_state: :submitted,
          transformed_model: screen_content,
          scoreable: true
        },
        :adaptive_activity,
        :ungraded_pending_attempt,
        :ungraded_pending_activity_attempt
      )
    end

    test "finalization rolls evaluated graded adaptive activity attempts to the resource attempt",
         %{
           section: section,
           graded_attempt: graded_attempt
         } do
      datashop_session_id = UUID.uuid4()

      {:ok, %FinalizationSummary{graded: true}} =
        PageLifecycle.finalize(section.slug, graded_attempt.attempt_guid, datashop_session_id)

      resource_attempt = Core.get_resource_attempt_by(attempt_guid: graded_attempt.attempt_guid)

      assert resource_attempt.lifecycle_state == :evaluated
      assert resource_attempt.score == 3.0
      assert resource_attempt.out_of == 4.0
    end

    test "finalization rolls evaluated ungraded adaptive activity attempts to the resource attempt",
         %{
           section: section,
           ungraded_attempt: ungraded_attempt
         } do
      datashop_session_id = UUID.uuid4()

      {:ok, %FinalizationSummary{graded: false}} =
        PageLifecycle.finalize(section.slug, ungraded_attempt.attempt_guid, datashop_session_id)

      resource_attempt = Core.get_resource_attempt_by(attempt_guid: ungraded_attempt.attempt_guid)

      assert resource_attempt.lifecycle_state == :evaluated
      assert resource_attempt.score == 2.0
      assert resource_attempt.out_of == 4.0
    end

    test "ungraded adaptive finalization stays submitted when manual grading is still pending",
         %{
           section: section,
           ungraded_pending_attempt: ungraded_pending_attempt
         } do
      datashop_session_id = UUID.uuid4()

      assert {:ok, %FinalizationSummary{graded: false, lifecycle_state: :submitted}} =
               PageLifecycle.finalize(
                 section.slug,
                 ungraded_pending_attempt.attempt_guid,
                 datashop_session_id
               )

      resource_attempt =
        Core.get_resource_attempt_by(attempt_guid: ungraded_pending_attempt.attempt_guid)

      assert resource_attempt.lifecycle_state == :submitted
      assert is_nil(resource_attempt.date_evaluated)
      refute is_nil(resource_attempt.date_submitted)
      assert is_nil(resource_attempt.score)
      assert is_nil(resource_attempt.out_of)
    end
  end
end
