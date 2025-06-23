defmodule OliWeb.Api.LtiAgsControllerTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.{ClientEvaluation}

  defp generate_lti_content() do
    %{
      "openInNewTab" => true,
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "scoringStrategy" => "best",
            "responses" => [],
            "hints" => []
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

  defp generate_mcq_content() do
    %{
      "stem" => %{
        "id" => "2028833010",
        "content" => [
          %{
            "id" => "280825708",
            "type" => "p",
            "children" => [%{"text" => "This is an mcq question"}]
          }
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

  defp setup_section(%{conn: conn}) do
    author = insert(:author)
    instructor = insert(:user, %{given_name: "Some", family_name: "Instructor"})
    project = insert(:project, authors: [author])

    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 1"
      )

    ## Activity registrations
    mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

    # Register LTI activity type
    lti_example_tool_reg =
      insert(:activity_registration, title: "LTI Tool", allow_client_evaluation: true)

    mcq_activity_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id
          ]
        },
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 1",
        content: generate_mcq_content()
      )

    lti_activity_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "1" => [
            objective_1_revision.resource_id
          ]
        },
        activity_type_id: lti_example_tool_reg.id,
        title: "Multiple Choice 2",
        content: generate_lti_content()
      )

    ## unscored page
    unscored_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Page",
        graded: false,
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
                      text: "This is an unscored page."
                    }
                  ]
                }
              ]
            },
            %{
              id: "3330767711",
              type: "activity-reference",
              children: [],
              activity_id: mcq_activity_revision.resource.id
            },
            %{
              id: "3330767712",
              type: "activity-reference",
              children: [],
              activity_id: lti_activity_revision.resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    ## scored page (assessments)
    scored_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Scored Page",
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
                      text: "This is a scored page."
                    }
                  ]
                }
              ]
            },
            %{
              id: "3330767711",
              type: "activity-reference",
              children: [],
              activity_id: mcq_activity_revision.resource.id
            },
            %{
              id: "3330767712",
              type: "activity-reference",
              children: [],
              activity_id: lti_activity_revision.resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        }
      )

    ## root container...
    curriculum_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          unscored_page_revision.resource_id,
          scored_page_revision.resource_id
        ],
        content: %{},
        deleted: false,
        title: "Curriculum"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: mcq_activity_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: lti_activity_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unscored_page_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: scored_page_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: curriculum_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: curriculum_revision.resource_id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_1_revision.resource,
      revision: objective_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: mcq_activity_revision.resource,
      revision: mcq_activity_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: lti_activity_revision.resource,
      revision: lti_activity_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unscored_page_revision.resource,
      revision: unscored_page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: scored_page_revision.resource,
      revision: scored_page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: curriculum_revision.resource,
      revision: curriculum_revision,
      author: author
    })

    # create section
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
    student_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
    student_2 = insert(:user, %{given_name: "Angel", family_name: "Di Maria"})

    Sections.enroll(student_1.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_2.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(instructor.id, section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    %{
      conn: conn,
      project: project,
      publication: publication,
      section: section,
      mcq_activity: mcq_activity_revision,
      lti_activity: lti_activity_revision,
      unscored_page: unscored_page_revision,
      unscored_page_objectives: objective_1_revision,
      scored_page: scored_page_revision,
      scored_page_objective: objective_1_revision,
      student_1: student_1,
      student_2: student_2,
      instructor: instructor
    }
  end

  defp setup_token(%{conn: conn}) do
    scopes = [
      "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
      "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
      "https://purl.imsglobal.org/spec/lti-ags/scope/result.score"
    ]

    {:ok, token, _expires_in} =
      Oli.Lti.Tokens.issue_access_token("valid-lti-ags-test-client", scopes)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)

    {:ok, conn: conn}
  end

  defp setup_activity_attempt(section, page, user, activity_revision, out_of) do
    resource_access =
      Oli.Delivery.Attempts.Core.track_access(
        page.resource_id,
        section.id,
        user.id
      )

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access_id: resource_access.id,
        resource_access: resource_access,
        revision_id: page.id,
        revision: page,
        attempt_guid: UUID.uuid4(),
        content: page.content
      })

    activity_attempt =
      insert(:activity_attempt, %{
        resource_attempt_id: resource_attempt.id,
        resource_attempt: resource_attempt,
        revision_id: activity_revision.id,
        revision: activity_revision,
        resource_id: activity_revision.resource_id,
        resource: activity_revision.resource,
        attempt_guid: UUID.uuid4(),
        out_of: out_of
      })

    part_attempt =
      insert(:part_attempt, %{
        activity_attempt_id: activity_attempt.id,
        activity_attempt: activity_attempt,
        attempt_guid: UUID.uuid4(),
        part_id: "1"
      })

    {resource_attempt, activity_attempt, part_attempt}
  end

  defp apply_score(
         section_slug,
         activity_attempt_guid,
         part_attempt_guid,
         score,
         out_of,
         datashop_id
       ) do
    Evaluate.apply_client_evaluation(
      section_slug,
      activity_attempt_guid,
      [
        %{
          attempt_guid: part_attempt_guid,
          client_evaluation: %ClientEvaluation{
            score: score,
            out_of: out_of
          }
        }
      ],
      datashop_id
    )
  end

  describe "validate token" do
    @tag capture_log: true
    test "returns 401 Unauthorized when no token is provided", %{conn: conn} do
      conn = get(conn, ~p"/lti/lineitems/some-attempt-guid/results", user_id: "user-1")
      assert response(conn, 401) =~ "Unauthorized"
    end

    @tag capture_log: true
    test "returns 401 Unauthorized when token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")

      conn = get(conn, ~p"/lti/lineitems/some-attempt-guid/results", user_id: "user-1")

      assert response(conn, 401) =~ "Unauthorized"
    end
  end

  describe "get_result/2" do
    setup [:setup_section, :setup_token]

    test "returns result JSON when activity attempt and part attempt exist", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      apply_score(
        section.slug,
        activity_attempt.attempt_guid,
        part_attempt.attempt_guid,
        1.0,
        2.0,
        UUID.uuid4()
      )

      conn =
        get(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/results",
          user_id: student_1.id
        )

      assert response = json_response(conn, 200)

      score = response |> hd()

      assert score["id"] ==
               "https://localhost/lineitems/#{activity_attempt.attempt_guid}/results/#{student_1.id}"

      assert score["resultMaximum"] == 2.0
      assert score["resultScore"] == 1.0
      assert score["scoreOf"] == "https://localhost/lineitems/#{activity_attempt.attempt_guid}"
      assert score["userId"] == "#{student_1.id}"
      assert score["timestamp"] != nil
    end

    test "returns result JSON and nil resultScore when an attempt has not been submitted", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      conn =
        get(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/results",
          user_id: student_1.id
        )

      assert json_response(conn, 200) == [
               %{
                 "id" =>
                   "https://localhost/lineitems/#{activity_attempt.attempt_guid}/results/#{student_1.id}",
                 "resultMaximum" => nil,
                 "resultScore" => nil,
                 "scoreOf" => "https://localhost/lineitems/#{activity_attempt.attempt_guid}",
                 "userId" => "#{student_1.id}",
                 "timestamp" => nil
               }
             ]
    end

    @tag capture_log: true
    test "returns error when activity attempt not found", %{conn: conn, student_1: student_1} do
      conn = get(conn, ~p"/lti/lineitems/some-attempt-guid/results", user_id: student_1.id)

      assert response(conn, 400) =~ "Error fetching result"
    end

    test "returns error when user_id param is missing", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      conn = get(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/results")

      assert response(conn, 400) =~ "Invalid request. 'user_id' parameter is required."
    end
  end

  describe "post_score/2" do
    setup [:setup_section, :setup_token]

    @tag :skip
    test "applies score and returns 204 for valid score payload", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 8,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)
    end

    test "resets unscored activity and returns 204 for NotReady/Initialized", %{
      conn: conn,
      section: section,
      student_1: student_1,
      unscored_page: unscored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, part_attempt} =
        setup_activity_attempt(section, unscored_page, student_1, lti_activity, 2.0)

      assert part_attempt.score == nil
      assert part_attempt.out_of == nil

      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 8,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)

      updated_part_attempt =
        Oli.Delivery.Attempts.Core.get_part_attempt_by(attempt_guid: part_attempt.attempt_guid)

      assert updated_part_attempt.score == 8
      assert updated_part_attempt.out_of == 10

      # Reset the activity attempt
      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "gradingProgress" => "NotReady",
        "activityProgress" => "Initialized"
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)

      updated_part_attempt =
        Oli.Delivery.Attempts.Core.get_part_attempt_by(attempt_guid: part_attempt.attempt_guid)

      assert updated_part_attempt.score == nil
      assert updated_part_attempt.out_of == nil
    end

    @tag capture_log: true
    test "returns an error when trying to update or reset a scored activity that is not active",
         %{
           conn: conn,
           section: section,
           student_1: student_1,
           scored_page: scored_page,
           lti_activity: lti_activity
         } do
      {resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      params =
        %{
          "activity_attempt_guid" => activity_attempt.attempt_guid,
          "userId" => student_1.sub,
          "scoreGiven" => 8,
          "scoreMaximum" => 10,
          "gradingProgress" => "FullyGraded",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)

      # Finalize the score page
      datashop_session_id = UUID.uuid4()

      {:ok, _} =
        Oli.Delivery.Attempts.PageLifecycle.finalize(
          section.slug,
          resource_attempt.attempt_guid,
          datashop_session_id
        )

      # Attempt to apply a score again after finalization
      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 10,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => DateTime.utc_now() |> DateTime.add(1, :second) |> DateTime.to_iso8601()
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 400) =~
               "Error processing score. Activity attempt is not active. Cannot update score"

      # Attempt to reset the activity attempt
      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "gradingProgress" => "NotReady",
        "activityProgress" => "Initialized"
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 400) =~
               "Error resetting score. Activity attempt is not active. Cannot reset score"
    end

    @tag capture_log: true
    test "returns error for invalid gradingProgress", %{conn: conn} do
      params = %{
        "activity_attempt_guid" => "attempt-guid",
        "userId" => "user-1",
        "scoreGiven" => 8,
        "scoreMaximum" => 10,
        "gradingProgress" => "NotGraded",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        post(conn, ~p"/lti/lineitems/attempt-guid/scores", params)

      assert response(conn, 400) =~
               "Error processing score. Invalid score payload. \"gradingProgress\" must be \"FullyGraded\""
    end

    @tag capture_log: true
    test "rejects a score POST with the same timestamp", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 8,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)

      # Attempt to apply the same score again
      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 400) =~
               "Error processing score. Timestamp must be later than the current date_submitted"
    end

    test "accepts a score POST with a later timestamp", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      now = DateTime.utc_now()
      timestamp = now |> DateTime.to_iso8601()

      later_timestamp =
        now |> DateTime.add(2, :second) |> DateTime.to_iso8601()

      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 8,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => timestamp
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)

      # Apply another score with a later timestamp
      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 10,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => later_timestamp
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)
    end

    @tag capture_log: true
    test "ignores a score POST with an earlier timestamp", %{
      conn: conn,
      section: section,
      student_1: student_1,
      scored_page: scored_page,
      lti_activity: lti_activity
    } do
      {_resource_attempt, activity_attempt, _part_attempt} =
        setup_activity_attempt(section, scored_page, student_1, lti_activity, 2.0)

      now = DateTime.utc_now()
      timestamp = now |> DateTime.to_iso8601()

      ealier_timestamp =
        now |> DateTime.add(-2, :second) |> DateTime.to_iso8601()

      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 8,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => timestamp
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 204)

      # Apply another score with a later timestamp
      params = %{
        "activity_attempt_guid" => activity_attempt.attempt_guid,
        "userId" => student_1.sub,
        "scoreGiven" => 10,
        "scoreMaximum" => 10,
        "gradingProgress" => "FullyGraded",
        "timestamp" => ealier_timestamp
      }

      conn =
        post(conn, ~p"/lti/lineitems/#{activity_attempt.attempt_guid}/scores", params)

      assert response(conn, 400) =~
               "Error processing score. Timestamp must be later than the current date_submitted"
    end
  end
end
