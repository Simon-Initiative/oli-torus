defmodule OliWeb.Delivery.Student.ScheduleLiveTest do
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
  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Analytics.Summary.{
    AttemptGroup
  }

  defp create_not_scheduled_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## activities...
    mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

    mcq_activity_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
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
        title: "Page 3",
        graded: true
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

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course"
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
        title: "Introduction"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_3_revision.resource_id],
        title: "Building a Phoenix app"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        mcq_activity_1_revision,
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        page_6_revision,
        module_1_revision,
        module_2_revision,
        module_3_revision,
        unit_1_revision,
        unit_2_revision,
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
        title: "The best course ever! (unscheduled version)",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    %{
      author: author,
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
      module_1: module_1_revision,
      module_2: module_2_revision,
      module_3: module_3_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision
    }
  end

  defp create_elixir_project(_) do
    %{
      author: author,
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
      module_1: module_1_revision,
      module_2: module_2_revision,
      module_3: module_3_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision
    } = create_not_scheduled_elixir_project(%{})

    {:ok, section} = Sections.update_section(section, %{title: "The best course ever!"})

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

    # schedule start and end date for page 1 to 6 section_resource
    Sections.get_section_resource(section.id, page_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-01 20:00:00Z],
      end_date: ~U[2023-11-02 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_2_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-02 20:00:00Z],
      end_date: ~U[2023-11-03 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_3_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-03 20:00:00Z],
      end_date: ~U[2023-11-04 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_4_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-04 20:00:00Z],
      end_date: ~U[2023-11-05 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_5_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-05 20:00:00Z],
      end_date: ~U[2023-11-06 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_6_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-07 20:00:00Z],
      end_date: ~U[2023-11-08 20:00:00Z]
    })

    %{
      author: author,
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
      module_1: module_1_revision,
      module_2: module_2_revision,
      module_3: module_3_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision
    }
  end

  defp set_progress(section_id, resource_id, user_id, progress) do
    {:ok, _resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})
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
        date_evaluated: ~U[2023-11-04 20:00:00Z],
        date_submitted: ~U[2023-11-04 20:00:00Z],
        score: if(correct, do: 1, else: 0),
        out_of: 1
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
        out_of: 1,
        date_evaluated: ~U[2023-11-04 20:00:00Z],
        date_submitted: ~U[2023-11-04 20:00:00Z]
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
        live(conn, ~p"/sections/#{section.slug}/schedule")

      assert redirect_path ==
               "/?request_path=%2Fsections%2F#{section.slug}%2Fschedule&section=#{section.slug}"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, ~p"/sections/#{section.slug}/schedule")

      assert redirect_path == "/unauthorized"
    end

    test "can access when enrolled to course", %{conn: conn, user: user, section: section} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/schedule")

      assert has_element?(view, "h1", "Course Schedule")
    end

    test "can see attempts summary and review historical attempts (if setting enabled by instructor)",
         %{
           conn: conn,
           user: user,
           section: section,
           mcq_1: mcq_1,
           page_3: page_3_revision,
           page_4: page_4_revision,
           project: project,
           publication: publication
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_4_revision.resource_id, user.id, 1.0)

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

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/schedule")

      # open attempts summary for page 3
      view
      |> element(~s{button[id="page-#{page_3_revision.slug}-attempts-dropdown-button"]})
      |> render_click()

      # the card shows no info, as no attempt has been made
      assert has_element?(
               view,
               ~s{div[id="page-#{page_3_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "There are no attempts for this page."
             )

      # open attempts summary for page 4
      view
      |> element(~s{button[id="page-#{page_4_revision.slug}-attempts-dropdown-button"]})
      |> render_click()

      # the card shows the correct attempt information

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "Score Information"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "Attempt 1:"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div[role="attempt score"]},
               "0.0"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div[role="attempt out of"]},
               "1.0"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "Sat Nov 4, 2023"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] a[role='review_attempt_link']},
               "Review"
             )
    end

    test "can see attempts summary and not review historical attempts (if setting is disabled by instructor)",
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

      Sections.get_section_resource(section.id, page_4_revision.resource_id)
      |> Sections.update_section_resource(%{
        review_submission: :disallow
      })

      set_progress(section.id, page_4_revision.resource_id, user.id, 1.0)

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

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/schedule")

      # open attempts summary for page 4
      view
      |> element(~s{button[id="page-#{page_4_revision.slug}-attempts-dropdown-button"]})
      |> render_click()

      # the card shows the correct attempt information

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "Score Information"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "Attempt 1:"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div[role="attempt score"]},
               "0.0"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div[role="attempt out of"]},
               "1.0"
             )

      assert has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] div},
               "Sat Nov 4, 2023"
             )

      # but there is no review link (as the setting is disabled)
      refute has_element?(
               view,
               ~s{div[id="page-#{page_4_revision.slug}-attempts-dropdown"] div[id=attempts_summary] a[role='review_attempt_link']},
               "Review"
             )
    end
  end

  describe "student on a section not yet scheduled" do
    setup [
      :user_conn,
      :create_not_scheduled_elixir_project
    ]

    test "can see course data", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      page_5: page_5,
      page_6: page_6,
      module_1: module_1,
      module_2: module_2,
      module_3: module_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/schedule")

      assert has_element?(view, "h1", "Course Schedule")

      [page_1, page_2, page_3, page_4, page_5, page_6]
      |> Enum.each(fn resource -> assert has_element?(view, "a", resource.title) end)

      [module_1, module_2, module_3]
      |> Enum.each(fn resource -> assert has_element?(view, "div", resource.title) end)
    end
  end
end
