defmodule OliWeb.Delivery.Student.ContentLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Repo
  alias Oli.Analytics.Summary
  alias Oli.Analytics.Common.Pipeline
  alias OliWeb.Delivery.Student.Utils
  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Analytics.Summary.{
    AttemptGroup
  }

  @default_selected_view :gallery

  defp set_progress(section_id, resource_id, user_id, progress, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress, score: 1.0, out_of: 2.0})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
  end

  defp create_elixir_project(_, add_schedule? \\ true) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## objectives
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 2"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 3"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 4"
      )

    ## activities...
    mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

    mcq_activity_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id,
            objective_2_revision.resource_id,
            objective_3_revision.resource_id,
            objective_4_revision.resource_id
          ]
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 1",
        content: generate_mcq_content("This is the first question")
      )

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10
      )

    exploration_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Exploration 1",
        content: %{
          model: [],
          advancedDelivery: true,
          displayApplicactionChrome: false
        }
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        duration_minutes: 15
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        graded: true,
        duration_minutes: 22,
        content: %{
          model: [
            %{
              id: "4286170280",
              type: "content",
              children: [
                %{
                  id: "2905665054",
                  type: "p",
                  children: [
                    %{
                      text: "This is a page with a multiple choice activity."
                    }
                  ]
                }
              ]
            },
            %{
              id: "3330767711",
              type: "activity-reference",
              children: [],
              activity_id: mcq_activity_1_revision.resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 5",
        duration_minutes: 0
      )

    page_6_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 6",
        duration_minutes: 0
      )

    page_7_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 7",
        duration_minutes: 12
      )

    page_8_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 8",
        graded: true,
        duration_minutes: 10
      )

    page_9_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 9",
        graded: true
      )

    page_10_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 10",
        graded: true
      )

    top_level_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Top Level Page",
        graded: true
      )

    page_11_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 11",
        duration_minutes: 10
      )

    page_12_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 12",
        duration_minutes: 15
      )

    page_13_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 13",
        duration_minutes: 15
      )

    page_14_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 14",
        duration_minutes: 15
      )

    page_15_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 15 - in class activity",
        duration_minutes: 15
      )

    page_16_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 16",
        duration_minutes: 11
      )

    page_17_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 17",
        duration_minutes: 18
      )

    page_18_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 18",
        duration_minutes: 1
      )

    # sections and sub-sections...

    subsection_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          page_11_revision.resource_id,
          page_13_revision.resource_id,
          page_14_revision.resource_id,
          page_15_revision.resource_id
        ],
        title: "Erlang as a motivation"
      })

    section_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [subsection_1_revision.resource_id, page_12_revision.resource_id],
        title: "Why Elixir?"
      })

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          page_1_revision.resource_id,
          page_2_revision.resource_id
        ],
        title: "How to use this course",
        poster_image: "module_1_custom_image_url",
        intro_content: %{
          children: [
            %{
              id: "2905665054",
              type: "p",
              children: [
                %{
                  text: "Throughout this unit you will learn how to use this course."
                }
              ]
            }
          ]
        },
        intro_video: "some_intro_video_url"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id, page_4_revision.resource_id],
        title: "Configure your setup"
      })

    module_3_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_5_revision.resource_id, page_6_revision.resource_id],
        title: "Installing Elixir, OTP and Phoenix"
      })

    module_4_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [section_1_revision.resource_id],
        title: "Final thoughts"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          module_1_revision.resource_id,
          module_2_revision.resource_id,
          page_16_revision.resource_id,
          page_17_revision.resource_id,
          page_18_revision.resource_id
        ],
        title: "Introduction",
        poster_image: "some_image_url",
        intro_video: "youtube.com/watch?v=123456789ab",
        # this duration corresponds to the intro video
        duration_minutes: 23
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_3_revision.resource_id],
        title: "Building a Phoenix app",
        poster_image: "some_other_image_url"
      })

    unit_3_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_7_revision.resource_id, page_8_revision.resource_id],
        title: "Implementing LiveView"
      })

    unit_4_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_9_revision.resource_id],
        title: "Learning OTP",
        poster_image: "some_other_image_url",
        intro_video: "s3_video_url"
      })

    unit_5_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_10_revision.resource_id, module_4_revision.resource_id],
        title: "Learning Macros",
        intro_video: "another_video"
      })

    unit_6_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [exploration_1_revision.resource_id],
        title: "What did you learn?"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id,
          unit_3_revision.resource_id,
          unit_4_revision.resource_id,
          unit_5_revision.resource_id,
          unit_6_revision.resource_id,
          top_level_page_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        objective_1_revision,
        objective_2_revision,
        objective_3_revision,
        objective_4_revision,
        mcq_activity_1_revision,
        page_1_revision,
        exploration_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        page_6_revision,
        page_7_revision,
        page_8_revision,
        page_9_revision,
        page_10_revision,
        top_level_page_revision,
        page_11_revision,
        page_12_revision,
        page_13_revision,
        page_14_revision,
        page_15_revision,
        page_16_revision,
        page_17_revision,
        page_18_revision,
        section_1_revision,
        subsection_1_revision,
        module_1_revision,
        module_2_revision,
        module_3_revision,
        module_4_revision,
        unit_1_revision,
        unit_2_revision,
        unit_3_revision,
        unit_4_revision,
        unit_5_revision,
        unit_6_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    if add_schedule? do
      # schedule start and end date for unit 1 section_resource
      Sections.get_section_resource(section.id, unit_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2023-10-31 20:00:00Z],
        end_date: ~U[2023-12-31 20:00:00Z]
      })

      # schedule start and end date for module 1 section_resource
      Sections.get_section_resource(section.id, module_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2023-11-01 20:00:00Z],
        end_date: ~U[2023-11-15 20:00:00Z]
      })

      # schedule start and end date for page 4 section_resource
      Sections.get_section_resource(section.id, page_4_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2023-11-02 20:00:00Z],
        end_date: ~U[2023-11-03 20:00:00Z]
      })

      # schedule start and end date for page 11 and 12 section_resource
      Sections.get_section_resource(section.id, page_11_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2023-11-02 20:00:00Z],
        end_date: ~U[2023-11-03 20:00:00Z]
      })

      Sections.get_section_resource(section.id, page_12_revision.resource_id)
      |> Sections.update_section_resource(%{
        scheduling_type: :due_by,
        start_date: ~U[2023-11-02 20:00:00Z],
        end_date: ~U[2023-11-03 20:00:00Z]
      })

      # set page 15 to in class activity and page 14 to due by
      Sections.get_section_resource(section.id, page_15_revision.resource_id)
      |> Sections.update_section_resource(%{
        scheduling_type: :inclass_activity
      })

      Sections.get_section_resource(section.id, page_14_revision.resource_id)
      |> Sections.update_section_resource(%{
        scheduling_type: :due_by
      })
    end

    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      mcq_1: mcq_activity_1_revision,
      page_1: page_1_revision,
      exploration_1: exploration_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_5_revision,
      page_6: page_6_revision,
      page_7: page_7_revision,
      page_8: page_8_revision,
      page_9: page_9_revision,
      page_10: page_10_revision,
      top_level_page: top_level_page_revision,
      page_11: page_11_revision,
      page_12: page_12_revision,
      page_13: page_13_revision,
      page_16: page_16_revision,
      page_17: page_17_revision,
      page_18: page_18_revision,
      section_1: section_1_revision,
      subsection_1: subsection_1_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      module_3: module_3_revision,
      module_4: module_4_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      unit_3: unit_3_revision,
      unit_4: unit_4_revision,
      unit_5: unit_5_revision,
      unit_6: unit_6_revision
    }
  end

  defp generate_mcq_content(title) do
    %{
      "stem" => %{
        "id" => "2028833010",
        "content" => [
          %{"id" => "280825708", "type" => "p", "children" => [%{"text" => title}]}
        ]
      },
      "choices" => generate_choices("2028833010"),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "hints" => [
              %{
                "id" => "540968727",
                "content" => [
                  %{"id" => "2256338253", "type" => "p", "children" => [%{"text" => ""}]}
                ]
              },
              %{
                "id" => "2627194758",
                "content" => [
                  %{"id" => "3013119256", "type" => "p", "children" => [%{"text" => ""}]}
                ]
              },
              %{
                "id" => "2413327578",
                "content" => [
                  %{"id" => "3742562774", "type" => "p", "children" => [%{"text" => ""}]}
                ]
              }
            ],
            "outOf" => nil,
            "responses" => [
              %{
                "id" => "4122423546",
                "rule" => "(!(input like {1968053412})) && (input like {1436663133})",
                "score" => 1,
                "feedback" => %{
                  "id" => "685174561",
                  "content" => [
                    %{
                      "id" => "2621700133",
                      "type" => "p",
                      "children" => [%{"text" => "Correct"}]
                    }
                  ]
                }
              },
              %{
                "id" => "3738563441",
                "rule" => "input like {.*}",
                "score" => 0,
                "feedback" => %{
                  "id" => "3796426513",
                  "content" => [
                    %{
                      "id" => "1605260471",
                      "type" => "p",
                      "children" => [%{"text" => "Incorrect"}]
                    }
                  ]
                }
              }
            ],
            "gradingApproach" => "automatic",
            "scoringStrategy" => "average"
          }
        ],
        "correct" => [["1436663133"], "4122423546"],
        "version" => 2,
        "targeted" => [],
        "previewText" => "",
        "transformations" => [
          %{
            "id" => "1349799137",
            "path" => "choices",
            "operation" => "shuffle",
            "firstAttemptOnly" => true
          }
        ]
      }
    }
  end

  defp generate_choices(id),
    do: [
      %{
        # this id value is the one that should be passed to set_activity_attempt as response_input_value
        id: "id_for_option_a",
        content: [
          %{
            id: "1866911747",
            type: "p",
            children: [%{text: "Choice 1 for #{id}"}]
          }
        ]
      },
      %{
        id: "id_for_option_b",
        content: [
          %{
            id: "3926142114",
            type: "p",
            children: [%{text: "Choice 2 for #{id}"}]
          }
        ]
      }
    ]

  defp set_activity_attempt(
         page,
         %{activity_type_id: activity_type_id} = activity_revision,
         student,
         section,
         project_id,
         publication_id,
         response_input_value,
         correct
       ) do
    resource_access =
      get_or_insert_resource_access(student, section, page.resource)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: page,
        lifecycle_state: :evaluated,
        date_evaluated: ~U[2020-01-01 00:00:00Z]
      })

    transformed_model =
      case activity_type_id do
        9 ->
          %{choices: generate_choices(activity_revision.id)}

        _ ->
          nil
      end

    activity_attempt =
      insert(:activity_attempt, %{
        revision: activity_revision,
        resource: activity_revision.resource,
        resource_attempt: resource_attempt,
        lifecycle_state: :evaluated,
        transformed_model: transformed_model,
        score: if(correct, do: 1, else: 0),
        out_of: 1
      })

    part_attempt =
      insert(:part_attempt, %{
        part_id: "1",
        activity_attempt: activity_attempt,
        response: %{"files" => [], "input" => response_input_value}
      })

    context = %Context{
      user_id: student.id,
      host_name: "localhost",
      section_id: section.id,
      project_id: project_id,
      publication_id: publication_id
    }

    build_analytics_v2(
      context,
      page.resource_id,
      activity_revision,
      activity_attempt,
      part_attempt
    )
  end

  defp build_analytics_v2(
         context,
         page_id,
         activity_revision,
         activity_attempt,
         part_attempt
       ) do
    group = %AttemptGroup{
      context: context,
      part_attempts: [
        %{
          part_id: part_attempt.part_id,
          response: part_attempt.response,
          score: activity_attempt.score,
          lifecycle_state: :evaluated,
          out_of: activity_attempt.out_of,
          activity_revision: activity_revision,
          hints: [],
          attempt_number: activity_attempt.attempt_number,
          activity_attempt: activity_attempt
        }
      ],
      activity_attempts: [],
      resource_attempt: %{resource_id: page_id}
    }

    Pipeline.init("test")
    |> Map.put(:data, group)
    |> Summary.upsert_resource_summaries()
    |> Summary.upsert_response_summaries()
  end

  defp get_or_insert_resource_access(student, section, resource) do
    resource_access =
      Repo.get_by(
        ResourceAccess,
        resource_id: resource.id,
        section_id: section.id,
        user_id: student.id
      )

    if resource_access do
      resource_access
    else
      insert(:resource_access, %{
        resource: resource,
        resource_id: resource.id,
        section: section,
        section_id: section.id,
        user: student,
        user_id: student.id
      })
    end
  end

  defp enroll_as_student(%{user: user, section: section} = context) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
    context
  end

  defp mark_section_visited(%{section: section, user: user} = context) do
    Sections.mark_section_visited_for_student(section, user)
    context
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, Utils.learn_live_path(section.slug))

      assert redirect_path == "/users/log_in"
    end
  end

  describe "student at Gallery view mode (the default view)" do
    setup [:user_conn, :create_elixir_project, :enroll_as_student, :mark_section_visited]

    test "can access when enrolled to course", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "h3", "Introduction")
      assert has_element?(view, "h3", "Building a Phoenix app")
      assert has_element?(view, "h3", "Implementing LiveView")
    end

    test "renders paywall message when grace period is not over (or gets redirected when over)",
         %{
           conn: conn,
           section: section
         } do
      stub_current_time(~U[2024-10-15 20:00:00Z])

      {:ok, product} =
        Sections.update_section(section, %{
          type: :blueprint,
          registration_open: true,
          requires_payment: true,
          amount: Money.new(10, "USD"),
          has_grace_period: true,
          grace_period_days: 18,
          start_date: ~U[2024-10-15 20:00:00Z],
          end_date: ~U[2024-11-30 20:00:00Z]
        })

      {:ok, view, _html} = live(conn, Utils.learn_live_path(product.slug))

      assert has_element?(
               view,
               "div[id=pay_early_message]",
               "You have 18 days left of your grace period for accessing this course"
             )

      # Grace period is over
      stub_current_time(~U[2024-11-13 20:00:00Z])

      redirect_path = "/sections/#{product.slug}/payment"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, Utils.learn_live_path(product.slug))
    end

    test "can see unit intro as first slider card and play the video (if provided)", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # unit 1 has an intro card with a video url provided, so there must be a play button
      assert has_element?(
               view,
               ~s{div[role="unit_1"] div[role="slider"] div[role="youtube_intro_video_card"] div[role="play_unit_intro_video"]}
             )

      # unit 2 has no video intro card
      refute has_element?(
               view,
               ~s{div[role="unit_2"] div[role="slider"] div[role="youtube_intro_video_card"] div[role="play_unit_intro_video"]}
             )

      # unit 3 has no video intro card
      refute has_element?(
               view,
               ~s{div[role="unit_3"] div[role="slider"] div[role="youtube_intro_video_card"]}
             )
    end

    test "can see card top label for intro videos, graded pages, practice pages and modules", %{
      conn: conn,
      section: section,
      unit_1: unit_1,
      page_7: practice_page,
      page_8: graded_page,
      module_1: module_1
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(
               view,
               ~s{div[id="intro_card_#{unit_1.resource_id}"] span[role="card top label"]},
               "INTRO"
             )

      assert has_element?(
               view,
               ~s{div[id="page_#{practice_page.resource_id}"] span[role="card top label"]},
               "PAGE"
             )

      assert has_element?(
               view,
               ~s{div[id="page_#{graded_page.resource_id}"] span[role="card top label"]},
               "PAGE"
             )

      assert has_element?(
               view,
               ~s{div[id="module_#{module_1.resource_id}"] span[role="card top label"]},
               "MODULE 1"
             )
    end

    test "can see not completed card badge for intro videos, practice pages and modules",
         %{
           conn: conn,
           section: section,
           unit_1: unit_1,
           page_7: practice_page,
           page_8: graded_page,
           module_1: module_1
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(
               view,
               ~s{div[id="intro_card_#{unit_1.resource_id}"] div[role="card badge"]},
               "23 min"
             )

      assert has_element?(
               view,
               ~s{div[id="page_#{practice_page.resource_id}"] div[role="card badge"]},
               "12 min"
             )

      assert has_element?(
               view,
               ~s{div[id="page_#{graded_page.resource_id}"] div[role="card badge"]},
               "10 min"
             )

      assert has_element?(
               view,
               ~s{div[id="module_#{module_1.resource_id}"] div[role="card badge"]},
               "2 pages · 25m"
             )
    end

    test "can not see card badge for pages that have no duration time set",
         %{
           conn: conn,
           section: section,
           page_9: page_9
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      refute has_element?(
               view,
               ~s{div[id="page_#{page_9.resource_id}"] div[role="card badge"]}
             )
    end

    test "can see completed card badge for intro videos, graded pages, practice pages and modules",
         %{
           conn: conn,
           section: section,
           user: user,
           unit_1: unit_1,
           page_1: page_1,
           page_2: page_2,
           page_7: practice_page,
           page_8: graded_page,
           module_1: module_1,
           mcq_1: mcq_1,
           project: project,
           publication: publication
         } do
      # complete all pages except the graded one
      [{page_1, 1.0}, {page_2, 1.0}, {practice_page, 1.0}, {graded_page, 0.75}]
      |> Enum.each(fn {page, progress} ->
        set_progress(section.id, page.resource_id, user.id, progress, page)

        set_activity_attempt(
          page,
          mcq_1,
          user,
          section,
          project.id,
          publication.id,
          "id_for_option_a",
          true
        )
      end)

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # play unit 1 intro video
      view
      |> element(~s{div[id="intro_card_#{unit_1.resource_id}"]})
      |> render_click()

      # revisit the page since the video is mark as seen in an async way
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(
               view,
               ~s{div[id="intro_card_#{unit_1.resource_id}"] div[role="card badge"] div[role="check icon"]}
             )

      assert has_element?(
               view,
               ~s{div[id="page_#{practice_page.resource_id}"] div[role="card badge"] div[role="check icon"]}
             )

      # this page is not yet completed, so we do not expect to see the check icon
      refute has_element?(
               view,
               ~s{div[id="page_#{graded_page.resource_id}"] div[role="card badge"] div[role="check icon"]}
             )

      assert has_element?(
               view,
               ~s{div[id="module_#{module_1.resource_id}"] div[role="card badge"] div[role="check icon"]}
             )
    end

    test "can expand a module card to view its details (header with title and due date, intro content and page details)",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           page_2: page_2
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      refute has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      # page 1 and page 2 are shown with their estimated read time
      page_1_element =
        element(
          view,
          ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
        )

      assert render(page_1_element) =~ "Page 1"
      assert render(page_1_element) =~ "10"
      assert render(page_1_element) =~ "min"

      page_2_element =
        element(
          view,
          ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_2.slug}"]}
        )

      assert render(page_2_element) =~ "Page 2"
      assert render(page_2_element) =~ "15"
      assert render(page_2_element) =~ "min"

      # intro content is shown
      assert has_element?(
               view,
               "p",
               "Throughout this unit you will learn how to use this course."
             )

      # header is shown with title and due date
      assert has_element?(
               view,
               ~s{div[role="expanded module header"] h2},
               "How to use this course"
             )

      assert has_element?(
               view,
               ~s{div[role="expanded module header"] span},
               "Read by: Wed Nov 15, 2023"
             )
    end

    test "can expand a module card and then collapse it with the bottom bar",
         %{
           conn: conn,
           section: section
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # expand module
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      assert has_element?(view, "span", "Page 1")

      # collapse module with bottom bar
      view
      |> element(~s{button[role="collapse module button"]})
      |> render_click()

      refute has_element?(view, "span", "Page 1")
    end

    test "can see intro video (if any) when expanding a module card",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # module 1 has intro video
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      assert view
             |> element(~s{button[role="intro video details"]})
             |> render() =~ "Introduction"

      assert has_element?(
               view,
               ~s{button[role="intro video details"] div[role="unseen video icon"]}
             )

      # module 2 has no intro video
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 2"]})
      |> render_click()

      refute has_element?(
               view,
               ~s{button[role="intro video details"] div[role="unseen video icon"]}
             )
    end

    test "intro video is marked as seen after playing it",
         %{
           conn: conn,
           user: user,
           section: section,
           module_1: module_1
         } do
      %{state: enrollment_state} =
        Sections.get_enrollment(section.slug, user.id)

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      refute enrollment_state["viewed_intro_video_resource_ids"]

      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{button[role="intro video details"] div[role="unseen video icon"]}
             )

      view
      |> element(~s{button[role="intro video details"]})
      |> render_click()

      # since the video is marked as seen in an async way, we revisit the page to check if the icon changed
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      %{state: enrollment_state} =
        Sections.get_enrollment(section.slug, user.id)

      assert enrollment_state["viewed_intro_video_resource_ids"] == [module_1.resource_id]

      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{button[role="intro video details"] div[role="seen video icon"]}
             )
    end

    test "can see orange flag and due date for graded pages in the module index details",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      view
      |> element(~s{div[role="unit_1"] div[role="resource card 2"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{button[role="resource page 4 details"] div[role="orange flag icon"]}
             )

      assert has_element?(
               view,
               ~s{button[role="resource page 4 details"] div[role="due date and score"]},
               "Read by: Fri Nov 3, 2023"
             )
    end

    test "can see checked square icon and score details for attempted graded pages in the module index details",
         %{
           conn: conn,
           user: user,
           section: section,
           mcq_1: mcq_1,
           page_4: page_4_revision,
           project: project,
           publication: publication
         } do
      set_progress(section.id, page_4_revision.resource_id, user.id, 1.0, page_4_revision)

      set_activity_attempt(
        page_4_revision,
        mcq_1,
        user,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_4_revision,
        mcq_1,
        user,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        false
      )

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))
      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      view
      |> element(~s{div[role="unit_1"] div[role="resource card 2"]})
      |> render_click()

      # graded page with title "Page 4" in the hierarchy has the correct icon
      assert has_element?(
               view,
               ~s{button[role="resource page 4 details"] div[role="square check icon"]}
             )

      # correct due date
      assert has_element?(
               view,
               ~s{button[role="resource page 4 details"] div[role="due date and score"]},
               "Read by: Fri Nov 3, 2023"
             )

      # and correct score summary
      assert has_element?(
               view,
               ~s{button[role="resource page 4 details"] div[role="due date and score"]},
               "1 / 2"
             )
    end

    # This feature was disabled in ticket NG-201 but will be reactivated with NG23-199
    @tag :skip
    test "can see module learning objectives (if any) in the tooltip", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      # there are no learning objectives for this module

      refute has_element?(
               view,
               ~s{div[role="module learning objectives"]},
               "Introduction and Learning Objectives"
             )

      refute has_element?(view, ~s{div[role="learning objectives tooltip"]})

      # expand unit 1/module 2 details
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 2"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{button[role="module learning objectives"]},
               "Introduction and Learning Objectives"
             )

      learning_objectives_tooltip = element(view, ~s{div[role="learning objectives tooltip"]})

      assert has_element?(learning_objectives_tooltip)

      assert render(learning_objectives_tooltip) =~ "Objective 1"
      assert render(learning_objectives_tooltip) =~ "Objective 2"
      assert render(learning_objectives_tooltip) =~ "Objective 3"
      assert render(learning_objectives_tooltip) =~ "Objective 4"
    end

    @tag :flaky
    test "can see unit correct progress when all pages are completed",
         %{
           conn: conn,
           user: user,
           section: section,
           mcq_1: mcq_1,
           page_1: page_1_revision,
           page_2: page_2_revision,
           page_3: page_3_revision,
           page_4: page_4_revision,
           page_16: page_16_revision,
           page_17: page_17_revision,
           page_18: page_18_revision,
           project: project,
           publication: publication
         } do
      set_progress(section.id, page_1_revision.resource_id, user.id, 1.0, page_1_revision)
      set_progress(section.id, page_2_revision.resource_id, user.id, 1.0, page_2_revision)
      set_progress(section.id, page_3_revision.resource_id, user.id, 1.0, page_3_revision)
      set_progress(section.id, page_4_revision.resource_id, user.id, 1.0, page_4_revision)
      set_progress(section.id, page_16_revision.resource_id, user.id, 1.0, page_16_revision)
      set_progress(section.id, page_17_revision.resource_id, user.id, 1.0, page_17_revision)
      set_progress(section.id, page_18_revision.resource_id, user.id, 1.0, page_18_revision)

      set_activity_attempt(
        page_4_revision,
        mcq_1,
        user,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        false
      )

      set_activity_attempt(
        page_4_revision,
        mcq_1,
        user,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      assert has_element?(view, ~s{div[role="unit_1_progress"]}, "Completed")
    end

    test "can expand more than one module card", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_5: page_5
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # page 1 belongs to module 1 (of unit 1) and page 5 belongs to module 3 (of unit 2)
      # Both should not be visible since they are not expanded yet
      refute has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      refute has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      refute has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )

      # expand unit 2/module 3 details
      view
      |> element(~s{div[role="unit_2"] div[role="resource card 3"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      assert has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )
    end

    # TODO: finish this test when the handle event for the "Let's discuss" button is implemented
    test "can click on let's discuss button to open DOT AI Bot interface", %{
      conn: conn,
      section: section
    } do
      {:ok, _view, _html} = live(conn, Utils.learn_live_path(section.slug))
    end

    test "sees a clock icon beside the duration in minutes for graded pages", %{
      conn: conn,
      section: section,
      page_4: page_4
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # expand unit 1/module 2 details
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 2"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[id="index_item_4_#{page_4.resource_id}"] svg[role="clock icon"]}
             )

      assert has_element?(
               view,
               ~s{div[id="index_item_4_#{page_4.resource_id}"] span[role="duration in minutes"]},
               "22"
             )
    end

    test "can see the toggle button to show and hide the completed pages", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(
               view,
               "#hide_completed_button",
               "Hide Completed"
             )

      assert has_element?(view, "#show_completed_button.hidden", "Show Completed")
    end

    test "does not see a check icon on visited pages that are not fully completed", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      set_progress(section.id, page_1.resource_id, user.id, 0.5, page_1)
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      assert has_element?(view, ~s{button[role="resource page 2 details"]})

      refute has_element?(
               view,
               ~s{button[role="resource page 1 details"] svg[role="visited check icon"]}
             )

      assert has_element?(view, ~s{button[role="resource page 2 details"]})

      refute has_element?(
               view,
               ~s{button[role="resource page 2 details"] svg[role="visited check icon"]}
             )
    end

    test "can visit a page", %{conn: conn, section: section, page_1: page_1} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="resource card 1"]})
      |> render_click()

      # click on page 1 to navigate to that page
      view
      |> element(~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]})
      |> render_click()

      request_path =
        Utils.learn_live_path(section.slug,
          target_resource_id: page_1.resource_id,
          selected_view: @default_selected_view
        )

      assert_redirect(
        view,
        Utils.lesson_live_path(section.slug, page_1.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "can see the unit schedule details considering if the instructor has already scheduled it",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # unit 1 has been scheduled by instructor, so there must be schedule details data
      assert view
             |> element(~s{div[role="unit_1"] div[role="schedule_details"]})
             |> render() =~
               "Read by: \n              </span><span class=\"whitespace-nowrap\">\n                Sun, Dec 31, 2023 (8:00pm)"

      # unit 2 has not been scheduled by instructor, so there must not be a schedule details data
      assert view
             |> element(~s{div[role="unit_2"] div[role="schedule_details"]})
             |> render() =~
               "Due by:\n              </span><span class=\"whitespace-nowrap\">\n                None"
    end

    test "can see the 'None' label when the instructor has not set a schedule",
         %{conn: conn, user: user} do
      %{section: section_without_schedule} = create_elixir_project(%{}, false)

      Sections.enroll(user.id, section_without_schedule.id, [
        ContextRoles.get_role(:context_learner)
      ])

      Sections.mark_section_visited_for_student(section_without_schedule, user)

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section_without_schedule.slug))

      assert has_element?(view, ~s{div[role="unit_1"] div[role="schedule_details"]}, "None")

      assert has_element?(view, ~s{div[role="unit_2"] div[role="schedule_details"]}, "None")
    end

    @tag :flaky
    test "can see units, modules and page (at module level) progresses", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_7: page_7
    } do
      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)
      set_progress(section.id, page_2.resource_id, user.id, 0.5, page_2)
      set_progress(section.id, page_7.resource_id, user.id, 1.0, page_7)
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      # unit 1 progress is 38% ((1 + 0.5 + 0.0 + 0.0) / 4)
      assert has_element?(view, ~s{div[role="unit_1"] div[role="unit_1_progress"]}, "21%")

      # module 1 progress is 75% ((1 + 0.5) / 2)
      assert view
             |> element(~s{div[role="unit_1"] div[role="card_1_progress"]})
             |> render() =~ "style=\"width: 75%\""

      # unit 3, practice page 1 card at module level has progress 100%
      assert view
             |> element(~s{div[role="unit_3"] div[role="card_10_progress"]})
             |> render() =~ "style=\"width: 100%\""
    end

    test "can navigate to pages at level 2 of hierarchy (rendered as cards)",
         %{
           conn: conn,
           section: section,
           page_7: page_7
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # click on page 7 card to navigate to that page
      view
      |> element(~s{div[role="unit_3"] div[role="resource card 10"]})
      |> render_click()

      request_path =
        Utils.learn_live_path(section.slug,
          target_resource_id: page_7.resource_id,
          selected_view: @default_selected_view
        )

      assert_redirect(
        view,
        Utils.lesson_live_path(section.slug, page_7.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "can navigate to graded pages at level 2 of hierarchy (rendered as cards)",
         %{
           conn: conn,
           section: section,
           page_8: page_8
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # click on page 8 card to navigate to that page
      view
      |> element(~s{div[role="unit_3"] div[role="resource card 11"]})
      |> render_click()

      request_path =
        Utils.learn_live_path(section.slug,
          target_resource_id: page_8.resource_id,
          selected_view: @default_selected_view
        )

      assert_redirect(
        view,
        Utils.lesson_live_path(section.slug, page_8.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "progress bar is rendered EVEN when there is no progress",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(view, ~s{div[role="unit_1"] div[role="card 1 progress"]})
      assert has_element?(view, ~s{div[role="unit_3"] div[role="card 11 progress"]})
    end

    test "can see card progress bar for modules at level 2 of hierarchy, and even for pages at level 2",
         %{
           conn: conn,
           user: user,
           section: section,
           page_2: page_2,
           page_7: page_7
         } do
      set_progress(section.id, page_2.resource_id, user.id, 0.5, page_2)
      set_progress(section.id, page_7.resource_id, user.id, 1.0, page_7)

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # when the slider buttons are enabled we know the student async metrics (including progress) were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      # Progress in module 1 (which has page 2)
      assert has_element?(view, ~s{div[role="unit_1"] div[role="card_1_progress"]})

      # Progress in page 7
      assert has_element?(view, ~s{div[role="unit_3"] div[role="card_10_progress"]})
    end

    test "can see card background image if provided (if not the default one is shown)",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert view
             |> element(~s{div[role="unit_1"] div[role="resource card 1"]"})
             |> render =~ "style=\"background-image: url(&#39;module_1_custom_image_url&#39;)"

      assert view
             |> element(~s{div[role="unit_1"] div[role="resource card 2"]"})
             |> render =~ "style=\"background-image: url(&#39;/images/course_default.png&#39;)"
    end

    test "can see Youtube or S3 video poster image",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert view
             |> element(~s{div[role="unit_1"] div[role="youtube_intro_video_card"]"})
             |> render =~
               "style=\"background-image: url(&#39;https://img.youtube.com/vi/123456789ab/hqdefault.jpg&#39;)"

      # S3 video
      assert view
             |> has_element?(~s{div[role="unit_4"] div[role="intro_video_card"]"})
    end

    test "can see pages at the top level of the curriculum (at unit level) with it's header and corresponding card",
         %{
           conn: conn,
           section: section,
           top_level_page: top_level_page
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert view
             |> element(
               ~s{div[id="top_level_page_#{top_level_page.resource_id}"] div[role="header"]}
             )
             |> render() =~ "PAGE 20"

      assert view
             |> element(
               ~s{div[id="top_level_page_#{top_level_page.resource_id}"] div[role="header"]}
             )
             |> render() =~ "Top Level Page"

      assert view
             |> element(
               ~s{div[id="top_level_page_#{top_level_page.resource_id}"] div[role="schedule_details"]}
             )
             |> render() =~ "None"

      assert view
             |> element(~s{div[id="page_#{top_level_page.resource_id}"][role="resource card 1"]})
             |> render() =~ "Top Level Page"
    end

    test "can navigate to a unit through url params",
         %{
           conn: conn,
           section: section,
           unit_2: unit_2
         } do
      unit_id = "unit_#{unit_2.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, %{target_resource_id: unit_2.resource_id})
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        id: ^unit_id,
        offset: 25,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a module through url params",
         %{
           conn: conn,
           section: section,
           unit_2: unit_2,
           module_3: module_3
         } do
      unit_id = "unit_#{unit_2.resource_id}"
      card_id = "module_#{module_3.resource_id}"
      unit_resource_id = unit_2.resource_id

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, %{target_resource_id: module_3.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 25})

      assert_push_event(view, "scroll-x-to-card-in-slider", %{
        card_id: ^card_id,
        scroll_delay: 300,
        unit_resource_id: ^unit_resource_id,
        pulse_target_id: ^card_id,
        pulse_delay: 500
      })

      # module 3 must be expanded so we can see its details
      assert has_element?(
               view,
               ~s{div[role="expanded module header"] h2},
               "Installing Elixir, OTP and Phoenix"
             )

      assert has_element?(view, ~s{div[id="index_for_#{module_3.resource_id}"]}, "Page 5")
    end

    test "can navigate to a page at top level (at unit level) through url params",
         %{
           conn: conn,
           section: section,
           top_level_page: top_level_page
         } do
      top_level_page_id = "top_level_page_#{top_level_page.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, %{target_resource_id: top_level_page.resource_id})
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        id: ^top_level_page_id,
        offset: 25,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a page at module level through url params",
         %{
           conn: conn,
           section: section,
           unit_3: unit_3,
           page_8: page_8
         } do
      unit_id = "unit_#{unit_3.resource_id}"
      card_id = "page_#{page_8.resource_id}"
      unit_resource_id = unit_3.resource_id

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, %{target_resource_id: page_8.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 25})

      assert_push_event(view, "scroll-x-to-card-in-slider", %{
        card_id: ^card_id,
        scroll_delay: 300,
        unit_resource_id: ^unit_resource_id,
        pulse_target_id: ^card_id,
        pulse_delay: 500
      })
    end

    test "can navigate to a page through url params",
         %{
           conn: conn,
           section: section,
           unit_2: unit_2,
           module_3: module_3,
           page_6: page_6
         } do
      unit_id = "unit_#{unit_2.resource_id}"
      card_id = "module_#{module_3.resource_id}"
      unit_resource_id = unit_2.resource_id
      pulse_target_id = "index_item_#{page_6.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, %{target_resource_id: page_6.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 25})

      assert_push_event(
        view,
        "scroll-x-to-card-in-slider",
        %{
          card_id: ^card_id,
          scroll_delay: 300,
          unit_resource_id: ^unit_resource_id,
          pulse_target_id: ^pulse_target_id,
          pulse_delay: 500
        }
      )

      # The module that contains Page 6 must be expanded so we can see that page
      assert has_element?(view, ~s{div[id="index_item_9_#{page_6.resource_id}"]}, "Page 6")
    end

    test "can navigate to a page at section level through url params",
         %{
           conn: conn,
           section: section,
           unit_5: unit_5,
           module_4: module_4,
           page_11: page_11
         } do
      unit_id = "unit_#{unit_5.resource_id}"
      card_id = "module_#{module_4.resource_id}"
      unit_resource_id = unit_5.resource_id
      pulse_target_id = "index_item_#{page_11.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, %{target_resource_id: page_11.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 25})

      assert_push_event(view, "scroll-x-to-card-in-slider", %{
        card_id: ^card_id,
        scroll_delay: 300,
        unit_resource_id: ^unit_resource_id,
        pulse_target_id: ^pulse_target_id,
        pulse_delay: 500
      })
    end

    test "can see pages within sections and sub-sections",
         %{
           conn: conn,
           section: section,
           section_1: section_1,
           subsection_1: subsection_1,
           page_11: page_11,
           page_12: page_12
         } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      refute has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_11.slug}"]}
             )

      refute has_element?(
               view,
               ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_12.slug}"]}
             )

      view
      |> element(~s{div[role="unit_5"] div[role="resource card 4"]})
      |> render_click()

      # page 11 and page 12 are displayed by default with their corresponding indentation
      page_11_element =
        element(
          view,
          ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_11.slug}"]}
        )

      assert render(page_11_element) =~ "Page 11"
      assert render(page_11_element) =~ "ml-[40px]"

      page_12_element =
        element(
          view,
          ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_12.slug}"]}
        )

      assert render(page_12_element) =~ "Page 12"
      assert render(page_12_element) =~ "ml-[20px]"

      # Section and Sub-section are displayed with their corresponding indentation
      section_1_element =
        element(
          view,
          "#index_item_#{section_1.resource_id}_read_by_2023-11-03"
        )

      subsection_1_element =
        element(
          view,
          "#index_item_#{subsection_1.resource_id}_read_by_2023-11-03"
        )

      assert render(section_1_element) =~ "Why Elixir?"
      assert render(section_1_element) =~ "ml-0"

      assert render(subsection_1_element) =~ "Erlang as a motivation"
      assert render(subsection_1_element) =~ "ml-[20px]"
    end

    test "groups pages within a module index by due date or read by (even if some pages do not yet have a scheduled date)",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      view
      |> element(~s{div[role="unit_5"] div[role="resource card 4"]})
      |> render_click()

      group_by_read_by_date_div = element(view, ~s{div[id="pages_grouped_by_read_by_2023-11-03"]})

      group_by_due_by_date_div = element(view, ~s{div[id="pages_grouped_by_due_by_2023-11-03"]})

      group_by_not_yet_scheduled_div =
        element(view, ~s{div[id="pages_grouped_by__Not yet scheduled"]})

      assert render(group_by_read_by_date_div) =~ "Read by: Fri Nov 3, 2023"
      assert render(group_by_read_by_date_div) =~ "Page 11"

      assert render(group_by_due_by_date_div) =~ "Due by: Fri Nov 3, 2023"
      assert render(group_by_due_by_date_div) =~ "Page 12"

      assert render(group_by_not_yet_scheduled_div) =~ "None"
      assert render(group_by_not_yet_scheduled_div) =~ "Page 13"
      assert render(group_by_not_yet_scheduled_div) =~ "Page 14"
    end

    test "considers student exceptions when grouping pages in index by due date", %{
      conn: conn,
      user: user,
      section: section,
      page_13: page_13
    } do
      # add a student exception for page 13
      insert(:student_exception, %{
        section: section,
        user: user,
        resource: page_13.resource,
        end_date: ~U[2023-11-10 00:00:00Z]
      })

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # when the slider buttons are enabled we know the student async metrics (including student exceptions) were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      view
      |> element(~s{div[role="unit_5"] div[role="resource card 4"]})
      |> render_click()

      group_by_due_date_div = element(view, ~s{div[id="pages_grouped_by_read_by_2023-11-10"]})

      # page 13 is due on Nov 10, 2023 as defined in the student exception
      assert render(group_by_due_date_div) =~ "Read by: Fri Nov 10, 2023"
      assert render(group_by_due_date_div) =~ "Page 13"
    end

    test "in class activities pages are not listed in the module index", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      view
      |> element(~s{div[role="unit_5"] div[role="resource card 4"]})
      |> render_click()

      assert render(view) =~ "Page 13"
      assert render(view) =~ "Page 14"
      refute render(view) =~ "Page 15"
    end

    test "do not show hidden pages", %{
      conn: conn,
      section: section,
      page_7: page_7
    } do
      # Set page 7 as hidden
      section_resource = Sections.get_section_resource(section.id, page_7.resource_id)
      Sections.update_section_resource(section_resource, %{hidden: !section_resource.hidden})

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      refute render(view) =~ "Page 7"
    end

    test "modules do not show duration minutes if duration is 0", %{
      conn: conn,
      section: section,
      module_3: module_3,
      page_5: page_5,
      page_6: page_6
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      view
      |> element(~s{div[id="module_#{module_3.resource_id}"]})
      |> render_click()

      # assert that page 5 and page 6 have duration 0
      assert page_5.duration_minutes == 0
      assert page_6.duration_minutes == 0

      # assert that module 3 contains 2 pages (page 5 and page 6)
      assert has_element?(
               view,
               ~s{div[id="module_#{module_3.resource_id}"] div[role="card badge"]},
               "2 pages"
             )

      # assert that module 3 does not show duration minutes (since it is 0)
      refute has_element?(
               view,
               ~s{div[id="module_#{module_3.resource_id}"] div[role="card badge"]},
               "0 minutes"
             )
    end

    test "displays timezone information component", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      # Verify that the timezone_info component is present
      assert has_element?(view, "#timezone_info")

      # Verify that it contains the timezone world icon
      assert has_element?(view, "[role='timezone world icon']")

      # Verify that it displays timezone text
      assert has_element?(view, "#timezone_info span")

      # Verify that the timezone text is not empty (should display actual timezone)
      timezone_element = element(view, "#timezone_info span")
      timezone_text = render(timezone_element)
      assert timezone_text =~ "Etc/UTC"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access Outline view when not enrolled to course", %{
      conn: conn,
      section: section
    } do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert redirect_path == "/sections/#{section.slug}/enroll"
    end

    test "can not access Gallery view (default one) when not enrolled to course", %{
      conn: conn,
      section: section
    } do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, Utils.learn_live_path(section.slug))

      assert redirect_path == "/sections/#{section.slug}/enroll"
    end
  end

  describe "student at Outline view mode" do
    setup [:user_conn, :create_elixir_project, :enroll_as_student, :mark_section_visited]

    test "can access when enrolled to course", %{conn: conn, section: section} do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "div", "Introduction")
      assert has_element?(view, "div", "Building a Phoenix app")
      assert has_element?(view, "div", "Implementing LiveView")
    end

    test "can see the toggle button to show and hide the completed pages", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert has_element?(view, ~s{button[id="hide_completed_button"]}, "Hide Completed")
    end

    @tag :skip
    test "can see unit intro as first row and play the video (if provided)", %{
      conn: conn,
      section: section,
      module_1: module_1,
      module_2: module_2
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      # unit 1 has an intro video
      assert has_element?(
               view,
               ~s{button[role="intro video details"][id=intro_video_for_module_#{module_1.resource_id}]},
               "Introduction"
             )

      # unit 2 has no intro video
      refute has_element?(
               view,
               ~s{button[role="intro video details"][id=intro_video_for_module_#{module_2.resource_id}]},
               "Introduction"
             )
    end

    @tag :skip
    test "intro video is marked as seen after playing it",
         %{
           conn: conn,
           user: user,
           section: section,
           module_1: module_1
         } do
      %{state: enrollment_state} =
        Sections.get_enrollment(section.slug, user.id)

      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      refute enrollment_state["viewed_intro_video_resource_ids"]

      assert has_element?(
               view,
               ~s{button[role="intro video details"] div[role="unseen video icon"]}
             )

      view
      |> element(~s{button[role="intro video details"]})
      |> render_click()

      # since the video is marked as seen in an async way, we revisit the page to check if the icon changed
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      %{state: enrollment_state} =
        Sections.get_enrollment(section.slug, user.id)

      assert enrollment_state["viewed_intro_video_resource_ids"] == [module_1.resource_id]

      assert has_element?(
               view,
               ~s{button[role="intro video details"] div[role="seen video icon"]}
             )
    end

    test "can see orange flag and due date for graded pages in the module index details",
         %{conn: conn, section: section} do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert has_element?(
               view,
               ~s{button[role="page 4 details"] div[role="orange flag icon"]}
             )
    end

    test "sees a clock icon beside the duration in minutes for graded pages", %{
      conn: conn,
      section: section,
      page_4: page_4
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert has_element?(
               view,
               ~s{div[id="index_item_4_#{page_4.resource_id}"] svg[role="clock icon"]}
             )

      assert has_element?(
               view,
               ~s{div[id="index_item_4_#{page_4.resource_id}"] span[role="duration in minutes"]},
               "22"
             )
    end

    test "does not see a check icon on visited pages that are not fully completed", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      set_progress(section.id, page_1.resource_id, user.id, 0.5, page_1)

      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      # when the garbage collection message is recieved we know the async metrics were loaded
      # since the gc message is sent from the handle_info that loads the async metrics
      assert_receive(:gc, 2_000)

      assert has_element?(view, ~s{button[role="page 2 details"]})
      refute has_element?(view, ~s{button[role="page 1 details"] svg[role="visited check icon"]})
      assert has_element?(view, ~s{button[role="page 2 details"]})
      refute has_element?(view, ~s{button[role="page 2 details"] svg[role="visited check icon"]})
    end

    test "can visit a page", %{conn: conn, section: section, page_1: page_1} do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      # click on page 1 to navigate to that page
      view
      |> element(~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]})
      |> render_click()

      request_path =
        Utils.learn_live_path(section.slug,
          target_resource_id: page_1.resource_id,
          selected_view: :outline
        )

      assert_redirect(
        view,
        Utils.lesson_live_path(section.slug, page_1.slug,
          request_path: request_path,
          selected_view: :outline
        )
      )
    end

    test "can see pages at the top level of the curriculum (at unit level) with it's header and corresponding row",
         %{
           conn: conn,
           section: section,
           top_level_page: top_level_page
         } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert view
             |> element(
               ~s{div[role="page_#{top_level_page.resource_id}"] span[role="page title"]}
             )
             |> render() =~ "Top Level Page"
    end

    test "can navigate to a unit through url params", ctx do
      %{conn: conn, section: section, unit_2: unit_2} = ctx
      unit_id = "unit_#{unit_2.resource_id}_outline"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug,
            target_resource_id: unit_2.resource_id,
            selected_view: :outline
          )
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        role: ^unit_id,
        offset: 125,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a module through url params", ctx do
      %{conn: conn, section: section, module_3: module_3} = ctx
      module_id = "module_#{module_3.resource_id}_outline"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug,
            target_resource_id: module_3.resource_id,
            selected_view: :outline
          )
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        role: ^module_id,
        offset: 125,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a page at top level (at unit level) through url params", ctx do
      %{conn: conn, section: section, top_level_page: top_level_page} = ctx
      top_level_page_id = "top_level_page_#{top_level_page.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug,
            target_resource_id: top_level_page.resource_id,
            selected_view: :outline
          )
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        role: ^top_level_page_id,
        offset: 125,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a page at module level through url params",
         %{
           conn: conn,
           section: section,
           page_8: page_8
         } do
      page_id = "page_#{page_8.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug,
            target_resource_id: page_8.resource_id,
            selected_view: :outline
          )
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        role: ^page_id,
        offset: 125,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a page through url params",
         %{
           conn: conn,
           section: section,
           page_6: page_6
         } do
      page_id = "page_#{page_6.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug,
            target_resource_id: page_6.resource_id,
            selected_view: :outline
          )
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        role: ^page_id,
        offset: 125,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a page at section level through url params", ctx do
      %{conn: conn, section: section, page_11: page_11} = ctx
      page_id = "page_#{page_11.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug,
            target_resource_id: page_11.resource_id,
            selected_view: :outline
          )
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        role: ^page_id,
        offset: 125,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can see pages within sections and sub-sections",
         %{
           conn: conn,
           section: section,
           section_1: section_1,
           subsection_1: subsection_1,
           page_11: page_11,
           page_12: page_12
         } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      # page 11 and page 12 are displayed by default with their corresponding indentation
      page_11_element =
        element(
          view,
          ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_11.slug}"]}
        )

      assert render(page_11_element) =~ "Page 11"
      assert render(page_11_element) =~ "ml-[60px]"

      page_12_element =
        element(
          view,
          ~s{button[phx-click="navigate_to_resource"][phx-value-slug="#{page_12.slug}"]}
        )

      assert render(page_12_element) =~ "Page 12"
      assert render(page_12_element) =~ "ml-[40px]"

      section_1_element =
        element(
          view,
          "div[role=section_#{section_1.resource_id}_outline]"
        )

      subsection_1_element =
        element(
          view,
          "div[role=section_#{subsection_1.resource_id}_outline]"
        )

      assert render(section_1_element) =~ "Why Elixir?"
      assert render(subsection_1_element) =~ "Erlang as a motivation"
      assert render(subsection_1_element) =~ "ml-[40px]"
    end

    test "can see scheduling details when course has scheduled resources", %{
      conn: conn,
      section: section,
      unit_1: unit_1,
      module_1: module_1,
      unit_2: unit_2
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :outline))

      assert view
             |> element(~s{div[role="unit #{unit_1.resource_id} scheduling details"]})
             |> render() =~ "Sun, Dec 31, 2023 (8:00pm)"

      assert view
             |> element(~s{div[role="unit #{unit_2.resource_id} scheduling details"]})
             |> render() =~ "None"

      assert view
             |> element(~s{div[role="module #{module_1.resource_id} scheduling details"]})
             |> render() =~ "Wed, Nov 15, 2023 (8:00pm)"

      assert view
             |> element(
               ~s{button[role="page 4 details"] div[role="due date and score"] span[role="page due date"]}
             )
             |> render() =~ "Read by: Fri Nov 3, 2023"
    end

    test "does see scheduling details when course has no scheduled resources", %{
      conn: conn,
      user: user
    } do
      %{section: section_without_schedule, unit_1: unit_1, unit_2: unit_2, module_1: module_1} =
        create_elixir_project(%{}, false)

      enroll_as_student(%{user: user, section: section_without_schedule})
      mark_section_visited(%{user: user, section: section_without_schedule})

      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section_without_schedule.slug, selected_view: :outline))

      assert view
             |> has_element?(~s{div[role="unit #{unit_1.resource_id} scheduling details"]})

      assert view
             |> has_element?(~s{div[role="unit #{unit_2.resource_id} scheduling details"]})

      assert view
             |> has_element?(~s{div[role="module #{module_1.resource_id} scheduling details"]})

      assert view
             |> has_element?(
               ~s{button[role="page 4 details"] div[role="due date and score"] span[role="page due date"]}
             )
    end
  end

  describe "view selector" do
    setup [:user_conn, :create_elixir_project, :enroll_as_student, :mark_section_visited]

    test "can switch from Outline to Gallery view", %{conn: conn, section: section} do
      {:ok, view, _html} =
        live(
          conn,
          Utils.learn_live_path(section.slug, selected_view: :outline, sidebar_expanded: true)
        )

      # selector text matches current view
      assert has_element?(view, ~s{div[id=view_selector] div}, "Outline")

      view
      |> element(~s{div[id=view_selector] button[phx-click="expand_select"]})
      |> render_click()

      # selector text changes when expanded
      assert has_element?(view, ~s{div[id=view_selector] div}, "View page as")

      view
      |> element(~s{button[phx-value-selected_view=gallery]})
      |> render_click()

      assert_patch(
        view,
        Utils.learn_live_path(section.slug, sidebar_expanded: true, selected_view: :gallery)
      )

      # selector text matches target view
      assert has_element?(view, ~s{div[id=view_selector] div}, "Gallery")
    end

    test "can switch from Gallery to Outline view", %{conn: conn, section: section} do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :gallery))

      # selector text matches current view
      assert has_element?(view, ~s{div[id=view_selector] div}, "Gallery")

      view
      |> element(~s{div[id=view_selector] button[phx-click="expand_select"]})
      |> render_click()

      # selector text changes when expanded
      assert has_element?(view, ~s{div[id=view_selector] div}, "View page as")

      view
      |> element(~s{button[phx-value-selected_view=outline]})
      |> render_click()

      assert_patch(
        view,
        Utils.learn_live_path(section.slug, sidebar_expanded: true, selected_view: :outline)
      )

      # selector text matches target view
      assert has_element?(view, ~s{div[id=view_selector] div}, "Outline")
    end

    test "arrows navigation works well when switch between views", %{
      conn: conn,
      section: section,
      unit_1: unit_1
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: :gallery))

      # gallery view is the current view
      assert has_element?(view, ~s{div[id=view_selector] div}, "Gallery")

      # right arrow is visible
      assert has_element?(view, ~s{button[id=slider_right_button_#{unit_1.resource_id}]})

      # change to outline view
      view
      |> element(~s{div[id=view_selector] button[phx-click="expand_select"]})
      |> render_click()

      view
      |> element(~s{button[phx-value-selected_view=outline]})
      |> render_click()

      assert_patch(
        view,
        Utils.learn_live_path(section.slug, sidebar_expanded: true, selected_view: :outline)
      )

      assert has_element?(view, ~s{div[id=view_selector] div}, "Outline")

      # change to gallery view again
      view
      |> element(~s{button[phx-value-selected_view=gallery]})
      |> render_click()

      assert_patch(
        view,
        Utils.learn_live_path(section.slug, sidebar_expanded: true, selected_view: :gallery)
      )

      assert has_element?(view, ~s{div[id=view_selector] div}, "Gallery")

      # assert that the event to show the slider buttons is triggered
      assert_push_event(view, "enable-slider-buttons", %{
        unit_resource_ids: _unit_ids
      })

      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      # right arrow is present
      assert has_element?(view, ~s{button[id=slider_right_button_#{unit_1.resource_id}]})
    end
  end

  describe "sidebar menu" do
    setup [:user_conn, :create_elixir_project, :enroll_as_student, :mark_section_visited]

    test "can see default logo", %{
      conn: conn,
      section: section
    } do
      Sections.update_section(section, %{brand_id: nil})

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert element(view, "#logo_button") |> render() =~ "/images/oli_torus_logo.png"
    end

    test "can see brand logo", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert element(view, "#logo_button") |> render() =~ "www.logo.com"
    end

    test "does not render Explorations, Practice and Collaboration links if those features are not enabled",
         %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      refute has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/explorations?sidebar_expanded=true"]},
               "Explorations"
             )

      refute has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/practice?sidebar_expanded=true"]},
               "Practice"
             )

      refute has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/discussions?sidebar_expanded=true"]},
               "Discussions"
             )
    end

    test "renders the Schedule link considering the section's scheduled_resources",
         %{conn: conn, section: section, user: user} do
      # a section with schedule should have the Schedule link
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/student_schedule?sidebar_expanded=true"]},
               "Schedule"
             )

      # a section without schedule should not have the Schedule link
      %{section: section_without_schedule} = create_elixir_project(%{}, false)

      Sections.enroll(user.id, section_without_schedule.id, [
        ContextRoles.get_role(:context_learner)
      ])

      Sections.mark_section_visited_for_student(section_without_schedule, user)

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section_without_schedule.slug))

      refute has_element?(
               view,
               ~s{a[href="/sections/#{section_without_schedule.slug}/student_schedule?sidebar_expanded=true"]},
               "Schedule"
             )
    end

    test "renders Explorations, Practice and Collaboration links if those features are enabled",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           page_2: page_2,
           page_3: page_3,
           author: author
         } do
      enable_all_sidebar_links(section, author, page_1, page_2, page_3)

      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug))

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/explorations?sidebar_expanded=true"]},
               "Explorations"
             )

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/practice?sidebar_expanded=true"]},
               "Practice"
             )

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/discussions?sidebar_expanded=true"]},
               "Notes"
             )
    end

    test "can see expanded/collapsed sidebar nav", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      author: author
    } do
      enable_all_sidebar_links(section, author, page_1, page_2, page_3)

      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, sidebar_expanded: true))

      assert has_element?(view, ~s{nav[id=desktop-nav-menu][aria-expanded=true]})

      labels = [
        "Home",
        "Learn",
        "Schedule",
        "Notes",
        "Explorations",
        "Practice",
        "Support",
        "Exit Course"
      ]

      Enum.each(labels, fn label ->
        assert view
               |> element(~s{nav[id=desktop-nav-menu]})
               |> render() =~ label
      end)

      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, sidebar_expanded: false))

      assert has_element?(view, ~s{nav[id=desktop-nav-menu][aria-expanded=false]})

      Enum.each(labels, fn label ->
        refute view
               |> element(~s{nav[id=desktop-nav-menu]})
               |> render() =~ label
      end)
    end

    test "navbar expanded or collapsed state is kept after navigating to other menu link", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, sidebar_expanded: true))

      assert has_element?(view, ~s{nav[id=desktop-nav-menu][aria-expanded=true]})

      view
      |> element(~s{nav[id=desktop-nav-menu] a}, "Schedule")
      |> render_click()

      assert_redirect(view, "/sections/#{section.slug}/student_schedule?sidebar_expanded=true")

      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, sidebar_expanded: false))

      assert has_element?(view, ~s{nav[id=desktop-nav-menu][aria-expanded=false]})

      view
      |> element(~s{nav[id="desktop-nav-menu"] a[id="schedule_nav_link"])})
      |> render_click()

      assert_redirect(view, "/sections/#{section.slug}/student_schedule?sidebar_expanded=false")
    end

    test "exit course button redirects to the student workspace", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug))

      view
      |> element(~s{nav[id=desktop-nav-menu] a[id="exit_course_button"]}, "Exit Course")
      |> render_click()

      assert_redirect(view, "/workspaces/student?sidebar_expanded=true")
    end

    test "logo icon redirects to home page", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug))

      view
      |> element(~s{nav[id=desktop-nav-menu] a[id="logo_button"]})
      |> render_click()

      assert_redirect(view, "/sections/#{section.slug}?sidebar_expanded=true")
    end
  end

  describe "preview" do
    setup [
      :user_conn,
      :set_timezone,
      :create_elixir_project,
      :enroll_as_student,
      :mark_section_visited
    ]

    test "redirects and ensures navigation to the preview Notes page", %{
      conn: conn,
      author: author,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3
    } do
      enable_all_sidebar_links(section, author, page_1, page_2, page_3)

      stub_current_time(~U[2023-11-04 20:00:00Z])
      {:ok, view, _html} = live(conn, "/sections/#{section.slug}/preview")

      view
      |> element(~s{nav[id="desktop-nav-menu"] a[id="discussions_nav_link"])})
      |> render_click()

      redirect_path = "/sections/#{section.slug}/preview/discussions"
      assert_redirect(view, redirect_path)

      {:ok, view, _html} = live(conn, redirect_path)

      assert view |> element(~s{#header span}, "(Preview Mode)") |> render() =~ "(Preview Mode)"
      assert view |> has_element?(~s{h1}, "Notes")
    end

    test "redirects and ensures navigation to the preview Practice page", %{
      conn: conn,
      section: section,
      author: author,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3
    } do
      enable_all_sidebar_links(section, author, page_1, page_2, page_3)
      stub_current_time(~U[2023-11-04 20:00:00Z])
      {:ok, view, _html} = live(conn, "/sections/#{section.slug}/preview")

      view
      |> element(~s{nav[id="desktop-nav-menu"] a[id="practice_nav_link"])})
      |> render_click()

      redirect_path = "/sections/#{section.slug}/preview/practice"
      assert_redirect(view, redirect_path)

      {:ok, view, _html} = live(conn, redirect_path)

      assert view |> element(~s{#header span}, "(Preview Mode)") |> render() =~ "(Preview Mode)"
      assert view |> element(~s{h1}) |> render() =~ "Your Practice Pages"
    end
  end

  describe "when view mode is invalid" do
    setup [:user_conn, :create_elixir_project, :enroll_as_student, :mark_section_visited]

    test "shows default view if selected_view is not a valid option", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(conn, Utils.learn_live_path(section.slug, selected_view: "invalid"))

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "h3", "Introduction")
      assert has_element?(view, "h3", "Building a Phoenix app")
      assert has_element?(view, "h3", "Implementing LiveView")
    end

    test "shows default view if selected_view is an empty string", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, Utils.learn_live_path(section.slug, selected_view: ""))

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "h3", "Introduction")
      assert has_element?(view, "h3", "Building a Phoenix app")
      assert has_element?(view, "h3", "Implementing LiveView")
    end
  end

  defp enable_all_sidebar_links(section, author, page_1, page_2, page_3) do
    # change the purpose of the pages to have an exploration page and a deliberate practice page
    Oli.Resources.update_revision(page_1, %{purpose: :application, author_id: author.id})

    Oli.Resources.update_revision(page_2, %{purpose: :deliberate_practice, author_id: author.id})

    # enable collab space on page 3
    page_3_sr =
      Oli.Delivery.Sections.get_section_resource(section.id, page_3.resource_id)

    {:ok, _} =
      Oli.Delivery.Sections.update_section_resource(page_3_sr, %{
        collab_space_config: %Oli.Resources.Collaboration.CollabSpaceConfig{
          status: :enabled
        }
      })

    # process changes in section
    Oli.Delivery.Sections.PostProcessing.apply(section, [
      :discussions,
      :explorations,
      :deliberate_practice
    ])
  end

  describe "search functionality" do
    setup [:user_conn, :create_elixir_project, :enroll_as_student, :mark_section_visited]

    test "shows all content when no search term is provided", %{conn: conn, section: section} do
      search_term = ""

      {:ok, view, _html} =
        live(
          conn,
          "/sections/#{section.slug}/learn?search_term=#{search_term}&selected_view=outline"
        )

      all_units_titles = [
        "Introduction",
        "Building a Phoenix app",
        "Implementing LiveView",
        "Learning OTP",
        "Learning Macros",
        "What did you learn?"
      ]

      all_page_titles = [
        "Page 1",
        "Page 2",
        "Page 3",
        "Page 4",
        "Page 5",
        "Page 6",
        "Page 7",
        "Page 8",
        "Page 9",
        "Page 10",
        "Page 11",
        "Page 12",
        "Page 13",
        "Page 14",
        "Page 15",
        "Page 16",
        "Page 17",
        "Page 18",
        "Exploration 1",
        "Top Level Page"
      ]

      Enum.each(all_units_titles, fn title ->
        assert has_element?(view, "div[role='unit title']", title)
      end)

      Enum.each(all_page_titles, fn title ->
        assert has_element?(view, "span[role='page title']", title)
      end)
    end

    test "filters content when searching for a page title", %{conn: conn, section: section} do
      search_term = "Page 1"

      {:ok, view, _html} =
        live(
          conn,
          "/sections/#{section.slug}/learn?search_term=#{search_term}&selected_view=outline"
        )

      # Should only show the matching page and its parent structure
      assert view |> has_element?("div[role='unit title']", "Introduction")
      assert view |> has_element?("div[role='module title']", "How to use this course")
      assert view |> has_element?("span[role='page title']", "Page 1")

      refute view |> has_element?("div[role='unit title']", "Building a Phoenix app")
      refute view |> has_element?("div[role='module title']", "Configure your setup")
      refute view |> has_element?("span[role='page title']", "Page 2")
      refute view |> has_element?("span[role='page title']", "Page 3")
      refute view |> has_element?("span[role='page title']", "Page 4")
    end

    test "filters content when searching for a container title", %{conn: conn, section: section} do
      search_term = "Introduction"

      {:ok, view, _html} =
        live(
          conn,
          "/sections/#{section.slug}/learn?search_term=#{search_term}&selected_view=outline"
        )

      # Should show the Introduction unit and its children
      assert view |> has_element?("div[role='unit title']", "Introduction")
      assert view |> has_element?("span[role='page title']", "Page 2")
      assert view |> has_element?("span[role='page title']", "Page 3")

      # Should not show unrelated content
      refute view |> has_element?("div[role='unit title']", "OTP")

      refute view
             |> has_element?("div[role='module title']", "Installing Elixir, OTP and Phoenix")
    end

    test "handles case-insensitive search", %{conn: conn, section: section} do
      search_term = "INTRODUCTION"

      {:ok, view, _html} =
        live(
          conn,
          "/sections/#{section.slug}/learn?search_term=#{search_term}&selected_view=outline"
        )

      # Should show the same results as case-sensitive search
      assert view |> has_element?("div[role='unit title']", "Introduction")
      assert view |> has_element?("span[role='page title']", "Page 2")
      assert view |> has_element?("span[role='page title']", "Page 3")

      # Should not show unrelated content
      refute view |> has_element?("div[role='unit title']", "OTP")

      refute view
             |> has_element?("div[role='module title']", "Installing Elixir, OTP and Phoenix")
    end

    test "shows empty state when no results match", %{conn: conn, section: section} do
      search_term = "nonexistent_content_xyz"

      {:ok, view, _html} =
        live(
          conn,
          "/sections/#{section.slug}/learn?search_term=#{search_term}&selected_view=outline"
        )

      # Should show empty state message
      assert view
             |> has_element?(
               "div[role='no search results warning']",
               "There are no results for the search term"
             )

      # Should not show any content
      refute view |> has_element?("div[role='unit title']", "Introduction")
      refute view |> has_element?("div[role='unit title']", "OTP")
    end

    test "updates results when search term changes", %{conn: conn, section: section} do
      initial_search_term = ""

      {:ok, view, _html} =
        live(
          conn,
          "/sections/#{section.slug}/learn?search_term=#{initial_search_term}&selected_view=outline"
        )

      all_units_titles = [
        "Introduction",
        "Building a Phoenix app",
        "Implementing LiveView",
        "Learning OTP",
        "Learning Macros",
        "What did you learn?"
      ]

      all_page_titles = [
        "Page 1",
        "Page 2",
        "Page 3",
        "Page 4",
        "Page 5",
        "Page 6",
        "Page 7",
        "Page 8",
        "Page 9",
        "Page 10",
        "Page 11",
        "Page 12",
        "Page 13",
        "Page 14",
        "Page 15",
        "Page 16",
        "Page 17",
        "Page 18",
        "Exploration 1",
        "Top Level Page"
      ]

      # Initial state shows all units
      Enum.each(all_units_titles, fn title ->
        assert view |> has_element?("div[role='unit title']", title)
      end)

      # and all pages
      Enum.each(all_page_titles, fn title ->
        assert view |> has_element?("span[role='page title']", title)
      end)

      # Update the search term
      new_search_term = "Page 1"

      view
      |> element("form[phx-submit=search]")
      |> render_change(%{"search_term" => new_search_term})

      # Should now only show matching content
      assert view |> has_element?("div[role='unit title']", "Introduction")
      assert view |> has_element?("span[role='page title']", "Page 1")

      # Learning Macros unit contains a page called "Page 10" that partially matches the search term
      assert view |> has_element?("div[role='unit title']", "Learning Macros")
      assert view |> has_element?("span[role='page title']", "Page 10")

      Enum.each(
        [
          "Building a Phoenix app",
          "Implementing LiveView",
          "Learning OTP",
          "What did you learn?"
        ],
        fn unit_title ->
          refute view |> has_element?("div[role='unit title']", unit_title)
        end
      )

      all_page_titles
      |> Enum.reject(&String.contains?(&1, "Page 1"))
      |> Enum.each(fn title ->
        refute view |> has_element?("span[role='page title']", title)
      end)
    end
  end
end
