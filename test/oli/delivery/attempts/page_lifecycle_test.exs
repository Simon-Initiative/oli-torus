defmodule Oli.Delivery.Attempts.PageLifecycleTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.AttemptState
  alias Oli.Delivery.Attempts.PageLifecycle.Hierarchy
  alias Oli.Delivery.Attempts.PageLifecycle.VisitContext
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Delivery.Experiments.RewardHandoffWorker

  alias Oli.Experiments.Schemas.{
    Assignment,
    AssessmentBinding,
    Condition,
    DecisionPoint,
    DecisionPointCondition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention
  }

  alias Oli.Activities.Model.{Part}
  alias Oli.Factory
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

  describe "starting attempts with Alternatives" do
    setup [:setup_tags]

    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_activity(
          %{title: "control", content: @content_automatic, scope: "embedded"},
          :activity_a
        )
        |> Seeder.add_activity(
          %{title: "variant", content: @content_automatic, scope: "embedded"},
          :activity_b
        )

      alternatives_revision =
        Factory.insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_alternatives(),
          content: %{
            "strategy" => "experiment_controlled",
            "options" => [%{"id" => "control"}, %{"id" => "variant"}]
          }
        )

      page_content = %{
        "model" => [
          %{
            "type" => "alternatives",
            "id" => "placement",
            "alternatives_id" => alternatives_revision.resource_id,
            "children" => [
              %{
                "type" => "alternative",
                "value" => "control",
                "children" => [
                  %{
                    "type" => "activity-reference",
                    "activity_id" => map.activity_a.revision.resource_id
                  }
                ]
              },
              %{
                "type" => "alternative",
                "value" => "variant",
                "children" => [
                  %{
                    "type" => "activity-reference",
                    "activity_id" => map.activity_b.revision.resource_id
                  }
                ]
              }
            ]
          }
        ]
      }

      map =
        map
        |> Seeder.add_page(%{title: "graded page", graded: true, content: page_content}, :page)
        |> Seeder.create_section_resources()

      Factory.insert(:project_resource,
        project_id: map.project.id,
        resource_id: alternatives_revision.resource_id
      )

      Factory.insert(:published_resource,
        publication: map.publication,
        resource: alternatives_revision.resource,
        revision: alternatives_revision
      )

      Factory.insert(:section_resource,
        section: map.section,
        project: map.project,
        resource_id: alternatives_revision.resource_id
      )

      Map.put(map, :alternatives_revision, alternatives_revision)
    end

    @tag isolation: "serializable"
    test "explicit start scores and completes only the delivered alternative", %{
      activity_a: activity_a,
      activity_b: activity_b,
      alternatives_revision: alternatives_revision,
      page: %{revision: revision},
      section: section,
      user1: user
    } do
      Oli.Delivery.Sections.enroll(user.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

      enrollment = Oli.Delivery.Sections.get_enrollment(section.slug, user.id)

      experiment =
        %ExperimentDefinition{}
        |> ExperimentDefinition.changeset(%{
          project_id: section.base_project_id,
          slug: "explicit-start-alternatives",
          name: "Explicit start Alternatives",
          state: :active,
          algorithm: :weighted_random
        })
        |> Repo.insert!()

      %ExperimentSection{}
      |> ExperimentSection.changeset(%{experiment_id: experiment.id, section_id: section.id})
      |> Repo.insert!()

      decision_point =
        %DecisionPoint{}
        |> DecisionPoint.changeset(%{
          experiment_id: experiment.id,
          alternatives_resource_id: alternatives_revision.resource_id,
          decision_point_key: "alternatives:#{alternatives_revision.resource_id}",
          algorithm: :weighted_random,
          policy_config: %{}
        })
        |> Repo.insert!()

      intervention =
        %Intervention{}
        |> Intervention.changeset(%{
          decision_point_id: decision_point.id,
          page_resource_id: revision.resource_id,
          content_element_id: "placement"
        })
        |> Repo.insert!()

      variant =
        %Condition{}
        |> Condition.changeset(%{
          experiment_id: experiment.id,
          decision_point_id: decision_point.id,
          condition_code: "variant",
          label: "Variant",
          weight: 1.0,
          position: 1
        })
        |> Repo.insert!()

      %DecisionPointCondition{}
      |> DecisionPointCondition.changeset(%{
        decision_point_id: decision_point.id,
        condition_id: variant.id,
        option_id: "variant",
        weight: 1.0,
        position: 1
      })
      |> Repo.insert!()

      %Assignment{}
      |> Assignment.changeset(%{
        experiment_id: experiment.id,
        decision_point_id: decision_point.id,
        condition_id: variant.id,
        intervention_id: intervention.id,
        section_id: section.id,
        enrollment_id: enrollment.id,
        user_id: user.id,
        assigned_by_policy: "weighted_random",
        assignment_key: "explicit-start-variant",
        assigned_at: DateTime.utc_now(),
        runtime_event_state: %{}
      })
      |> Repo.insert!()

      Core.track_access(revision.resource_id, section.id, user.id)

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user.id)

      activity_provider =
        Oli.Delivery.Experiments.ActivityProvider.for_page(
          &Oli.Delivery.ActivityProvider.provide/6,
          section,
          revision,
          user
        )

      assert {:ok, %AttemptState{} = state} =
               PageLifecycle.start(
                 revision.slug,
                 section.slug,
                 UUID.uuid4(),
                 user,
                 effective_settings,
                 activity_provider
               )

      refute Map.has_key?(state.attempt_hierarchy, activity_a.revision.resource_id)
      assert Map.has_key?(state.attempt_hierarchy, activity_b.revision.resource_id)

      assert state.resource_attempt.experiment_decisions["placement"].condition_code == "variant"

      assert [attribution] = state.resource_attempt.experiment_attributions
      assert attribution["experiment_id"] == experiment.id
      assert attribution["decision_point_id"] == decision_point.id
      assert attribution["condition_id"] == variant.id
      assert attribution["assignment_id"]

      {activity_attempt, _part_attempts} =
        Map.fetch!(state.attempt_hierarchy, activity_b.revision.resource_id)

      {:ok, _activity_attempt} =
        Core.update_activity_attempt(activity_attempt, %{
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0
        })

      assert {:ok, %FinalizationSummary{resource_access: resource_access}} =
               PageLifecycle.finalize(
                 section.slug,
                 state.resource_attempt.attempt_guid,
                 UUID.uuid4()
               )

      resource_attempt = Core.get_resource_attempt(id: state.resource_attempt.id)

      assert resource_attempt.score == 1.0
      assert resource_attempt.out_of == 1.0
      assert resource_access.progress == 1.0
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
      project: project,
      section: section,
      attempt1: attempt1,
      attempt2: attempt2
    } do
      datashop_session_id_user1 = UUID.uuid4()

      assessment_page_resource_id =
        Repo.get!(Oli.Delivery.Attempts.Core.ResourceAccess, attempt1.resource_access_id).resource_id

      add_assessment_binding(project, section, assessment_page_resource_id)

      {:ok, %FinalizationSummary{resource_access: resource_access1}} =
        PageLifecycle.finalize(section.slug, attempt1.attempt_guid, datashop_session_id_user1)

      assert_enqueued(
        worker: RewardHandoffWorker,
        args: %{"resource_attempt_id" => attempt1.id}
      )

      assert {:error, {:already_submitted}} =
               PageLifecycle.finalize(
                 section.slug,
                 attempt1.attempt_guid,
                 datashop_session_id_user1
               )

      assert [_job] = all_enqueued(worker: RewardHandoffWorker)

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

      resource_access =
        Repo.get!(Oli.Delivery.Attempts.Core.ResourceAccess, resource_attempt.resource_access_id)

      assert resource_attempt.lifecycle_state == :evaluated
      assert resource_attempt.score == 2.0
      assert resource_attempt.out_of == 4.0
      assert resource_access.progress == 1.0
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

      resource_access =
        Repo.get!(Oli.Delivery.Attempts.Core.ResourceAccess, resource_attempt.resource_access_id)

      assert resource_attempt.lifecycle_state == :submitted
      assert is_nil(resource_attempt.date_evaluated)
      refute is_nil(resource_attempt.date_submitted)
      assert is_nil(resource_attempt.score)
      assert is_nil(resource_attempt.out_of)
      assert resource_access.progress == 1.0
    end
  end

  defp add_assessment_binding(project, section, assessment_page_resource_id) do
    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "page-finalization-reward-#{System.unique_integer([:positive])}",
        name: "Page finalization reward",
        state: :active,
        algorithm: :thompson_sampling
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{experiment_id: experiment.id, section_id: section.id})
    |> Repo.insert!()

    alternatives = Factory.insert(:revision)

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: experiment.id,
        alternatives_resource_id: alternatives.resource_id,
        decision_point_key: "page-finalization-point",
        algorithm: :thompson_sampling,
        policy_config: %{}
      })
      |> Repo.insert!()

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        decision_point_id: decision_point.id,
        page_resource_id: alternatives.resource_id,
        content_element_id: "page-finalization-placement"
      })
      |> Repo.insert!()

    %AssessmentBinding{}
    |> AssessmentBinding.changeset(%{
      intervention_id: intervention.id,
      assessment_page_resource_id: assessment_page_resource_id,
      reward_threshold: 1.0
    })
    |> Repo.insert!()
  end
end
