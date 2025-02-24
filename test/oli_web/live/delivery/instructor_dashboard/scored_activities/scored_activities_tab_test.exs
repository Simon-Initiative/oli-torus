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

  alias Oli.Analytics.Summary
  alias Oli.Analytics.Common.Pipeline
  alias Oli.Activities
  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Analytics.Summary.{
    AttemptGroup
  }

  defp live_view_scored_activities_route(section_slug, params \\ %{}) do
    case params[:assessment_id] do
      nil ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section_slug,
          :insights,
          :scored_activities,
          params
        )

      assessment_id ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section_slug,
          :insights,
          :scored_activities,
          assessment_id,
          params
        )
    end
  end

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
    resource_access = get_or_insert_resource_access(student, section, page.resource)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: page,
        lifecycle_state: :evaluated,
        date_evaluated: ~U[2020-01-01 00:00:00Z]
      })

    activity_registration = Activities.get_registration(activity_type_id)

    transformed_model =
      case activity_registration.slug do
        "oli_multi_input" ->
          %{
            "authoring" => %{},
            "inputs" => [%{"id" => "1458555427", "inputType" => "text", "partId" => "1"}]
          }

        "oli_multiple_choice" ->
          %{choices: generate_choices(activity_revision.id)}

        "oli_likert" ->
          Oli.TestHelpers.likert_activity_content()

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
          id: part_attempt.id,
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

  defp generate_single_response_content(title) do
    %{
      "stem" => %{
        "id" => "1122006446",
        "content" => [
          %{
            "id" => "286746399",
            "type" => "p",
            "children" => [%{"text" => "#{title}"}]
          }
        ]
      },
      "bibrefs" => [],
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "hints" => [
              %{
                "id" => "261621518",
                "content" => [
                  %{"id" => "3539571997", "type" => "p", "children" => [%{"text" => ""}]}
                ]
              },
              %{
                "id" => "3720232586",
                "content" => [
                  %{"id" => "646828153", "type" => "p", "children" => [%{"text" => ""}]}
                ]
              },
              %{
                "id" => "4061998735",
                "content" => [
                  %{"id" => "1840398296", "type" => "p", "children" => [%{"text" => ""}]}
                ]
              }
            ],
            "responses" => [
              %{
                "id" => "414211103",
                "rule" => "input contains {answer}",
                "score" => 1,
                "feedback" => %{
                  "id" => "2661284074",
                  "content" => [
                    %{"id" => "1350343319", "type" => "p", "children" => [%{"text" => "Correct"}]}
                  ]
                }
              },
              %{
                "id" => "354281247",
                "rule" => "input like {.*}",
                "score" => 0,
                "feedback" => %{
                  "id" => "3230456808",
                  "content" => [
                    %{
                      "id" => "3182181303",
                      "type" => "p",
                      "children" => [%{"text" => "Incorrect"}]
                    }
                  ]
                }
              }
            ],
            "scoringStrategy" => "average"
          }
        ],
        "previewText" => "single response",
        "transformations" => []
      },
      "inputType" => "text"
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

  defp generate_multi_input_content(title) do
    %{
      "authoring" => %{
        "parts" => [
          %{
            "gradingApproach" => "automatic",
            "hints" => [
              %{
                "content" => [
                  %{
                    "children" => [%{"text" => ""}],
                    "id" => "3144326996",
                    "type" => "p"
                  }
                ],
                "editor" => "slate",
                "id" => "2324370830",
                "textDirection" => "ltr"
              }
            ],
            "id" => "1",
            "outOf" => nil,
            "responses" => [
              %{
                "feedback" => %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Correct"}],
                      "id" => "1443012830",
                      "type" => "p"
                    }
                  ],
                  "editor" => "slate",
                  "id" => "4023967540",
                  "textDirection" => "ltr"
                },
                "id" => "3595683503",
                "rule" => "input = {1}",
                "score" => 1
              },
              %{
                "feedback" => %{
                  "content" => [
                    %{
                      "children" => [%{"text" => "Incorrect"}],
                      "id" => "862813719",
                      "type" => "p"
                    }
                  ],
                  "editor" => "slate",
                  "id" => "409522953",
                  "textDirection" => "ltr"
                },
                "id" => "2117868767",
                "rule" => "input like {.*}",
                "score" => 0
              }
            ],
            "scoringStrategy" => "average"
          }
        ],
        "previewText" => "Write NUMBER .",
        "targeted" => [],
        "transformations" => [
          %{
            "firstAttemptOnly" => true,
            "id" => "273348963",
            "operation" => "shuffle",
            "path" => "choices"
          }
        ]
      },
      "bibrefs" => [],
      "choices" => [],
      "inputs" => [%{"id" => "1458555427", "inputType" => "text", "partId" => 1}],
      "stem" => %{
        "content" => [
          %{
            "children" => [
              %{"text" => title},
              %{
                "children" => [%{"text" => ""}],
                "id" => "763756970",
                "type" => "input_ref"
              },
              %{"text" => "."}
            ],
            "id" => "1622099819",
            "type" => "p"
          }
        ],
        "id" => "3205611195"
      },
      "submitPerPart" => false
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
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 2"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 3"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 4"
      )

    ## activities...
    mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")
    single_response_reg = Oli.Activities.get_registration_by_slug("oli_short_answer")
    multi_input_reg = Oli.Activities.get_registration_by_slug("oli_multi_input")
    likert_reg = Oli.Activities.get_registration_by_slug("oli_likert")

    mcq_activity_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id
          ]
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 1",
        content: generate_mcq_content("This is the first question")
      )

    mcq_activity_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "1" => []
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 2",
        content: generate_mcq_content("This is the second question")
      )

    single_response_activity_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id,
            objective_2_revision.resource_id
          ]
        },
        activity_type_id: single_response_reg.id,
        title: "The Single Response question",
        content: generate_single_response_content("This is a single response question")
      )

    multi_input_activity_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        objectives: %{
          "1" => []
        },
        activity_type_id: multi_input_reg.id,
        title: "The Multi Input question",
        content: generate_multi_input_content("This is a multi input question")
      )

    likert_activity_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        objectives: %{
          "1" => []
        },
        activity_type_id: likert_reg.id,
        title: "The Likert question",
        content: Oli.TestHelpers.likert_activity_content("This is a likert question")
      )

    ## graded pages (assessments)...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
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
              activity_id: mcq_activity_1_revision.resource.id
            },
            %{
              id: "3330767712",
              type: "activity-reference",
              children: [],
              activity_id: mcq_activity_2_revision.resource.id
            },
            %{
              id: "3330767712",
              type: "activity-reference",
              children: [],
              activity_id: single_response_activity_revision.resource.id
            },
            %{
              id: "3330767714",
              type: "activity-reference",
              children: [],
              activity_id: multi_input_activity_revision.resource.id
            },
            %{
              id: "3330767714",
              type: "activity-reference",
              children: [],
              activity_id: likert_activity_revision.resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_2_revision.resource_id]},
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3",
        graded: true
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4",
        graded: true
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Orphaned Page",
        graded: true
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Introduction"
      })

    module_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [module_1_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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
      resource_id: mcq_activity_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: mcq_activity_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: single_response_activity_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: multi_input_activity_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: likert_activity_revision.resource_id
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
      resource: mcq_activity_1_revision.resource,
      revision: mcq_activity_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: mcq_activity_2_revision.resource,
      revision: mcq_activity_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: single_response_activity_revision.resource,
      revision: single_response_activity_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: multi_input_activity_revision.resource,
      revision: multi_input_activity_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: likert_activity_revision.resource,
      revision: likert_activity_revision,
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

    # create section with analytics v2...
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll students to section
    student_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
    student_2 = insert(:user, %{given_name: "Angel", family_name: "Di Maria"})
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

    # create section with analytics v1...
    section_v1 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        analytics_version: :v1
      )

    {:ok, section_v1} = Sections.create_section_resources(section_v1, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section_v1)

    # enroll students to section
    Sections.enroll(student_1.id, section_v1.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(instructor.id, section_v1.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    %{
      section: section,
      section_v1: section_v1,
      project: project,
      publication: publication,
      mcq_activity_1: mcq_activity_1_revision,
      mcq_activity_2: mcq_activity_2_revision,
      single_response_activity: single_response_activity_revision,
      multi_input_activity: multi_input_activity_revision,
      likert_activity: likert_activity_revision,
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
            :order,
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
              |> String.split("\n")
              |> Enum.map(fn string -> String.trim(string) end)
              |> Enum.join()

            select ->
              Floki.find(select, "option[selected]") |> Floki.text()
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
        "/users/log_in"

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
      assert has_element?(view, "p", "There are no activities to show")
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
      assert a0.title == "Module 1: IntroductionPage 1"
      assert a1.title == "Module 1: IntroductionPage 2"
      assert a2.title == "Module 2: BasicsPage 3"
      assert a3.title == "Module 2: BasicsPage 4"
      assert a4.title == "Orphaned Page"
    end

    # NON-DETERMINISTIC: https://eliterate.atlassian.net/browse/TRIAGE-4 Fix or remove
    @tag :skip
    test "sorting by Due Date", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4
    } do
      # Only section resources of scheduling_type = due_by are considered when sorting by Due Date
      # It's considered also in the case that the scheduling_type is read_by, but the end_date is nil
      [
        {page_1, %{end_date: ~U[2000-01-21 12:00:00.00Z], scheduling_type: :due_by}},
        {page_2, %{end_date: ~U[2000-01-22 12:00:00.00Z], scheduling_type: :read_by}},
        {page_3, %{end_date: ~U[2000-01-23 12:00:00.00Z], scheduling_type: :due_by}},
        {page_4, %{end_date: nil, scheduling_type: :due_by}}
      ]
      |> Enum.each(fn {page, params} ->
        Sections.get_section_resource(section.id, page.resource_id)
        |> Sections.update_section_resource(params)
      end)

      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      assert [
               "No due date",
               "Jan. 21, 2000 - 7:00 AM",
               "No due date",
               "Jan. 23, 2000 - 7:00 AM",
               "No due date"
             ] = table_as_list_of_maps(view, :assessments) |> Enum.map(& &1.due_date)

      view
      |> element("th[phx-value-sort_by=due_date]")
      |> render_click()

      assert [
               "No due date",
               "No due date",
               "No due date",
               "Jan. 21, 2000 - 7:00 AM",
               "Jan. 23, 2000 - 7:00 AM"
             ] = table_as_list_of_maps(view, :assessments) |> Enum.map(& &1.due_date)

      view
      |> element("th[phx-value-sort_by=due_date]")
      |> render_click()

      assert [
               "Jan. 23, 2000 - 7:00 AM",
               "Jan. 21, 2000 - 7:00 AM",
               "No due date",
               "No due date",
               "No due date"
             ] = table_as_list_of_maps(view, :assessments) |> Enum.map(& &1.due_date)
    end

    test "sorting by Order number", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~ "1"

      assert view
             |> element("tr:first-child > td:nth-child(2) > div")
             |> render() =~ "Page 1"

      assert view
             |> element("tr:last-child > td:first-child > div")
             |> render() =~ "5"

      assert view
             |> element("tr:last-child > td:nth-child(2) > div > div")
             |> render() =~ "Orphaned Page"

      view
      |> element("th[phx-value-sort_by=order]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~ "5"

      assert view
             |> element("tr:first-child > td:nth-child(2) > div > div > a")
             |> render() =~ "Orphaned Page"

      assert view
             |> element("tr:last-child > td:first-child > div")
             |> render() =~ "1"

      assert view
             |> element("tr:last-child > td:nth-child(2) > div")
             |> render() =~ "Page 1"
    end

    test "displays custom labels", %{
      conn: conn,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          customizations: %{unit: "Volume", module: "Chapter", section: "Lesson"}
        })

      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      [a0, a1, a2, a3, a4] = table_as_list_of_maps(view, :assessments)

      assert has_element?(view, "h4", "Scored Activities")
      assert a0.title == "Chapter 1: IntroductionPage 1"
      assert a1.title == "Chapter 1: IntroductionPage 2"
      assert a2.title == "Chapter 2: BasicsPage 3"
      assert a3.title == "Chapter 2: BasicsPage 4"
      assert a4.title == "Orphaned Page"
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

      assert view |> element("button", "Back to Activities") |> has_element?()

      url =
        live_view_scored_activities_route(section.slug, %{
          assessment_id: page_5.id
        })

      # we assert that the url was patched correctly after click
      receive do
        {_ref, {:patch, _topic, %{kind: :push, to: url_with_params}}} ->
          assert String.starts_with?(url_with_params, url)
          assert url_with_params =~ "assessment_table_params[offset]=0"
          assert url_with_params =~ "assessment_table_params[limit]=20"
          assert url_with_params =~ "assessment_table_params[sort_by]=order"
          assert url_with_params =~ "assessment_table_params[assessment_id]="
          assert url_with_params =~ "assessment_table_params[text_search]="
          assert url_with_params =~ "assessment_table_params[sort_order]=asc"
          assert url_with_params =~ "assessment_table_params[assessment_table_params]="
          assert url_with_params =~ "assessment_table_params[selected_activity]="
      end

      # and that the activitiy content was rendered
      assert view
             |> element("h4", "Orphaned Page")
             |> has_element?()

      assert view
             |> element("p", "There are no activities to show")
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
      assert has_element?(view, "p", "There are no activities to show")
    end

    @tag :skip
    test "shows an warning and redirect to the scored activities tab when the assessment doesn't exist",
         %{
           conn: conn,
           section: section
         } do
      {:ok, _view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: 500
          })
        )

      assert_receive {_ref, {:redirect, _lv, %{flash: _flash_msg, to: url}}}
      assert url == ~p"/sections/#{section.slug}/instructor_dashboard/overview/scored_activities"
    end

    test "loads correctly activity details", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      mcq_activity_1: mcq_activity_1,
      project: project,
      publication: publication
    } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

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
      single_response_activity: single_response_activity,
      project: project,
      publication: publication
    } do
      set_activity_attempt(
        page_1,
        single_response_activity,
        student_1,
        section,
        project.id,
        publication.id,
        "this is my answer to the single response question",
        false
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      [activity] = table_as_list_of_maps(view, :activities)

      assert activity.title ==
               "The Single Response question:This is a single response question"

      assert activity.learning_objectives == "Objective 1Objective 2"
      assert activity.avg_score == "0%"
      assert activity.total_attempts =~ "1"
    end

    test "loads correctly an activity with no objective attached", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      mcq_activity_2: mcq_activity_2,
      project: project,
      publication: publication
    } do
      set_activity_attempt(
        page_1,
        mcq_activity_2,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_b",
        false
      )

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

    test "first activity (MCQ) gets pre-selected and its question details get rendered correctly",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2,
           student_3: student_3,
           mcq_activity_1: mcq_activity_1,
           mcq_activity_2: mcq_activity_2,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_2,
        section,
        project.id,
        publication.id,
        "id_for_option_b",
        false
      )

      # a blank attempt
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_3,
        section,
        project.id,
        publication.id,
        "",
        false
      )

      set_activity_attempt(
        page_1,
        mcq_activity_2,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_b",
        false
      )

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

      activity_id =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("activity_id")
        |> hd()
        |> String.split("_")
        |> Enum.at(1)
        |> String.to_integer()

      assert activity_id == mcq_activity_1.resource_id
    end

    test "single response details get rendered correctly when activity is selected",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2,
           mcq_activity_1: mcq_activity_1,
           single_response_activity: single_response_activity,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        single_response_activity,
        student_2,
        section,
        project.id,
        publication.id,
        "This is an incorrect answer from student 2",
        false
      )

      set_activity_attempt(
        page_1,
        single_response_activity,
        student_2,
        section,
        project.id,
        publication.id,
        "This is the second answer (correct) from student 2",
        true
      )

      set_activity_attempt(
        page_1,
        single_response_activity,
        student_1,
        section,
        project.id,
        publication.id,
        "This is the first answer (correct) from the GOAT",
        true
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      # we click on the single response activity
      view
      |> element(~s{table tbody tr:nth-of-type(2)})
      |> render_click()

      # and check that the single response details render correctly
      # sorted by student name
      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-short-answer-authoring})
        |> Floki.attribute("model")
        |> hd

      assert selected_activity_model =~
               "\"responses\":[{\"text\":\"This is an incorrect answer from student 2\",\"user_name\":\"Di Maria, Angel\"},{\"text\":\"This is the second answer (correct) from student 2\",\"user_name\":\"Di Maria, Angel\"},{\"text\":\"This is the first answer (correct) from the GOAT\",\"user_name\":\"Messi, Lionel\"}]"
    end

    test "multi input activity details get rendered correctly when activity is selected",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           multi_input_activity: multi_input_activity,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        multi_input_activity,
        student_1,
        section,
        project.id,
        publication.id,
        "Answer for input 1",
        true
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      # check that the multi input details render correctly
      _selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multi-input-authoring})
        |> Floki.attribute("model")
        |> hd

      assert has_element?(
               view,
               ~s(div[role="activity_title"]),
               "Question details"
             )
    end

    test "likert activity details get rendered correctly when activity is selected",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           likert_activity: likert_activity,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        likert_activity,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      # check that the likert VegaLite visualization renders correctly
      selected_activity_data =
        view
        |> element("div[data-live-react-class=\"Components.VegaLiteRenderer\"]")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.attribute("data-live-react-props")
        |> hd()
        |> Jason.decode!()

      assert selected_activity_data["spec"]["title"]["text"] == likert_activity.title
    end

    test "question details responds to user click on an activity", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1,
      mcq_activity_1: mcq_activity_1,
      mcq_activity_2: mcq_activity_2,
      project: project,
      publication: publication
    } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_2,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_b",
        false
      )

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

      activity_id =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("activity_id")
        |> hd()
        |> String.split("_")
        |> Enum.at(1)
        |> String.to_integer()

      assert activity_id == mcq_activity_2.resource_id
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
      mcq_activity_1: mcq_activity_1,
      project: project,
      publication: publication
    } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

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
           mcq_activity_1: mcq_activity_1,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_2,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_3,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

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
           mcq_activity_1: mcq_activity_1,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_2,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_3,
        section,
        project.id,
        publication.id,
        "id_for_option_b",
        false
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_3,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_4,
        section,
        project.id,
        publication.id,
        "id_for_option_b",
        false
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_4,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

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
           mcq_activity_1: mcq_activity_1,
           project: project,
           publication: publication
         } do
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_2,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

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

  describe "page size change" do
    setup [:instructor_conn, :create_project]

    test "lists table elements according to the default page size", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      [a0, a1, a2, a3, a4] = table_as_list_of_maps(view, :assessments)

      assert a0.title == "Module 1: IntroductionPage 1"
      assert a1.title == "Module 1: IntroductionPage 2"
      assert a2.title == "Module 2: BasicsPage 3"
      assert a3.title == "Module 2: BasicsPage 4"
      assert a4.title == "Orphaned Page"

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    test "updates page size and list expected elements", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      [a0, a1] = table_as_list_of_maps(view, :assessments)

      # Page 1
      assert a0.title == "Module 1: IntroductionPage 1"
      assert a1.title == "Module 1: IntroductionPage 2"
    end

    test "change page size works as expected", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_scored_activities_route(section.slug))

      # Refute that the pagination options are displayed
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      [a0, a1] = table_as_list_of_maps(view, :assessments)

      # Page 1
      assert a0.title == "Module 1: IntroductionPage 1"
      assert a1.title == "Module 1: IntroductionPage 2"

      # Assert that the pagination options are displayed
      assert has_element?(view, "nav[aria-label=\"Paging\"]")

      # Change to page 2
      view
      |> element("button[phx-value-offset=\"2\"]", "2")
      |> render_click()

      [a2, a3] = table_as_list_of_maps(view, :assessments)

      # Page 2
      assert a2.title == "Module 2: BasicsPage 3"
      assert a3.title == "Module 2: BasicsPage 4"
    end

    test "keeps showing the same elements when changing the page size", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_scored_activities_route(section.slug, %{
            limit: 2,
            offset: 2
          })
        )

      [a2, a3] = table_as_list_of_maps(view, :assessments)

      # Page 2
      assert a2.title == "Module 2: BasicsPage 3"
      assert a3.title == "Module 2: BasicsPage 4"

      # Change page size from 2 to 1
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "1"})

      [a2] = table_as_list_of_maps(view, :assessments)

      # Page 3. It keeps showing the same element.
      assert a2.title == "Module 2: BasicsPage 3"
    end
  end
end
