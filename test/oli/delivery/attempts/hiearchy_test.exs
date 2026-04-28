defmodule Oli.Delivery.Attempts.PageLifecycle.HierarchyTest do
  use Oli.DataCase

  alias Oli.Activities
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.PageLifecycle.{Hierarchy, VisitContext, AttemptState}

  describe "creating the attempt tree records" do
    setup do
      content1 = %{
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

      content2 = %{
        "stem" => "2",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "some_key",
              "responses" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            },
            %{
              "id" => "some_other_key",
              "responses" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_activity(%{title: "one", content: content1}, :a1)
        |> Seeder.add_activity(%{title: "two", content: content2}, :a2)
        |> Seeder.add_activity(%{title: "three", content: content1, scope: :banked}, :a3)
        |> Seeder.add_activity(%{title: "three", content: content1, scope: :banked}, :a3)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
        graded: true
      }

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(map, attrs, :p1)
      |> Seeder.create_section_resources()
    end

    test "create the attempt tree", %{
      p1: p1,
      user1: user,
      section: section,
      a1: a1,
      a2: a2,
      publication: pub
    } do
      Attempts.track_access(p1.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      datashop_session_id = UUID.uuid4()

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user: user,
          audience_role: :student,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id,
          effective_settings:
            Oli.Delivery.Settings.get_combined_settings(p1.revision, section.id, user.id)
        })

      assert resource_attempt.lifecycle_state == :active

      # verify that creating the attempt tree returns both activity attempts
      {:ok, %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: attempts}} =
        AttemptState.fetch_attempt_state(resource_attempt, p1.revision)

      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

      # verify that reading the latest attempts back from the db gives us
      # the same results
      attempts = Hierarchy.get_latest_attempts(resource_attempt.id)

      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

      {act_attempt1, part_map1} = Map.get(attempts, a1.resource.id)
      {act_attempt2, part_map2} = Map.get(attempts, a2.resource.id)

      assert act_attempt1.lifecycle_state == :active
      assert act_attempt2.lifecycle_state == :active

      pa1 = Map.get(part_map1, "1")
      pa2 = Map.get(part_map2, "some_key")
      pa3 = Map.get(part_map2, "some_other_key")

      assert pa1.activity_attempt_id == act_attempt1.id
      assert pa2.activity_attempt_id == act_attempt2.id
      assert pa3.activity_attempt_id == act_attempt2.id

      assert pa1.lifecycle_state == :active
      assert pa2.lifecycle_state == :active
      assert pa3.lifecycle_state == :active

      assert %{attempt_number: 1, part_id: "1", hints: []} = pa1

      assert %{
               attempt_number: 1,
               part_id: "some_key",
               hints: []
             } = pa2

      assert %{
               attempt_number: 1,
               part_id: "some_other_key",
               hints: []
             } = pa3

      assert pa1.attempt_guid != pa2.attempt_guid
      assert pa3.attempt_guid != pa2.attempt_guid
      assert pa3.attempt_guid != pa1.attempt_guid
    end

    test "adaptive attempt creation keeps stateful non-scorable parts but skips display-only parts" do
      adaptive_registration = Activities.get_registration_by_slug("oli_adaptive")

      adaptive_content = %{
        "partsLayout" => [
          %{
            "id" => "janus_formula-1",
            "type" => "janus-formula",
            "custom" => %{"title" => "Formula"}
          },
          %{
            "id" => "janus_mcq-1",
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
          },
          %{
            "id" => "janus_navigation_button-1",
            "type" => "janus-navigation-button",
            "custom" => %{"title" => "Begin"}
          },
          %{
            "id" => "janus_popup-1",
            "type" => "janus-popup",
            "custom" => %{"title" => "Popup"}
          },
          %{
            "id" => "janus_audio-1",
            "type" => "janus-audio",
            "custom" => %{"title" => "Audio"}
          },
          %{
            "id" => "janus_video-1",
            "type" => "janus-video",
            "custom" => %{"title" => "Video"}
          },
          %{
            "id" => "janus_image_carousel-1",
            "type" => "janus-image-carousel",
            "custom" => %{"title" => "Carousel"}
          },
          %{
            "id" => "janus_capi_iframe-1",
            "type" => "janus-capi-iframe",
            "custom" => %{"title" => "Simulation"}
          }
        ],
        "authoring" => %{
          "parts" => [
            %{"id" => "janus_formula-1", "type" => "janus-formula"},
            %{
              "id" => "janus_mcq-1",
              "type" => "janus-mcq",
              "gradingApproach" => "automatic"
            },
            %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"},
            %{"id" => "janus_popup-1", "type" => "janus-popup"},
            %{"id" => "janus_audio-1", "type" => "janus-audio"},
            %{"id" => "janus_video-1", "type" => "janus-video"},
            %{"id" => "janus_image_carousel-1", "type" => "janus-image-carousel"},
            %{"id" => "janus_capi_iframe-1", "type" => "janus-capi-iframe"}
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :adaptive_user)
        |> Seeder.add_activity(
          %{
            title: "adaptive",
            activity_type_id: adaptive_registration.id,
            content: adaptive_content
          },
          :adaptive_activity
        )
        |> then(fn map ->
          attrs = %{
            title: "adaptive page",
            content: %{
              "model" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => map.adaptive_activity.resource.id
                }
              ]
            },
            graded: true
          }

          Seeder.add_page(map, attrs, :adaptive_page)
        end)
        |> then(fn map ->
          Seeder.ensure_published(map.publication.id)
          map
        end)
        |> Seeder.create_section_resources()

      adaptive_page = map.adaptive_page
      adaptive_user = map.adaptive_user
      adaptive_activity = map.adaptive_activity

      Attempts.track_access(adaptive_page.resource.id, map.section.id, adaptive_user.id)

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: adaptive_page.revision,
          section_slug: map.section.slug,
          datashop_session_id: UUID.uuid4(),
          user: adaptive_user,
          audience_role: :student,
          activity_provider: &Oli.Delivery.ActivityProvider.provide/6,
          blacklisted_activity_ids: [],
          publication_id: map.publication.id,
          effective_settings:
            Oli.Delivery.Settings.get_combined_settings(
              adaptive_page.revision,
              map.section.id,
              adaptive_user.id
            )
        })

      {:ok, %AttemptState{attempt_hierarchy: attempts}} =
        AttemptState.fetch_attempt_state(resource_attempt, adaptive_page.revision)

      {_activity_attempt, part_map} = Map.fetch!(attempts, adaptive_activity.resource.id)

      assert Map.keys(part_map) |> Enum.sort() == [
               "janus_audio-1",
               "janus_capi_iframe-1",
               "janus_image_carousel-1",
               "janus_mcq-1",
               "janus_navigation_button-1",
               "janus_popup-1",
               "janus_video-1"
             ]

      assert part_map["janus_audio-1"].grading_approach == :automatic
      assert part_map["janus_capi_iframe-1"].grading_approach == :automatic
      assert part_map["janus_image_carousel-1"].grading_approach == :automatic
      assert part_map["janus_navigation_button-1"].grading_approach == :automatic
      assert part_map["janus_popup-1"].grading_approach == :automatic
      assert part_map["janus_video-1"].grading_approach == :automatic
      refute Map.has_key?(part_map, "janus_formula-1")
    end

    test "adaptive attempt creation includes explicitly rule-scored display-only parts only" do
      adaptive_registration = Activities.get_registration_by_slug("oli_adaptive")

      adaptive_content = %{
        "partsLayout" => [
          %{
            "id" => "janus_capi_iframe-1",
            "type" => "janus-capi-iframe",
            "custom" => %{"title" => "Simulation"}
          },
          %{
            "id" => "janus_formula-1",
            "type" => "janus-formula",
            "custom" => %{"title" => "Formula"}
          },
          %{
            "id" => "janus_mcq-1",
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
            %{"id" => "janus_capi_iframe-1", "type" => "janus-capi-iframe"},
            %{"id" => "janus_formula-1", "type" => "janus-formula"},
            %{
              "id" => "janus_mcq-1",
              "type" => "janus-mcq",
              "gradingApproach" => "automatic"
            }
          ],
          "rules" => [
            %{
              "id" => "r.correct",
              "name" => "correct",
              "disabled" => false,
              "default" => false,
              "correct" => true,
              "conditions" => %{
                "all" => [
                  %{
                    "fact" => "stage.janus_capi_iframe-1.simScore",
                    "operator" => "equal",
                    "value" => "100"
                  }
                ]
              },
              "event" => %{
                "type" => "r.correct",
                "params" => %{"actions" => []}
              }
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :adaptive_user)
        |> Seeder.add_activity(
          %{
            title: "adaptive compatibility",
            activity_type_id: adaptive_registration.id,
            content: adaptive_content
          },
          :adaptive_activity
        )
        |> then(fn map ->
          attrs = %{
            title: "adaptive page",
            content: %{
              "model" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => map.adaptive_activity.resource.id
                }
              ]
            },
            graded: true
          }

          Seeder.add_page(map, attrs, :adaptive_page)
        end)
        |> then(fn map ->
          Seeder.ensure_published(map.publication.id)
          map
        end)
        |> Seeder.create_section_resources()

      adaptive_page = map.adaptive_page
      adaptive_user = map.adaptive_user
      adaptive_activity = map.adaptive_activity

      Attempts.track_access(adaptive_page.resource.id, map.section.id, adaptive_user.id)

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: adaptive_page.revision,
          section_slug: map.section.slug,
          datashop_session_id: UUID.uuid4(),
          user: adaptive_user,
          audience_role: :student,
          activity_provider: &Oli.Delivery.ActivityProvider.provide/6,
          blacklisted_activity_ids: [],
          publication_id: map.publication.id,
          effective_settings:
            Oli.Delivery.Settings.get_combined_settings(
              adaptive_page.revision,
              map.section.id,
              adaptive_user.id
            )
        })

      {:ok, %AttemptState{attempt_hierarchy: attempts}} =
        AttemptState.fetch_attempt_state(resource_attempt, adaptive_page.revision)

      {_activity_attempt, part_map} = Map.fetch!(attempts, adaptive_activity.resource.id)

      assert Map.keys(part_map) |> Enum.sort() == ["janus_capi_iframe-1", "janus_mcq-1"]
      assert part_map["janus_capi_iframe-1"].grading_approach == :automatic
      assert part_map["janus_mcq-1"].grading_approach == :automatic
      refute Map.has_key?(part_map, "janus_formula-1")
    end

    test "adaptive attempt creation respects custom manual grading flags even when authored metadata is stale" do
      adaptive_registration = Activities.get_registration_by_slug("oli_adaptive")

      adaptive_content = %{
        "partsLayout" => [
          %{
            "id" => "janus_multi_line_text-1",
            "type" => "janus-multi-line-text",
            "custom" => %{
              "requiresManualGrading" => true,
              "maxScore" => 1
            }
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "janus_multi_line_text-1",
              "type" => "janus-multi-line-text",
              "gradingApproach" => "automatic"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :adaptive_user)
        |> Seeder.add_activity(
          %{
            title: "adaptive manual grading sync",
            activity_type_id: adaptive_registration.id,
            content: adaptive_content
          },
          :adaptive_activity
        )
        |> then(fn map ->
          attrs = %{
            title: "adaptive page",
            content: %{
              "model" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => map.adaptive_activity.resource.id
                }
              ]
            },
            graded: true
          }

          Seeder.add_page(map, attrs, :adaptive_page)
        end)
        |> then(fn map ->
          Seeder.ensure_published(map.publication.id)
          map
        end)
        |> Seeder.create_section_resources()

      adaptive_page = map.adaptive_page
      adaptive_user = map.adaptive_user
      adaptive_activity = map.adaptive_activity

      Attempts.track_access(adaptive_page.resource.id, map.section.id, adaptive_user.id)

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: adaptive_page.revision,
          section_slug: map.section.slug,
          datashop_session_id: UUID.uuid4(),
          user: adaptive_user,
          audience_role: :student,
          activity_provider: &Oli.Delivery.ActivityProvider.provide/6,
          blacklisted_activity_ids: [],
          publication_id: map.publication.id,
          effective_settings:
            Oli.Delivery.Settings.get_combined_settings(
              adaptive_page.revision,
              map.section.id,
              adaptive_user.id
            )
        })

      {:ok, %AttemptState{attempt_hierarchy: attempts}} =
        AttemptState.fetch_attempt_state(resource_attempt, adaptive_page.revision)

      {_activity_attempt, part_map} = Map.fetch!(attempts, adaptive_activity.resource.id)

      assert Map.keys(part_map) == ["janus_multi_line_text-1"]
      assert part_map["janus_multi_line_text-1"].grading_approach == :manual
    end
  end
end
