defmodule OliWeb.Delivery.Student.ContentLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Repo
  alias Oli.Analytics.Summary
  alias Oli.Analytics.Common.Pipeline
  alias OliWeb.Delivery.Student.Utils

  alias Oli.Analytics.Summary.{
    Context,
    AttemptGroup
  }

  defp live_view_learn_live_route(section_slug, params \\ %{}) do
    ~p"/sections/#{section_slug}/learn?#{params}"
  end

  defp set_progress(section_id, resource_id, user_id, progress, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
  end

  defp create_elixir_project(_) do
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
        title: "Page 5"
      )

    page_6_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 6"
      )

    page_7_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 7"
      )

    page_8_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 8",
        graded: true
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

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course",
        poster_image: "module_1_custom_image_url",
        intro_content: %{
          children: [
            %{
              type: "p",
              children: [
                %{
                  text: "Thoughout this unit you will learn how to use this course."
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

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id, module_2_revision.resource_id],
        title: "Introduction",
        poster_image: "some_image_url",
        intro_video: "youtube.com/watch?v=123456789ab"
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
        children: [page_10_revision.resource_id],
        title: "Learning Macros",
        intro_video: "another_video"
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
          unit_5_revision.resource_id
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
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        page_6_revision,
        page_7_revision,
        page_8_revision,
        page_9_revision,
        page_10_revision,
        module_1_revision,
        module_2_revision,
        module_3_revision,
        unit_1_revision,
        unit_2_revision,
        unit_3_revision,
        unit_4_revision,
        unit_5_revision,
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

    %{
      section: section,
      project: project,
      publication: publication,
      mcq_1: mcq_activity_1_revision,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_5_revision,
      page_6: page_6_revision,
      page_7: page_7_revision,
      page_8: page_8_revision,
      page_9: page_9_revision,
      page_10: page_10_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      module_3: module_3_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      unit_3: unit_3_revision,
      unit_4: unit_4_revision,
      unit_5: unit_5_revision
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

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, live_view_learn_live_route(section.slug))

      assert redirect_path ==
               "/session/new?request_path=%2Fsections%2F#{section.slug}%2Flearn&section=#{section.slug}"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, live_view_learn_live_route(section.slug))

      assert redirect_path == "/unauthorized"
    end

    test "can access when enrolled to course", %{conn: conn, user: user, section: section} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "h3", "Introduction")
      assert has_element?(view, "h3", "Building a Phoenix app")
      assert has_element?(view, "h3", "Implementing LiveView")
    end

    test "can see unit intro as first slider card and play the video (if provided)", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # unit 1 has an intro card with a video url provided, so there must be a play button
      assert has_element?(
               view,
               ~s{div[role="unit_1"] div[role="slider"] div[role="intro_card"] button[role="play_unit_intro_video"]}
             )

      # unit 2 has an intro card without video url (only poster_image was provided)
      assert has_element?(
               view,
               ~s{div[role="unit_2"] div[role="slider"] div[role="intro_card"]}
             )

      refute has_element?(
               view,
               ~s{div[role="unit_2"] div[role="slider"] div[role="intro_card"] button[role="play_unit_intro_video"]}
             )

      # unit 3 has no intro card at all
      refute has_element?(
               view,
               ~s{div[role="unit_3"] div[role="slider"] div[role="intro_card"]}
             )
    end

    test "can expand a module card to view its details (header with title and due date, intro content and page details)",
         %{
           conn: conn,
           user: user,
           section: section,
           page_1: page_1,
           page_2: page_2
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      # page 1 and page 2 are shown with their estimated read time
      page_1_element =
        element(
          view,
          ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
        )

      assert render(page_1_element) =~ "Page 1"
      assert render(page_1_element) =~ "10"
      assert render(page_1_element) =~ "min"

      page_2_element =
        element(
          view,
          ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_2.slug}"]}
        )

      assert render(page_2_element) =~ "Page 2"
      assert render(page_2_element) =~ "15"
      assert render(page_2_element) =~ "min"

      # intro content is shown
      assert has_element?(view, "p", "Thoughout this unit you will learn how to use this course.")

      # header is shown with title and due date
      assert has_element?(
               view,
               ~s{div[role="expanded module header"] h2},
               "How to use this course"
             )

      assert has_element?(
               view,
               ~s{div[role="expanded module header"] span},
               "Due: Wed Nov 15, 2023"
             )
    end

    test "can see intro video (if any) when expanding a module card",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # module 1 has intro video
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert view
             |> element(~s{div[role="intro 1 details"]})
             |> render() =~ "Introduction"

      assert has_element?(
               view,
               ~s{div[role="intro 1 details"] div[role="unseen video icon"]}
             )

      # module 2 has no intro video
      view
      |> element(~s{div[role="unit_1"] div[role="card_2"]})
      |> render_click()

      refute has_element?(view, ~s{div[role="intro 1 details"] div[role="unseen video icon"]})
    end

    test "intro video is marked as seen after playing it",
         %{
           conn: conn,
           user: user,
           section: section,
           module_1: module_1
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      %{state: enrollment_state} =
        Sections.get_enrollment(section.slug, user.id)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      refute enrollment_state["viewed_intro_video_resource_ids"]

      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[role="intro 1 details"] div[role="unseen video icon"]}
             )

      view
      |> element(~s{div[role="intro 1 details"] div[phx-click="play_video"]})
      |> render_click()

      # since the video is marked as seen in an async way, we revisit the page to check if the icon changed
      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      %{state: enrollment_state} =
        Sections.get_enrollment(section.slug, user.id)

      assert enrollment_state["viewed_intro_video_resource_ids"] == [module_1.resource_id]

      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[role="intro 1 details"] div[role="seen video icon"]}
             )
    end

    test "can see orange flag and due date for graded pages in the module index details",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      view
      |> element(~s{div[role="unit_1"] div[role="card_2"]})
      |> render_click()

      # page number 2 in the module index is the graded page with title "Page 4" in the hierarchy
      assert has_element?(
               view,
               ~s{div[role="page 2 details"] div[role="orange flag icon"]}
             )

      assert has_element?(
               view,
               ~s{div[role="page 2 details"] div[role="due date and score"]},
               "Due: Fri Nov 3, 2023"
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
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

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

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))
      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      view
      |> element(~s{div[role="unit_1"] div[role="card_2"]})
      |> render_click()

      # page number 2 in the module index is the graded page with title "Page 4" in the hierarchy
      # has the correct icon
      assert has_element?(
               view,
               ~s{div[role="page 2 details"] div[role="square check icon"]}
             )

      # correct due date
      assert has_element?(
               view,
               ~s{div[role="page 2 details"] div[role="due date and score"]},
               "Due: Fri Nov 3, 2023"
             )

      # and correct score summary
      assert has_element?(
               view,
               ~s{div[role="page 2 details"] div[role="due date and score"]},
               "1 / 2"
             )
    end

    test "can see module learning objectives (if any) in the tooltip", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
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
      |> element(~s{div[role="unit_1"] div[role="card_2"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[role="module learning objectives"]},
               "Introduction and Learning Objectives"
             )

      learning_objectives_tooltip = element(view, ~s{div[role="learning objectives tooltip"]})

      assert has_element?(learning_objectives_tooltip)

      assert render(learning_objectives_tooltip) =~ "Objective 1"
      assert render(learning_objectives_tooltip) =~ "Objective 2"
      assert render(learning_objectives_tooltip) =~ "Objective 3"
      assert render(learning_objectives_tooltip) =~ "Objective 4"
    end

    test "can see unit check icon and score summary when all pages are completed",
         %{
           conn: conn,
           user: user,
           section: section,
           mcq_1: mcq_1,
           page_1: page_1_revision,
           page_2: page_2_revision,
           page_3: page_3_revision,
           page_4: page_4_revision,
           project: project,
           publication: publication
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_1_revision.resource_id, user.id, 1.0, page_1_revision)
      set_progress(section.id, page_2_revision.resource_id, user.id, 1.0, page_2_revision)
      set_progress(section.id, page_3_revision.resource_id, user.id, 1.0, page_3_revision)
      set_progress(section.id, page_4_revision.resource_id, user.id, 1.0, page_4_revision)

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

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      assert has_element?(
               view,
               ~s{div[role="unit_1"] div[role="score summary"]},
               "1 / 2"
             )

      assert has_element?(
               view,
               ~s{div[role="unit_1"] svg[role="unit completed check icon"]}
             )
    end

    test "can expand more than one module card", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_5: page_5
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # page 1 belongs to module 1 (of unit 1) and page 5 belongs to module 3 (of unit 2)
      # Both should not be visible since they are not expanded yet
      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )

      # expand unit 2/module 3 details
      view
      |> element(~s{div[role="unit_2"] div[role="card_1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      assert has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )
    end

    # TODO: finish this test when the handle event for the "Let's discuss" button is implemented
    @tag :skip
    test "can click on let's discuss button to open DOT AI Bot interface", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, _view, _html} = live(conn, live_view_learn_live_route(section.slug))
    end

    test "sees a check icon on visited and completed pages", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)
      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      # pages are numbered starting from 2 since there is an intro video for this module
      assert has_element?(view, ~s{div[role="page 2 details"] div[role="check icon"]})
      assert has_element?(view, ~s{div[role="page 3 details"]})
      refute has_element?(view, ~s{div[role="page 3 details"] div[role="check icon"]})
    end

    test "does not see a check icon on visited pages that are not fully completed", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_1.resource_id, user.id, 0.5, page_1)
      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert has_element?(view, ~s{div[role="page 2 details"]})
      refute has_element?(view, ~s{div[role="page 1 details"] svg[role="visited check icon"]})
      assert has_element?(view, ~s{div[role="page 2 details"]})
      refute has_element?(view, ~s{div[role="page 2 details"] svg[role="visited check icon"]})
    end

    test "can visit a page", %{conn: conn, user: user, section: section, page_1: page_1} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      # click on page 1 to navigate to that page
      view
      |> element(~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]})
      |> render_click()

      request_path = Utils.learn_live_path(section.slug, page_1.resource_id)
      assert_redirect(view, Utils.lesson_live_path(section.slug, page_1.slug, request_path))
    end

    test "can see the unit schedule details considering if the instructor has already scheduled it",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # unit 1 has been scheduled by instructor, so there must be schedule details data
      assert view
             |> element(~s{div[role="unit_1"] div[role="schedule_details"]})
             |> render() =~
               "Due:\n              </span>\n              Sun, Dec 31, 2023 (8:00pm)"

      # unit 2 has not been scheduled by instructor, so there must not be a schedule details data
      assert view
             |> element(~s{div[role="unit_2"] div[role="schedule_details"]})
             |> render() =~ "Due:\n              </span>\n              not yet scheduled"
    end

    test "can see units, modules and page (at module level) progresses", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_7: page_7
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)
      set_progress(section.id, page_2.resource_id, user.id, 0.5, page_2)
      set_progress(section.id, page_7.resource_id, user.id, 1.0, page_7)
      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # when the slider buttons are enabled we know the student async metrics were loaded
      assert_receive({_ref, {:push_event, "enable-slider-buttons", _}}, 2_000)

      # unit 1 progress is 38% ((1 + 0.5 + 0.0 + 0.0) / 4)
      assert view
             |> element(~s{div[role="unit_1"] div[role="unit_1_progress"]})
             |> render() =~ "style=\"width: 38%\""

      assert view
             |> element(~s{div[role="unit_1"] div[role="unit_1_progress"]})
             |> render() =~ "font-semibold\">\n    38%\n"

      # module 1 progress is 75% ((1 + 0.5) / 2)
      assert view
             |> element(~s{div[role="unit_1"] div[role="card_1_progress"]})
             |> render() =~ "style=\"width: 75%\""

      # unit 3, practice page 1 card at module level has progress 100%
      assert view
             |> element(~s{div[role="unit_3"] div[role="card_1_progress"]})
             |> render() =~ "style=\"width: 100%\""
    end

    test "can see icon that identifies practice pages at level 2 of hierarchy (and can navigate to them)",
         %{
           conn: conn,
           user: user,
           section: section,
           page_7: page_7
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(view, ~s{div[role="unit_3"] div[role="card_1"] div[role="page icon"]})

      # click on page 7 card to navigate to that page
      view
      |> element(~s{div[role="unit_3"] div[role="card_1"]})
      |> render_click()

      request_path = Utils.learn_live_path(section.slug, page_7.resource_id)

      assert_redirect(view, Utils.lesson_live_path(section.slug, page_7.slug, request_path))
    end

    test "can see icon that identifies graded pages at level 2 of hierarchy (and can navigate to them)",
         %{
           conn: conn,
           user: user,
           section: section,
           page_8: page_8
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(
               view,
               ~s{div[role="unit_3"] div[role="card_2"] div[role="graded page icon"]}
             )

      # click on page 8 card to navigate to that page
      view
      |> element(~s{div[role="unit_3"] div[role="card_2"]})
      |> render_click()

      request_path = Utils.learn_live_path(section.slug, page_8.resource_id)

      assert_redirect(view, Utils.lesson_live_path(section.slug, page_8.slug, request_path))
    end

    test "progress bar is not rendered when there is no progress",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # no progress yet, so progress bar is not rendered
      refute has_element?(view, ~s{div[role="unit_1"] div[role="card_1_progress"]})
      refute has_element?(view, ~s{div[role="unit_3"] div[role="card_1_progress"]})
    end

    test "can see card progress bar for modules at level 2 of hierarchy, and even for pages at level 2",
         %{
           conn: conn,
           user: user,
           section: section,
           page_2: page_2,
           page_7: page_7
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_2.resource_id, user.id, 0.5, page_2)
      set_progress(section.id, page_7.resource_id, user.id, 1.0, page_7)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(view, ~s{div[role="unit_1"] div[role="card_1_progress"]})
      assert has_element?(view, ~s{div[role="unit_3"] div[role="card_1_progress"]})
    end

    test "can see card background image if provided (if not the default one is shown)",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert view
             |> element(~s{div[role="unit_1"] div[role="card_1"]"})
             |> render =~ "style=\"background-image: url(&#39;module_1_custom_image_url&#39;)"

      assert view
             |> element(~s{div[role="unit_1"] div[role="card_2"]"})
             |> render =~ "style=\"background-image: url(&#39;/images/course_default.jpg&#39;)"
    end

    test "can see Youtube video poster image (if not the default one is shown)",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert view
             |> element(~s{div[role="unit_1"] div[role="intro_card"]"})
             |> render =~
               "style=\"background-image: url(&#39;https://img.youtube.com/vi/123456789ab/hqdefault.jpg&#39;)"

      # S3 video, uses provided poster image
      assert view
             |> element(~s{div[role="unit_4"] div[role="intro_card"]"})
             |> render =~ "style=\"background-image: url(&#39;some_other_image_url&#39;)"

      # S3 video without poster image, uses default one
      assert view
             |> element(~s{div[role="unit_5"] div[role="intro_card"]"})
             |> render =~ "style=\"background-image: url(&#39;/images/course_default.jpg&#39;)"
    end

    test "can navigate to a unit through url params",
         %{
           conn: conn,
           user: user,
           section: section,
           unit_2: unit_2
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      unit_id = "unit_#{unit_2.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          live_view_learn_live_route(section.slug, %{target_resource_id: unit_2.resource_id})
        )

      # scrolling and pulse animation are triggered
      assert_push_event(view, "scroll-y-to-target", %{
        id: ^unit_id,
        offset: 80,
        pulse: true,
        pulse_delay: 500
      })
    end

    test "can navigate to a module through url params",
         %{
           conn: conn,
           user: user,
           section: section,
           unit_2: unit_2,
           module_3: module_3
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      unit_id = "unit_#{unit_2.resource_id}"
      card_id = "module_#{module_3.resource_id}"
      unit_resource_id = unit_2.resource_id

      {:ok, view, _html} =
        live(
          conn,
          live_view_learn_live_route(section.slug, %{target_resource_id: module_3.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 80})

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

    test "can navigate to a page at module level through url params",
         %{
           conn: conn,
           user: user,
           section: section,
           unit_3: unit_3,
           page_8: page_8
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      unit_id = "unit_#{unit_3.resource_id}"
      card_id = "page_#{page_8.resource_id}"
      unit_resource_id = unit_3.resource_id

      {:ok, view, _html} =
        live(
          conn,
          live_view_learn_live_route(section.slug, %{target_resource_id: page_8.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 80})

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
           user: user,
           section: section,
           unit_2: unit_2,
           module_3: module_3,
           page_6: page_6
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      unit_id = "unit_#{unit_2.resource_id}"
      card_id = "module_#{module_3.resource_id}"
      unit_resource_id = unit_2.resource_id
      pulse_target_id = "index_item_#{page_6.resource_id}"

      {:ok, view, _html} =
        live(
          conn,
          live_view_learn_live_route(section.slug, %{target_resource_id: page_6.resource_id})
        )

      # scrolling and pulse animations are triggered
      assert_push_event(view, "scroll-y-to-target", %{id: ^unit_id, offset: 80})

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
      assert has_element?(view, ~s{div[id="index_item_2_#{page_6.resource_id}"]}, "Page 6")
    end
  end
end
