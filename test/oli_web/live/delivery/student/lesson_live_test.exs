defmodule OliWeb.Delivery.Student.LessonLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase
  use Oban.Testing, repo: Oli.Repo

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false
  import Oli.TestHelpers

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.Student.Utils

  @default_selected_view :gallery

  defp live_view_adaptive_lesson_live_route(section_slug, revision_slug, request_path \\ nil)

  defp live_view_adaptive_lesson_live_route(section_slug, revision_slug, nil) do
    ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}"
  end

  defp live_view_adaptive_lesson_live_route(section_slug, revision_slug, request_path) do
    ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}?request_path=#{request_path}"
  end

  defp create_attempt(student, section, revision, resource_attempt_data) do
    resource_access = get_or_insert_resource_access(student, section, revision)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: revision,
        date_submitted: resource_attempt_data[:date_submitted] || ~U[2023-11-14 20:00:00Z],
        date_evaluated: resource_attempt_data[:date_evaluated] || ~U[2023-11-14 20:30:00Z],
        score: resource_attempt_data[:score] || 5,
        out_of: resource_attempt_data[:out_of] || 10,
        lifecycle_state: resource_attempt_data[:lifecycle_state] || :submitted,
        content: resource_attempt_data[:content] || %{model: []},
        inserted_at: resource_attempt_data[:inserted_at] || DateTime.utc_now()
      })

    resource_attempt
  end

  defp get_or_insert_resource_access(student, section, revision) do
    Oli.Repo.get_by(
      ResourceAccess,
      resource_id: revision.resource_id,
      section_id: section.id,
      user_id: student.id
    )
    |> case do
      nil ->
        insert(:resource_access, %{
          user: student,
          section: section,
          resource: revision.resource
        })

      resource_access ->
        resource_access
    end
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## objectives...
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "this is the first objective"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "this is the second objective"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "this is the third objective"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "this is the forth objective"
      )

    # bibentries...

    bibentry_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("bibentry"),
        title: "Physics, Gravity & the Laws of Motion",
        content: %{
          data: [
            %{
              author: [%{family: "Newton", given: "Isaac"}],
              id: "temp_id_3295638416",
              issued: %{"date-parts": [[1643, 1, 4]]},
              publisher: "Isaac Newton",
              shortTitle: "Gravity",
              title: "Physics, Gravity & the Laws of Motion",
              type: "webpage",
              version: "1"
            }
          ]
        }
      )

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10,
        content: %{
          model: [
            %{
              id: "158828742",
              type: "content",
              children: [
                %{
                  id: "3371710400",
                  type: "p",
                  children: [%{text: "Here's some practice page content"}]
                }
              ]
            }
          ],
          bibrefs: [bibentry_1_revision.resource_id]
        }
      )

    exploration_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Exploration 1",
        purpose: :application,
        content: %{
          "model" => [],
          "advancedDelivery" => true,
          "displayApplicationChrome" => false,
          "additionalStylesheets" => [
            "/css/delivery_adaptive_themes_default_light.css"
          ]
        }
      )

    graded_adaptive_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        graded: true,
        max_attempts: 5,
        title: "Graded Adaptive Page",
        purpose: :foundation,
        content: %{
          "model" => [],
          "advancedDelivery" => true,
          "displayApplicationChrome" => false,
          "additionalStylesheets" => [
            "/css/delivery_adaptive_themes_default_light.css"
          ]
        }
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        duration_minutes: 15,
        objectives: %{
          "attached" => [
            objective_1_revision.resource_id,
            objective_2_revision.resource_id,
            objective_3_revision.resource_id,
            objective_4_revision.resource_id
          ]
        }
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3",
        graded: true,
        max_attempts: 5,
        content: %{
          model: [
            %{
              id: "158828742",
              type: "content",
              children: [
                %{
                  id: "3371710400",
                  type: "p",
                  children: [%{text: "Here's some graded page content"}]
                }
              ]
            }
          ],
          bibrefs: [bibentry_1_revision.resource_id]
        }
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        duration_minutes: 5,
        graded: true,
        max_attempts: 5,
        content: %{
          model: []
        }
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 5",
        duration_minutes: 5,
        graded: true,
        max_attempts: 5,
        content: %{
          model: []
        }
      )

    page_6_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 6",
        duration_minutes: 5,
        max_attempts: 5,
        content: %{
          model: []
        }
      )

    ## activities...
    mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

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

    one_at_a_time_question_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "This is a page configured to show one question at a time",
        duration_minutes: 5,
        graded: true,
        max_attempts: 5,
        assessment_mode: :one_at_a_time,
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

    empty_one_at_a_time_question_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "This is a page configured to show one question at a time with no questions",
        duration_minutes: 5,
        graded: true,
        max_attempts: 5,
        content: %{
          model: []
        }
      )

    ## sections and subsections...
    subsection_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          page_4_revision.resource_id
        ],
        title: "Erlang as a motivation"
      })

    section_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          subsection_1_revision.resource_id,
          page_5_revision.resource_id,
          page_6_revision.resource_id
        ],
        title: "Why Elixir?"
      })

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
                  text: "Throughout this unit you will learn how to use this course."
                }
              ]
            }
          ]
        }
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [section_1_revision.resource_id, page_3_revision.resource_id],
        title: "The second module is awesome!",
        poster_image: "module_2_custom_image_url",
        intro_content: %{
          children: [
            %{
              type: "p",
              children: [
                %{
                  text: "Thoughout this unit you will have a lot of fun."
                }
              ]
            }
          ]
        }
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id, module_2_revision.resource_id],
        title: "Introduction",
        poster_image: "some_image_url",
        intro_video: "some_video_url"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [exploration_1_revision.resource_id, graded_adaptive_page_revision.resource_id],
        title: "What did you learn?"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id,
          one_at_a_time_question_page_revision.resource_id,
          empty_one_at_a_time_question_page_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        bibentry_1_revision,
        objective_1_revision,
        objective_2_revision,
        objective_3_revision,
        objective_4_revision,
        page_1_revision,
        exploration_1_revision,
        graded_adaptive_page_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        page_6_revision,
        mcq_activity_1_revision,
        one_at_a_time_question_page_revision,
        empty_one_at_a_time_question_page_revision,
        subsection_1_revision,
        section_1_revision,
        module_1_revision,
        module_2_revision,
        unit_1_revision,
        unit_2_revision,
        container_revision
      ]

    # associate resources to project
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
        analytics_version: :v2,
        assistant_enabled: true
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # schedule start and end date for unit 1 section resource
    Sections.get_section_resource(section.id, unit_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-10-31 20:00:00Z],
      end_date: ~U[2023-12-31 20:00:00Z]
    })

    # schedule start and end date for page 2 section resource
    Sections.get_section_resource(section.id, page_2_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-10 20:00:00Z],
      end_date: ~U[2023-11-14 20:00:00Z]
    })

    # configure page as one at a time
    Sections.get_section_resource(section.id, one_at_a_time_question_page_revision.resource_id)
    |> Sections.update_section_resource(%{
      assessment_mode: :one_at_a_time
    })

    Sections.get_section_resource(
      section.id,
      empty_one_at_a_time_question_page_revision.resource_id
    )
    |> Sections.update_section_resource(%{
      assessment_mode: :one_at_a_time
    })

    # enable collaboration spaces for all pages in the section
    {_total_page_count, _section_resources} =
      Oli.Resources.Collaboration.enable_all_page_collab_spaces_for_section(
        section.slug,
        %Oli.Resources.Collaboration.CollabSpaceConfig{
          status: :enabled,
          threaded: true,
          auto_accept: true,
          show_full_history: true,
          anonymous_posting: true,
          participation_min_replies: 0,
          participation_min_posts: 0
        }
      )

    %{
      section: section,
      project: project,
      publication: publication,
      bibentry_1: bibentry_1_revision,
      objective_1: objective_1_revision,
      objective_2: objective_2_revision,
      objective_3: objective_3_revision,
      objective_4: objective_4_revision,
      page_1: page_1_revision,
      exploration_1: exploration_1_revision,
      graded_adaptive_page_revision: graded_adaptive_page_revision,
      mcq_activity_1: mcq_activity_1_revision,
      one_at_a_time_question_page: one_at_a_time_question_page_revision,
      empty_one_at_a_time_question_page: empty_one_at_a_time_question_page_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_5_revision,
      page_6: page_6_revision,
      section_1: section_1_revision,
      subsection_1: subsection_1_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision
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

  describe "user" do
    setup [:create_elixir_project]

    test "can not access page when it is not logged in", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      assert redirect_path ==
               "/users/log_in"
    end
  end

  defp verify_access_as(conn, system_role_id, section, page) do
    # Create a new authoring account and make it an admin
    author = insert(:author)

    {:ok, updated_author} = Oli.Accounts.update_author(author, %{system_role_id: system_role_id})

    conn = log_in_author(conn, updated_author)

    {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page.slug))

    ensure_content_is_visible(view)

    assert has_element?(view, "span", "The best course ever!")
  end

  describe "authors" do
    setup [:setup_tags, :create_elixir_project]

    test "can access via hidden instructor when content admin", %{
      conn: conn,
      section: section,
      page_1: page
    } do
      verify_access_as(conn, Oli.Accounts.SystemRole.role_id().content_admin, section, page)
    end

    test "can access via hidden instructor when account admin", %{
      conn: conn,
      section: section,
      page_1: page
    } do
      verify_access_as(conn, Oli.Accounts.SystemRole.role_id().account_admin, section, page)
    end

    test "can access via hidden instructor when system admin", %{
      conn: conn,
      section: section,
      page_1: page
    } do
      verify_access_as(conn, Oli.Accounts.SystemRole.role_id().system_admin, section, page)
    end

    test "cannot access when regular author", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      author = insert(:author)
      conn = log_in_author(conn, author)

      {:error,
       {:redirect,
        %{to: "/users/log_in", flash: %{"error" => "You must log in to access this page."}}}} =
        live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
    end
  end

  describe "student" do
    setup [:setup_tags, :user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      assert redirect_path == "/sections/#{section.slug}/enroll"
    end

    test "does not show the blocking gates warning when the practice page is not gated", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      refute has_element?(view, "div[id='blocking_gates_warning']")
      assert has_element?(view, "div[role='page content']")
    end

    test "does not show the blocking gates warning when the practice page is gated but gating condition is not yet met",
         %{
           conn: conn,
           section: section,
           user: user,
           page_1: page_1
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page_1.resource_id,
          data: %{start_datetime: yesterday(), end_datetime: tomorrow()}
        })

      {:ok, section} = Oli.Delivery.Gating.update_resource_gating_index(section)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      refute has_element?(view, "div[id='blocking_gates_warning']")
      assert has_element?(view, "div[role='page content']")
    end

    test "shows the blocking gates warning when the practice page is gated and the gating condition is met",
         %{
           conn: conn,
           section: section,
           user: user,
           page_1: page_1
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page_1.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Oli.Delivery.Gating.update_resource_gating_index(section)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, "div[id='blocking_gates_warning']")
      refute has_element?(view, "div[role='page content']")
    end

    test "does not show the blocking gates warning when the graded page is not gated", %{
      conn: conn,
      section: section,
      user: user,
      page_3: page_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)

      refute has_element?(view, "div[id='blocking_gates_warning']")
      assert has_element?(view, "div[role='page content']")
    end

    test "does not show the blocking gates warning when the graded page is gated but gating condition is not yet met",
         %{
           conn: conn,
           section: section,
           user: user,
           page_3: page_3
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page_3.resource_id,
          data: %{start_datetime: yesterday(), end_datetime: tomorrow()}
        })

      {:ok, section} = Oli.Delivery.Gating.update_resource_gating_index(section)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)

      refute has_element?(view, "div[id='blocking_gates_warning']")
      assert has_element?(view, "div[role='page content']")
    end

    test "shows the blocking gates warning when the graded page is gated and the gating condition is met",
         %{
           conn: conn,
           section: section,
           user: user,
           page_3: page_3
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: page_3.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Oli.Delivery.Gating.update_resource_gating_index(section)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, "div[id='blocking_gates_warning']")
      refute has_element?(view, "div[role='page content']")
    end

    test "redirects when page is adaptive", %{
      conn: conn,
      user: user,
      section: section,
      exploration_1: exploration_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:error, {:redirect, %{to: redirect_path}}} =
        live(
          conn,
          Utils.lesson_live_path(section.slug, exploration_1.slug,
            request_path: "some_request_path",
            selected_view: @default_selected_view
          )
        )

      # adaptive pages should not have query params in the url (MER-3708)
      assert redirect_path ==
               live_view_adaptive_lesson_live_route(section.slug, exploration_1.slug)
    end

    test "can see default logo", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.update_section(section, %{brand_id: nil})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      ensure_content_is_visible(view)

      assert element(view, "#header_logo_button") |> render() =~ "/images/oli_torus_logo.png"
    end

    test "can see brand logo", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)
      assert element(view, "#header_logo_button") |> render() =~ "www.logo.com"
    end

    test "see default brand logo if the section is not open and free", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      {:ok, section} =
        Sections.update_section(section, %{open_and_free: false, lti_1p3_deployment_id: nil})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      # assert that the section has a brand
      assert is_struct(section.brand, Oli.Branding.Brand)

      # assert that the default logo is shown because the section is not open and free even if the brand is set
      assert element(view, "#header_logo_button") |> render() =~ "/images/oli_torus_logo.png"
    end

    test "can access when enrolled to course", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2,
      module_1: module_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      ensure_content_is_visible(view)

      assert has_element?(view, "span", "The best course ever!")

      assert has_element?(
               view,
               ~s{div[role="prev_page"]},
               module_1.title
             )

      assert has_element?(
               view,
               ~s{div[role="next_page"]},
               page_2.title
             )
    end

    test "renders paywall message when grace period is not over (or gets redirected when over)",
         %{
           conn: conn,
           user: user,
           section: section,
           page_1: page_1
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

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

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(product.slug, page_1.slug))
      ensure_content_is_visible(view)

      assert has_element?(
               view,
               "div[id=pay_early_message]",
               "You have 18 days left of your grace period for accessing this course"
             )

      # Grace period is over
      stub_current_time(~U[2024-11-13 20:00:00Z])

      redirect_path = "/sections/#{product.slug}/payment"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, Utils.lesson_live_path(product.slug, page_1.slug))
    end

    test "can see practice page content", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)
      assert has_element?(view, "div[role='page content'] p", "Here's some practice page content")

      # Support link is visible
      assert has_element?(view, "#tech-support", "Support")
    end

    @tag isolation: "serializable"
    test "timer will not be shown on practice pages", %{
      conn: conn,
      user: user,
      section: section,
      page_1: ungraded_page
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} =
        live(conn, "/sections/#{section.slug}/lesson/#{ungraded_page.slug}")

      ensure_content_is_visible(view)

      assert render(view) =~ ungraded_page.title
      refute render(view) =~ "<div id=\"countdown_timer_display\""
    end

    test "can not see `reset answers` button on practice pages without activities", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      refute has_element?(view, "button[id='reset_answers']", "Reset Answers")
    end

    test "can see practice page references", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      assert has_element?(
               view,
               "div[data-live-react-class='Components.References']"
             )
    end

    test "can see graded page references", %{
      conn: conn,
      user: user,
      section: section,
      page_3: page_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))

      ensure_content_is_visible(view)

      assert has_element?(
               view,
               "div[data-live-react-class='Components.References']"
             )

      # Support link is visible
      assert has_element?(view, "#tech-support", "Support")
    end

    test "does not see prologue but graded page when an attempt is in progress", %{
      conn: conn,
      user: user,
      section: section,
      page_3: page_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)
      refute has_element?(view, "div[id='attempts_summary_with_tooltip']", "Attempts 0/5")
      refute has_element?(view, "button[id='begin_attempt_button']", "Begin 1st Attempt")
      assert has_element?(view, "div[role='page content']")
      assert has_element?(view, "button[id=submit_answers]", "Submit Answers")
    end

    test "triggers CheckCertification job if certificate_enabled is true on submit", ctx do
      %{conn: conn, user: user, section: section, page_3: page_3} = ctx
      {:ok, section} = Sections.update_section(section, %{certificate_enabled: true})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)
      refute has_element?(view, "div[id='attempts_summary_with_tooltip']", "Attempts 0/5")
      refute has_element?(view, "button[id='begin_attempt_button']", "Begin 1st Attempt")
      assert has_element?(view, "div[role='page content']")
      assert has_element?(view, "button[id=submit_answers]", "Submit Answers")

      view
      |> element("button[id=submit_answers]", "Submit Answers")
      |> render_hook("finalize_attempt")

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "skips CheckCertification job if certificate_enabled is off on submit",
         ctx do
      %{conn: conn, user: user, section: section, page_3: page_3} = ctx
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)
      refute has_element?(view, "div[id='attempts_summary_with_tooltip']", "Attempts 0/5")
      refute has_element?(view, "button[id='begin_attempt_button']", "Begin 1st Attempt")
      assert has_element?(view, "div[role='page content']")
      assert has_element?(view, "button[id=submit_answers]", "Submit Answers")

      view
      |> element("button[id=submit_answers]", "Submit Answers")
      |> render_hook("finalize_attempt")

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "does not see prologue but adaptive page when an attempt is in progress", %{
      conn: conn,
      user: user,
      section: section,
      exploration_1: exploration_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, exploration_1, %{lifecycle_state: :active})

      conn =
        get(
          conn,
          live_view_adaptive_lesson_live_route(
            section.slug,
            exploration_1.slug
          )
        )

      assert html_response(conn, 200) =~ ~s{<div id=\"delivery_container\">}
      # It loads the adaptive themes
      assert html_response(conn, 200) =~ "/css/delivery_adaptive_themes_default_light.css"

      # Support link is not visible on adaptive pages
      refute html_response(conn, 200) =~ "Support"
    end

    test "back button of an adaptive page (NOT an exploration one) points to the provided url param 'request_path'",
         %{
           conn: conn,
           user: user,
           section: section,
           graded_adaptive_page_revision: graded_adaptive_page_revision
         } do
      # the goal is to set the back button of the adaptive page to point to the provided request_path
      # (that will match the page from where the user accesed the adaptive page)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # we need an active attempt to avoid being redirected to the prologue view
      create_attempt(user, section, graded_adaptive_page_revision, %{lifecycle_state: :active})

      request_path = "some_request_path"

      conn =
        conn
        |> init_test_session(%{request_path: request_path})
        |> get(
          live_view_adaptive_lesson_live_route(
            section.slug,
            graded_adaptive_page_revision.slug,
            request_path
          )
        )

      assert conn.resp_body
             |> Floki.parse_fragment!()
             |> Floki.find(~s{div[data-react-class="Components.Delivery"]})
             |> Floki.attribute("data-react-props")
             |> Jason.decode!()
             |> Map.get("content")
             |> Map.get("backUrl") ==
               "some_request_path"
    end

    test "back button of an adaptive page (an exploration one) points to the provided url param 'request_path'",
         %{
           conn: conn,
           user: user,
           section: section,
           exploration_1: exploration_1
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # we need an active attempt to avoid being redirected to the prologue view
      create_attempt(user, section, exploration_1, %{lifecycle_state: :active})

      request_path = "some_other_request_path"

      conn =
        conn
        |> init_test_session(%{request_path: request_path})
        |> get(
          live_view_adaptive_lesson_live_route(
            section.slug,
            exploration_1.slug,
            request_path
          )
        )

      assert conn.resp_body
             |> Floki.parse_fragment!()
             |> Floki.find(~s{div[data-react-class="Components.Delivery"]})
             |> Floki.attribute("data-react-props")
             |> Jason.decode!()
             |> Map.get("content")
             |> Map.get("backUrl") ==
               "some_other_request_path"
    end

    test "adaptive page does not have a backUrl key in it's content if no request_path is provided",
         %{
           conn: conn,
           user: user,
           section: section,
           exploration_1: exploration_1
         } do
      # if the react Component.Delivery does not recieve a backUrl key, then
      # the back button will point to the root path of the section
      # this logic is handled within the react component, so we can not test it here.
      # (we can only test that the backUrl key is not present in the content)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # we need an active attempt to avoid being redirected to the prologue view
      create_attempt(user, section, exploration_1, %{lifecycle_state: :active})

      request_path = nil

      conn =
        get(
          conn,
          live_view_adaptive_lesson_live_route(
            section.slug,
            exploration_1.slug,
            request_path
          )
        )

      refute conn.resp_body
             |> Floki.parse_fragment!()
             |> Floki.find(~s{div[data-react-class="Components.Delivery"]})
             |> Floki.attribute("data-react-props")
             |> Jason.decode!()
             |> Map.get("content")
             |> Map.get("backUrl")
    end

    test "can see page info on header", %{
      conn: conn,
      user: user,
      section: section,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_2.slug))
      ensure_content_is_visible(view)
      assert has_element?(view, ~s{div[role="container label"]}, "Module 1")
      assert has_element?(view, ~s{div[role="page numbering index"]}, "2.")
      assert has_element?(view, ~s{div[role="page title"]}, "Page 2")
      assert has_element?(view, ~s{div[role="page read time"]}, "15")
      assert has_element?(view, ~s{div[role="page schedule"]}, "Read by:")
      assert has_element?(view, ~s{div[role="page schedule"]}, "Tue Nov 14, 2023")
      assert has_element?(view, ~s{div[role="page start schedule"]}, "Available by:")
      assert has_element?(view, ~s{div[role="page start schedule"]}, "Fri Nov 10, 2023")
    end

    test "can not see page duration time when it is not set", %{
      conn: conn,
      user: user,
      section: section,
      page_3: page_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))

      refute has_element?(view, ~s{div[role="page read time"]})
    end

    test "can see proficiency explanation modal", %{
      conn: conn,
      user: user,
      section: section,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_2.slug))

      ensure_content_is_visible(view)

      # if we render_click() on PROFICIENCY to show the modal, a JS command should be triggered.
      # But, since the phx-click does not have any push command, we get "no push command found within JS commands".
      # The workaround is to directly assert on the content of the modal

      assert has_element?(
               view,
               "#proficiency_explanation_modal h1",
               "Measuring Learning Proficiency"
             )

      assert has_element?(
               view,
               "#proficiency_explanation_modal p",
               "This course contains several learning objectives. As you continue the course, you will receive an estimate of your understanding of each objective. This estimate takes into account the activities you complete on each page."
             )
    end

    test "can see learning objectives and proficiency on page header", %{
      conn: conn,
      user: user,
      section: section,
      page_2: page_2,
      objective_1: objective_1,
      objective_2: objective_2,
      objective_3: objective_3,
      objective_4: objective_4
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      o1 = objective_1.resource_id
      o2 = objective_2.resource_id
      o3 = objective_3.resource_id
      o4 = objective_4.resource_id

      objective_type_id = Oli.Resources.ResourceType.id_for_objective()

      [
        # objective records
        [-1, -1, section.id, user.id, o1, nil, objective_type_id, 2, 6, 1, 4, 1],
        [-1, -1, section.id, user.id, o2, nil, objective_type_id, 2, 6, 1, 4, 3],
        [-1, -1, section.id, user.id, o3, nil, objective_type_id, 2, 6, 1, 4, 4]
      ]
      |> Enum.each(&add_resource_summary(&1))

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_2.slug))
      ensure_content_is_visible(view)

      assert has_element?(
               view,
               ~s{div[role="objective #{o1} title"]},
               "this is the first objective"
             )

      assert has_element?(
               view,
               ~s{div[role="objective #{o1}"] svg[role="beginning proficiency icon"]}
             )

      assert has_element?(view, ~s{div[id="objective_#{o1}_tooltip"]}, "Beginning Proficiency")

      assert has_element?(
               view,
               ~s{div[role="objective #{o2} title"]},
               "this is the second objective"
             )

      assert has_element?(
               view,
               ~s{div[role="objective #{o2}"] svg[role="growing proficiency icon"]}
             )

      assert has_element?(view, ~s{div[id="objective_#{o2}_tooltip"]}, "Growing Proficiency")

      assert has_element?(
               view,
               ~s{div[role="objective #{o3} title"]},
               "this is the third objective"
             )

      assert has_element?(
               view,
               ~s{div[role="objective #{o3}"] svg[role="establishing proficiency icon"]}
             )

      assert has_element?(view, ~s{div[id="objective_#{o3}_tooltip"]}, "Establishing Proficiency")

      assert has_element?(
               view,
               ~s{div[role="objective #{o4} title"]},
               "this is the forth objective"
             )

      assert has_element?(
               view,
               ~s{div[role="objective #{o4}"] svg[role="no data proficiency icon"]}
             )

      assert has_element?(view, ~s{div[id="objective_#{o4}_tooltip"]}, "Not enough information")
    end

    test "can navigate between pages and updates references in the request path", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      # It redirects to the next page, but still referencing the targeted Learn view in the URL with the next page resource
      request_path =
        Utils.learn_live_path(section.slug,
          target_resource_id: page_2.resource_id,
          selected_view: @default_selected_view
        )

      assert_redirected(
        view,
        Utils.lesson_live_path(section.slug, page_2.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "can navigate between pages and keeps the request path when it is not the learn view", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # when the request path is not the learn view, it keeps it when navigating between pages
      request_path = ~p"/sections/#{section.slug}/student_schedule"

      {:ok, view, _html} =
        live(
          conn,
          Utils.lesson_live_path(section.slug, page_1.slug,
            request_path: request_path,
            selected_view: @default_selected_view
          )
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.lesson_live_path(section.slug, page_2.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "redirects to the learn page when the next or previous page corresponds to a module",
         %{
           conn: conn,
           user: user,
           section: section,
           page_1: page_1,
           page_2: page_2,
           module_1: module_1,
           module_2: module_2
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # next page is a container
      {:ok, view, _html} =
        live(
          conn,
          Utils.lesson_live_path(section.slug, page_2.slug, selected_view: @default_selected_view)
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.learn_live_path(section.slug,
          target_resource_id: module_2.resource_id,
          selected_view: @default_selected_view
        )
      )

      # previous page is a container
      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="prev_page"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.learn_live_path(section.slug,
          target_resource_id: module_1.resource_id,
          selected_view: @default_selected_view
        )
      )
    end

    test "back link returns to the learn view when visited directly", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_1, %{lifecycle_state: :active})

      {:ok, view, _html} =
        live(
          conn,
          Utils.lesson_live_path(section.slug, page_1.slug, selected_view: @default_selected_view)
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.learn_live_path(section.slug, selected_view: @default_selected_view)
      )
    end

    test "back link returns to the learn view when visited from there", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      request_path = Utils.learn_live_path(section.slug, target_resource_id: page_1.resource_id)

      {:ok, view, _html} =
        live(conn, Utils.lesson_live_path(section.slug, page_1.slug, request_path: request_path))

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click

      assert_redirected(
        view,
        request_path
      )
    end

    test "can see DOT AI Bot interface if it's on a non scored page", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, "div[id='dialogue-window']")
      assert has_element?(view, "div[id=ai_bot_collapsed]")
    end

    test "can not see DOT AI Bot interface if it's on a scored page", %{
      conn: conn,
      user: user,
      section: section,
      page_3: page_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)

      refute has_element?(view, "div[id='dialogue-window']")
      refute has_element?(view, "div[id=ai_bot_collapsed]")
    end

    test "show check icon when page is not graded and is completed", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      set_progress(section.id, page_2.resource_id, user.id, 1.0, page_2)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, ~s{div[role="next_page"]}, page_2.title)

      assert has_element?(view, ~s{div[role="check icon"]})
    end

    test "show square checked icon when page is graded and is completed", %{
      conn: conn,
      user: user,
      section: section,
      page_5: page_5,
      page_6: page_6
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      set_progress(section.id, page_5.resource_id, user.id, 1.0, page_5)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_6.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, ~s{div[role="prev_page"]}, page_5.title)

      assert has_element?(view, ~s{svg[role="square checked icon"]})
    end

    test "show orange flag icon when page is graded and is not completed", %{
      conn: conn,
      user: user,
      section: section,
      page_5: page_5,
      page_6: page_6
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      set_progress(section.id, page_5.resource_id, user.id, 0.5, page_5)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_6.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, ~s{div[role="prev_page"]}, page_5.title)

      assert has_element?(view, ~s{svg[role="flag icon"]})
    end

    test "does not show any icon when page is not graded and is not completed", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      assert has_element?(view, ~s{div[role="next_page"]}, page_2.title)

      refute has_element?(view, ~s{div[role="check icon"]})
      refute has_element?(view, ~s{svg[role="square checked icon"]})
      refute has_element?(view, ~s{svg[role="flag icon"]})
    end

    test "no auto-submit when late disallowed, no time limit, and scheduling type is read_by", %{
      conn: conn,
      user: user,
      section: section,
      page_3: page_3
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      attempt_in_progress =
        create_attempt(user, section, page_3, %{lifecycle_state: :active})

      ## update the section resource needed for the test
      Sections.get_section_resource(section.id, attempt_in_progress.resource_access.resource_id)
      |> Sections.update_section_resource(%{
        end_date: yesterday(),
        late_submit: :disallow,
        late_start: :disallow,
        scheduling_type: :read_by
      })

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_3.slug))
      ensure_content_is_visible(view)

      ## assert that redirect is not happening and the submit button and title are present
      assert has_element?(view, "div[role='page title']", page_3.title)
      assert has_element?(view, "button[id='submit_answers']", "Submit Answers")
    end

    test "auto-submit when late disallowed and there is a time limit (even when scheduling type is read_by)",
         %{
           conn: conn,
           user: user,
           section: section,
           page_3: page_3
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      Sections.get_section_resource(section.id, page_3.resource_id)
      |> Sections.update_section_resource(%{
        end_date: yesterday(),
        late_submit: :disallow,
        late_start: :disallow,
        scheduling_type: :read_by,
        time_limit: 20
      })

      # the attempt in progress is past the time limit by one minute
      # (we are mimicking the case the student has closed the browser and reopened the page after the time limit)
      attempt_in_progress =
        create_attempt(user, section, page_3, %{
          lifecycle_state: :active,
          inserted_at: DateTime.add(DateTime.utc_now(), -21, :minute)
        })

      # attempt is auto-submitted and the student is redirected to the review page

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, Utils.lesson_live_path(section.slug, page_3.slug))

      assert redirect_path ==
               "/sections/#{section.slug}/lesson/#{page_3.slug}/attempt/#{attempt_in_progress.attempt_guid}/review?request_path=%2Fsections%2F#{section.slug}%2Flearn%3Fselected_view%3Dgallery"

      updated_attempt =
        Core.get_resource_attempt_by(attempt_guid: attempt_in_progress.attempt_guid)

      # the attempt was auto-submitted, so it's not considered late
      assert updated_attempt.lifecycle_state == :evaluated
      refute updated_attempt.was_late
    end
  end

  describe "annotations toggle" do
    setup [:user_conn, :create_elixir_project]

    test "button is not rendered when annotations are disabled", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      Oli.Resources.Collaboration.disable_all_page_collab_spaces_for_section(section.slug)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      assert not has_element?(
               view,
               "button[phx-click='toggle_notes_sidebar']"
             )
    end

    test "button is rendered when annotations are enabled", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))

      ensure_content_is_visible(view)

      assert has_element?(
               view,
               "button[phx-click='toggle_notes_sidebar']"
             )
    end

    test "can access user menu on the header", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)
      assert has_element?(view, "button[id=user-account-menu]")
    end
  end

  describe "annotations panel" do
    setup [:user_conn, :create_elixir_project]

    test "is toggled open when toolbar button is clicked", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{button[phx-click='toggle_notes_sidebar']})
      |> render_click

      assert has_element?(
               view,
               "#annotations_panel"
             )
    end

    test "renders empty message when there are no notes", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{button[phx-click='toggle_notes_sidebar']})
      |> render_click

      wait_while(fn -> has_element?(view, "svg.loading") end)

      assert has_element?(
               view,
               "div",
               "There are no notes yet"
             )
    end

    test "renders class notes", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # create a class note
      create_post(user, section, page_1, "This is a class note")
      create_post(user, section, page_1, "This is another class note")

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{button[phx-click='toggle_notes_sidebar']})
      |> render_click

      view
      |> element(~s{button[phx-click='select_tab'][phx-value-tab='class_notes']})
      |> render_click

      wait_while(fn -> has_element?(view, "svg.loading") end)

      assert has_element?(
               view,
               "div.post",
               "This is a class note"
             )

      assert has_element?(
               view,
               "div.post",
               "This is another class note"
             )
    end

    test "renders class note with correct number of likes", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      # create a class note
      {:ok, post_1} = create_post(user, section, page_1, "This is a class note")
      create_post(user, section, page_1, "This is another class note")

      # like the post by 3 different users
      user2 = insert(:user)
      user3 = insert(:user)

      react_to_post(post_1, user, :like)
      react_to_post(post_1, user2, :like)
      react_to_post(post_1, user3, :like)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{button[phx-click='toggle_notes_sidebar']})
      |> render_click

      view
      |> element(~s{button[phx-click='select_tab'][phx-value-tab='class_notes']})
      |> render_click

      wait_while(fn -> has_element?(view, "svg.loading") end)

      like_button_html =
        element(
          view,
          "button[phx-value-reaction='like'][phx-value-post-id='#{post_1.id}']"
        )
        |> render()

      # verify number of likes is correct
      assert like_button_html =~ "3"

      # verify the like button is styled as primary since it was liked by the current user
      assert like_button_html =~ "<path class=\"stroke-primary\""
    end

    @tag :flaky
    test "skips CheckCertification if require_certification_check is false when creating a student note",
         ctx do
      %{conn: conn, section: section, user: user, page_1: page_1} = ctx
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      # We need this initial post to show the annotation points
      {:ok, _post_1} = create_post(user, section, page_1, "This is a class note")
      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element("button[phx-click='toggle_notes_sidebar']")
      |> render_click()

      # change the selected tab to class notes -> search should be retriggered
      view
      |> element("button[phx-click='select_tab'][phx-value-tab='class_notes']")
      |> render_click()

      wait_while(fn -> has_element?(view, "svg.loading") end)

      render_hook(view, "update_point_markers", %{
        point_markers: [
          %{"id" => "158828742", "top" => 100.0000},
          %{"id" => "3371710400", "top" => 150.0000}
        ]
      })

      # Click on annotation point
      view
      |> element("button[phx-click='toggle_annotation_point']", "1")
      |> render_click()

      # Focus on input, this open the textarea
      view
      |> element("input[phx-focus='begin_create_annotation']")
      |> render_focus()

      # Submit form
      view
      |> element("form[phx-submit='create_annotation']")
      |> render_submit(%{"content" => "New Note"})

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "triggers CheckCertification when creating an student note", ctx do
      %{conn: conn, section: section, user: user, page_1: page_1} = ctx
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      section = Sections.update_section!(section, %{certificate_enabled: true})
      # We need this initial post to show the annotation points
      {:ok, _post_1} = create_post(user, section, page_1, "This is a class note")
      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element("button[phx-click='toggle_notes_sidebar']")
      |> render_click()

      # change the selected tab to class notes -> search should be retriggered
      view
      |> element("button[phx-click='select_tab'][phx-value-tab='class_notes']")
      |> render_click()

      wait_while(fn -> has_element?(view, "svg.loading") end)

      render_hook(view, "update_point_markers", %{
        point_markers: [
          %{"id" => "158828742", "top" => 100.0000},
          %{"id" => "3371710400", "top" => 150.0000}
        ]
      })

      # Click on annotation point
      view
      |> element("button[phx-click='toggle_annotation_point']", "1")
      |> render_click()

      # Focus on input, this open the textarea
      view
      |> element("input[phx-focus='begin_create_annotation']")
      |> render_focus()

      # Submit form
      view
      |> element("form[phx-submit='create_annotation']")
      |> render_submit(%{"content" => "New Note"})

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.CheckCertification,
        args: %{"user_id" => user.id, "section_id" => section.id}
      )
    end

    test "posts a note", %{
      conn: conn,
      section: section,
      user: user,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{button[phx-click='toggle_notes_sidebar']})
      |> render_click

      assert_push_event(view, "request_point_markers", %{})

      # when we handle the event "toggle_notes_sidebar", the "request_point_markers" event is pushed to the client.
      # The client then responds back with the "update_point_markers" event
      # that is handled by the server and finally used to show the point marks on the annotations panel.
      # We need to trigger the "update_point_markers" event manually because no js is executed while testing the liveview

      render_hook(view, "update_point_markers", %{
        point_markers: [
          %{"id" => "158828742", "top" => 100.0000},
          %{"id" => "3371710400", "top" => 150.0000}
        ]
      })

      view
      |> element(
        ~s{button[phx-click='toggle_annotation_point'][phx-value-point-marker-id='158828742']}
      )
      |> render_click

      render_hook(view, "begin_create_annotation", %{})

      view
      |> form(~s{form[phx-submit='create_annotation']}, %{content: "some new post content"})
      |> render_submit()

      {[post], _more_posts_exist?} =
        Oli.Resources.Collaboration.list_all_user_notes_for_section(
          user.id,
          section.id,
          1,
          0,
          "date",
          :desc
        )

      # the post is stored in the DB
      assert post.content.message == "some new post content"

      # and is shown in the UI
      assert has_element?(view, "div[role='user name']", "Me")

      assert has_element?(view, "div[role='posted at']", "now") or
               has_element?(view, "div[role='posted at']", "1 second ago")

      assert has_element?(view, "p[role='post content']", "some new post content")
    end

    test "retrigers search when selected tab is changed and returns notes of current tab when search is cleared",
         %{
           conn: conn,
           section: section,
           user: user,
           page_1: page_1
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, _student_note} =
        create_post(user, section, page_1, "This is a student note", %{
          visibility: :private
        })

      {:ok, _student_note_2} =
        create_post(user, section, page_1, "This is a another one for the student", %{
          visibility: :private
        })

      {:ok, _class_note} =
        create_post(user, section, page_1, "This is a class note", %{
          visibility: :public
        })

      {:ok, _class_note_2} =
        create_post(user, section, page_1, "This is another one for all the class", %{
          visibility: :public
        })

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, page_1.slug))
      ensure_content_is_visible(view)

      view
      |> element(~s{button[phx-click='toggle_notes_sidebar']})
      |> render_click

      wait_while(fn -> has_element?(view, "svg.loading") end)

      assert render(view) =~ "This is a student note"
      assert render(view) =~ "This is a another one for the student"
      refute render(view) =~ "This is a class note"
      refute render(view) =~ "This is another one for all the class"

      # search for the word "note" within the student notes
      view
      |> form(~s{form[phx-submit='search']}, %{search_term: "note"})
      |> render_submit()

      wait_while(fn -> has_element?(view, "svg.loading") end)

      assert render(view) =~ "This is a student <em>note</em>"
      refute render(view) =~ "This is a class <em>note</em>"

      # change the selected tab to class notes -> search should be retriggered
      view
      |> element(~s{button[phx-click='select_tab'][phx-value-tab='class_notes']})
      |> render_click()

      wait_while(fn -> has_element?(view, "svg.loading") end)

      refute render(view) =~ "This is a student <em>note</em>"
      assert render(view) =~ "This is a class <em>note</em>"

      # clear the search within the class notes -> all class notes should be visible
      view
      |> element(~s{button[phx-click='clear_search']})
      |> render_click()

      wait_while(fn -> has_element?(view, "svg.loading") end)

      refute render(view) =~ "This is a student note"
      refute render(view) =~ "This is a another one for the student"
      assert render(view) =~ "This is a class note"
      assert render(view) =~ "This is another one for all the class"
    end
  end

  describe "outline panel" do
    setup [:user_conn, :create_elixir_project]

    test "do not display the panel in graded pages", %{
      conn: conn,
      section: section,
      user: user,
      page_3: graded_page
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, graded_page, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, graded_page.slug))
      ensure_content_is_visible(view)

      refute has_element?(
               view,
               ~s{button[phx-click='toggle_outline_sidebar']}
             )
    end

    test "is toggled open when toolbar button is clicked in practice pages", %{
      conn: conn,
      section: section,
      user: user,
      page_1: practice_page
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, practice_page.slug))
      ensure_content_is_visible(view)

      # It is not stored as a user preference and is not open by default
      refute Oli.Accounts.get_user_preference(user.id, :page_outline_panel_active?)

      view
      |> element(~s{button[phx-click='toggle_outline_sidebar']})
      |> render_click

      assert has_element?(
               view,
               "#outline_panel"
             )

      # It stores the user preference
      assert Oli.Accounts.get_user_preference(user.id, :page_outline_panel_active?)
    end
  end

  describe "pages configured with :one_at_a_time assessment mode" do
    setup [:user_conn, :create_elixir_project]

    test "are rendered correctly", %{
      conn: conn,
      section: section,
      mcq_activity_1: mcq_activity_1,
      user: user,
      one_at_a_time_question_page: one_at_a_time_question_page
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      resource_access =
        Oli.Delivery.Attempts.Core.track_access(
          one_at_a_time_question_page.resource_id,
          section.id,
          user.id
        )

      resource_attempt =
        insert(:resource_attempt, %{
          resource_access_id: resource_access.id,
          resource_access: resource_access,
          revision_id: one_at_a_time_question_page.id,
          revision: one_at_a_time_question_page,
          attempt_guid: UUID.uuid4(),
          content: one_at_a_time_question_page.content
        })

      activity_attempt =
        insert(:activity_attempt, %{
          resource_attempt_id: resource_attempt.id,
          resource_attempt: resource_attempt,
          revision_id: mcq_activity_1.id,
          revision: mcq_activity_1,
          resource_id: mcq_activity_1.resource_id,
          resource: mcq_activity_1.resource,
          attempt_guid: UUID.uuid4()
        })

      _part_attempt =
        insert(:part_attempt, %{
          activity_attempt_id: activity_attempt.id,
          activity_attempt: activity_attempt,
          attempt_guid: UUID.uuid4(),
          part_id: "1"
        })

      {:ok, view, _html} =
        live(conn, Utils.lesson_live_path(section.slug, one_at_a_time_question_page.slug))

      ensure_content_is_visible(view)

      assert has_element?(
               view,
               "div[role='page title']",
               "This is a page configured to show one question at a time"
             )

      assert has_element?(view, "div[id='one_at_a_time_questions']")
    end

    test "are rendered correctly even if the page has no questions in it's content",
         %{
           conn: conn,
           section: section,
           user: user,
           empty_one_at_a_time_question_page: empty_one_at_a_time_question_page
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, empty_one_at_a_time_question_page, %{
          lifecycle_state: :active
        })

      {:ok, view, _html} =
        live(conn, Utils.lesson_live_path(section.slug, empty_one_at_a_time_question_page.slug))

      ensure_content_is_visible(view)

      assert has_element?(
               view,
               "div[role='page title']",
               "This is a page configured to show one question at a time with no questions"
             )

      assert has_element?(view, "p", "There are no questions available for this page.")
    end
  end

  describe "offline detector" do
    setup [:user_conn, :create_elixir_project]

    test "gets loaded on graded pages that are in progress", %{
      conn: conn,
      section: section,
      user: user,
      page_3: graded_page
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, graded_page, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, graded_page.slug))
      ensure_content_is_visible(view)
      assert has_element?(view, "div[id='offline_detector']")
    end

    test "gets loaded on practice pages that are in progress", %{
      conn: conn,
      section: section,
      user: user,
      page_1: practice_page
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      _first_attempt_in_progress =
        create_attempt(user, section, practice_page, %{lifecycle_state: :active})

      {:ok, view, _html} = live(conn, Utils.lesson_live_path(section.slug, practice_page.slug))
      ensure_content_is_visible(view)
      assert has_element?(view, "div[id='offline_detector']")
    end
  end

  defp create_post(user, section, page, message, attrs \\ %{}) do
    default_attrs = %{
      status: :approved,
      user_id: user.id,
      section_id: section.id,
      resource_id: page.resource_id,
      annotated_resource_id: page.resource_id,
      annotated_block_id: nil,
      annotation_type: :none,
      anonymous: false,
      visibility: :public,
      content: %Oli.Resources.Collaboration.PostContent{message: message}
    }

    Oli.Resources.Collaboration.create_post(Map.merge(default_attrs, attrs))
  end

  defp react_to_post(post, user, reaction) do
    Oli.Resources.Collaboration.toggle_reaction(post.id, user.id, reaction)
  end

  defp ensure_content_is_visible(view) do
    # the content of the page will not be rendered until the socket is connected
    # and the client side confirms that the scripts are loaded
    view
    |> element("#eventIntercept")
    |> render_hook("survey_scripts_loaded", %{"loaded" => true})
  end

  defp set_progress(
         section_id,
         resource_id,
         user_id,
         progress,
         revision,
         opts \\ [attempt_state: :evaluated]
       ) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress, score: 5.0, out_of: 10.0})

    attempt_attrs =
      case opts[:updated_at] do
        nil ->
          %{}

        updated_at ->
          Ecto.Changeset.change(resource_access, updated_at: updated_at)
          |> Oli.Repo.update()

          %{updated_at: updated_at}
      end

    insert(
      :resource_attempt,
      Map.merge(attempt_attrs, %{
        resource_access: resource_access,
        revision: revision,
        lifecycle_state: opts[:attempt_state],
        date_submitted:
          if(opts[:attempt_state] == :evaluated, do: ~U[2024-05-16 20:00:00Z], else: nil)
      })
    )

    insert(:resource_summary, %{
      resource_id: resource_id,
      section_id: section_id,
      user_id: user_id
    })
  end
end
