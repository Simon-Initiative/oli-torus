defmodule OliWeb.PageDeliveryControllerTest do
  use OliWeb.ConnCase

  import Mox
  import Oli.Factory
  import Oli.Utils.Seeder.Utils
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Course
  alias Oli.Seeder
  alias Oli.Delivery.{Sections, Settings}
  alias Oli.Delivery.Attempts.{Core, PageLifecycle}
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, PartAttempt, ResourceAccess}
  alias Oli.Resources.Collaboration
  alias OliWeb.Common.{FormatDateTime, Utils}
  alias OliWeb.Router.Helpers, as: Routes

  defp ensure_content_is_visible(view) do
    # the content of the page will not be rendered until the socket is connected
    # and the client side confirms that the scripts are loaded
    view
    |> element("#eventIntercept")
    |> render_hook("survey_scripts_loaded", %{"loaded" => true})
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
        content: resource_attempt_data[:content] || %{model: []}
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
          resource: revision.resource,
          resource_id: revision.resource_id
        })

      resource_access ->
        resource_access
    end
  end

  describe "page_delivery_controller build_hierarchy" do
    setup [:setup_tags, :setup_lti_session]

    test "properly converts a deeply nested  student access by an enrolled student", %{} do
      # Defines a hierarchy of:

      # Page one
      # Page two
      # New page
      # Unit ONE
      # Unit TWO
      # -- Module
      # ---- Section
      # ------ Nested Section
      # --------- Deep Page
      #

      previous_next_index = %{
        "10429" => %{
          "children" => [],
          "graded" => "false",
          "id" => "10429",
          "index" => "1",
          "level" => "1",
          "next" => "10430",
          "prev" => "5",
          "slug" => "unit_one",
          "title" => "Unit ONE",
          "type" => "container"
        },
        "10430" => %{
          "children" => ["14112"],
          "graded" => "false",
          "id" => "10430",
          "index" => "2",
          "level" => "1",
          "next" => "14112",
          "prev" => "10429",
          "slug" => "unit_two",
          "title" => "Unit TWO",
          "type" => "container"
        },
        "14112" => %{
          "children" => ["14113"],
          "graded" => "false",
          "id" => "14112",
          "index" => "1",
          "level" => "2",
          "next" => "14113",
          "prev" => "10430",
          "slug" => "module",
          "title" => "Module",
          "type" => "container"
        },
        "14113" => %{
          "children" => ["14114"],
          "graded" => "false",
          "id" => "14113",
          "index" => "1",
          "level" => "3",
          "next" => "14114",
          "prev" => "14112",
          "slug" => "section",
          "title" => "Section",
          "type" => "container"
        },
        "14114" => %{
          "children" => ["14115"],
          "graded" => "false",
          "id" => "14114",
          "index" => "1",
          "level" => "4",
          "next" => "14115",
          "prev" => "14113",
          "slug" => "section_40s9w",
          "title" => "Nested Section",
          "type" => "container"
        },
        "14115" => %{
          "children" => [],
          "graded" => "false",
          "id" => "14115",
          "index" => "4",
          "level" => "5",
          "next" => nil,
          "prev" => "14114",
          "slug" => "new_page_3fi3r",
          "title" => "Deep Page",
          "type" => "page"
        },
        "2" => %{
          "children" => [],
          "graded" => "true",
          "id" => "2",
          "index" => "1",
          "level" => "1",
          "next" => "3",
          "prev" => nil,
          "slug" => "page_one",
          "title" => "Page one",
          "type" => "page"
        },
        "3" => %{
          "children" => [],
          "graded" => "false",
          "id" => "3",
          "index" => "2",
          "level" => "1",
          "next" => "5",
          "prev" => "2",
          "slug" => "page_two",
          "title" => "Page two",
          "type" => "page"
        },
        "5" => %{
          "children" => [],
          "graded" => "false",
          "id" => "5",
          "index" => "3",
          "level" => "1",
          "next" => "10429",
          "prev" => "3",
          "slug" => "new_page",
          "title" => "New Page",
          "type" => "page"
        }
      }

      # Build the hierarchy and check the correctness of the deeply nested containers
      hierarchy =
        Sections.build_hierarchy_from_top_level(
          ["2", "3", "5", "10429", "10430"],
          previous_next_index
        )

      assert Enum.count(hierarchy) == 5

      unit_two = Enum.at(hierarchy, 4)
      assert unit_two["title"] == "Unit TWO"

      module = unit_two["children"] |> Enum.at(0)
      assert module["title"] == "Module"

      section = module["children"] |> Enum.at(0)
      assert section["title"] == "Section"

      nested_section = section["children"] |> Enum.at(0)
      assert nested_section["title"] == "Nested Section"

      deep_page = nested_section["children"] |> Enum.at(0)
      assert deep_page["title"] == "Deep Page"
    end
  end

  describe "page_delivery_controller index" do
    setup [:setup_tags, :setup_lti_session]

    test "handles student access by an enrolled student", %{
      conn: conn,
      user: user,
      section: section
    } do
      enroll_as_student(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ section.title
    end

    @tag :skip
    test "shows the related exploration pages for a given page", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "exploration page 1"
      assert html_response(conn, 200) =~ "exploration page 2"
      assert html_response(conn, 200) =~ section.title
    end

    @tag :skip
    test "shows a 'no exploration pages' message when the page doesn't have any related exploration pages",
         %{
           conn: conn,
           user: user,
           section: section,
           ungraded_page_revision: ungraded_page_revision
         } do
      enroll_as_student(%{section: section, user: user})

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{ungraded_page_revision.slug}")

      assert html_response(conn, 200) =~ "There are no explorations related to this page"
      assert html_response(conn, 200) =~ section.title
    end

    @tag :skip
    test "handles student adaptive page access by an enrolled student", %{
      conn: conn,
      map: %{adaptive_page_revision: revision},
      user: user,
      section: section
    } do
      enroll_as_student(%{section: section, user: user})

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{revision.slug}")

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.Delivery\" data-react-props=\""
    end

    test "handles student page access by a non enrolled student", %{
      conn: conn,
      revision: revision,
      section: section
    } do
      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{revision.slug}")

      assert html_response(conn, 302) =~ "You are being <a href=\"/sections/#{section.slug}/enroll\">redirected</a>"
    end

    test "handles student access who is not enrolled", %{conn: conn, section: section} do
      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 302) =~ "You are being <a href=\"/sections/#{section.slug}/enroll\">redirected</a>"
    end

    test "handles student access who is not enrolled when section requires enrollment", %{
      conn: conn,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: false,
          requires_enrollment: true
        })

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "handles student access who is enrolled but has not paid", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: false
        })

      enroll_as_student(%{section: section, user: user})

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"#{Routes.payment_path(conn, :guard, section.slug)}\">redirected"
    end

    test "handles student access who is enrolled, has not paid but is pay by institution", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: false,
          pay_by_institution: true
        })

      stub_current_time(~U[2023-11-04 20:00:00Z])

      enroll_as_student(%{section: section, user: user})

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 200) =~ section.title
    end

    @tag :skip
    @tag isolation: "serializable"
    test "shows the prologue page on an assessment", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Answers'
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Answers"

      # fetch the resource attempt and part attempt that will have been created
      [attempt] = Oli.Repo.all(ResourceAttempt)
      [part_attempt] = Oli.Repo.all(PartAttempt)

      # simulate an interaction
      Oli.Delivery.Attempts.Core.update_part_attempt(part_attempt, %{
        response: %{"input" => "a"}
      })

      # Submit the assessment and verify we see the summary view
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.page_lifecycle_path(
            conn,
            :transition
          ),
          %{
            "action" => "finalize",
            "section_slug" => section.slug,
            "revision_slug" => page_revision.slug,
            "attempt_guid" => attempt.attempt_guid
          }
        )

      # fetch the resource id record and verify the grade rolled up
      [access] = Oli.Repo.all(ResourceAccess)
      assert access.score == 10.0
      assert access.out_of == 11.0

      # now visit the page again, verifying that we see the prologue, but this time it
      # does not allow us to start a new attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      {:ok, conn: conn, ctx: session_context} = set_timezone(%{conn: conn})

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "You have no attempts remaining out of 1 total attempt"

      assert html_response(conn, 200) =~ "Attempt 1 of 1"
      assert html_response(conn, 200) =~ Utils.render_date(attempt, :inserted_at, session_context)

      assert html_response(conn, 200) =~
               Utils.render_date(attempt, :date_evaluated, session_context)

      # visit assessment review page
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :review_attempt,
            section.slug,
            page_revision.slug,
            attempt.attempt_guid
          )
        )

      assert html_response(conn, 200) =~ "(Review)"
    end

    @tag isolation: "serializable"
    test "grade update worker is not created if section has not grade passback enabled", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      attempt = create_attempt(user, section, page_revision, %{lifecycle_state: :active})

      post(
        conn,
        Routes.page_lifecycle_path(
          conn,
          :transition
        ),
        %{
          "action" => "finalize",
          "section_slug" => section.slug,
          "revision_slug" => page_revision.slug,
          "attempt_guid" => attempt.attempt_guid,
          "resource_id" => page_revision.resource_id
        }
      )

      # verify that Oban job has not been created
      assert Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.get_jobs() == []
    end

    @tag isolation: "serializable"
    test "grade update worker is created if section has grade passback enabled", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, section} = Sections.update_section(section, %{grade_passback_enabled: true})
      enroll_as_student(%{section: section, user: user})

      attempt = create_attempt(user, section, page_revision, %{lifecycle_state: :active})

      post(
        conn,
        Routes.page_lifecycle_path(
          conn,
          :transition
        ),
        %{
          "action" => "finalize",
          "section_slug" => section.slug,
          "revision_slug" => page_revision.slug,
          "attempt_guid" => attempt.attempt_guid
        }
      )

      # verify that Oban job has been created
      assert Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.get_jobs() |> length() == 1
    end

    @tag :skip
    @tag isolation: "serializable"
    test "requires correct password to start an attempt", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      sr = Sections.get_section_resource(section.id, page_revision.resource_id)
      Sections.update_section_resource(sr, %{password: "password"})

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "This assessment requires a password to begin"

      # now start the attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.page_delivery_path(
            conn,
            :start_attempt_protected,
            section.slug,
            page_revision.slug
          ),
          %{password: "wrong"}
        )

      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Incorrect password"

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.page_delivery_path(
            conn,
            :start_attempt_protected,
            section.slug,
            page_revision.slug
          ),
          %{password: "password"}
        )

      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Answers'
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Answers"
    end

    @tag :skip
    test "renders custom license in footer for started page", %{
      conn: conn,
      user: user,
      section: section,
      revision: revision,
      project: project
    } do
      {:ok, _project_with_license} =
        Course.update_project(project, %{
          attributes: %{
            license: %{license_type: :custom, custom_license_details: "This is a custom license"}
          }
        })

      enroll_as_student(%{section: section, user: user})

      html_response =
        get(conn, ~p"/sections/#{section.slug}/page/#{revision.slug}") |> html_response(200)

      # Verify License legend
      assert html_response
             |> Floki.parse_document!()
             |> Floki.find("footer")
             |> Floki.find("#license")
             |> Floki.text() =~ "This is a custom license"
    end

    @tag :skip
    test "renders :none license case in footer for started page", %{
      conn: conn,
      user: user,
      section: section,
      revision: revision,
      project: project
    } do
      {:ok, _project_with_license} =
        Course.update_project(project, %{
          attributes: %{
            license: %{license_type: :none, custom_license_details: ""}
          }
        })

      enroll_as_student(%{section: section, user: user})

      html_response =
        get(conn, ~p"/sections/#{section.slug}/page/#{revision.slug}") |> html_response(200)

      # Verify License legend
      assert html_response
             |> Floki.parse_document!()
             |> Floki.find("footer")
             |> Floki.find("#license")
             |> Floki.text() =~ "Non-CC / Copyrighted / Other"
    end

    @tag :skip
    test "renders custom license in footer for a not_started page -- prologue", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision,
      project: project
    } do
      {:ok, _project_with_license} =
        Course.update_project(project, %{
          attributes: %{
            license: %{license_type: :custom, custom_license_details: "This is a custom license"}
          }
        })

      enroll_as_student(%{section: section, user: user})

      html_response =
        get(conn, ~p"/sections/#{section.slug}/page/#{page_revision.slug}") |> html_response(200)

      # Verify License legend
      assert html_response
             |> Floki.parse_document!()
             |> Floki.find("footer")
             |> Floki.find("#license")
             |> Floki.text() =~ "This is a custom license"
    end

    @tag :skip
    test "renders creative commons license in footer for a not_started page -- prologue", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision,
      project: project
    } do
      {:ok, _project_with_license} =
        Course.update_project(project, %{attributes: %{license: %{license_type: :cc_by}}})

      enroll_as_student(%{section: section, user: user})

      html_response =
        get(conn, ~p"/sections/#{section.slug}/page/#{page_revision.slug}") |> html_response(200)

      # Verify License legend
      license =
        html_response
        |> Floki.parse_document!()
        |> Floki.find("footer")
        |> Floki.find("#license")

      assert Floki.text(license) =~
               "Unless otherwise noted this work is licensed under a Creative Commons Attribution 4.0 Unported License."

      # Verify hiperlink to creative commons
      assert Floki.find(license, "a")
             |> Floki.attribute("href") ==
               ["https://creativecommons.org/licenses/by/4.0/"]

      assert Floki.find(license, "a") |> Floki.attribute("target") == ["_blank"]

      # Verify logo
      assert Floki.find(license, "img") |> Floki.attribute("src") == ["/images/cc_logos/by.svg"]
    end

    @tag :skip
    # This tests the edge case for when a student goes to a page that is available to start and the instructor changes the start date
    # to a future date simultaneously and before the student refreshes the page.
    # The student should be redirected back to the page and see a message that the page is not yet available when trying to start an attempt.
    test "requires a past start date to start an attempt", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      sr = Sections.get_section_resource(section.id, page_revision.resource_id)

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "Start Attempt"

      # change the start date to tomorrow
      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)
      Sections.update_section_resource(sr, %{start_date: tomorrow})

      # now start the attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)

      assert html_response(conn, 200) =~
               "This assessment is not yet available. It will be available on #{FormatDateTime.date(tomorrow, conn: conn, precision: :minutes)}."
    end

    @tag :skip
    @tag isolation: "serializable"
    test "shows 'Start Attempt' button when start date has passed", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      sr = Sections.get_section_resource(section.id, page_revision.resource_id)

      tomorrow = DateTime.utc_now() |> DateTime.add(-1, :day)
      Sections.update_section_resource(sr, %{start_date: tomorrow})

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Answers'
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Answers"
    end

    @tag :skip
    test "does not show 'Start Attempt' button when start date has not passed yet", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      sr = Sections.get_section_resource(section.id, page_revision.resource_id)

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)
      Sections.update_section_resource(sr, %{start_date: tomorrow})

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      html_response = html_response(conn, 200)

      assert html_response =~
               "This assessment is not yet available. It will be available on #{FormatDateTime.date(tomorrow, conn: conn, precision: :minutes)}."

      refute html_response =~ "Start Attempt"
    end

    @tag :skip
    @tag isolation: "serializable"
    test "changing a page from graded to ungraded allows the graded attempt to continue", %{
      map: map,
      project: project,
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Answers'
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Answers"

      # fetch the resource attempt and part attempt that will have been created
      [attempt] = Oli.Repo.all(ResourceAttempt)
      [part_attempt] = Oli.Repo.all(PartAttempt)

      # simulate an interaction
      Oli.Delivery.Attempts.Core.update_part_attempt(part_attempt, %{
        response: %{"input" => "a"}
      })

      # Now change the page from graded to ungraded, and issue a publication
      toggle_graded = %{graded: false, title: "This is now ungraded"}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        toggle_graded
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      {:ok, pub} = Oli.Publishing.publish_project(project, "some changes", map.author.id)
      Sections.update_section_project_publication(section, project.id, pub.id)
      Oli.Delivery.Sections.rebuild_section_resources(section: section, publication: pub)

      # now visit the page again, verifying that we are able to resume the original graded attempt
      # even through the page has been changed to ungraded
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      assert html_response(conn, 200) =~ "Submit Answers"

      # Submit the assessment
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.page_lifecycle_path(
            conn,
            :transition
          ),
          %{
            "action" => "finalize",
            "section_slug" => section.slug,
            "revision_slug" => page_revision.slug,
            "attempt_guid" => attempt.attempt_guid
          }
        )

      # now visit the page again, verifying that we see the page as an ungraded page
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      assert html_response(conn, 200) =~ "This is now ungraded"
      refute html_response(conn, 200) =~ "Submit Answers"
    end

    @tag :skip
    @tag isolation: "serializable"
    test "changing a page from ungraded to graded shows the prologue even with an ungraded attempt present",
         %{
           map: map,
           project: project,
           user: user,
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      enroll_as_student(%{section: section, user: user})

      # Change the page to ungraded, and issue a publication
      toggle_graded = %{graded: false, title: "This is now ungraded"}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        toggle_graded
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      {:ok, pub} = Oli.Publishing.publish_project(project, "some changes", map.author.id)
      Sections.update_section_project_publication(section, project.id, pub.id)
      Oli.Delivery.Sections.rebuild_section_resources(section: section, publication: pub)

      # Visit the page in its ungraded state, thus generating a resource attempt
      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      assert html_response(conn, 200) =~ "This is now ungraded"
      refute html_response(conn, 200) =~ "Submit Answers"

      # Now change the page to graded and issue a publication
      toggle_graded = %{graded: true, title: "This is now graded"}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        toggle_graded
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      {:ok, latest_pub} = Oli.Publishing.publish_project(project, "some changes", map.author.id)

      Sections.update_section_project_publication(section, project.id, latest_pub.id)
      Sections.rebuild_section_resources(section: section, publication: latest_pub)

      # Now visit the page again, verifying that we are presented with the prologue page
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Answers'
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Answers"
    end

    @tag :skip
    @tag isolation: "serializable"
    test "multiple requests to start attempt only results in single active attempt record", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      enroll_as_student(%{section: section, user: user})

      # visit the page verifying that we are presented with the prologue page
      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      effective_settings = Settings.get_combined_settings(page_revision, section.id, user.id)

      datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6

      # simulate multiple requests to start an attempt, such as browser back/forward
      [
        Task.async(fn ->
          PageLifecycle.start(
            page_revision.slug,
            section.slug,
            datashop_session_id,
            user,
            effective_settings,
            activity_provider
          )
        end),
        Task.async(fn ->
          PageLifecycle.start(
            page_revision.slug,
            section.slug,
            datashop_session_id,
            user,
            effective_settings,
            activity_provider
          )
        end)
      ]
      |> Task.await_many()

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "Submit Answers"

      # verify there is only a single resource attempt record
      assert {%ResourceAccess{
                access_count: 2
              },
              [
                %ResourceAttempt{
                  attempt_number: 1,
                  lifecycle_state: :active
                }
              ]} =
               Core.get_resource_attempt_history(page_revision.resource_id, section.slug, user.id)
    end

    @tag :skip
    @tag isolation: "serializable"
    test "page with content breaks renders pagination controls", %{
      map: map,
      project: project,
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      # add some content breaks to the page, and issue a publication
      update_with_content_breaks = %{content: content_with_page_breaks()}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        update_with_content_breaks
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      {:ok, pub} =
        Oli.Publishing.publish_project(project, "add some content breaks", map.author.id)

      Sections.update_section_project_publication(section, project.id, pub.id)
      Oli.Delivery.Sections.rebuild_section_resources(section: section, publication: pub)

      enroll_as_student(%{section: section, user: user})

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a pagination control
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ ~s|<div class="paginated"><div class="elements content">|
      assert html_response(conn, 200) =~ "part one"
      assert html_response(conn, 200) =~ ~s|<div class="content-break"></div>|
      assert html_response(conn, 200) =~ "part two"
      assert html_response(conn, 200) =~ "part three"
      assert html_response(conn, 200) =~ ~s|<div data-react-class="Components.PaginationControls"|
    end

    @tag :skip
    @tag isolation: "serializable"
    test "page renders learning objectives in ungraded pages but not graded, except for review mode",
         %{
           user: user,
           conn: conn,
           section: section,
           page_revision: graded_page_revision,
           ungraded_page_revision: ungraded_page_revision
         } do
      enroll_as_student(%{section: section, user: user})

      conn =
        get(conn, ~p"/sections/#{section.slug}/lesson/#{graded_page_revision.slug}")

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, graded_page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the graded page, which should not show learning objectives
      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = get(conn, redir_path)
      assert not String.contains?(html_response(conn, 200), "Learning Objectives")

      # now access an ungraded page, which should show learning objectives
      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/lesson/#{ungraded_page_revision.slug}")

      assert html_response(conn, 200) =~ "Learning Objectives"
      assert html_response(conn, 200) =~ "objective one"
    end

    @tag :skip
    test "render student's upcoming activities if any exists", %{
      conn: conn,
      user: user
    } do
      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Upcoming assessment",
          graded: true,
          content: %{"advancedDelivery" => true}
        )

      container_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "A graded container?",
          graded: true,
          content: %{"advancedDelivery" => true}
        )

      {:ok, section: section, project: _project, author: _author} =
        section_with_pages(%{
          revisions: [page_revision, container_revision],
          revision_section_attributes: [
            %{
              start_date: DateTime.add(DateTime.utc_now(), -10, :day),
              end_date: DateTime.add(DateTime.utc_now(), 5, :day)
            },
            %{
              start_date: DateTime.add(DateTime.utc_now(), -10, :day),
              end_date: DateTime.add(DateTime.utc_now(), 5, :day)
            }
          ]
        })

      enroll_as_student(%{section: section, user: user})

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ "Upcoming assessment"
      refute html_response(conn, 200) =~ "A graded container?"
    end

    @tag :skip
    test "shows page index based navigation", %{
      conn: conn,
      revision: revision,
      user: user,
      section: section
    } do
      enroll_as_student(%{section: section, user: user})

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{revision.slug}")

      assert html_response(conn, 200) =~ "id=\"top_page_navigator\""
      assert html_response(conn, 200) =~ "id=\"bottom_page_navigator\""
    end

    @tag :skip
    @tag isolation: "serializable"
    test "timer will be shown it if revision is graded", %{
      conn: conn,
      user: user,
      section: section,
      map: map
    } do
      %{page: page} = map

      enroll_as_student(%{section: section, user: user})

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(page.revision, section.id, user.id)

      datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6

      Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)
      |> Oli.Delivery.Sections.update_section_resource(%{time_limit: 5})

      insert(:resource_access,
        user: user,
        section: section,
        resource: page.resource
      )

      Oli.Delivery.Attempts.PageLifecycle.start(
        page.revision.slug,
        section.slug,
        datashop_session_id,
        user,
        effective_settings,
        activity_provider
      )

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{page.revision.slug}")

      assert html_response(conn, 200) =~ page.revision.title
      assert html_response(conn, 200) =~ "<div id=\"countdown_timer_display\""
    end

    test "shows an error when the section doesn't exist", %{conn: conn} do
      conn =
        conn
        |> get(~p"/sections/non_existent_section")

      assert html_response(conn, 404) =~ "The section you are trying to view does not exist"
    end

    @tag :skip
    test "shows 'Where you left off' card when student has visited a page before", %{
      conn: conn,
      user: user,
      section: section,
      map: map
    } do
      %{page: page} = map

      enroll_as_student(%{section: section, user: user})

      visit_page(page.revision, section, user)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      # card gets rendered
      assert html_response(conn, 200) =~ "Continue where you left off"

      # with latest visited page title
      [{"h4", [{"class", _}], [title]}] =
        html_response(conn, 200)
        |> Floki.parse_document!()
        |> Floki.find("#latest_visited_page_card h4")

      assert title =~ page.revision.title

      # with a link to that page
      assert html_response(conn, 200)
             |> Floki.parse_document!()
             |> Floki.find("#latest_visited_page_card a")
             |> Floki.attribute("href")
             |> hd() == "/sections/#{section.slug}/page/#{page.revision.slug}"
    end

    test "does not show 'Where you left off' card when student has not visited a page before", %{
      conn: conn,
      user: user,
      section: section
    } do
      enroll_as_student(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      refute html_response(conn, 200) =~ "Continue where you left off"
    end
  end

  describe "independent learner page_delivery_controller" do
    setup [:setup_tags, :setup_independent_learner_section]

    test "handles new independent learner user access", %{conn: conn, section: section} do
      Oli.Test.MockHTTP
      |> expect(:post, fn "https://www.google.com/recaptcha/api/siteverify",
                          _body,
                          _headers,
                          _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true
             })
         }}
      end)

      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      # redirected to enroll page
      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :show_enroll, section.slug)

      conn =
        recycle(conn)
        |> post(Routes.delivery_path(conn, :process_enroll, section.slug), %{
          "user_details" => %{
            "redirect_to" => "/sections/some_title"
          },
          "g-recaptcha-response" => "some-valid-capcha-data"
        })

      assert html_response(conn, 302) =~
               ~p"/sections/#{section.slug}"

      conn = OliWeb.UserAuth.fetch_current_user(conn, [])

      user = conn.assigns[:current_user]

      ensure_user_visit(user, section)

      # make the same request with a user logged in
      conn =
        recycle(conn)
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ section.title
      assert user.sub != nil

      # access again, verify the same user is used that was created before
      conn = recycle(conn)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      same_user = conn.assigns[:current_user]

      assert html_response(conn, 200) =~ section.title
      assert user.id == same_user.id
      assert user.sub == same_user.sub
    end

    test "redirect unenrolled user to enrollment page", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()
      stub_current_time(~U[2023-11-04 20:00:00Z])

      enroll_as_student(%{section: section, user: enrolled_user})

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> log_in_user(other_user)

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :show_enroll, section.slug)

      # user that was previously enrolled should be able to access without enrolling again
      conn =
        recycle(conn)
        |> log_in_user(enrolled_user)

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 200) =~ section.title
    end

    test "redirects to enroll page if no user is logged in", %{conn: conn, section: section} do
      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :show_enroll, section.slug)
    end

    @tag :skip
    test "handles independent learner user access after author and another user have been deleted",
         %{
           conn: conn,
           section: section,
           author: author
         } do
      enrolled_user = user_fixture()
      another_user = user_fixture()

      enroll_as_student(%{section: section, user: enrolled_user})
      enroll_as_student(%{section: section, user: another_user})

      {:ok, _} = Oli.Accounts.delete_author(author)
      {:ok, _} = Oli.Accounts.delete_user(another_user)

      # user should still be able to access
      conn =
        recycle(conn)
        |> log_in_user(enrolled_user)

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 200) =~ "Course Content"
    end

    test "handles student access who has not paid when section not requires enrollment", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)

      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: false
        })

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 302) =~
               "You are being <a href=\"#{Routes.payment_path(conn, :guard, section.slug)}\">redirected"
    end

    test "handles student access who is not enrolled and has not paid when section requires enrollment",
         %{conn: conn, section: section} do
      user = insert(:user)

      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: false,
          requires_enrollment: true
        })

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "handles student access who is enrolled but has not paid", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)

      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: false,
          requires_enrollment: true
        })

      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 302) =~
               "You are being <a href=\"#{Routes.payment_path(conn, :guard, section.slug)}\">redirected"
    end
  end

  describe "displaying unit numbers" do
    setup [:setup_tags, :base_project_with_curriculum]

    @tag :skip
    test "does not display unit numbers if setting is set to false", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      user = insert(:user)

      section = open_and_free_section(project, %{display_curriculum_item_numbering: false})

      {:ok, section} = Sections.create_section_resources(section, publication)

      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)

      # Check visibility in the section overview
      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      response = html_response(conn, 200)

      refute response =~ "Unit 1:"
      assert response =~ "Unit: The first unit"

      conn =
        recycle(conn)
        |> log_in_user(user)

      # Check visibility at the unit level
      conn = get(conn, Routes.page_delivery_path(conn, :container, section.slug, "first_unit"))

      response = html_response(conn, 200)

      refute response =~ "Unit 1:"
      assert response =~ "Unit: The first unit"
    end

    @tag :skip
    test "does display unit numbers if setting is set to true", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      user = insert(:user)

      section = open_and_free_section(project, %{display_curriculum_item_numbering: true})

      {:ok, section} = Sections.create_section_resources(section, publication)

      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)

      # Check visibility in the section overview
      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      response = html_response(conn, 200)

      assert response =~ "Unit 1: The first unit"

      conn =
        recycle(conn)
        |> log_in_user(user)

      # Check visibility at the unit level
      conn = get(conn, Routes.page_delivery_path(conn, :container, section.slug, "first_unit"))

      response = html_response(conn, 200)

      assert response =~ "Unit 1: The first unit"
    end
  end

  describe "displaying custom labels" do
    setup [:setup_tags, :create_project_with_units_and_modules]

    test "displays custom labels if setting are set", %{
      conn: conn,
      section: section,
      revisions: %{unit_revision: unit_revision}
    } do
      user = insert(:user)

      {:ok, section} =
        Sections.update_section(section, %{
          display_curriculum_item_numbering: true,
          customizations: %{unit: "Volume", module: "Chapter", section: "Lesson"}
        })

      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)

      # Check visibility at the unit level
      conn =
        get(conn, Routes.page_delivery_path(conn, :container, section.slug, unit_revision.slug))

      response = html_response(conn, 200)

      assert response =~ "Volume 1: Unit Container"
      assert response =~ "Chapter 1: Module Container 1"
    end

    test "displays default labels if setting are not set", %{
      conn: conn,
      section: section,
      revisions: %{unit_revision: unit_revision}
    } do
      user = insert(:user)

      {:ok, section} =
        Sections.update_section(section, %{
          display_curriculum_item_numbering: true
        })

      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)

      # Check visibility at the unit level
      conn =
        get(conn, Routes.page_delivery_path(conn, :container, section.slug, unit_revision.slug))

      response = html_response(conn, 200)

      assert response =~ "Unit 1: Unit Container"
      assert response =~ "Module 1: Module Container 1"
    end
  end

  describe "export" do
    setup [:admin_conn]

    test "export enrollments as csv", %{conn: conn} do
      user = insert(:user)
      section = insert(:section, open_and_free: true)

      {:ok, enrollment: enrollment} = enroll_as_student(%{section: section, user: user})

      conn =
        post(conn, Routes.page_delivery_path(OliWeb.Endpoint, :export_enrollments, section.slug))

      assert response(conn, 200) =~
               "Cost: Free\r\nDiscount N/A\r\n\r\nStudent name,Student email,Enrolled on\r\n#{user.name},#{user.email},\"#{FormatDateTime.date(enrollment.inserted_at)}\"\r\n"
    end

    test "export enrollments as csv with discount info - percentage", %{conn: conn} do
      institution = insert(:institution)

      product =
        insert(:section, %{
          type: :blueprint,
          institution: institution,
          requires_payment: true,
          amount: Money.new(:USD, 100)
        })

      insert(:discount, section: product, institution: institution)

      tool_jwk = jwk_fixture()
      registration = insert(:lti_registration, %{tool_jwk_id: tool_jwk.id})

      deployment =
        insert(:lti_deployment, %{institution: institution, registration: registration})

      section = insert(:section, blueprint: product, lti_1p3_deployment: deployment)

      user = insert(:user)

      {:ok, enrollment: enrollment} = enroll_as_student(%{section: section, user: user})

      conn =
        post(conn, Routes.page_delivery_path(OliWeb.Endpoint, :export_enrollments, section.slug))

      assert response(conn, 200) =~
               "Cost: Free\r\nDiscount By Product-Institution: 10.0%\r\n\r\nStudent name,Student email,Enrolled on\r\n#{user.name},#{user.email},\"#{FormatDateTime.date(enrollment.inserted_at)}\"\r\n"
    end

    test "export enrollments as csv with discount info - amount", %{conn: conn} do
      institution = insert(:institution)

      product =
        insert(:section, %{
          type: :blueprint,
          institution: institution,
          requires_payment: true,
          amount: Money.new(:USD, 100)
        })

      insert(:discount,
        section: product,
        institution: institution,
        type: :fixed_amount,
        amount: Money.new(:USD, 100)
      )

      tool_jwk = jwk_fixture()
      registration = insert(:lti_registration, %{tool_jwk_id: tool_jwk.id})

      deployment =
        insert(:lti_deployment, %{institution: institution, registration: registration})

      section = insert(:section, blueprint: product, lti_1p3_deployment: deployment)

      user = insert(:user)

      {:ok, enrollment: enrollment} = enroll_as_student(%{section: section, user: user})

      conn =
        post(conn, Routes.page_delivery_path(OliWeb.Endpoint, :export_enrollments, section.slug))

      assert response(conn, 200) =~
               "Cost: Free\r\nDiscount By Product-Institution: $100.00\r\n\r\nStudent name,Student email,Enrolled on\r\n#{user.name},#{user.email},\"#{FormatDateTime.date(enrollment.inserted_at)}\"\r\n"
    end

    test "export enrollments as csv with discount info - institution wide", %{conn: conn} do
      institution = insert(:institution)

      product =
        insert(:section, %{
          type: :blueprint,
          institution: institution,
          requires_payment: true,
          amount: Money.new(:USD, 100)
        })

      insert(:discount, institution: institution, section: nil)

      tool_jwk = jwk_fixture()
      registration = insert(:lti_registration, %{tool_jwk_id: tool_jwk.id})

      deployment =
        insert(:lti_deployment, %{institution: institution, registration: registration})

      section = insert(:section, blueprint: product, lti_1p3_deployment: deployment)

      user = insert(:user)

      {:ok, enrollment: enrollment} = enroll_as_student(%{section: section, user: user})

      conn =
        post(conn, Routes.page_delivery_path(OliWeb.Endpoint, :export_enrollments, section.slug))

      assert response(conn, 200) =~
               "Cost: Free\r\nDiscount By Institution: 10.0%\r\n\r\nStudent name,Student email,Enrolled on\r\n#{user.name},#{user.email},\"#{FormatDateTime.date(enrollment.inserted_at)}\"\r\n"
    end
  end

  describe "preview redirects to not authorized when not logged in" do
    setup [:section_with_assessment]

    test "index preview redirects to enroll", %{
      conn: conn,
      section: section
    } do
      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 302) =~
               Routes.delivery_path(
                 conn,
                 :show_enroll,
                 section.slug
               )
    end

    test "container preview redirects ok", %{
      conn: conn,
      section: section,
      unit_one_revision: unit_one_revision
    } do
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :container_preview, section.slug, unit_one_revision)
        )

      assert html_response(conn, 403) =~ "Not authorized"
    end

    test "page preview redirects ok", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      conn =
        get(conn, Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision))

      assert html_response(conn, 403) =~ "Not authorized"
    end
  end

  describe "preview redirects to student view when is enrolled" do
    @describetag :skip
    setup [:setup_lti_session, :section_with_assessment, :enroll_as_student]

    test "index preview redirects ok", %{
      conn: conn,
      section: section
    } do
      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}"
        )

      assert html_response(conn, 200) =~ "Course Content"
    end

    @tag :skip
    test "index preview redirects ok when section slug ends with 'preview'", %{
      conn: conn,
      section: section
    } do
      {:ok, updated_section} = Sections.update_section(section, %{slug: "test_slug_preview"})

      conn =
        get(
          conn,
          ~p"/sections/#{updated_section.slug}"
        )

      assert html_response(conn, 200) =~ "Course Content"
    end

    test "container preview redirects ok", %{
      conn: conn,
      section: section,
      unit_one_revision: unit_one_revision
    } do
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :container_preview, section.slug, unit_one_revision)
        )

      assert redirected_to(conn) ==
               Routes.page_delivery_path(conn, :container, section.slug, unit_one_revision)
    end

    @tag :skip
    test "page preview redirects ok", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      conn =
        get(conn, Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision))

      assert redirected_to(conn) ==
               ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}"
    end
  end

  describe "preview" do
    setup [:setup_lti_session, :enroll_as_instructor]

    test "container preview - renders ok", %{
      conn: conn,
      user: user
    } do
      {:ok,
       section: section,
       unit_one_revision: unit_one_revision,
       page_revision: _page_revision,
       page_2_revision: _page_2_revision} =
        section_with_assessment(%{})

      enroll_as_instructor(%{user: user, section: section})

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :container_preview,
            section.slug,
            unit_one_revision.slug
          )
        )

      # Unit title
      assert html_response(conn, 200) =~ "The first unit"
      assert html_response(conn, 200) =~ section.title
    end

    test "page preview - renders ok", %{
      conn: conn,
      user: user,
      revision: revision,
      section: section
    } do
      conn =
        conn
        |> log_in_user(user)
        |> get(Routes.page_delivery_path(conn, :page_preview, section.slug, revision.slug))

      # page title
      assert html_response(conn, 200) =~ "Page one (Preview)"
      assert html_response(conn, 200) =~ section.title
    end

    test "page preview - adaptive renders ok", %{
      conn: conn,
      map: %{adaptive_page_revision: revision},
      section: section
    } do
      conn =
        get(conn, Routes.page_delivery_path(conn, :page_preview, section.slug, revision.slug))

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.Delivery\" data-react-props=\""
    end

    test "page preview - do not show the prologue when is graded", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision.slug)
        )

      refute html_response(conn, 200) =~ "This is a <strong>scored</strong> page"
      refute html_response(conn, 200) =~ "Start Attempt"
      # page title
      assert html_response(conn, 200) =~ "page1 (Preview)"
    end

    test "index preview - can access if the user is logged in as instructor", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)
      enroll_as_instructor(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}/preview"
        )

      assert html_response(conn, 200) =~ section.title
      assert html_response(conn, 200) =~ "Preview"
    end

    test "index preview - can access if the user is logged in as admin", %{
      conn: conn,
      section: section
    } do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        get(
          conn,
          ~p"/sections/#{section.slug}/preview"
        )

      assert html_response(conn, 200) =~ section.title
      assert html_response(conn, 200) =~ "Preview"
    end

    test "shows page index based navigation", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision.slug)
        )

      assert html_response(conn, 200) =~ "id=\"bottom_page_navigator\""
    end
  end

  describe "exploration" do
    setup [:project_section_revisions]

    @tag :skip
    test "student can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/explorations")

      assert html_response(conn, 200)
      assert html_response(conn, 200) =~ "Your Exploration Activities"
    end

    test "instructor can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/explorations")

      assert html_response(conn, 200)
    end

    @tag :skip
    test "user logged in as system admin can access to exploration preview", %{
      conn: conn,
      section: section
    } do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      conn = get(conn, ~p"/sections/#{section.slug}/preview/explorations")

      assert html_response(conn, 200) =~ "Your Exploration Activities"
    end

    test "redirects to enroll page if not is enrolled in the section", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/explorations")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll\">redirected</a>."
    end

    @tag :skip
    test "page renders a list of exploration pages", %{
      conn: conn,
      section: section,
      other_revision: other_revision
    } do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/explorations")

      assert html_response(conn, 200) =~ other_revision.title
      assert html_response(conn, 200) =~ "Your Exploration Activities"
    end

    @tag :skip
    test "page renders a message when there are no exploration pages available", %{
      conn: conn
    } do
      {:ok,
       section: section,
       unit_one_revision: _unit_one_revision,
       page_revision: _page_revision,
       page_2_revision: _page_2_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/explorations")

      assert html_response(conn, 200) =~ "<h6>There are no exploration pages available</h6>"
    end

    test "do not show the 'exploration' access in the left navbar when the section has no explorations to show",
         %{conn: conn} do
      {:ok,
       section: section,
       unit_one_revision: _unit_one_revision,
       page_revision: _page_revision,
       page_2_revision: _page_2_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      enroll_as_student(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}")

      refute html_response(conn, 200) =~ "<a>Exploration</a>"
      assert html_response(conn, 200) =~ section.title
    end

    test "do not show the 'exploration' access in the Windowshade when the section does not have explorations to show",
         %{conn: conn} do
      {:ok,
       section: section,
       unit_one_revision: _unit_one_revision,
       page_revision: _page_revision,
       page_2_revision: _page_2_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      enroll_as_student(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}")

      refute html_response(conn, 200) =~ "<h4>Your Exploration Activities</h4>"
      assert html_response(conn, 200) =~ section.title
    end
  end

  describe "discussion" do
    setup [:create_section_with_posts]

    test "student can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/discussions")

      assert html_response(conn, 200) =~ section.title
    end

    test "instructor can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/discussions")

      assert html_response(conn, 200)
    end

    @tag :skip
    test "user logged in as system admin can access to discussion preview", %{
      conn: conn,
      section: section
    } do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      conn = get(conn, ~p"/sections/#{section.slug}/preview/discussions")

      assert html_response(conn, 200) =~ "Your Latest Discussion Activity"
    end

    @tag :skip
    test "page renders a list of posts of current user", %{
      conn: conn,
      section: section,
      user: user
    } do
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/discussions")

      assert html_response(conn, 200) =~ "Your Latest Discussion Activity"
      posts = Collaboration.list_lasts_posts_for_user(user.id, section.id, 5)

      for post <- posts do
        assert html_response(conn, 200) =~ post.title
        assert html_response(conn, 200) =~ post.content.message
        assert html_response(conn, 200) =~ post.user_name
      end
    end

    @tag :skip
    test "page renders a list of posts of all users", %{
      conn: conn,
      section: section,
      user: user
    } do
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/discussions")

      assert html_response(conn, 200) =~ "All Discussion Activity"
      posts = Collaboration.list_lasts_posts_for_section(user.id, section.id, 5)

      for post <- posts do
        assert html_response(conn, 200) =~ post.title
        assert html_response(conn, 200) =~ post.content.message
        assert html_response(conn, 200) =~ post.user_name
      end
    end

    @tag :skip
    test "page renders a message when there are no posts to show", %{
      conn: conn
    } do
      {:ok,
       section: section,
       unit_one_revision: _unit_one_revision,
       page_revision: _page_revision,
       page_2_revision: _page_2_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/discussions")

      assert html_response(conn, 200) =~ "<h6>There are no posts to show</h6>"
    end
  end

  describe "assignments" do
    setup [:section_with_gating_conditions]

    @tag :skip
    test "student can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/student_schedule")

      assert html_response(conn, 200) =~ section.title

      assert html_response(conn, 200) =~ "Assignments"

      assert html_response(conn, 200) =~
               "Find all your assignments, quizzes and activities associated with graded material."
    end

    @tag :skip
    test "user logged in as system admin can access to assignments preview", %{
      conn: conn,
      section: section
    } do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      conn = get(conn, Routes.page_delivery_path(conn, :assignments_preview, section.slug))

      assert html_response(conn, 200) =~ "Assignments"

      assert html_response(conn, 200) =~
               "Find all your assignments, quizzes and activities associated with graded material."
    end

    @tag :skip
    test "related activities get rendered", %{conn: conn, section: section} do
      user = insert(:user)
      enroll_as_student(%{section: section, user: user})

      conn =
        recycle(conn)
        |> log_in_user(user)
        |> get(~p"/sections/#{section.slug}/preview/student_schedule")

      assert html_response(conn, 200) =~ section.title
      assert html_response(conn, 200) =~ "Course content"
      assert html_response(conn, 200) =~ "Explorations"

      assert html_response(conn, 200) =~
               "<td class=\"w-1/3 border-none\">Graded page 1 - Level 1 (w/ no date)</td>"

      assert html_response(conn, 200) =~
               "<td class=\"w-1/3 border-none\">Graded page 2 - Level 0 (w/ date)</td>"

      assert html_response(conn, 200) =~
               "<td class=\"w-1/3 border-none\">Graded page 4 - Level 0 (w/ gating condition)</td>"
    end
  end

  describe "required survey" do
    setup [:user_conn, :section_with_survey]

    test "when student, the survey gets rendered if the user didn't complete it", %{
      conn: conn,
      user: user,
      section: section,
      survey: survey,
      survey_questions: survey_questions
    } do
      enroll_as_student(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      create_survey_access(user, section, survey, survey_questions)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/page/#{survey.slug}\">redirected</a>"
    end

    test "when instructor, the survey doesn't get rendered", %{
      conn: conn,
      user: user,
      section: section
    } do
      enroll_as_instructor(%{user: user, section: section})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ section.title
    end

    test "when student, the survey doesn't get rendered if the user has already complete it", %{
      conn: conn,
      user: user,
      section: section,
      survey: survey,
      survey_questions: survey_questions
    } do
      enroll_as_student(%{section: section, user: user})
      stub_current_time(~U[2023-11-04 20:00:00Z])

      complete_student_survey(user, section, survey, survey_questions)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ section.title
    end
  end

  defp sample_content_with_audiences() do
    %{
      "model" => [
        %{
          "children" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{
                      "text" => "group content with unset audience"
                    }
                  ],
                  "id" => "2832905765",
                  "type" => "p"
                }
              ],
              "id" => "1637405903",
              "type" => "content"
            }
          ],
          "id" => "2596425610",
          "layout" => "vertical",
          "purpose" => "none",
          "type" => "group"
        },
        %{
          "audience" => "always",
          "children" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{
                      "text" => "group content with always audience"
                    }
                  ],
                  "id" => "1397779851",
                  "type" => "p"
                }
              ],
              "id" => "2731683728",
              "type" => "content"
            }
          ],
          "id" => "2507062198",
          "layout" => "vertical",
          "purpose" => "none",
          "type" => "group"
        },
        %{
          "audience" => "instructor",
          "children" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{
                      "text" => "group content with instructor audience"
                    }
                  ],
                  "id" => "3636203845",
                  "type" => "p"
                }
              ],
              "id" => "2754007861",
              "type" => "content"
            }
          ],
          "id" => "221805210",
          "layout" => "vertical",
          "purpose" => "none",
          "type" => "group"
        },
        %{
          "audience" => "feedback",
          "children" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{
                      "text" => "group content with feedback audience"
                    }
                  ],
                  "id" => "1059608464",
                  "type" => "p"
                }
              ],
              "id" => "145362978",
              "type" => "content"
            }
          ],
          "id" => "3207833098",
          "layout" => "vertical",
          "purpose" => "none",
          "type" => "group"
        },
        %{
          "audience" => "never",
          "children" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{
                      "text" => "group content with never audience"
                    }
                  ],
                  "id" => "3983480101",
                  "type" => "p"
                }
              ],
              "id" => "3188423142",
              "type" => "content"
            }
          ],
          "id" => "541687263",
          "layout" => "vertical",
          "purpose" => "none",
          "type" => "group"
        }
      ]
    }
  end

  defp setup_audience_section(map) do
    map
    |> Oli.Utils.Seeder.Project.create_admin(admin_tag: :admin)
    |> Oli.Utils.Seeder.Project.create_author(author_tag: :author)
    |> Oli.Utils.Seeder.Project.create_sample_project(
      ref(:author),
      project_tag: :proj,
      publication_tag: :pub,
      curriculum_revision_tag: :curriculum,
      unscored_page1_tag: :unscored_page1,
      unscored_page1_activity_tag: :unscored_page1_activity,
      scored_page2_tag: :scored_page2,
      scored_page2_activity_tag: :scored_page2_activity
    )
    |> Oli.Utils.Seeder.Project.create_page(
      ref(:author),
      ref(:proj),
      ref(:curriculum),
      %{
        title: "page_with_audience_groups",
        content: sample_content_with_audiences()
      },
      revision_tag: :page_with_audience_groups,
      container_revision_tag: :curriculum
    )
    |> Oli.Utils.Seeder.Project.create_page(
      ref(:author),
      ref(:proj),
      ref(:curriculum),
      %{
        title: "graded_page_with_audience_groups",
        content: sample_content_with_audiences(),
        graded: true
      },
      revision_tag: :graded_page_with_audience_groups,
      container_revision_tag: :curriculum
    )
    |> Oli.Utils.Seeder.Project.ensure_published(ref(:pub))
    |> Oli.Utils.Seeder.Section.create_section(
      ref(:proj),
      ref(:pub),
      nil,
      %{},
      section_tag: :section
    )
    |> Oli.Utils.Seeder.Section.create_and_enroll_learner(
      ref(:section),
      %{},
      user_tag: :student1
    )
    |> Oli.Utils.Seeder.Section.create_and_enroll_instructor(
      ref(:section),
      %{},
      user_tag: :instructor1
    )
  end

  describe "audience" do
    setup [:setup_tags, :setup_audience_section]

    test "student sees the appropriate content according to audience", map do
      %{
        page_with_audience_groups: page_with_audience_groups,
        section: section,
        student1: user
      } = map

      ensure_user_visit(user, section)

      %{conn: conn} =
        map
        |> Oli.Utils.Seeder.Session.login_as_user(ref(:student1))

      {:ok, view, _html} =
        live(conn, "/sections/#{section.slug}/lesson/#{page_with_audience_groups.slug}")

      ensure_content_is_visible(view)

      assert render(view) =~ "group content with unset audience"
      assert render(view) =~ "group content with always audience"
      refute render(view) =~ "group content with instructor audience"
      refute render(view) =~ "group content with feedback audience"
      refute render(view) =~ "group content with never audience"
    end

    test "instructor sees the appropriate content according to audience",
         %{student1: user} = map do
      %{page_with_audience_groups: page_with_audience_groups, section: section} = map

      ensure_user_visit(user, section)

      %{conn: conn} =
        map
        |> Oli.Utils.Seeder.Session.login_as_user(ref(:student1))

      {:ok, view, _html} =
        live(conn, "/sections/#{section.slug}/lesson/#{page_with_audience_groups.slug}")

      ensure_content_is_visible(view)

      assert render(view) =~ "group content with unset audience"
      assert render(view) =~ "group content with always audience"
      refute render(view) =~ "group content with instructor audience"
      refute render(view) =~ "group content with feedback audience"
      refute render(view) =~ "group content with never audience"
    end

    @tag isolation: "serializable"
    test "student sees the appropriate content according to audience during review",
         %{student1: user} = map do
      %{graded_page_with_audience_groups: graded_page_with_audience_groups, section: section} =
        map

      ensure_user_visit(user, section)

      datashop_session_id_user1 = UUID.uuid4()

      %{graded_page_with_audience_groups_attempt: graded_page_with_audience_groups_attempt} =
        map =
        map
        |> Oli.Utils.Seeder.Attempt.start_scored_assessment(
          ref(:graded_page_with_audience_groups),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :graded_page_with_audience_groups_attempt,
          attempt_hierarchy_tag: :graded_page_with_audience_groups_attempt_hierarchy
        )
        |> Oli.Utils.Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:graded_page_with_audience_groups_attempt),
          datashop_session_id_user1
        )

      %{conn: conn} =
        map
        |> Oli.Utils.Seeder.Session.login_as_user(ref(:student1))

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :review_attempt,
            section.slug,
            graded_page_with_audience_groups.slug,
            graded_page_with_audience_groups_attempt.attempt_guid
          )
        )

      assert html_response(conn, 200) =~ "group content with unset audience"
      assert html_response(conn, 200) =~ "group content with always audience"
      refute html_response(conn, 200) =~ "group content with instructor audience"
      assert html_response(conn, 200) =~ "group content with feedback audience"
      refute html_response(conn, 200) =~ "group content with never audience"
    end

    @tag isolation: "serializable"
    test "instructor sees the appropriate content according to audience during review", map do
      %{graded_page_with_audience_groups: graded_page_with_audience_groups, section: section} =
        map

      datashop_session_id_user1 = UUID.uuid4()

      %{graded_page_with_audience_groups_attempt: graded_page_with_audience_groups_attempt} =
        map =
        map
        |> Oli.Utils.Seeder.Attempt.start_scored_assessment(
          ref(:graded_page_with_audience_groups),
          ref(:section),
          ref(:instructor1),
          datashop_session_id_user1,
          resource_attempt_tag: :graded_page_with_audience_groups_attempt,
          attempt_hierarchy_tag: :graded_page_with_audience_groups_attempt_hierarchy
        )
        |> Oli.Utils.Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:graded_page_with_audience_groups_attempt),
          datashop_session_id_user1
        )

      %{conn: conn} =
        map
        |> Oli.Utils.Seeder.Session.login_as_user(ref(:instructor1))

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :review_attempt,
            section.slug,
            graded_page_with_audience_groups.slug,
            graded_page_with_audience_groups_attempt.attempt_guid
          )
        )

      assert html_response(conn, 200) =~ "group content with unset audience"
      assert html_response(conn, 200) =~ "group content with always audience"
      assert html_response(conn, 200) =~ "group content with instructor audience"
      assert html_response(conn, 200) =~ "group content with feedback audience"
      refute html_response(conn, 200) =~ "group content with never audience"
    end
  end

  defp enroll_as_student(%{section: section, user: user}) do
    {:ok, enrollment} = enroll_user_to_section(user, section, :context_learner)
    ensure_user_visit(user, section)
    {:ok, [enrollment: enrollment]}
  end

  defp enroll_as_instructor(%{section: section, user: user}) do
    enroll_user_to_section(user, section, :context_instructor)
    []
  end

  defp setup_lti_session(%{conn: conn}) do
    user = user_fixture()

    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              },
              %{
                "rule" => "input like {b}",
                "score" => 11,
                "id" => "r2",
                "feedback" => %{"id" => "2", "content" => "almost"}
              },
              %{
                "rule" => "input like {c}",
                "score" => 0,
                "id" => "r3",
                "feedback" => %{"id" => "3", "content" => "no"}
              }
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

    graded_attrs = %{
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

    ungraded_attrs = %{
      graded: false,
      title: "ungraded page",
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

    collab_space_config = build(:collab_space_config, status: :enabled)

    collab_space_attrs = %{
      title: "collab space page",
      slug: "collab_space_revision",
      content: %{
        "model" => []
      },
      collab_space_config: collab_space_config
    }

    collab_space_config = build(:collab_space_config, status: :disabled)

    disabled_collab_space_attrs = %{
      title: "collab space page",
      slug: "collab_space_revision",
      content: %{
        "model" => []
      },
      collab_space_config: collab_space_config
    }

    map = Seeder.add_page(map, graded_attrs, :container, :page)
    map = Seeder.add_page(map, ungraded_attrs, :container, :ungraded_page)
    map = Seeder.add_page(map, collab_space_attrs, :container, :collab_space_page)

    map =
      Seeder.add_page(map, disabled_collab_space_attrs, :container, :disabled_collab_space_page)

    exploration_page_1 = %{
      graded: false,
      title: "exploration page 1",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      },
      purpose: :application,
      relates_to: [map.page.resource.id]
    }

    exploration_page_2 = %{
      graded: false,
      title: "exploration page 2",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      },
      purpose: :application,
      relates_to: [map.page.resource.id]
    }

    map = Seeder.add_page(map, exploration_page_1, :container, :exploration_page_1)
    map = Seeder.add_page(map, exploration_page_2, :container, :exploration_page_2)

    {:ok, publication} =
      Oli.Publishing.publish_project(map.project, "some changes", map.author.id)

    map = Map.merge(map, %{publication: publication, contains_explorations: true})

    map =
      map
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(
      ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
      map.section.context_id
    )
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_author(map.author)
      |> log_in_user(user)

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     user: user,
     project: map.project,
     publication: map.publication,
     section: map.section,
     revision: map.revision1,
     page_revision: map.page.revision,
     ungraded_page_revision: map.ungraded_page.revision,
     collab_space_page_revision: map.collab_space_page.revision,
     disabled_collab_space_page_revision: map.disabled_collab_space_page.revision}
  end

  defp setup_independent_learner_section(_) do
    author = author_fixture()

    %{project: project, institution: institution} = Oli.Seeder.base_project_with_resource(author)

    {:ok, publication} = Oli.Publishing.publish_project(project, "some changes", author.id)

    section =
      section_fixture(%{
        institution_id: institution.id,
        base_project_id: project.id,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true
      })

    {:ok, section} = Sections.create_section_resources(section, publication)

    %{section: section, project: project, publication: publication, author: author}
  end

  defp content_with_page_breaks() do
    %{
      "model" => [
        %{
          "children" => [
            %{
              "children" => [
                %{
                  "text" => "part one"
                }
              ],
              "id" => "1336568196",
              "type" => "p"
            }
          ],
          "id" => "1771657333",
          "purpose" => "none",
          "type" => "content"
        },
        %{
          "id" => "3756901939",
          "type" => "break"
        },
        %{
          "children" => [
            %{
              "children" => [
                %{
                  "text" => "part two"
                }
              ],
              "id" => "3143315989",
              "type" => "p"
            }
          ],
          "id" => "1056281351",
          "purpose" => "none",
          "type" => "content"
        },
        %{
          "id" => "4183898367",
          "type" => "break"
        },
        %{
          "children" => [
            %{
              "children" => [
                %{
                  "text" => "part three"
                }
              ],
              "id" => "1908654643",
              "type" => "p"
            }
          ],
          "id" => "4063802480",
          "purpose" => "none",
          "type" => "content"
        }
      ],
      "version" => "0.1.0"
    }
  end
end
