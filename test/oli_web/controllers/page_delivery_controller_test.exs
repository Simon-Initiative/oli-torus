defmodule OliWeb.PageDeliveryControllerTest do
  use OliWeb.ConnCase

  import Mox
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, PartAttempt, ResourceAccess}
  alias Lti_1p3.Tool.ContextRoles
  alias OliWeb.Common.{FormatDateTime, Utils}
  alias OliWeb.Router.Helpers, as: Routes

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

      assert html_response(conn, 200) =~ "<h1 class=\"title\">"
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

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :finalize_attempt,
            section.slug,
            page_revision.slug,
            attempt.attempt_guid
          )
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
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :finalize_attempt,
            section.slug,
            page_revision.slug,
            attempt.attempt_guid
          )
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

      assert html_response(conn, 200) =~ "Course Overview"
      assert html_response(conn, 200) =~ "Manage Section"
    end

    test "index preview do not show manage section button when accessing as instructor", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index_preview, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
      refute html_response(conn, 200) =~ "Manage Section"
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

      assert html_response(conn, 302) =~ Routes.page_delivery_path(conn, :index, section.slug)
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

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :show_enroll, section.slug)

      # user that was previously enrolled should be able to access without enrolling again
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          enrolled_user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "redirects to enroll page if no user is logged in", %{conn: conn, section: section} do
      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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
      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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
      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

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

    map = Seeder.add_page(map, graded_attrs, :page)
    map = Seeder.add_page(map, ungraded_attrs, :ungraded_page)

    {:ok, publication} = Oli.Publishing.publish_project(map.project, "some changes")

    map = Map.put(map, :publication, publication)

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
     ungraded_page_revision: map.ungraded_page.revision}
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
