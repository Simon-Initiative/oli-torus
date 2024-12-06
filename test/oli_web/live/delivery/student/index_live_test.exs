defmodule OliWeb.Delivery.Student.IndexLiveTest do
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

  defp enroll_as_student(%{user: user, section: section} = context) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
    context
  end

  defp mark_section_visited(%{section: section, user: user} = context) do
    Sections.mark_section_visited_for_student(section, user)
    context
  end

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

    mcq_activity_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("activity"),
        activity_type_id: mcq_reg.id,
        title: "Multiple Choice 2",
        content: generate_mcq_content("This is the second question")
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
              activity_id: mcq_activity_2_revision.resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
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
        title: "Page 3",
        graded: true,
        purpose: :application
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
        title: "Page 5",
        graded: true,
        max_attempts: 1
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
        intro_content: %{
          "children" => [
            %{
              "children" => [%{"text" => "Welcome to the best course ever!"}],
              "id" => "3477687079",
              "type" => "p"
            }
          ],
          "type" => "p"
        },
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        mcq_activity_1_revision,
        mcq_activity_2_revision,
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
      mcq_2: mcq_activity_2_revision,
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
      unit_2: unit_2_revision,
      container_revision: container_revision
    }
  end

  defp create_elixir_project(_) do
    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      mcq_1: mcq_activity_1_revision,
      mcq_2: mcq_activity_2_revision,
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
      unit_2: unit_2_revision,
      container_revision: container_revision
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
      end_date: ~U[2023-11-05 20:00:00Z],
      time_limit: 75
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
      mcq_2: mcq_activity_2_revision,
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
      unit_2: unit_2_revision,
      container_revision: container_revision
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
        inserted_at: opts[:inserted_at] || DateTime.utc_now(),
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

  defp initiate_activity_attempt(
         page,
         student,
         section
       ) do
    resource_access =
      get_or_insert_resource_access(student, section, page.resource)

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: page,
      lifecycle_state: :active,
      score: 0,
      out_of: 1
    })
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
        live(conn, ~p"/sections/#{section.slug}")

      assert redirect_path ==
               "/users/log_in"
    end

    test "can not access when not enrolled to course", context do
      {:ok, conn: conn, user: _user} = user_conn(context)
      section = insert(:section)

      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, ~p"/sections/#{section.slug}")

      assert redirect_path == "/unauthorized"
    end
  end

  describe "student" do
    setup [
      :user_conn,
      :set_timezone,
      :create_elixir_project,
      :enroll_as_student,
      :mark_section_visited
    ]

    test "can access when enrolled to course", %{conn: conn, section: section} do
      stub_current_time(~U[2023-11-04 20:00:00Z])

      Sections.update_section(section, %{
        agenda: true
      })

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "div", "Upcoming Agenda")
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
          amount: Money.new(:USD, 10),
          has_grace_period: true,
          grace_period_days: 18,
          start_date: ~U[2024-10-15 20:00:00Z],
          end_date: ~U[2024-11-30 20:00:00Z]
        })

      {:ok, view, _html} = live(conn, ~p"/sections/#{product.slug}")

      assert has_element?(
               view,
               "div[id=pay_early_message]",
               "You have 18 days left of your grace period for accessing this course"
             )

      # Grace period is over
      stub_current_time(~U[2024-11-13 20:00:00Z])

      redirect_path = "/sections/#{product.slug}/payment"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, ~p"/sections/#{product.slug}")
    end

    # test this
    test "can see welcome title and encouraging subtitle when is set and the student just joined the course",
         %{
           conn: conn,
           user: user,
           section: section,
           page_1: page_1
         } do
      stub_current_time(~U[2023-11-04 20:00:00Z])

      welcome_title = %{
        type: "p",
        children: [
          %{
            id: "2748906063",
            type: "p",
            children: [%{text: "Welcome to "}, %{text: "the best course ever!", strong: true}]
          }
        ]
      }

      encouraging_subtitle = "Unlock Your Potential. Start Learning Today!"

      Sections.update_section(section, %{
        welcome_title: welcome_title,
        encouraging_subtitle: encouraging_subtitle,
        agenda: true
      })

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "div", "Hi, #{user.given_name} !")

      # Shows welcome title respecting the strong tag
      assert has_element?(view, "span", "Welcome to")
      assert has_element?(view, "strong", "the best course ever!")

      # Shows encouraging subtitle
      assert has_element?(view, "div", encouraging_subtitle)

      assert has_element?(view, "div", "Upcoming Agenda")

      # Shows link of the first page of the course
      assert has_element?(view, "a", "Start course")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/lesson/#{page_1.slug}?request_path=%2Fsections%2F#{section.slug}\""
             )

      assert has_element?(view, "a", "Discover content")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/learn"
             )

      # Shows course progress initial message
      assert has_element?(view, "div", "Course Progress")

      assert has_element?(
               view,
               "div",
               "Begin your learning journey to watch your progress unfold here!"
             )
    end

    test "can see default welcome title and encouraging subtitle when is not set and the student just joined the course",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      stub_current_time(~U[2023-11-04 20:00:00Z])

      # Section with default welcome title and encouraging subtitle
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "div", "Hi, #{user.given_name} !")

      # Shows welcome title respecting the strong tag
      assert has_element?(view, "span", "Welcome to the Course")

      # Shows encouraging subtitle
      assert has_element?(view, "div", "Dive Into Discovery. Begin Your Learning Adventure Now!")
    end

    test "can see the last open and unfinished page when it is a graded page", %{
      conn: conn,
      user: user,
      section: section,
      page_4: page_4,
      mcq_1: mcq_1,
      project: project,
      publication: publication
    } do
      stub_current_time(~U[2024-05-01 20:00:00Z])

      set_activity_attempt(
        page_4,
        mcq_1,
        user,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        false
      )

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "div", "Continue Learning")

      # the last open and unfinished page is page 4
      assert has_element?(view, "div", page_4.title)

      assert has_element?(
               view,
               "div",
               "Sun Nov 5, 2023"
             )

      assert has_element?(view, "div", "Module 2")
      assert has_element?(view, "a", "Resume lesson")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/lesson/#{page_4.slug}?request_path=%2Fsections%2F#{section.slug}\""
             )

      assert has_element?(view, "a", "Show in course")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/learn?target_resource_id=#{page_4.resource_id}&amp;request_path=%2Fsections%2F#{section.slug}\""
             )
    end

    test "can see the last open and unfinished page when it is a practice page", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      stub_current_time(~U[2024-05-01 20:00:00Z])

      initiate_activity_attempt(page_1, user, section)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "div", "Continue Learning")

      # the last open and unfinished page is page 1
      assert has_element?(view, "div", page_1.title)
      assert has_element?(view, "div", "Estimated time #{page_1.duration_minutes} m")

      assert has_element?(
               view,
               "div",
               "Thu Nov 2, 2023"
             )

      assert has_element?(view, "a", "Resume practice")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/lesson/#{page_1.slug}?request_path=%2Fsections%2F#{section.slug}\""
             )

      assert has_element?(view, "a", "Show in course")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/learn?target_resource_id=#{page_1.resource_id}&amp;request_path=%2Fsections%2F#{section.slug}\""
             )
    end

    test "can see the last open and unfinished page when it is an exploration page", %{
      conn: conn,
      user: user,
      section: section,
      page_3: page_3
    } do
      stub_current_time(~U[2024-05-01 20:00:00Z])

      initiate_activity_attempt(page_3, user, section)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "div", "Continue Learning")

      # the last open and unfinished page is page 3
      assert has_element?(view, "div", page_3.title)

      assert has_element?(
               view,
               "div",
               "Sat Nov 4, 2023"
             )

      assert has_element?(view, "a", "Resume exploration")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/lesson/#{page_3.slug}?request_path=%2Fsections%2F#{section.slug}\""
             )

      assert has_element?(view, "a", "Show in course")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/learn?target_resource_id=#{page_3.resource_id}&amp;request_path=%2Fsections%2F#{section.slug}\""
             )
    end

    test "can see nearest upcoming page from agenda when there are no attempts in progress",
         %{conn: conn, user: user, section: section, page_1: page_1, page_2: page_2} do
      stub_current_time(~U[2023-11-02 20:00:00Z])

      initiate_activity_attempt(page_1, user, section)

      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "div", "Continue Learning")

      # the next page from agenda is page 2
      assert has_element?(view, "div", page_2.title)

      assert has_element?(
               view,
               "div",
               "Fri Nov 3, 2023"
             )

      assert has_element?(view, "a", "Start practice")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/lesson/#{page_2.slug}?request_path=%2Fsections%2F#{section.slug}\""
             )

      assert has_element?(view, "a", "Show in course")

      assert element(
               view,
               "a",
               "href=\"/sections/#{section.slug}/learn?target_resource_id=#{page_2.resource_id}&amp;request_path=%2Fsections%2F#{section.slug}\""
             )
    end

    test "can navigate to my assignments page from the homonymous component", %{
      conn: conn,
      section: section
    } do
      stub_current_time(~U[2024-05-01 20:00:00Z])
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "div[role='my assignments'] a", "View All Assignments")

      assert view
             |> element("div[role='my assignments'] a", "View All Assignments")
             |> render_click() ==
               {:error,
                {:live_redirect,
                 %{
                   kind: :push,
                   to:
                     "/sections/#{section.slug}/assignments?request_path=%2Fsections%2F#{section.slug}"
                 }}}
    end

    test "can see the course progress details and navigate to the learn page", %{
      conn: conn,
      user: user,
      section: section,
      page_4: page_4,
      page_5: page_5,
      mcq_1: mcq_1,
      project: project,
      publication: publication
    } do
      # the progress for the course progress component is calculated in an "acid" way,
      # where only 100% completed pages are considered for the progress calculation

      stub_current_time(~U[2024-05-01 20:00:00Z])

      set_activity_attempt(
        page_4,
        mcq_1,
        user,
        section,
        project.id,
        publication.id,
        "id_for_option_a",
        false
      )

      set_progress(section.id, page_4.resource_id, user.id, 1.0, page_4)

      # this page should not be considered for the progress calculation,
      # since it's progress is 50%
      set_progress(section.id, page_5.resource_id, user.id, 0.5, page_5)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "div", "Course Progress")
      assert has_element?(view, "a", "1/6 Pages Completed")
      # 1/6 = 0.166666 => rounded to 17%
      assert has_element?(view, "span", "17")

      # navigate to the learn page
      assert view
             |> element("a", "1/6 Pages Completed")
             |> render_click() ==
               {:error,
                {:live_redirect,
                 %{kind: :push, to: "/sections/#{section.slug}/learn?sidebar_expanded=true"}}}

      # the student now completes page_5
      # so we should see that page considered for the progress calculation
      set_progress(section.id, page_5.resource_id, user.id, 1.0, page_5)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "a", "2/6 Pages Completed")
      # 2/6 = 0.333333 => rounded to 33%
      assert has_element?(view, "span", "33")
    end

    test "can see upcoming agenda if this option is enabled", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4
    } do
      Sections.update_section(section, %{
        agenda: true
      })

      stub_current_time(~U[2023-11-03 21:00:00Z])
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(view, "div", "Upcoming Agenda")
      assert has_element?(view, "div", "This Week")
      assert has_element?(view, "div", page_1.title)
      assert has_element?(view, "div", page_2.title)
      assert has_element?(view, "div", page_3.title)
      assert has_element?(view, "div", page_4.title)
    end

    test "can not see upcoming agenda if this option is disabled", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      stub_current_time(~U[2023-11-03 21:00:00Z])
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      refute has_element?(view, "div", "Upcoming Agenda")
      refute has_element?(view, "div", "This Week")
      refute has_element?(view, "div", page_1.title)
    end

    test "do not show hidden pages in upcoming agenda", %{
      conn: conn,
      section: section,
      page_3: page_3
    } do
      stub_current_time(~U[2023-11-03 00:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      first_assignment = ~s{div[role=assignments] a:nth-child(1) }

      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, first_assignment <> ~s{div[role=title]}, page_3.title)

      # Set page 3 as hidden
      section_resource = Sections.get_section_resource(section.id, page_3.resource_id)
      Sections.update_section_resource(section_resource, %{hidden: !section_resource.hidden})

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      refute has_element?(view, first_assignment <> ~s{div[role=title]}, page_3.title)
    end
  end

  describe "student on a section not yet scheduled" do
    setup [
      :user_conn,
      :set_timezone,
      :create_not_scheduled_elixir_project,
      :enroll_as_student,
      :mark_section_visited
    ]

    test "displays three upcoming assignments", %{
      conn: conn,
      section: section,
      page_3: page_3,
      page_4: page_4,
      page_5: page_5
    } do
      stub_current_time(~U[2023-11-03 00:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      first_assignment = ~s{div[role=assignments] a:nth-child(1) }
      second_assignment = ~s{div[role=assignments] a:nth-child(2) }
      third_assignment = ~s{div[role=assignments] a:nth-child(3) }

      # First upcoming assignment
      assert element(
               view,
               first_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_3.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, first_assignment <> ~s{div[role=title]}, page_3.title)

      assert has_element?(
               view,
               first_assignment <> ~s{div[role=resource_type][aria-label=exploration]}
             )

      # Second upcoming assignment
      assert element(
               view,
               second_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_4.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, second_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, second_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, second_assignment <> ~s{div[role=title]}, page_4.title)

      assert has_element?(
               view,
               second_assignment <> ~s{div[role=resource_type][aria-label=checkpoint]}
             )

      # Third upcoming assignment
      assert element(
               view,
               third_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_5.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, third_assignment <> ~s{div[role=container_label]}, "Unit 2")
      assert has_element?(view, third_assignment <> ~s{div[role=container_label]}, "Module 3")
      assert has_element?(view, third_assignment <> ~s{div[role=title]}, page_5.title)

      assert has_element?(
               view,
               third_assignment <> ~s{div[role=resource_type][aria-label=checkpoint]}
             )
    end
  end

  describe "my assignments" do
    setup [
      :user_conn,
      :set_timezone,
      :create_elixir_project,
      :enroll_as_student,
      :mark_section_visited
    ]

    test "displays default message when there are no upcoming assignments", %{
      conn: conn,
      section: section
    } do
      stub_current_time(~U[2024-05-01 20:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      assert has_element?(
               view,
               ~s{div[role="message"]},
               "Great job, you completed all the assignments! There are no upcoming assignments."
             )
    end

    test "displays default message when there are no latest assignments", %{
      conn: conn,
      section: section
    } do
      stub_current_time(~U[2024-05-01 20:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      view
      |> element("#latest_tab")
      |> render_click()

      assert has_element?(
               view,
               ~s{div[role="message"]},
               "It looks like you need to start your attempt. Begin with the upcoming assignments!"
             )
    end

    test "displays three upcoming assignments", %{
      conn: conn,
      section: section,
      page_3: page_3,
      page_4: page_4,
      page_5: page_5
    } do
      stub_current_time(~U[2023-11-03 00:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      first_assignment = ~s{div[role=assignments] a:nth-child(1) }
      second_assignment = ~s{div[role=assignments] a:nth-child(2) }
      third_assignment = ~s{div[role=assignments] a:nth-child(3) }

      # First upcoming assignment
      assert element(
               view,
               first_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_3.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, first_assignment <> ~s{div[role=title]}, page_3.title)

      assert has_element?(
               view,
               first_assignment <> ~s{div[role=resource_type][aria-label=exploration]}
             )

      assert has_element?(view, first_assignment <> ~s{div[role=details]}, "2 days left")

      # Second upcoming assignment
      assert element(
               view,
               second_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_4.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, second_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, second_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, second_assignment <> ~s{div[role=title]}, page_4.title)

      assert has_element?(
               view,
               second_assignment <> ~s{div[role=resource_type][aria-label=checkpoint]}
             )

      assert has_element?(view, second_assignment <> ~s{div[role=details]}, "3 days left")

      # Third upcoming assignment
      assert element(
               view,
               third_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_5.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, third_assignment <> ~s{div[role=container_label]}, "Unit 2")
      assert has_element?(view, third_assignment <> ~s{div[role=container_label]}, "Module 3")
      assert has_element?(view, third_assignment <> ~s{div[role=title]}, page_5.title)

      assert has_element?(
               view,
               third_assignment <> ~s{div[role=resource_type][aria-label=checkpoint]}
             )

      assert has_element?(view, third_assignment <> ~s{div[role=details]}, "4 days left")
    end

    test "displays three latest assignments", %{
      conn: conn,
      section: section,
      user: user,
      page_3: page_3,
      page_4: page_4,
      page_5: page_5
    } do
      stub_current_time(~U[2023-10-31 00:00:00Z])

      # It has only one allowed attempt
      set_progress(section.id, page_5.resource_id, user.id, 1.0, page_5,
        attempt_state: :evaluated,
        updated_at: ~U[2023-11-01 20:00:00Z]
      )

      stub_current_time(~U[2024-04-22 21:00:00Z])

      set_progress(section.id, page_4.resource_id, user.id, 0.5, page_4,
        attempt_state: :active,
        updated_at: ~U[2023-11-01 21:00:00Z],
        inserted_at: ~U[2024-04-22 21:00:00Z]
      )

      set_progress(section.id, page_3.resource_id, user.id, 0.3, page_3,
        attempt_state: :evaluated,
        updated_at: ~U[2023-11-01 22:00:00Z]
      )

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      view
      |> element("#latest_tab")
      |> render_click()

      first_assignment = ~s{div[role=assignments] a:nth-child(1) }
      second_assignment = ~s{div[role=assignments] a:nth-child(2) }
      third_assignment = ~s{div[role=assignments] a:nth-child(3) }

      # First latest assignment
      assert element(
               view,
               first_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_3.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, first_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, first_assignment <> ~s{div[role=title]}, page_3.title)

      assert has_element?(
               view,
               first_assignment <> ~s{div[role=resource_type][aria-label=exploration]}
             )

      assert has_element?(
               view,
               first_assignment <> ~s{div[role=details] div[role=count]},
               "Attempt 1/∞"
             )

      assert has_element?(view, first_assignment <> ~s{div[role=details] div[role=score]}, "5")
      assert has_element?(view, first_assignment <> ~s{div[role=details] div[role=out_of]}, "10")

      # Second latest assignment
      assert element(
               view,
               second_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_4.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, second_assignment <> ~s{div[role=container_label]}, "Unit 1")
      assert has_element?(view, second_assignment <> ~s{div[role=container_label]}, "Module 2")
      assert has_element?(view, second_assignment <> ~s{div[role=title]}, page_4.title)

      assert has_element?(
               view,
               second_assignment <> ~s{div[role=resource_type][aria-label=checkpoint]}
             )

      assert has_element?(
               view,
               second_assignment <> ~s{div[role=details] div[role=countdown]},
               "01:15:00"
             )

      # Third latest assignment
      assert element(
               view,
               third_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_5.slug}?request_path=%2Fsections%2F#{section.slug}"}

      assert has_element?(view, third_assignment <> ~s{div[role=container_label]}, "Unit 2")
      assert has_element?(view, third_assignment <> ~s{div[role=container_label]}, "Module 3")
      assert has_element?(view, third_assignment <> ~s{div[role=title]}, page_5.title)

      assert has_element?(
               view,
               third_assignment <> ~s{div[role=resource_type][aria-label=checkpoint]}
             )

      assert has_element?(view, third_assignment <> ~s{div[role=details]}, "Completed")
    end

    test "do not show hidden pages in latest assignments", %{
      conn: conn,
      section: section,
      user: user,
      page_3: page_3
    } do
      stub_current_time(~U[2024-04-22 21:00:00Z])

      set_progress(section.id, page_3.resource_id, user.id, 0.3, page_3,
        attempt_state: :evaluated,
        updated_at: ~U[2023-11-01 22:00:00Z]
      )

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      view
      |> element("#latest_tab")
      |> render_click()

      first_assignment = ~s{div[role=assignments] a:nth-child(1) }

      # First latest assignment
      assert has_element?(
               view,
               first_assignment <> ~s{div[role=resource_type][aria-label=exploration]}
             )

      assert has_element?(
               view,
               first_assignment <> ~s{div[role=details] div[role=count]},
               "Attempt 1/∞"
             )

      # Set page 3 as hidden
      section_resource = Sections.get_section_resource(section.id, page_3.resource_id)
      Sections.update_section_resource(section_resource, %{hidden: !section_resource.hidden})

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      # First latest assignment
      refute has_element?(
               view,
               first_assignment <> ~s{div[role=resource_type][aria-label=exploration]}
             )

      refute has_element?(
               view,
               first_assignment <> ~s{div[role=details] div[role=count]},
               "Attempt 1/∞"
             )
    end

    test "do not show hidden pages in upcoming assignments", %{
      conn: conn,
      section: section,
      page_3: page_3
    } do
      stub_current_time(~U[2023-11-03 00:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      first_assignment = ~s{div[role=assignments] a:nth-child(1) }

      # First upcoming assignment
      assert element(
               view,
               first_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_3.slug}?request_path=%2Fsections%2F#{section.slug}"}

      # Set page 3 as hidden
      section_resource = Sections.get_section_resource(section.id, page_3.resource_id)
      Sections.update_section_resource(section_resource, %{hidden: !section_resource.hidden})

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      # First upcoming assignment
      refute element(
               view,
               first_assignment
             )
             |> render() =~
               ~s{href="/sections/#{section.slug}/lesson/#{page_3.slug}?request_path=%2Fsections%2F#{section.slug}"}
    end

    test "do not show assignments navigation if there are no assignments in section", %{
      conn: conn,
      user: user
    } do
      stub_current_time(~U[2023-11-03 00:00:00Z])

      author = insert(:author)
      project = insert(:project, authors: [author])

      page_1_revision =
        insert(:revision,
          resource_type_id: ResourceType.get_id_by_type("page"),
          title: "Start here",
          graded: false
        )

      module_1_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
          children: [page_1_revision.resource_id],
          title: "How to use this course"
        })

      unit_1_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
          children: [module_1_revision.resource_id],
          title: "Introduction"
        })

      container_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
          children: [unit_1_revision.resource_id],
          title: "Root Container"
        })

      all_revisions =
        [
          page_1_revision,
          module_1_revision,
          unit_1_revision,
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

      section =
        insert(:section,
          base_project: project,
          title: "Another course!",
          analytics_version: :v2
        )

      {:ok, section} = Sections.create_section_resources(section, publication)
      {:ok, _} = Sections.rebuild_contained_pages(section)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}")

      refute view |> element("#assignments_nav_link") |> has_element?()
    end
  end
end
