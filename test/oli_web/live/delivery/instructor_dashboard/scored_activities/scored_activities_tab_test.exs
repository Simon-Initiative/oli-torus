defmodule OliWeb.Delivery.InstructorDashboard.ScoredActivitiesTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Repo

  defp live_view_scored_activities_route(section_slug, params \\ %{}) do
    case params[:assessment_id] do
      nil ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section_slug,
          :overview,
          :scored_activities,
          params
        )

      assessment_id ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section_slug,
          :overview,
          :scored_activities,
          assessment_id,
          params
        )
    end
  end

  defp set_activity_attempt(page, activity_revision, student, section, score) do
    resource_access = get_or_insert_resource_access(student, section, page.resource)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: page,
        lifecycle_state: :evaluated,
        date_evaluated: ~U[2020-01-01 00:00:00Z]
      })

    activity_attempt =
      insert(:activity_attempt, %{
        revision: activity_revision,
        resource: activity_revision.resource,
        resource_attempt: resource_attempt,
        lifecycle_state: :evaluated,
        transformed_model: %{choices: generate_choices(activity_revision.id)},
        score: score,
        out_of: 1
      })

    insert(:part_attempt, %{
      activity_attempt: activity_attempt,
      response: %{files: [], input: "option_1_id"}
    })
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

  defp generate_content(title) do
    %{
      stem: %{
        id: "2028833010",
        content: [
          %{id: "280825708", type: "p", children: [%{text: title}]}
        ]
      },
      choices: generate_choices("2028833010"),
      authoring: %{
        parts: [
          %{
            id: "1",
            hints: [
              %{
                id: "540968727",
                content: [
                  %{id: "2256338253", type: "p", children: [%{text: ""}]}
                ]
              },
              %{
                id: "2627194758",
                content: [
                  %{id: "3013119256", type: "p", children: [%{text: ""}]}
                ]
              },
              %{
                id: "2413327578",
                content: [
                  %{id: "3742562774", type: "p", children: [%{text: ""}]}
                ]
              }
            ],
            outOf: nil,
            responses: [
              %{
                id: "4122423546",
                rule: "(!(input like {1968053412})) && (input like {1436663133})",
                score: 1,
                feedback: %{
                  id: "685174561",
                  content: [
                    %{
                      id: "2621700133",
                      type: "p",
                      children: [%{text: "Correct"}]
                    }
                  ]
                }
              },
              %{
                id: "3738563441",
                rule: "input like {.*}",
                score: 0,
                feedback: %{
                  id: "3796426513",
                  content: [
                    %{
                      id: "1605260471",
                      type: "p",
                      children: [%{text: "Incorrect"}]
                    }
                  ]
                }
              }
            ],
            gradingApproach: "automatic",
            scoringStrategy: "average"
          }
        ],
        correct: [["1436663133"], "4122423546"],
        version: 2,
        targeted: [],
        previewText: "",
        transformations: [
          %{
            id: "1349799137",
            path: "choices",
            operation: "shuffle",
            firstAttemptOnly: true
          }
        ]
      }
    }
  end

  defp generate_choices(id),
    do: [
      %{
        id: "1436663133",
        content: [
          %{
            id: "1866911747",
            type: "p",
            children: [%{text: "Choice 1 for #{id}"}]
          }
        ]
      },
      %{
        id: "1968053412",
        content: [
          %{
            id: "3926142114",
            type: "p",
            children: [%{text: "Choice 2 for #{id}"}]
          }
        ]
      }
    ]

  defp enroll_instructor(%{section: section, instructor: instructor}) do
    {:ok, _enrollment} =
      Sections.enroll(instructor.id, section.id, [
        ContextRoles.get_role(:context_instructor)
      ])

    :ok
  end

  defp create_project(%{instructor: instructor}) do
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

    activity_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id
          ]
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 1",
        content: generate_content("This is the first question")
      )

    activity_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        objectives: %{
          "1" => []
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 2",
        content: generate_content("This is the second question")
      )

    activity_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id,
            objective_2_revision.resource_id
          ]
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 3",
        content: generate_content("This is the third question")
      )

    ## graded pages (assessments)...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Page 1",
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
              activity_id: activity_1_revision.resource.id
            },
            %{
              id: "3330767712",
              type: "activity-reference",
              children: [],
              activity_id: activity_2_revision.resource.id
            },
            %{
              id: "3330767712",
              type: "activity-reference",
              children: [],
              activity_id: activity_3_revision.resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_2_revision.resource_id]},
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3",
        graded: true
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4",
        graded: true
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Orphaned Page",
        graded: true
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Introduction"
      })

    module_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id, page_4_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Basics"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 2"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id,
          page_5_revision.resource_id
        ],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: activity_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: activity_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: activity_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_5_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_1_revision.resource,
      revision: objective_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_2_revision.resource,
      revision: objective_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_3_revision.resource,
      revision: objective_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_4_revision.resource,
      revision: objective_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: activity_1_revision.resource,
      revision: activity_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: activity_2_revision.resource,
      revision: activity_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: activity_3_revision.resource,
      revision: activity_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_1_revision.resource,
      revision: page_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_3_revision.resource,
      revision: page_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_4_revision.resource,
      revision: page_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_5_revision.resource,
      revision: page_5_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_1_revision.resource,
      revision: module_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_2_revision.resource,
      revision: module_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_2_revision.resource,
      revision: unit_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    # create section...
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll students to section
    [student_1, student_2] = insert_pair(:user)
    [student_3, student_4] = insert_pair(:user)

    Sections.enroll(student_1.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_2.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_3.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_4.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(instructor.id, section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    %{
      section: section,
      activity_1: activity_1_revision,
      activity_2: activity_2_revision,
      activity_3: activity_3_revision,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_5_revision,
      page_1_objective: objective_1_revision,
      page_2_objective: objective_2_revision,
      page_3_objective: objective_3_revision,
      page_4_objective: objective_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      instructor: instructor
    }
  end

  defp table_as_list_of_maps(view, tab_name) do
    keys =
      case tab_name do
        :assessments ->
          [
            :title,
            :due_date,
            :avg_score,
            :total_attempts,
            :students_completion
          ]

        :activities ->
          [
            :title,
            :learning_objectives,
            :avg_score,
            :total_attempts
          ]
      end

    rows =
      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{.instructor_dashboard_table tbody tr})
      |> Enum.map(fn row ->
        Floki.find(row, "td")
        |> Enum.map(fn data ->
          case Floki.find(data, "select") do
            [] ->
              Floki.text(data)

            select ->
              Floki.find(select, "option[selected]")
              |> Floki.text()
          end
        end)
      end)

    Enum.map(rows, fn a ->
      Enum.zip(keys, a)
      |> Enum.into(%{})
    end)
  end

  describe "user" do
    test "cannot access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Foverview%2Fscored_activities"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_scored_activities_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "cannot access page", %{user: user, conn: conn} do
      section = insert(:section)

      Sections.enroll(user.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_scored_activities_route(section.slug))
    end
  end

  describe "scored activities assessments table" do
    setup [:instructor_conn, :section_without_pages, :enroll_instructor]

    test "loads correctly when there are no assessments", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      assert has_element?(view, "h4", "Scored Activities")
      assert has_element?(view, "p", "None exist")
    end
  end

  describe "scored activities assessments table WITH activities" do
    setup [:instructor_conn, :create_project]

    test "loads correctly", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      [a0, a1, a2, a3, a4] = table_as_list_of_maps(view, :assessments)

      assert has_element?(view, "h4", "Scored Activities")
      assert a0.title == "Orphaned Page"
      assert a1.title == "Module 1: IntroductionPage 1"
      assert a2.title == "Module 1: IntroductionPage 2"
      assert a3.title == "Module 2: BasicsPage 3"
      assert a4.title == "Module 2: BasicsPage 4"
    end

    test "patches url to see activity details when a row is clicked", %{
      conn: conn,
      section: section,
      page_5: page_5
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      view
      |> element("table tbody tr:nth-of-type(1) a")
      |> render_click(%{id: page_5.id})

      # we assert that the url was patched correctly after click
      current_params =
        "?assessment_table_params[assessment_id]=&assessment_table_params[assessment_table_params]=&assessment_table_params[limit]=10&assessment_table_params[offset]=0&assessment_table_params[selected_activity]=&assessment_table_params[sort_by]=title&assessment_table_params[sort_order]=asc&assessment_table_params[text_search]="

      url =
        live_view_scored_activities_route(section.slug, %{
          assessment_id: page_5.id
        }) <>
          current_params

      assert_receive {_ref, {:patch, _topic, %{to: ^url}}}

      # and that the activitiy content was rendered
      assert view
             |> element("h4", "Orphaned Page")
             |> has_element?()

      assert view
             |> element("p", "None exist")
             |> has_element?()
    end
  end

  describe "details of assessment activities" do
    setup [:instructor_conn, :create_project]

    test "loads correctly when there are no activites for that assessment", %{
      conn: conn,
      section: section,
      page_5: page_5
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_5.id
          })
        )

      assert has_element?(view, "h4", "Orphaned Page")
      assert has_element?(view, "p", "None exist")
    end

    test "loads correctly activity details", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      activity_1: activity_1
    } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      [activity] = table_as_list_of_maps(view, :activities)

      assert activity.title == "Multiple Choice 1:This is the first question"
      assert activity.learning_objectives == "Objective 1"
      assert activity.avg_score == "100%"
      assert activity.total_attempts =~ "1"
    end

    test "loads correctly an activity with more than one objective attached", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      activity_3: activity_3
    } do
      set_activity_attempt(page_1, activity_3, student_1, section, 0)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      [activity] = table_as_list_of_maps(view, :activities)

      assert activity.title == "Multiple Choice 3:This is the third question"
      assert activity.learning_objectives == "Objective 1Objective 2"
      assert activity.avg_score == "0%"
      assert activity.total_attempts =~ "1"
    end

    test "loads correctly an activity with no objective attached", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      activity_2: activity_2
    } do
      set_activity_attempt(page_1, activity_2, student_1, section, 0)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      [activity] = table_as_list_of_maps(view, :activities)

      assert activity.title == "Multiple Choice 2:This is the second question"
      assert activity.learning_objectives == ""
      assert activity.avg_score == "0%"
      assert activity.total_attempts =~ "1"
    end

    test "first activity gets pre-selected and its question details gets rendered correctly", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      activity_1: activity_1,
      activity_2: activity_2
    } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)
      set_activity_attempt(page_1, activity_2, student_1, section, 0)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      [act_1, _act_2] = table_as_list_of_maps(view, :activities)

      first_table_row_html =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{table tbody tr:first-of-type})
        |> Floki.raw_html()

      # first row is highlighted as selected
      assert first_table_row_html =~ ~s{class="border-b table-active}
      assert act_1.title == "Multiple Choice 1:This is the first question"

      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("model")
        |> hd

      # and the question details are rendered
      assert selected_activity_model =~
               "{\"choices\":[{\"content\":[{\"children\":[{\"text\":\"Choice 1 for #{activity_1.id}\"}],\"id\":\"1866911747\",\"type\":\"p\"}],\"id\":\"1436663133\"},{\"content\":[{\"children\":[{\"text\":\"Choice 2 for #{activity_1.id}\"}],\"id\":\"3926142114\",\"type\":\"p\"}],\"id\":\"1968053412\"}]}"
    end

    test "question details responds to user click on an activity", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      activity_1: activity_1,
      activity_2: activity_2
    } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)
      set_activity_attempt(page_1, activity_2, student_1, section, 0)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      [_act_1, act_2] = table_as_list_of_maps(view, :activities)

      second_table_row_html =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{table tbody tr:nth-of-type(2)})
        |> Floki.raw_html()

      # second row is not highlighted as selected
      refute second_table_row_html =~ ~s{class="border-b table-active}
      assert act_2.title == "Multiple Choice 2:This is the second question"

      # we click on the second activity
      view
      |> element(~s{table tbody tr:nth-of-type(2)})
      |> render_click()

      # and check the highlighted row has changed
      [_act_1, act_2] = table_as_list_of_maps(view, :activities)

      second_table_row_html =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{table tbody tr:nth-of-type(2)})
        |> Floki.raw_html()

      assert second_table_row_html =~ ~s{class="border-b table-active}
      assert act_2.title == "Multiple Choice 2:This is the second question"

      # and check that the question details have changed to match the selected activity
      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("model")
        |> hd

      assert selected_activity_model =~
               "{\"choices\":[{\"content\":[{\"children\":[{\"text\":\"Choice 1 for #{activity_2.id}\"}],\"id\":\"1866911747\",\"type\":\"p\"}],\"id\":\"1436663133\"},{\"content\":[{\"children\":[{\"text\":\"Choice 2 for #{activity_2.id}\"}],\"id\":\"3926142114\",\"type\":\"p\"}],\"id\":\"1968053412\"}]}"
    end

    test "student attempts summary gets rendered correctly when no students have attempted", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "No student has completed any attempts."

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "4 students have not completed any attempt"
    end

    test "student attempts summary gets rendered correctly when one student has attempted", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      activity_1: activity_1
    } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "1 student has completed 1 attempt."

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "3 students have not completed any attempt"
    end

    test "student attempts summary gets rendered correctly when more than one student has attempted",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2,
           student_3: student_3,
           activity_1: activity_1
         } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)
      set_activity_attempt(page_1, activity_1, student_2, section, 1)
      set_activity_attempt(page_1, activity_1, student_3, section, 1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "3 students have completed 3 attempts."

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "1 student has not completed any attempt"
    end

    test "student attempts summary gets rendered correctly when all students have attempted (even more than once)",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2,
           student_3: student_3,
           student_4: student_4,
           activity_1: activity_1
         } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)
      set_activity_attempt(page_1, activity_1, student_2, section, 1)
      set_activity_attempt(page_1, activity_1, student_3, section, 0)
      set_activity_attempt(page_1, activity_1, student_3, section, 1)
      set_activity_attempt(page_1, activity_1, student_4, section, 0)
      set_activity_attempt(page_1, activity_1, student_4, section, 1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      assert view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "4 students have completed 6 attempts."

      refute view
             |> element(~s{#student_attempts_summary})
             |> render() =~ "not completed"

      refute view
             |> has_element?("#copy_emails_button", "Copy their email addresses")
    end

    test "instructor can copy email of students that have not yet attempted",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2,
           activity_1: activity_1
         } do
      set_activity_attempt(page_1, activity_1, student_1, section, 1)
      set_activity_attempt(page_1, activity_1, student_2, section, 1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      assert view
             |> has_element?("#copy_emails_button", "Copy email addresses")
    end
  end
end
