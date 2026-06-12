defmodule OliWeb.Delivery.Instructor.PreviewLessonLiveTest do
  use OliWeb.ConnCase

  import Ecto.Query
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Activities
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt,
    PartAttempt,
    ResourceAccess,
    ResourceAttempt
  }

  alias Oli.Repo
  alias Oli.Seeder
  alias OliWeb.Delivery.Instructor.PreviewRoutes

  describe "instructor basic page preview lesson" do
    setup [:setup_preview_section]

    test "renders a basic page at the explicit preview lesson route", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, _view, html} = live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      assert html =~ ~s|id="instructor-preview-header"|
      assert html =~ ~s|<main id="main"|
      assert html =~ "page1"
      assert html =~ "instructor-preview-activity-wrapper"
      assert html =~ "/js/oli_multiple_choice_preview.js"
      refute html =~ "/js/oli_multiple_choice_authoring.js"
      refute html =~ "Page Discussion"
    end

    test "uses preview lesson URLs for in-preview navigation and preserves safe return context",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           next_page_revision: next_page_revision
         } do
      {:ok, _view, html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "return_to" => "/sections/#{section.slug}/remix?from=curriculum"
          })
        )

      assert html =~ PreviewRoutes.lesson_path(section.slug, next_page_revision.slug)
      assert html =~ "return_to=%2Fsections%2F#{section.slug}%2Fremix%3Ffrom%3Dcurriculum"
      assert html =~ "id=\"bottom-bar-wrapper\""
    end

    test "does not render the outline and notes toggles for graded preview pages", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, view, _html} = live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      refute has_element?(view, "#toggle_outline_button")
      refute has_element?(view, "#toggle_notes_button")
    end

    test "back link returns to preview learn with preserved state", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      preview_learn_path =
        PreviewRoutes.learn_path(section.slug, %{
          "selected_view" => "outline",
          "sidebar_expanded" => "false",
          "target_resource_id" => page_revision.resource_id
        })

      {:ok, view, _html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "return_to" => preview_learn_path
          })
        )

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click()

      assert_redirect(view, preview_learn_path)
    end

    test "back link falls back to request_path when return_to is absent", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      request_path = "/sections/#{section.slug}/preview/assignments"

      {:ok, view, _html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "request_path" => request_path
          })
        )

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click()

      assert_redirect(view, request_path)
    end

    test "back link returns to preview learn when request_path is not provided", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      overview_path = "/sections/#{section.slug}/instructor_dashboard/overview/course_content"

      {:ok, view, _html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "return_to" => overview_path
          })
        )

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click()

      assert_redirect(
        view,
        PreviewRoutes.learn_path(section.slug, %{
          "target_resource_id" => page_revision.resource_id,
          "selected_view" => "gallery",
          "sidebar_expanded" => true,
          "return_to" => overview_path
        })
      )
    end

    test "back link falls back to preview schedule request_path when return_to is absent", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      request_path = "/sections/#{section.slug}/preview/student_schedule"

      {:ok, view, _html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "request_path" => request_path
          })
        )

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click()

      assert_redirect(view, request_path)
    end

    test "uses the return context when safe and falls back when unsafe", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, _view, html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "return_to" => "/sections/#{section.slug}/remix?from=curriculum"
          })
        )

      assert html =~ ~s|href="/sections/#{section.slug}/remix?from=curriculum"|
      assert html =~ "Return to Customize Content"

      {:ok, _view, html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "return_to" => "https://example.com/bad"
          })
        )

      assert html =~ ~s|href="/sections/#{section.slug}/remix"|
      assert html =~ "Return to Customize Content"
    end

    test "drops an unsafe request_path while preserving a safe return_to", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, _view, html} =
        live(
          conn,
          PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
            "return_to" => "/sections/#{section.slug}/remix?from=curriculum",
            "request_path" => "https://example.com/bad"
          })
        )

      refute html =~ "request_path=https%3A%2F%2Fexample.com%2Fbad"
      assert html =~ "return_to=%2Fsections%2F#{section.slug}%2Fremix%3Ffrom%3Dcurriculum"
    end

    test "keeps adaptive preview handled by the existing controller route", %{
      conn: conn,
      section: section,
      adaptive_page_revision: adaptive_page_revision
    } do
      {:error, {:redirect, %{to: path}}} =
        live(conn, PreviewRoutes.lesson_path(section.slug, adaptive_page_revision.slug))

      assert path == PreviewRoutes.page_path(section.slug, adaptive_page_revision.slug)
    end

    test "does not create learner delivery side effects for a basic page", %{
      conn: conn,
      section: section,
      user: user,
      page_revision: page_revision
    } do
      before_counts = side_effect_counts(section, user, page_revision)

      {:ok, _view, _html} =
        live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      assert side_effect_counts(section, user, page_revision) == before_counts
    end

    test "remove hook event stores an exclusion and shows a success flash", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      activity_resource_id = first_activity_resource_id(page_revision)

      {:ok, view, _html} = live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      html =
        view
        |> element("#instructor-preview-lesson")
        |> render_hook("toggle_preview_activity_customization", %{
          "action" => "remove",
          "target" => %{
            "kind" => "embedded_activity",
            "pageResourceId" => page_revision.resource_id,
            "activityResourceId" => activity_resource_id
          }
        })

      assert html =~ "Question removed from this page."

      exclusions =
        InstructorCustomizations.get_page_exclusions(section.id, page_revision.resource_id)

      assert Enum.any?(exclusions, fn exclusion ->
               exclusion.kind == :embedded_activity and
                 exclusion.excluded_resource_id == activity_resource_id
             end)
    end

    test "restore hook event removes an exclusion and shows a success flash", %{
      conn: conn,
      section: section,
      user: user,
      page_revision: page_revision
    } do
      activity_resource_id = first_activity_resource_id(page_revision)

      {:ok, _view} =
        InstructorCustomizations.exclude_activity(
          section,
          page_revision.resource_id,
          activity_resource_id,
          actor: user
        )

      {:ok, view, _html} = live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      html =
        view
        |> element("#instructor-preview-lesson")
        |> render_hook("toggle_preview_activity_customization", %{
          "action" => "restore",
          "target" => %{
            "kind" => "embedded_activity",
            "pageResourceId" => page_revision.resource_id,
            "activityResourceId" => activity_resource_id
          }
        })

      assert html =~ "Question restored to this page."

      assert InstructorCustomizations.get_page_exclusions(section.id, page_revision.resource_id) ==
               []
    end

    test "invalid hook target is rejected and does not write exclusions", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      activity_resource_id = first_activity_resource_id(page_revision)

      {:ok, view, _html} = live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      html =
        view
        |> element("#instructor-preview-lesson")
        |> render_hook("toggle_preview_activity_customization", %{
          "action" => "remove",
          "target" => %{
            "kind" => "embedded_activity",
            "pageResourceId" => page_revision.resource_id + 999_999,
            "activityResourceId" => activity_resource_id
          }
        })

      assert html =~ "Unable to update a question outside this page preview."

      assert InstructorCustomizations.get_page_exclusions(section.id, page_revision.resource_id) ==
               []
    end
  end

  describe "mixed activity preview script selection" do
    setup [:setup_mixed_preview_section]

    test "uses preview scripts for supported activities and authoring fallback for unsupported activities",
         %{conn: conn, section: section, page_revision: page_revision} do
      {:ok, _view, html} = live(conn, PreviewRoutes.lesson_path(section.slug, page_revision.slug))

      assert html =~ "/js/oli_multiple_choice_preview.js"
      assert html =~ "supported objective"
      assert html =~ "/js/oli_short_answer_authoring.js"
      assert html =~ "fallback objective"
      assert length(Regex.scan(~r/instructor-preview-activity-wrapper/, html)) == 2
      refute html =~ "/js/oli_short_answer_preview.js"
      refute html =~ "/js/oli_multiple_choice_authoring.js"
    end
  end

  defp setup_preview_section(%{conn: conn}) do
    user = user_fixture(%{independent_learner: false})

    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{"rule" => "input like {a}", "score" => 10, "id" => "r1"},
              %{"rule" => "input like {b}", "score" => 0, "id" => "r2"}
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(
        %{title: "one", max_attempts: 2, content: content},
        :publication,
        :project,
        :author,
        :activity
      )
      |> Seeder.add_adaptive_page()

    page_attrs = %{
      graded: true,
      max_attempts: 1,
      title: "page1",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      },
      objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
    }

    map = Seeder.add_page(map, page_attrs, :container, :page)

    second_page_attrs = %{
      graded: false,
      title: "page2",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      }
    }

    map = Seeder.add_page(map, second_page_attrs, :container, :next_page)

    {:ok, publication} =
      Oli.Publishing.publish_project(map.project, "preview lesson", map.author.id)

    map =
      map
      |> Map.merge(%{publication: publication})
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    page_section_resource = Sections.get_section_resource(map.section.id, map.page.resource.id)

    {:ok, _updated_section_resource} =
      Sections.update_section_resource(page_section_resource, %{
        collab_space_config: %CollabSpaceConfig{status: :enabled}
      })

    insert(:post,
      user: user,
      section: map.section,
      resource: map.page.resource,
      visibility: :public,
      content: build(:post_content, message: "Preview note for instructors")
    )

    enroll_as_instructor(%{section: map.section, user: user})
    cache_lti_context(map.section, user)

    {:ok,
     conn: log_in_user(conn, user),
     user: user,
     section: map.section,
     page_revision: map.page.revision,
     next_page_revision: map.next_page.revision,
     adaptive_page_revision: map.adaptive_page_revision}
  end

  defp setup_mixed_preview_section(%{conn: conn}) do
    user = user_fixture(%{independent_learner: false})

    content = %{
      "stem" => "mixed preview activity",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "part_1",
            "responses" => [
              %{"rule" => "input like {a}", "score" => 1, "id" => "r1"},
              %{"rule" => "input like {b}", "score" => 0, "id" => "r2"}
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    short_answer_id = Activities.get_registration_by_slug("oli_short_answer").id

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("fallback objective", :fallback_objective)
      |> Seeder.add_objective("supported objective", :supported_objective)

    map =
      map
      |> Seeder.add_activity(
        %{
          title: "supported",
          content: content,
          objectives: %{"part_1" => [Map.get(map, :supported_objective).resource.id]}
        },
        :publication,
        :project,
        :author,
        :supported_activity
      )
      |> Seeder.add_activity(
        %{
          title: "unsupported",
          content: content,
          objectives: %{"attached" => [Map.get(map, :fallback_objective).resource.id]}
        },
        :publication,
        :project,
        :author,
        :unsupported_activity,
        short_answer_id
      )

    page_attrs = %{
      graded: true,
      title: "mixed preview page",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :supported_activity).resource.id
          },
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :unsupported_activity).resource.id
          }
        ]
      }
    }

    map = Seeder.add_page(map, page_attrs, :container, :page)

    {:ok, publication} =
      Oli.Publishing.publish_project(map.project, "mixed preview page", map.author.id)

    map =
      map
      |> Map.merge(%{publication: publication})
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    enroll_as_instructor(%{section: map.section, user: user})
    cache_lti_context(map.section, user)

    {:ok, conn: log_in_user(conn, user), section: map.section, page_revision: map.page.revision}
  end

  defp enroll_as_instructor(%{section: section, user: user}) do
    enroll_user_to_section(user, section, :context_instructor)
    :ok
  end

  defp first_activity_resource_id(page_revision) do
    page_revision.content["model"]
    |> Enum.find_value(fn
      %{"type" => "activity-reference", "activity_id" => activity_id} -> activity_id
      _ -> nil
    end)
  end

  defp cache_lti_context(section, user) do
    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)
    |> cache_lti_params(user.id)
  end

  defp side_effect_counts(section, user, page_revision) do
    resource_access_query =
      from access in ResourceAccess,
        where:
          access.section_id == ^section.id and access.user_id == ^user.id and
            access.resource_id == ^page_revision.resource_id

    resource_attempt_query =
      from attempt in ResourceAttempt,
        join: access in ResourceAccess,
        on: access.id == attempt.resource_access_id,
        where:
          access.section_id == ^section.id and access.user_id == ^user.id and
            access.resource_id == ^page_revision.resource_id

    activity_attempt_query =
      from attempt in ActivityAttempt,
        join: resource_attempt in ResourceAttempt,
        on: resource_attempt.id == attempt.resource_attempt_id,
        join: access in ResourceAccess,
        on: access.id == resource_attempt.resource_access_id,
        where:
          access.section_id == ^section.id and access.user_id == ^user.id and
            access.resource_id == ^page_revision.resource_id

    part_attempt_query =
      from part_attempt in PartAttempt,
        join: activity_attempt in ActivityAttempt,
        on: activity_attempt.id == part_attempt.activity_attempt_id,
        join: resource_attempt in ResourceAttempt,
        on: resource_attempt.id == activity_attempt.resource_attempt_id,
        join: access in ResourceAccess,
        on: access.id == resource_attempt.resource_access_id,
        where:
          access.section_id == ^section.id and access.user_id == ^user.id and
            access.resource_id == ^page_revision.resource_id

    resource_summary_query =
      from summary in ResourceSummary,
        where:
          summary.section_id == ^section.id and summary.user_id == ^user.id and
            summary.resource_id == ^page_revision.resource_id

    %{
      resource_accesses: Repo.aggregate(resource_access_query, :count),
      resource_attempts: Repo.aggregate(resource_attempt_query, :count),
      activity_attempts: Repo.aggregate(activity_attempt_query, :count),
      part_attempts: Repo.aggregate(part_attempt_query, :count),
      resource_summaries: Repo.aggregate(resource_summary_query, :count)
    }
  end
end
