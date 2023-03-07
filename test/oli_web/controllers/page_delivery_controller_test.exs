defmodule OliWeb.PageDeliveryControllerTest do
  use OliWeb.ConnCase

  import Mox
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, PartAttempt, ResourceAccess}
  alias Oli.Resources.Collaboration
  alias Lti_1p3.Tool.ContextRoles
  alias OliWeb.Common.{FormatDateTime, Utils}
  alias OliWeb.Router.Helpers, as: Routes

  describe "page_delivery_controller build_hierarchy" do
    setup [:setup_lti_session]

    test "properly converts a deeply nested  student access by an enrolled student", %{} do
      # Defines a hierachry of:

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
    setup [:setup_lti_session]

    test "handles student access by an enrolled student", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "handles student page access by an enrolled student", %{
      conn: conn,
      revision: revision,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "Page one"
    end

    test "shows the related exploration pages for a given page", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "exploration page 1"
      assert html_response(conn, 200) =~ "exploration page 2"
    end

    test "shows a 'no exploration pages' message when the page doesn't have any related exploration pages",
         %{
           conn: conn,
           user: user,
           section: section,
           ungraded_page_revision: ungraded_page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, ungraded_page_revision.slug))

      assert html_response(conn, 200) =~ "There are no explorations related to this page"
    end

    test "handles student adaptive page access by an enrolled student", %{
      conn: conn,
      map: %{adaptive_page_revision: revision},
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

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
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "handles student access who is not enrolled", %{conn: conn, section: section} do
      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Not authorized"
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
          Routes.page_delivery_path(conn, :index, section.slug)
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

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
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

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "shows the prologue page on an assessment", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
      assert abs(access.score - 0.909) < 0.01
      assert access.out_of == 1

      # now visit the page again, verifying that we see the prologue, but this time it
      # does not allow us to start a new attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, conn: conn, context: session_context} = set_timezone(%{conn: conn})

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "You have 0 attempts remaining out of 1 total attempt"

      assert html_response(conn, 200) =~ "Attempt 1 of 1"
      assert html_response(conn, 200) =~ Utils.render_date(attempt, :inserted_at, session_context)

      assert html_response(conn, 200) =~
               Utils.render_date(attempt, :date_evaluated, session_context)

      # visit assessment review page
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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

    test "changing a page from graded to ungraded allows the graded attempt to continue", %{
      map: map,
      project: project,
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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

      {:ok, pub} = Oli.Publishing.publish_project(project, "some changes")
      Sections.update_section_project_publication(section, project.id, pub.id)
      Oli.Delivery.Sections.rebuild_section_resources(section: section, publication: pub)

      # now visit the page again, verifying that we are able to resume the original graded attempt
      # even through the page has been changed to ungraded
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "Submit Answers"

      # Submit the assessment
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "This is now ungraded"
      refute html_response(conn, 200) =~ "Submit Answers"
    end

    test "changing a page from ungraded to graded shows the prologue even with an ungraded attempt present",
         %{
           map: map,
           project: project,
           user: user,
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

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

      {:ok, pub} = Oli.Publishing.publish_project(project, "some changes")
      Sections.update_section_project_publication(section, project.id, pub.id)
      Oli.Delivery.Sections.rebuild_section_resources(section: section, publication: pub)

      # Visit the page in its ungraded state, thus generating a resource attempt
      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
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

      {:ok, latest_pub} = Oli.Publishing.publish_project(project, "some changes")

      Sections.update_section_project_publication(section, project.id, latest_pub.id)
      Sections.rebuild_section_resources(section: section, publication: latest_pub)

      # Now visit the page again, verifying that we are presented with the prologue page
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Answers"
    end

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

      {:ok, pub} = Oli.Publishing.publish_project(project, "add some content breaks")
      Sections.update_section_project_publication(section, project.id, pub.id)
      Oli.Delivery.Sections.rebuild_section_resources(section: section, publication: pub)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ ~s|<div class="paginated"><div class="elements">|
      assert html_response(conn, 200) =~ "part one"
      assert html_response(conn, 200) =~ ~s|<div class="content-break"></div>|
      assert html_response(conn, 200) =~ "part two"
      assert html_response(conn, 200) =~ "part three"
      assert html_response(conn, 200) =~ ~s|<div data-react-class="Components.PaginationControls"|
    end

    test "index show manage section button when accessing as instructor", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 302) =~
               Routes.live_path(
                 conn,
                 OliWeb.Delivery.InstructorDashboard.ContentLive,
                 section.slug
               )

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(
          Routes.live_path(
            conn,
            OliWeb.Delivery.InstructorDashboard.ContentLive,
            section.slug
          )
        )

      assert html_response(conn, 200) =~ "Course Overview"
      assert html_response(conn, 200) =~ "Manage Section"
    end

    test "page renders learning objectives in ungraded pages but not graded, except for review mode",
         %{
           user: user,
           conn: conn,
           section: section,
           page_revision: graded_page_revision,
           ungraded_page_revision: ungraded_page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        get(conn, Routes.page_delivery_path(conn, :page, section.slug, graded_page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, redir_path)
      assert not String.contains?(html_response(conn, 200), "Learning Objectives")

      # now access an ungraded page, which should show learning objectives
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :page, section.slug, ungraded_page_revision.slug))

      assert html_response(conn, 200) =~ "Learning Objectives"
      assert html_response(conn, 200) =~ "objective one"
    end

    test "page renders the collab space if configured",
         %{
           user: user,
           conn: conn,
           section: section,
           collab_space_page_revision: page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "<h3 class=\"text-xl font-bold\">Discussion</h3>"
    end

    test "page does not render the collab space if it's not configured",
         %{
           user: user,
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      refute html_response(conn, 200) =~ "<h3 class=\"text-xl font-bold\">Discussion</h3>"
    end

    test "page does not render the collab space if it's disabled",
         %{
           user: user,
           conn: conn,
           section: section,
           disabled_collab_space_page_revision: page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      refute html_response(conn, 200) =~ "<h3 class=\"text-xl font-bold\">Discussion</h3>"
    end
  end

  describe "independent learner page_delivery_controller" do
    setup [:setup_independent_learner_section]

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

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

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
               Routes.page_delivery_path(conn, :index, section.slug)

      user = Pow.Plug.current_user(conn)

      # make the same request with a user logged in
      conn =
        recycle(conn)
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
      assert user.sub != nil

      # access again, verify the same user is used that was created before
      conn = recycle(conn)

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      same_user = Pow.Plug.current_user(conn)

      assert html_response(conn, 200) =~ "Course Overview"
      assert user.id == same_user.id
      assert user.sub == same_user.sub
    end

    test "redirect unenrolled user to enrollment page", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :show_enroll, section.slug)

      # user that was previously enrolled should be able to access without enrolling again
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          enrolled_user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "redirects to enroll page if no user is logged in", %{conn: conn, section: section} do
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :show_enroll, section.slug)
    end

    test "handles independent learner user access after author and another user have been deleted",
         %{
           conn: conn,
           section: section,
           author: author
         } do
      enrolled_user = user_fixture()
      another_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _enrollment} =
        Sections.enroll(another_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Oli.Accounts.delete_author(author)
      {:ok, _} = Oli.Accounts.delete_user(another_user)

      # user should still be able to access
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          enrolled_user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      assert html_response(conn, 200) =~ "Course Overview"
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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

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
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

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

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"#{Routes.payment_path(conn, :guard, section.slug)}\">redirected"
    end
  end

  describe "displaying unit numbers" do
    setup [:base_project_with_curriculum]

    test "does not display unit numbers if setting is set to false", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      user = insert(:user)

      section = open_and_free_section(project, %{display_curriculum_item_numbering: false})

      {:ok, section} = Sections.create_section_resources(section, publication)

      enroll_user_to_section(user, section, :context_learner)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      # Check visibility in the section overview
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      response = html_response(conn, 200)

      refute response =~ "Unit 1:"
      assert response =~ "Unit: The first unit"

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      # Check visibility at the unit level
      conn = get(conn, Routes.page_delivery_path(conn, :container, section.slug, "first_unit"))

      response = html_response(conn, 200)

      refute response =~ "Unit 1:"
      assert response =~ "Unit: The first unit"
    end

    test "does display unit numbers if setting is set to true", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      user = insert(:user)

      section = open_and_free_section(project, %{display_curriculum_item_numbering: true})

      {:ok, section} = Sections.create_section_resources(section, publication)

      enroll_user_to_section(user, section, :context_learner)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      # Check visibility in the section overview
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      response = html_response(conn, 200)

      assert response =~ "Unit 1: The first unit"

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      # Check visibility at the unit level
      conn = get(conn, Routes.page_delivery_path(conn, :container, section.slug, "first_unit"))

      response = html_response(conn, 200)

      assert response =~ "Unit 1: The first unit"
    end
  end

  describe "export" do
    setup [:admin_conn]

    test "export enrollments as csv", %{conn: conn} do
      user = insert(:user)
      section = insert(:section, open_and_free: true)

      {:ok, enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

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

      {:ok, enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

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

      {:ok, enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

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

      {:ok, enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

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
          Routes.page_delivery_path(conn, :index, section.slug)
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
    setup [:setup_lti_session, :section_with_assessment, :enroll_as_student]

    test "index preview redirects ok", %{
      conn: conn,
      section: section
    } do
      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, section.slug)
        )

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "index preview redirects ok when section slug ends with 'preview'", %{
      conn: conn,
      section: section
    } do
      {:ok, updated_section} = Sections.update_section(section, %{slug: "test_slug_preview"})

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :index, updated_section.slug)
        )

      assert html_response(conn, 200) =~ "Course Overview"
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

    test "page preview redirects ok", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      conn =
        get(conn, Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision))

      assert redirected_to(conn) ==
               Routes.page_delivery_path(conn, :page, section.slug, page_revision)
    end
  end

  describe "preview" do
    setup [:setup_lti_session, :enroll_as_instructor]

    test "container preview - renders ok", %{
      conn: conn,
      user: user
    } do
      {:ok, section: section, unit_one_revision: unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(%{})

      enroll_user_to_section(user, section, :context_instructor)

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
    end

    test "page preview - renders ok", %{
      conn: conn,
      user: user,
      revision: revision,
      section: section
    } do
      conn =
        conn
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :page_preview, section.slug, revision.slug))

      # page title
      assert html_response(conn, 200) =~ "Page one (Preview)"
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
  end

  describe "exploration" do
    setup [:project_section_revisions]

    test "student can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :exploration, section.slug))

      assert html_response(conn, 200)
    end

    test "instructor can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :exploration, section.slug))

      assert html_response(conn, 200)
    end

    test "user must be enrolled in the section even if is a system admin", %{
      conn: conn,
      section: section
    } do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      conn = get(conn, Routes.page_delivery_path(conn, :exploration, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll\">redirected</a>."
    end

    test "redirects to enroll page if not is enrolled in the section", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :exploration, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll\">redirected</a>."
    end

    test "page renders a list of exploration pages", %{
      conn: conn,
      section: section,
      other_revision: other_revision
    } do
      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :exploration, section.slug))

      assert html_response(conn, 200) =~ other_revision.title
    end

    test "page renders a message when there are no exploration pages available", %{
      conn: conn
    } do
      {:ok,
       section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :exploration, section.slug))

      assert html_response(conn, 200) =~ "<h6>There are no exploration pages available</h6>"
    end

    test "do not show the 'exploration' access in the left navbar when the section has no explorations to show",
         %{conn: conn} do
      {:ok,
       section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      refute html_response(conn, 200) =~ "<a>Exploration</a>"
    end

    test "do not show the 'exploration' access in the Windowshade when the section does not have explorations to show",
         %{conn: conn} do
      {:ok,
       section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      refute html_response(conn, 200) =~ "<h4>Your Exploration Activities</h4>"
    end
  end

  describe "discussion" do
    setup [:create_section_with_posts]

    test "student can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :discussion, section.slug))

      assert html_response(conn, 200)
    end

    test "instructor can access if is enrolled in the section", %{conn: conn, section: section} do
      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :discussion, section.slug))

      assert html_response(conn, 200)
    end

    test "page renders a list of posts of current user", %{
      conn: conn,
      section: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :discussion, section.slug))

      assert html_response(conn, 200) =~ "Your Latest Discussion Activity"
      posts = Collaboration.list_lasts_posts_for_user(user.id, section.id, 5)

      for post <- posts do
        assert html_response(conn, 200) =~ post.title
        assert html_response(conn, 200) =~ post.content.message
        assert html_response(conn, 200) =~ post.user_name
      end
    end

    test "page renders a list of posts of all users", %{
      conn: conn,
      section: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :discussion, section.slug))

      assert html_response(conn, 200) =~ "All Discussion Activity"
      posts = Collaboration.list_lasts_posts_for_section(user.id, section.id, 5)

      for post <- posts do
        assert html_response(conn, 200) =~ post.title
        assert html_response(conn, 200) =~ post.content.message
        assert html_response(conn, 200) =~ post.user_name
      end
    end

    test "page renders a message when there are no posts to show", %{
      conn: conn
    } do
      {:ok,
       section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(%{})

      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
        |> get(Routes.page_delivery_path(conn, :discussion, section.slug))

      assert html_response(conn, 200) =~ "<h6>There are no posts to show</h6>"
    end
  end

  defp enroll_as_student(%{section: section, user: user}) do
    enroll_user_to_section(user, section, :context_learner)
    []
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

    map = Seeder.add_page(map, graded_attrs, :page)
    map = Seeder.add_page(map, ungraded_attrs, :ungraded_page)
    map = Seeder.add_page(map, collab_space_attrs, :collab_space_page)
    map = Seeder.add_page(map, disabled_collab_space_attrs, :disabled_collab_space_page)

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

    map = Seeder.add_page(map, exploration_page_1, :exploration_page_1)
    map = Seeder.add_page(map, exploration_page_2, :exploration_page_2)

    {:ok, publication} = Oli.Publishing.publish_project(map.project, "some changes")

    map = Map.merge(map, %{publication: publication, contains_explorations: true})

    map =
      map
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(
        ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
        map.section.context_id
      )
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> OliWeb.Common.LtiSession.put_session_lti_params(lti_params_id)

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

    {:ok, publication} = Oli.Publishing.publish_project(project, "some changes")

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
