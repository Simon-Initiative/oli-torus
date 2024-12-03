defmodule OliWeb.Delivery.InstructorDashboard.SurveysTabTest do
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

  defp live_surveys_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :insights,
      :surveys,
      params
    )
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
        out_of: 1,
        survey_id: "4286170280"
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
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "1" => []
        },
        activity_type_id: multi_input_reg.id,
        title: "The Multi Input question",
        content: generate_multi_input_content("This is a multi input question")
      )

    likert_activity_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
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
        graded: false,
        content: %{
          model: [
            %{
              id: "4286170280",
              type: "survey",
              children: [
                %{
                  id: "3330767711",
                  type: "activity-reference",
                  children: [],
                  activity_id: mcq_activity_1_revision.resource.id
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
        graded: false,
        content: %{
          model: [
            %{
              id: "4286170281",
              type: "survey",
              children: []
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3",
        graded: false,
        content: %{
          model: [
            %{
              id: "4286170282",
              type: "survey",
              children: []
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4",
        graded: false,
        content: %{
          model: [
            %{
              id: "4286170283",
              type: "survey",
              children: []
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Orphaned Page",
        graded: false,
        content: %{
          model: [
            %{
              id: "4286170284",
              type: "survey",
              children: []
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
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

  defp table_as_list_of_maps(view) do
    keys =
      [
        :title,
        :due_date,
        :avg_score,
        :total_attempts,
        :students_completion
      ]

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
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Finsights%2Fsurveys"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_surveys_route(section.slug))
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
               live(conn, live_surveys_route(section.slug))
    end
  end

  describe "surveys assessments table" do
    setup [:instructor_conn, :section_without_pages, :enroll_instructor]

    test "loads correctly when there are no assessments", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      assert has_element?(view, "h4", "Surveys")
      assert has_element?(view, "p", "There are no surveys present in this course")
    end
  end

  describe "surveys assessments table WITH assessments" do
    setup [:instructor_conn, :create_project]

    test "loads correctly", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      [a0, a1, a2, a3, a4] = table_as_list_of_maps(view)

      assert has_element?(view, "h4", "Surveys")
      assert a0.title == "Orphaned Page"
      assert a1.title == "Module 1: IntroductionPage 1"
      assert a2.title == "Module 1: IntroductionPage 2"
      assert a3.title == "Module 2: BasicsPage 3"
      assert a4.title == "Module 2: BasicsPage 4"
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
          live_surveys_route(section.slug)
        )

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_5.id}\"]")
      |> render_click()

      assert has_element?(view, "p", "No attempt registered for this question")
    end

    test "multiple choice details get rendered correctly when page is selected", %{
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
          live_surveys_route(section.slug)
        )

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      assert element(
               view,
               "table tbody tr:nth-of-type(1)[class=\"table-active bg-delivery-primary-100\"]"
             )

      # check that the multiple choice details render correctly
      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("model")
        |> hd

      assert has_element?(
               view,
               ~s(div[role="activity_title"]),
               "#{mcq_activity_1.title} - Question details"
             )

      assert selected_activity_model =~
               "{\"choices\":[{\"content\":[{\"children\":[{\"text\":\"Choice 1 for #{mcq_activity_1.id}\"}],\"id\":\"1866911747\",\"type\":\"p\"}],\"frequency\":1,\"id\":\"id_for_option_a\"},{\"content\":[{\"children\":[{\"text\":\"Choice 2 for #{mcq_activity_1.id}\"}],\"id\":\"3926142114\",\"type\":\"p\"}],\"frequency\":0,\"id\":\"id_for_option_b\"}]}"
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

      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

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

    test "multi input activity details get rendered correctly when page is selected",
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

      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      # check that the multi input details render correctly
      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multi-input-authoring})
        |> Floki.attribute("model")
        |> hd

      assert has_element?(
               view,
               ~s(div[role="activity_title"]),
               "#{multi_input_activity.title} - Question details"
             )

      assert selected_activity_model =~
               "{\"authoring\":{\"responses\":[{\"type\":\"text\",\"text\":\"unsupported\",\"user_name\":\"#{student_1.family_name}, #{student_1.given_name}\",\"part_id\":\"1\"}]},\"inputs\":[{\"id\":\"1458555427\",\"inputType\":\"text\",\"partId\":\"1\"}]}"
    end

    test "likert activity details get rendered correctly when page is selected",
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

      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      # check that the likert VegaLite visualization renders correctly
      selected_activity_data =
        view
        |> element("div[data-live-react-class=\"Components.VegaLiteRenderer\"]")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.attribute("data-live-react-props")
        |> hd()
        |> Jason.decode!()

      assert has_element?(
               view,
               ~s(div[role="activity_title"]),
               "#{likert_activity.title} - Question details"
             )

      assert selected_activity_data["spec"]["title"]["text"] == likert_activity.title
    end

    test "single response details get rendered for a section with analytics_version :v2 but not for :v1",
         %{
           conn: conn,
           section_v1: section_v1,
           section: section,
           page_1: page_1,
           student_1: student_1,
           single_response_activity: single_response_activity,
           project: project,
           publication: publication
         } do
      ## section with analytics_version :v1
      set_activity_attempt(
        page_1,
        single_response_activity,
        student_1,
        section_v1,
        project.id,
        publication.id,
        "This is an incorrect answer from student 1",
        false
      )

      {:ok, view, _html} = live(conn, live_surveys_route(section_v1.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-short-answer-authoring})
        |> Floki.attribute("model")
        |> hd

      refute selected_activity_model =~ "This is an incorrect answer from student 1"

      ## section with analytics_version :v2
      set_activity_attempt(
        page_1,
        single_response_activity,
        student_1,
        section,
        project.id,
        publication.id,
        "This is an incorrect answer from student 1",
        false
      )

      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-short-answer-authoring})
        |> Floki.attribute("model")
        |> hd

      assert selected_activity_model =~ "This is an incorrect answer from student 1"
    end

    test "multiple choice frequency details get rendered for a section with analytics_version :v2 but not for :v1",
         %{
           conn: conn,
           section_v1: section_v1,
           section: section,
           page_1: page_1,
           student_1: student_1,
           mcq_activity_1: mcq_activity_1,
           project: project,
           publication: publication
         } do
      ## section with analytics_version :v1
      set_activity_attempt(
        page_1,
        mcq_activity_1,
        student_1,
        section_v1,
        project.id,
        publication.id,
        "id_for_option_a",
        true
      )

      {:ok, view, _html} = live(conn, live_surveys_route(section_v1.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("model")
        |> hd

      assert selected_activity_model =~ ~s{"id":"id_for_option_a"}
      refute selected_activity_model =~ ~s{"frequency":}

      ## section with analytics_version :v2
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

      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("model")
        |> hd

      assert selected_activity_model =~ ~s{"frequency":1,"id":"id_for_option_a"}
    end

    test "multi input details get not rendered for a section with analytics_version :v1",
         %{
           conn: conn,
           section_v1: section_v1,
           page_1: page_1,
           student_1: student_1,
           multi_input_activity: multi_input_activity,
           project: project,
           publication: publication
         } do
      ## section with analytics_version :v1
      set_activity_attempt(
        page_1,
        multi_input_activity,
        student_1,
        section_v1,
        project.id,
        publication.id,
        "Incorrect answer",
        false
      )

      {:ok, view, _html} = live(conn, live_surveys_route(section_v1.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multi-input-authoring})
        |> Floki.attribute("model")
        |> hd

      refute selected_activity_model =~ "Incorrect answer"
    end

    test "likert activity details get not rendered for a section with analytics_version :v1",
         %{
           conn: conn,
           section_v1: section_v1,
           page_1: page_1,
           student_1: student_1,
           likert_activity: likert_activity,
           project: project,
           publication: publication
         } do
      ## section with analytics_version :v1
      set_activity_attempt(
        page_1,
        likert_activity,
        student_1,
        section_v1,
        project.id,
        publication.id,
        "id_for_option_a",
        false
      )

      {:ok, view, _html} = live(conn, live_surveys_route(section_v1.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      # check that the likert VegaLite visualization is not rendered
      refute has_element?(
               view,
               ~s(div[data-live-react-class="Components.VegaLiteRenderer"])
             )
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

      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      assert element(
               view,
               "table tbody tr:nth-of-type(1)[class=\"table-active bg-delivery-primary-100\"]"
             )

      # and check that the question details have changed to match the selected activity
      selected_activity_model =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{oli-multiple-choice-authoring})
        |> Floki.attribute("model")
        |> hd

      assert selected_activity_model =~
               "{\"choices\":[{\"content\":[{\"children\":[{\"text\":\"Choice 1 for #{mcq_activity_1.id}\"}],\"id\":\"1866911747\",\"type\":\"p\"}],\"frequency\":1,\"id\":\"id_for_option_a\"},{\"content\":[{\"children\":[{\"text\":\"Choice 2 for #{mcq_activity_1.id}\"}],\"id\":\"3926142114\",\"type\":\"p\"}],\"frequency\":0,\"id\":\"id_for_option_b\"}]}"
    end

    test "student attempts summary gets rendered correctly when no students have attempted", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_surveys_route(section.slug, %{
            assessment_id: page_1.id
          })
        )

      view
      |> element("table tbody tr td div[phx-value-id=\"#{page_1.id}\"]")
      |> render_click()

      assert has_element?(view, "p", "No attempt registered for this question")
    end
  end

  describe "page size change" do
    setup [:instructor_conn, :create_project]

    test "lists table elements according to the default page size", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      [a0, a1, a2, a3, a4] = table_as_list_of_maps(view)

      assert a0.title == "Orphaned Page"
      assert a1.title == "Module 1: IntroductionPage 1"
      assert a2.title == "Module 1: IntroductionPage 2"
      assert a3.title == "Module 2: BasicsPage 3"
      assert a4.title == "Module 2: BasicsPage 4"

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    test "updates page size and list expected elements", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_surveys_route(section.slug))

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      [a0, a1] = table_as_list_of_maps(view)

      # Page 1
      assert a0.title == "Orphaned Page"
      assert a1.title == "Module 1: IntroductionPage 1"
    end

    test "keeps showing the same elements when changing the page size", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_surveys_route(section.slug, %{
            limit: 2,
            offset: 2
          })
        )

      [a2, a3] = table_as_list_of_maps(view)

      # Page 2
      assert a2.title == "Module 1: IntroductionPage 2"
      assert a3.title == "Module 2: BasicsPage 3"

      # Change page size from 2 to 1
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "1"})

      [a2] = table_as_list_of_maps(view)

      # Page 3. It keeps showing the same element.
      assert a2.title == "Module 1: IntroductionPage 2"
    end
  end
end
